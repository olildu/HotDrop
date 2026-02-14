import 'dart:io';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:test_mobile/constants/globals.dart';
import 'package:test_mobile/screens/main_screen.dart';
import 'package:test_mobile/services/data_services.dart';

class AndroidFunction {
  static const platform = MethodChannel('com.example.wifi_direct/channel');

  void initialize() {
    DartFunction().connectToPort("192.168.137.1", 42069);
    platform.setMethodCallHandler((call) async {
      if (call.method == "onPeerConnected") {
        String? deviceIP = call.arguments["deviceIP"];
        dev.log(deviceIP.toString(), name: "onPeerConnected");

        if (!connectedToPort) {
          await DartFunction().connectToPort(deviceIP!, 42069);
          Navigator.of(navigatorKey.currentContext!).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const MainScreen(),
            ),
          );
        }
      }
    });
  }

  Future<void> discoverPeers() async {
    try {
      await platform.invokeMethod('discoverPeers');
    } on PlatformException catch (e) {
      dev.log("Failed to discover peers: '${e.message}'.", name: "discoverPeers");
    }
  }

  Future<bool> setTargetDeviceName(String deviceName) async {
    initialize();
    try {
      final result = await platform.invokeMethod('setTargetDeviceName', {'deviceName': deviceName.toLowerCase()});
      dev.log("Result: $result", name: "setTargetDeviceName");

      checkConnectionStatus();

      return result;
    } on PlatformException catch (e) {
      dev.log("Failed to set target device name: ${e.message}", name: "setTargetDeviceName");
      return false;
    }
  }

  Future<Map<String, dynamic>> checkConnectionStatus() async {
    try {
      await platform.invokeMethod("initialize");
      final connectionInfo = await platform.invokeMethod<Map<dynamic, dynamic>>("checkConnectionStatus");
      if (connectionInfo != null && connectionInfo["deviceIP"].trim().isNotEmpty) {
        dev.log("Already connected to device at ${connectionInfo["deviceName"]}", name: "checkConnectionStatus");

        await Future.delayed(const Duration(seconds: 2));
        return {"connectionStatus" : 1, "deviceName" : connectionInfo["deviceName"], "deviceIP" : connectionInfo["deviceIP"],};
      } else {
        dev.log("No device connected", name: "checkConnectionStatus");
        await Future.delayed(const Duration(seconds: 2));
        return {"connectionStatus" : 1, "deviceName" : null, "deviceIP" : null,};
      }
    } catch (e) {
        dev.log("Failed to check connection status: $e", name: "checkConnectionStatus");
        await Future.delayed(const Duration(seconds: 2));
        return {"connectionStatus" : -1, "deviceName" : null, "deviceIP" : null,};
    } 
  }
}

class Permissions{
  Future<void> requestPermissions() async {
    await [
      Permission.location,
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
      Permission.storage,
      Permission.contacts
    ].request();
  }
}

class DartFunction {
  // Connect to the port and initialize the socket
  Future<void> connectToPort(String ipAddress, int port) async {
    try {
      dev.log(socket.toString(), name: "connectToPort");
      socket = await Socket.connect(ipAddress, port);
      dev.log("Connected to $ipAddress on port $port", name: "connectToPort");
      connectedToPort = true;

      List<Contact> contacts = await FlutterContacts.getContacts(withProperties: true, withThumbnail: true);
      OutgoingDataParser().parseContacts(contacts);

      dev.log(socket.toString(), name: "connectToPort");

      socket!.listen(
        (data) {
          // Handle incoming data here
          final message = String.fromCharCodes(data).trim();
          dev.log('Received message from client: $message', name: "connectToPort");
          ReceivedDataParser().parseData(message);
        },
        onError: (error) {
          dev.log("Socket error: $error", name: "connectToPort");
          connectedToPort = false; // Mark as disconnected if error occurs
        },
        onDone: () {
          dev.log("Socket closed", name: "connectToPort");
          connectedToPort = false; // Mark as disconnected when the socket closes
        },
      );
    } catch (e) {
      dev.log("Error connecting to $ipAddress on port $port: $e", name: "connectToPort");
      connectedToPort = false;
    }
  }

  // Send a message if connected
  Future<void> sendDataToSocket(String message) async {
    if (socket != null) {
      socket!.write(message);
      dev.log("Sent message: $message", name: "sendDataToSocket");
    } else {  
      dev.log("Cannot send message: Not connected to any socket.", name: "sendDataToSocket");
    }
  }

  Future<void> sendBigDataToSocket(String message) async {
    if (socket != null) {
      socket!.write(message);
    } else {
      dev.log("Cannot send message: Not connected to any socket.", name: "sendBigDataToSocket");
    }
  }

  // Close the socket connection when done
  void closeConnection() {
    socket?.close();
    dev.log("Socket closed manually.", name: "closeConnection");
    connectedToPort = false;
  }
}
