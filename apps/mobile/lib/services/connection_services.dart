import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart'; // ADDED
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_mobile/constants/globals.dart';
import 'package:test_mobile/screens/main_screen.dart'; // ADDED
import 'package:test_mobile/services/data_services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wifi_iot/wifi_iot.dart';

class AndroidFunction {
  static const platform = MethodChannel('com.example.wifi_direct/channel');

  Future<Map<String, String>?> startHosting() async {
    try {
      final Map<dynamic, dynamic>? creds = await platform.invokeMethod('startLocalOnlyHotspot');

      if (creds != null) {
        String ssid = creds['ssid'];
        String password = creds['password'];
        log("Hotspot Started: $ssid", name: "Host");

        await DartFunction().startServer();

        String hostIp = "192.168.43.1";
        try {
          final interfaces = await NetworkInterface.list();
          for (var interface in interfaces) {
            for (var addr in interface.addresses) {
              if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
                if (addr.address.startsWith('192.168.') || addr.address.startsWith('10.')) {
                  hostIp = addr.address;
                }
              }
            }
          }
        } catch (e) {
          log("Error finding Host IP: $e", name: "Host");
        }

        return {"ssid": ssid, "password": password, "ip": hostIp};
      }
    } on PlatformException catch (e) {
      log("Failed to start hotspot: '${e.message}'.", name: "Host");
    }
    return null;
  }

  Future<Map<String, dynamic>> checkConnectionStatus() async {
    if (connectedToPort) {
      return {"connectionStatus": 1, "deviceName": "Connected Device", "deviceIP": "Connected"};
    }
    return {"connectionStatus": 0, "deviceName": null, "deviceIP": null};
  }
}

class ClientServices {
  Future<bool> connectToHostHotspot(String ssid, String password, String hostIp, {bool isAuto = false}) async {
    try {
      log("Attempting to connect to Hotspot: $ssid", name: "Client");

      // 1. Attempt programmatic connection (Optimized for Android 10+)
      bool connected = await WiFiForIoTPlugin.connect(
        ssid,
        password: password,
        security: NetworkSecurity.WPA,
        withInternet: false,
        joinOnce: true, // CRITICAL: Forces the Android 10+ connection dialog
      );

      if (connected) {
        log("Successfully connected to Hotspot Wi-Fi programmatically!", name: "Client");
        await WiFiForIoTPlugin.forceWifiUsage(true);
        await Future.delayed(const Duration(seconds: 4)); // Wait for DHCP

        // Save credentials for future auto-reconnects
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_ssid', ssid);
        await prefs.setString('last_password', password);
        await prefs.setString('last_host_ip', hostIp);

        return await connectToHostSocket(hostIp, isAuto: isAuto);
      } else {
        // 2. ULTIMATE FALLBACK: Polling for manual connection
        log("Programmatic connection blocked by Android OS. Triggering manual fallback.", name: "Client");

        if (navigatorKey.currentContext != null) {
          // Copy password to clipboard
          await Clipboard.setData(ClipboardData(text: password));

          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            SnackBar(
              content: Text("Auto-connect blocked. Password '$password' copied!\n\nPlease open your Wi-Fi settings and connect to '$ssid'."),
              duration: const Duration(seconds: 10), // Give user time to read
            ),
          );
        }

        // 3. SMART POLLING: Wait until the user actually connects to the correct Wi-Fi
        bool userConnectedManually = false;
        log("Waiting for user to connect manually to $ssid...", name: "Client");

        for (int i = 0; i < 30; i++) {
          // Poll for up to 30 seconds
          await Future.delayed(const Duration(seconds: 1));

          String? currentSsid = await WiFiForIoTPlugin.getSSID();
          // Clean up quotes that Android sometimes adds around SSIDs
          String cleanSsid = currentSsid?.replaceAll('"', '') ?? '';

          if (cleanSsid == ssid) {
            userConnectedManually = true;
            break;
          }
        }

        if (userConnectedManually) {
          log("User successfully connected manually!", name: "Client");
          // Give Android 3 seconds to assign an IP address via DHCP
          await Future.delayed(const Duration(seconds: 3));

          // Save credentials for future auto-reconnects
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_ssid', ssid);
          await prefs.setString('last_password', password);
          await prefs.setString('last_host_ip', hostIp);

          return await connectToHostSocket(hostIp, isAuto: isAuto);
        } else {
          log("Timeout: User did not connect to the Hotspot within 30 seconds.", name: "Client");
          if (navigatorKey.currentContext != null) {
            ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
              const SnackBar(content: Text("Connection timeout. Please try scanning again.")),
            );
          }
          return false;
        }
      }
    } catch (e) {
      log("Error connecting to Wi-Fi: $e", name: "Client");
      return false;
    }
  }

  Future<bool> connectToHostSocket(String hostIp, {bool isAuto = false}) async {
    try {
      log("Connecting to TCP Server at $hostIp:42069...", name: "Client");
      socket = await Socket.connect(hostIp, 42069, timeout: const Duration(seconds: 5));
      connectedToPort = true;
      log("Connected to Host Socket!", name: "Client");

      if (navigatorKey.currentState != null) {
        Future.delayed(const Duration(milliseconds: 100), () {
          navigatorKey.currentState!.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (route) => false,
          );
        });
      }

      socket!.listen(
        (data) {
          final message = String.fromCharCodes(data).trim();
          log('Received: $message', name: "Client");
          ReceivedDataParser().parseData(message);
        },
        onError: (e) {
          log("Socket Error: $e", name: "Client");
          connectedToPort = false;
        },
        onDone: () {
          log("Socket closed by host", name: "Client");
          connectedToPort = false;
        },
      );

      return true;
    } catch (e) {
      log('Error connecting to socket: $e', name: "Client");
      return false; 
    }
  }

  // --- NEW: Auto Reconnect Function ---
  Future<bool> tryAutoReconnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? ssid = prefs.getString('last_ssid');
      String? password = prefs.getString('last_password');
      String? hostIp = prefs.getString('last_host_ip');

      if (ssid != null && password != null && hostIp != null) {
        log("Found previous session, attempting auto-reconnect...", name: "Client");
        return await connectToHostHotspot(ssid, password, hostIp, isAuto: true);
      }
    } catch (e) {
      log("Auto-reconnect failed: $e", name: "Client");
    }
    return false;
  }
}

