import 'dart:io';
import 'package:flutter/material.dart';

import 'package:test/logic/constants/globals.dart' as globals;
import 'package:test/presentation/screens/main_screen.dart';
import 'data_services.dart';

Socket? socket;
ServerSocket? server;

class DartFunction {
  Future<void> openPort({
    BuildContext? context,
    VoidCallback? onClientConnected,
    VoidCallback? onClientDisconnected,
  }) async {
    const int port = 42069;
    try {
      // FIX: Close any existing server before starting a new one
      await server?.close();
      server = null;

      // FIX: Add shared: true
      server = await ServerSocket.bind(InternetAddress.anyIPv4, port, shared: true);
      print('Server listening on port $port');

      server?.listen((Socket client) {
        print('Connection from ${client.remoteAddress.address}:${client.remotePort}');
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
            print('Error: $error');
            client.close();
          },
          onDone: () {
            print('Client disconnected');
            socket = null;
            onClientDisconnected?.call();
            client.close();
          },
        );
      });
    } catch (e) {
      print('Error opening port: $e');
    }
  }

  void closePort() {
    print("Closing port manually");
    socket?.close();
    server?.close();
    socket = null;
    server = null;
  }

  void _navigateToMain(BuildContext context) {
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MainScreen()), (r) => false);
  }

  Future<void> connectToHost(String ip, {BuildContext? context}) async {
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
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> sendMessage(String message) async {
    try {
      if (message.isEmpty) return false;

      if (socket == null) {
        print('Error: No active connection');
        return false;
      }

      socket!.write('$message\n');
      print('Message sent: $message');
      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  bool isConnected() {
    return socket != null;
  }
}

void shutdownHotspotSync() {
  if (!globals.isHotspotActive) return;

  print("Shutting down Mobile Hotspot...");

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
  print("Performing hard cleanup on startup...");
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
    print("Startup cleanup encountered an error (safe to ignore): $e");
  }
}

void sendMessage(String message) {
  if (message.isEmpty) return;
  socket?.write(message);
}
