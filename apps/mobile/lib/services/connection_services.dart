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
      log("Connecting to Hotspot: $ssid", name: "Client");

      bool connected = await WiFiForIoTPlugin.connect(
        ssid,
        password: password,
        security: NetworkSecurity.WPA,
        withInternet: false,
      );

      if (connected) {
        log("Successfully connected to Hotspot Wi-Fi!", name: "Client");
        await WiFiForIoTPlugin.forceWifiUsage(true);
        await Future.delayed(const Duration(seconds: 3));

        log("Connecting to Host IP: $hostIp", name: "Client");

        // Save credentials for future auto-reconnects
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_ssid', ssid);
        await prefs.setString('last_password', password);
        await prefs.setString('last_host_ip', hostIp);

        await connectToHostSocket(hostIp, isAuto: isAuto);
        return true;
      }
      return false;
    } catch (e) {
      log("Error connecting to Wi-Fi: $e", name: "Client");
      return false;
    }
  }

  Future<void> connectToHostSocket(String hostIp, {bool isAuto = false}) async {
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
    } catch (e) {
      log('Error connecting to socket: $e', name: "Client");
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