class Permissions {
  Future<void> requestPermissions() async {
    await [
      Permission.location,
      Permission.nearbyWifiDevices,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.storage,
      Permission.manageExternalStorage,
      Permission.contacts,
      Permission.camera,
    ].request();
  }
}

class DartFunction {
  ServerSocket? _serverSocket;

  Future<void> startServer({int port = 42069}) async {
    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      log("TCP Server listening on port $port", name: "Server");

      _serverSocket!.listen((client) {
        log("New connection from ${client.remoteAddress.address}", name: "Server");
        handleClient(client);
      });
    } catch (e) {
      log("Error starting server: $e", name: "Server");
    }
  }

  void handleClient(Socket client) {
    socket = client;
    connectedToPort = true;

    // NEW: Force the Host's UI to refresh to the Main Screen, closing the QR code!
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MainScreen()),
      (route) => false,
    );

    _sendInitData();

    socket!.listen(
      (data) {
        final message = String.fromCharCodes(data).trim();
        log('Received: $message', name: "Server");
        ReceivedDataParser().parseData(message);
      },
      onError: (e) {
        log("Socket Error: $e", name: "Server");
        connectedToPort = false;
      },
      onDone: () {
        log("Client disconnected", name: "Server");
        connectedToPort = false;
      },
    );
  }

  Future<void> _sendInitData() async {
    if (await FlutterContacts.requestPermission()) {
      List<Contact> contacts = await FlutterContacts.getContacts(withProperties: true, withThumbnail: true);
      OutgoingDataParser().parseContacts(contacts);
    }
  }

  Future<void> sendDataToSocket(String message) async {
    if (socket != null) {
      try {
        socket!.write('$message\n');
        log("Sent: $message", name: "Socket");
      } catch (e) {
        log("Send Error: $e", name: "Socket");
      }
    }
  }
}
