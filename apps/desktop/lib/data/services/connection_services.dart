import 'dart:io';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';

import 'package:test/logic/constants/globals.dart' as globals;
import 'package:test/presentation/screens/main_screen.dart';
import 'data_services.dart';

Socket? socket;
ServerSocket? server;

void _logConnection(String functionName, String message, {Object? error, StackTrace? stackTrace}) {
  dev.log(message, name: functionName, error: error, stackTrace: stackTrace);
}

class DartFunction {
  Future<void> openPort({
    BuildContext? context,
    VoidCallback? onClientConnected,
    VoidCallback? onClientDisconnected,
  }) async {
    const int port = 42069;
    _logConnection('openPort', 'Opening TCP server on port $port');
    try {
      // FIX: Close any existing server before starting a new one
      await server?.close();
      server = null;

      // FIX: Add shared: true
      server = await ServerSocket.bind(InternetAddress.anyIPv4, port, shared: true);
      _logConnection('openPort', 'Server listening on port $port');

      server?.listen((Socket client) {
        _logConnection('openPort', 'Client connected from ${client.remoteAddress.address}:${client.remotePort}');
        client.setOption(SocketOption.tcpNoDelay, true);

        socket = client;
        onClientConnected?.call();

        Navigator.pushAndRemoveUntil(context!, MaterialPageRoute(builder: (context) => const MainScreen()), (Route<dynamic> route) => false);

        client.listen(
          (data) {
            final rawString = String.fromCharCodes(data);
            final messages = rawString.split('\n');
            for (var msg in messages) {
              if (msg.trim().isNotEmpty) {
                ReceivedDataParser().parseData(msg.trim());
              }
            }
          },
          onError: (error) {
            _logConnection('openPort', 'Socket stream error', error: error);
            client.close();
          },
          onDone: () {
            _logConnection('openPort', 'Client disconnected');
            socket = null;
            onClientDisconnected?.call();
            client.close();
          },
        );
      });
    } catch (e) {
      _logConnection('openPort', 'Error opening port', error: e);
    }
  }

  void closePort() {
    _logConnection('closePort', 'Closing server and socket manually');
    socket?.close();
    server?.close();
    socket = null;
    server = null;
  }

  void _navigateToMain(BuildContext context) {
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MainScreen()), (r) => false);
  }

  Future<void> connectToHost(String ip, {BuildContext? context}) async {
    _logConnection('connectToHost', 'Connecting to host at $ip:42069');
    try {
      socket = await Socket.connect(ip, 42069, timeout: const Duration(seconds: 10));
      socket!.setOption(SocketOption.tcpNoDelay, true);
      _navigateToMain(context!);

      socket!.listen((data) {
        final rawString = String.fromCharCodes(data);
        final messages = rawString.split('\n');
        for (var msg in messages) {
          if (msg.trim().isNotEmpty) {
            ReceivedDataParser().parseData(msg.trim());
          }
        }
      });
      _logConnection('connectToHost', 'Connected to host and listener attached');
    } catch (e) {
      _logConnection('connectToHost', 'Failed to connect to host', error: e);
      rethrow;
    }
  }

  Future<bool> sendMessage(String message) async {
    try {
      if (message.isEmpty) return false;

      if (socket == null) {
        _logConnection('sendMessage', 'No active connection available');
        return false;
      }

      socket!.write('$message\n');
      _logConnection('sendMessage', 'Message sent (${message.length} chars)');
      return true;
    } catch (e) {
      _logConnection('sendMessage', 'Error sending message', error: e);
      return false;
    }
  }

  bool isConnected() {
    return socket != null;
  }
}

void shutdownHotspotSync() {
  if (!globals.isHotspotActive) return;

  _logConnection('shutdownHotspotSync', 'Shutting down mobile hotspot');

  if (Platform.isWindows) {
    const psScript = '''
      \$ErrorActionPreference = 'SilentlyContinue'
      Add-Type -AssemblyName System.Runtime.WindowsRuntime
      
      \$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | ? { 
          \$_.Name -eq 'AsTask' -and \$_.GetParameters().Count -eq 1 -and \$_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' 
      })[0]
      
      Function Await(\$WinRtTask, \$ResultType) {
          \$asTask = \$asTaskGeneric.MakeGenericMethod(\$ResultType)
          \$netTask = \$asTask.Invoke(\$null, @(\$WinRtTask))
          \$netTask.Wait(-1) | Out-Null
      }

      \$connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile()
      
      if (\$null -ne \$connectionProfile) {
          \$tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile(\$connectionProfile)
          Await (\$tetheringManager.StopTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult])
      }
    ''';
    Process.runSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', psScript]);
  } else if (Platform.isLinux && globals.activeHotspotSsid != null) {
    Process.runSync('nmcli', ['connection', 'down', globals.activeHotspotSsid!]);
    Process.runSync('nmcli', ['connection', 'delete', globals.activeHotspotSsid!]);
  }
}

Future<void> hardCleanupOnStartup() async {
  _logConnection('hardCleanupOnStartup', 'Performing hard cleanup on startup');
  try {
    if (Platform.isWindows) {
      Process.runSync('taskkill', ['/F', '/IM', 'HotDropBLE.exe', '/T']);

      const psScript = '''
        \$ErrorActionPreference = 'SilentlyContinue'
        Add-Type -AssemblyName System.Runtime.WindowsRuntime
        
        \$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | ? { 
            \$_.Name -eq 'AsTask' -and \$_.GetParameters().Count -eq 1 -and \$_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' 
        })[0]
        
        Function Await(\$WinRtTask, \$ResultType) {
            \$asTask = \$asTaskGeneric.MakeGenericMethod(\$ResultType)
            \$netTask = \$asTask.Invoke(\$null, @(\$WinRtTask))
            \$netTask.Wait(-1) | Out-Null
        }

        \$connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile()
        
        if (\$null -ne \$connectionProfile) {
            \$tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile(\$connectionProfile)
            Await (\$tetheringManager.StopTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult])
        }
      ''';
      Process.runSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', psScript]);
    } else if (Platform.isLinux) {
      Process.runSync('pkill', ['-f', 'HotDropBLE']);

      final result = Process.runSync('nmcli', ['-t', '-f', 'NAME', 'connection', 'show']);
      final lines = result.stdout.toString().split('\n');
      for (var line in lines) {
        if (line.trim().startsWith('HotDrop_')) {
          Process.runSync('nmcli', ['connection', 'down', line.trim()]);
          Process.runSync('nmcli', ['connection', 'delete', line.trim()]);
        }
      }
    }
  } catch (e) {
    _logConnection('hardCleanupOnStartup', 'Startup cleanup encountered an error (safe to ignore)', error: e);
  }
}

void sendMessage(String message) {
  if (message.isEmpty) return;
  socket?.write(message);
}
