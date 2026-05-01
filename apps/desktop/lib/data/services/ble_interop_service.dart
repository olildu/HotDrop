import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BleInteropService {
  Process? _serverProcess;
  bool _isStarted = false;
  String? _stagedExecutablePath;
  Socket? _hostStreamSocket;
  StreamSubscription<String>? _hostStreamSub;
  int _hostScanSession = 0;
  Timer? _pingTimer;
  int _failedPings = 0;
  bool _isRecovering = false;

  static const Duration _bridgeConnectTimeout = Duration(seconds: 5);

  void _log(String functionName, String message, {Object? error, StackTrace? stackTrace}) {
    dev.log(message, name: functionName, error: error, stackTrace: stackTrace);
  }

  String _getExePath(Function(String) log) {
    _log('_getExePath', 'Resolving BLE bridge executable path');
    final String executableName =
        Platform.isWindows ? 'HotDropBLE.exe' : 'HotDropBLE';
    final String fallbackName =
        Platform.isWindows ? 'HotDropBLE' : 'HotDropBLE.exe';

    String baseDir = p.dirname(Platform.resolvedExecutable);
    String prodPath = p.join(
        baseDir, 'data', 'flutter_assets', 'assets', 'bin', executableName);
    String prodFallbackPath = p.join(
        baseDir, 'data', 'flutter_assets', 'assets', 'bin', fallbackName);
    String projectRoot =
        p.normalize(p.join(baseDir, '..', '..', '..', '..', '..'));
    String devPath = p.join(projectRoot, 'assets', 'bin', executableName);
    String devFallbackPath = p.join(projectRoot, 'assets', 'bin', fallbackName);

    if (File(prodPath).existsSync()) return prodPath;
    if (File(prodFallbackPath).existsSync()) return prodFallbackPath;
    if (File(devPath).existsSync()) return devPath;
    if (File(devFallbackPath).existsSync()) return devFallbackPath;
    _log('_getExePath', 'BLE executable could not be resolved');
    throw Exception("BLE Executable not found.");
  }

  Future<String> _ensureExecutablePath(String sourcePath) async {
    if (!Platform.isLinux) {
      return sourcePath;
    }

    _log('_ensureExecutablePath', 'Ensuring Linux executable permissions for $sourcePath');

    final sourceFile = File(sourcePath);
    final stat = sourceFile.statSync();
    const int executableMask = 0x49;

    if ((stat.mode & executableMask) != 0) {
      return sourcePath;
    }

    final supportDir = await getApplicationSupportDirectory();
    final stagingDir = Directory(p.join(supportDir.path, 'bin'));
    if (!await stagingDir.exists()) {
      await stagingDir.create(recursive: true);
    }

    final stagedPath = p.join(stagingDir.path, p.basename(sourcePath));
    await sourceFile.copy(stagedPath);

    final chmodResult = await Process.run('chmod', ['+x', stagedPath]);
    if (chmodResult.exitCode != 0) {
      throw Exception(
          'Failed to mark BLE executable as runnable: ${chmodResult.stderr}');
    }

    _stagedExecutablePath = stagedPath;
    _log('_ensureExecutablePath', 'Staged BLE executable at $stagedPath');
    return stagedPath;
  }

  Future<void> _ensureServerRunning(Function(String) log) async {
    if (_serverProcess != null) return;
    try {
      _log('_ensureServerRunning', 'Starting BLE bridge process');
      final exePath = await _ensureExecutablePath(_getExePath(log));
      _serverProcess = await Process.start(exePath, []);
      await Future.delayed(const Duration(milliseconds: 500));
      _startPingService(log);
    } catch (e) {
      _log('_ensureServerRunning', 'Failed to start BLE bridge process', error: e);
      log("Start Error: $e");
    }
  }

  void _startPingService(Function(String) log) {
    _pingTimer?.cancel();
    _failedPings = 0;
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_serverProcess == null || _isRecovering) return;

      final res = await _sendCommand("ping", null, (_) {});
      if (res != null && res['status'] == 'pong') {
        _failedPings = 0;
      } else {
        _failedPings++;
        _log('_startPingService', 'Ping failed ($_failedPings/3)');
        if (_failedPings >= 3) {
          _handleRecovery(log);
        }
      }
    });
  }

  Future<void> _handleRecovery(Function(String) log) async {
    if (_isRecovering) return;
    _isRecovering = true;
    _log('_handleRecovery', 'Starting bridge recovery...');
    log("BLE Bridge not responding. Restarting...");

    try {
      await _stopServerGracefully();
      _serverProcess?.kill();
      _serverProcess = null;
      await Future.delayed(const Duration(seconds: 1));
      await _ensureServerRunning(log);
    } catch (e) {
      _log('_handleRecovery', 'Recovery failed', error: e);
    } finally {
      _isRecovering = false;
    }
  }

  Future<void> _stopServerGracefully() async {
    try {
      await _sendCommand("kill", null, (_) {}).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  Future<void> streamAvailableHosts(
    Function(Map<String, dynamic>) onHostFound,
    Function() onDone,
    Function(String) log,
  ) async {
    _log('streamAvailableHosts', 'Starting host discovery stream');
    await _ensureServerRunning(log);
    await stopHostScan();

    final int sessionId = ++_hostScanSession;

    try {
      final socket = await Socket.connect('127.0.0.1', 8765);
      _hostStreamSocket = socket;
      final payload = {"command": "stream_hosts"};
      socket.write(jsonEncode(payload));

      // Listen to the stream line by line
      _hostStreamSub = socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (String line) {
          if (sessionId != _hostScanSession) {
            return;
          }

          try {
            final data = jsonDecode(line);
            if (data['status'] == 'found') {
              onHostFound(data['host']); // Trigger callback with live data
            } else if (data['status'] == 'done') {
              socket.destroy();
            }
          } catch (e) {
            _log('streamAvailableHosts', 'Stream parse error', error: e);
            log("Stream parse error: $e");
          }
        },
        onDone: () {
          if (sessionId != _hostScanSession) {
            return;
          }

          onDone();
          _hostStreamSub = null;
          _hostStreamSocket = null;
          socket.destroy();
        },
        onError: (e) {
          if (sessionId != _hostScanSession) {
            return;
          }

          log("Stream socket error: $e");
          _log('streamAvailableHosts', 'Stream socket error', error: e);
          onDone();
          _hostStreamSub = null;
          _hostStreamSocket = null;
          socket.destroy();
        },
      );
    } catch (e) {
      _log('streamAvailableHosts', 'Stream connection error', error: e);
      log("Stream connection error: $e");
      onDone();
    }
  }

  Future<void> stopHostScan() async {
    _log('stopHostScan', 'Stopping host discovery stream');
    _hostScanSession++;

    try {
      await _hostStreamSub?.cancel();
    } catch (_) {}

    _hostStreamSub = null;
    _hostStreamSocket?.destroy();
    _hostStreamSocket = null;
  }

  Future<Map<String, dynamic>?> _sendCommand(
      String cmd, Map<String, dynamic>? extras, Function(String) log) async {
    _log('_sendCommand', 'Sending bridge command: $cmd');
    try {
      final socket = await Socket.connect('127.0.0.1', 8765)
          .timeout(_bridgeConnectTimeout);

      final Map<String, dynamic> payload = {"command": cmd};

      if (extras != null) {
        payload.addAll(extras);
      }

      socket.write(jsonEncode(payload));

      final response =
          await socket.cast<List<int>>().transform(utf8.decoder).join();
      socket.destroy();
      _log('_sendCommand', 'Received response for command: $cmd');

      return jsonDecode(response);
    } catch (e) {
      _log('_sendCommand', 'Socket communication error for command: $cmd', error: e);
      log("Socket communication error: $e");
      return null;
    }
  }

  Future<String?> _discoverLatestAddressByName(
    String hostName,
    Function(String) log,
  ) async {
    _log('_discoverLatestAddressByName', 'Rediscovering host address for name: $hostName');
    final completer = Completer<String?>();

    try {
      final socket = await Socket.connect('127.0.0.1', 8765)
          .timeout(_bridgeConnectTimeout);
      socket.write(jsonEncode({"command": "stream_hosts"}));

      late StreamSubscription<String> sub;
      sub = socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) async {
          try {
            final data = jsonDecode(line);
            final status = data['status']?.toString();

            if (status == 'found') {
              final host = data['host'];
              final name = host is Map ? host['name']?.toString() : null;
              final address = host is Map ? host['address']?.toString() : null;

              if (name == hostName && address != null && address.isNotEmpty) {
                if (!completer.isCompleted) {
                  completer.complete(address);
                }
                await sub.cancel();
                socket.destroy();
              }
            } else if (status == 'done') {
              if (!completer.isCompleted) {
                completer.complete(null);
              }
              await sub.cancel();
              socket.destroy();
            }
          } catch (_) {
            // Ignore malformed lines while scanning for a host update.
          }
        },
        onError: (_) async {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
          await sub.cancel();
          socket.destroy();
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
          socket.destroy();
        },
      );

      return completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () async {
          await sub.cancel();
          socket.destroy();
          return null;
        },
      );
    } catch (e) {
      _log('_discoverLatestAddressByName', 'Host rediscovery error', error: e);
      log('Host rediscovery error: $e');
      return null;
    }
  }

  // --- New Methods for Joiner Role ---
  Future<List<dynamic>> getAvailableHosts(Function(String) log) async {
    _log('getAvailableHosts', 'Fetching available hosts');
    await _ensureServerRunning(log);
    final res = await _sendCommand("list_hosts", null, log);
    return (res != null && res['status'] == 'success')
        ? res['hosts'] as List<dynamic>
        : [];
  }

  Future<Map<String, dynamic>?> fetchConnectionData(
    String address,
    String hostName,
    Function(String) log,
  ) async {
    _log('fetchConnectionData', 'Fetching connection data for $hostName at $address');
    await _ensureServerRunning(log);
    await stopHostScan();

    final first = await _sendCommand("connect_to", {"address": address}, log);
    _log('fetchConnectionData', 'Initial connect_to response: $first');
    if (first != null && first['status'] == 'success' && first['data'] is Map) {
      return Map<String, dynamic>.from(first['data']);
    }

    final firstErr = first?['message']?.toString();
    if (firstErr != null && firstErr.isNotEmpty) {
      log('Initial connect_to failed for $address: $firstErr');
    }

    final refreshedAddress = await _discoverLatestAddressByName(hostName, log);
    if (refreshedAddress == null || refreshedAddress == address) {
      return null;
    }

    log('Retrying connect_to with refreshed address: $refreshedAddress');
    final retry =
        await _sendCommand("connect_to", {"address": refreshedAddress}, log);
    if (retry != null && retry['status'] == 'success' && retry['data'] is Map) {
      return Map<String, dynamic>.from(retry['data']);
    }

    final retryErr = retry?['message']?.toString();
    if (retryErr != null && retryErr.isNotEmpty) {
      log('Retry connect_to failed for $refreshedAddress: $retryErr');
    }

    return null;
  }

  // --- Methods for Host Role ---
  Future<void> startAdvertising(String qrData, Function(String) log) async {
    _log('startAdvertising', 'Starting BLE advertising with payload');
    await _ensureServerRunning(log);
    await _sendCommand("start", {"data": qrData}, log);
    _isStarted = true;
  }

  Future<void> stopAdvertising(Function(String) log) async {
    if (!_isStarted) return;
    _log('stopAdvertising', 'Stopping BLE advertising');
    await _sendCommand("stop", null, log);
    _isStarted = false;
  }

  Future<void> dispose() async {
    _log('dispose', 'Disposing BLE interop service resources');
    _pingTimer?.cancel();
    await stopHostScan();
    await stopAdvertising((_) {});
    await _stopServerGracefully();

    if (_serverProcess != null) {
      if (Platform.isWindows) {
        Process.runSync(
            'taskkill', ['/F', '/T', '/PID', _serverProcess!.pid.toString()]);
      } else {
        _serverProcess!.kill();
      }
      _serverProcess = null;
    }

    if (_stagedExecutablePath != null) {
      try {
        final stagedDir = p.dirname(_stagedExecutablePath!);
        await File(_stagedExecutablePath!).delete();
        await Directory(stagedDir).delete(recursive: true);
      } catch (_) {}
      _stagedExecutablePath = null;
    }
  }
}
