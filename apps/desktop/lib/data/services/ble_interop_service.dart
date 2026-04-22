import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;

class BleInteropService {
  Process? _serverProcess;
  bool _isStarted = false;

  String _getExePath(Function(String) log) {
    String baseDir = p.dirname(Platform.resolvedExecutable);
    String prodPath = p.join(baseDir, 'data', 'flutter_assets', 'assets', 'bin', 'HotDropBLE.exe');
    String projectRoot = p.normalize(p.join(baseDir, '..', '..', '..', '..', '..'));
    String devPath = p.join(projectRoot, 'assets', 'bin', 'HotDropBLE.exe');

    if (File(prodPath).existsSync()) return prodPath;
    if (File(devPath).existsSync()) return devPath;
    throw Exception("BLE Executable not found.");
  }

  Future<void> _ensureServerRunning(Function(String) log) async {
    if (_serverProcess != null) return;
    try {
      final exePath = _getExePath(log);
      _serverProcess = await Process.start(exePath, []);
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      log("Start Error: $e");
    }
  }

  Future<void> streamAvailableHosts(
    Function(Map<String, dynamic>) onHostFound,
    Function() onDone,
    Function(String) log,
  ) async {
    await _ensureServerRunning(log);

    try {
      final socket = await Socket.connect('127.0.0.1', 8765);
      final payload = {"command": "stream_hosts"};
      socket.write(jsonEncode(payload));

      // Listen to the stream line by line
      socket.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen(
        (String line) {
          try {
            final data = jsonDecode(line);
            if (data['status'] == 'found') {
              onHostFound(data['host']); // Trigger callback with live data
            } else if (data['status'] == 'done') {
              socket.destroy();
              onDone();
            }
          } catch (e) {
            log("Stream parse error: $e");
          }
        },
        onDone: () {
          onDone();
          socket.destroy();
        },
        onError: (e) {
          log("Stream socket error: $e");
          onDone();
          socket.destroy();
        },
      );
    } catch (e) {
      log("Stream connection error: $e");
      onDone();
    }
  }

  Future<Map<String, dynamic>?> _sendCommand(String cmd, Map<String, dynamic>? extras, Function(String) log) async {
    try {
      final socket = await Socket.connect('127.0.0.1', 8765);

      final Map<String, dynamic> payload = {"command": cmd};

      if (extras != null) {
        payload.addAll(extras);
      }

      socket.write(jsonEncode(payload));

      final response = await socket.cast<List<int>>().transform(utf8.decoder).join();
      socket.destroy();

      return jsonDecode(response);
    } catch (e) {
      log("Socket communication error: $e");
      return null;
    }
  }

  // --- New Methods for Joiner Role ---
  Future<List<dynamic>> getAvailableHosts(Function(String) log) async {
    await _ensureServerRunning(log);
    final res = await _sendCommand("list_hosts", null, log);
    return (res != null && res['status'] == 'success') ? res['hosts'] as List<dynamic> : [];
  }

  Future<Map<String, dynamic>?> fetchConnectionData(String address, Function(String) log) async {
    final res = await _sendCommand("connect_to", {"address": address}, log);
    return (res != null && res['status'] == 'success') ? res['data'] : null;
  }

  // --- Methods for Host Role ---
  Future<void> startAdvertising(String qrData, Function(String) log) async {
    await _ensureServerRunning(log);
    await _sendCommand("start", {"data": qrData}, log);
    _isStarted = true;
  }

  Future<void> stopAdvertising(Function(String) log) async {
    if (!_isStarted) return;
    await _sendCommand("stop", null, log);
    _isStarted = false;
  }

  Future<void> dispose() async {
    await stopAdvertising((_) {});
    if (_serverProcess != null) {
      Process.runSync('taskkill', ['/F', '/T', '/PID', _serverProcess!.pid.toString()]);
      _serverProcess = null;
    }
  }
}
