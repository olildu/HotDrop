import 'dart:io';
import 'package:flutter/material.dart';
import 'package:test/constants/globals.dart' as globals;
import 'package:test/screens/main_screen.dart';
import 'package:test/services/data_services.dart';

Socket? socket;
ServerSocket? server;

class DartFunction {
  Future<void> openPort({BuildContext? context}) async {
    const int port = 42069;
    try {
      server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      print('Server listening on port $port');

      server?.listen((Socket client) {
        print('Connection from ${client.remoteAddress.address}:${client.remotePort}');
        client.setOption(SocketOption.tcpNoDelay, true);

        socket = client;

        Navigator.pushAndRemoveUntil(
          context!,
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (Route<dynamic> route) => false,
        );

        client.listen(
          (data) {
            final message = String.fromCharCodes(data).trim();
            ReceivedDataParser().parseData(message, context);
          },
          onError: (error) {
            print('Error: $error');
            client.close();
          },
          onDone: () {
            print('Client disconnected');
            socket = null;
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
    // Bring down the connection and delete the temporary profile
    Process.runSync('nmcli', ['connection', 'down', globals.activeHotspotSsid!]);
    Process.runSync('nmcli', ['connection', 'delete', globals.activeHotspotSsid!]);
  }
}

void sendMessage(String message) {
  if (message.isEmpty) return;
  socket?.write(message);
}
