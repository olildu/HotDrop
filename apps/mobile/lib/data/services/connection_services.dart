import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_mobile/data/constants/globals.dart';
import 'package:test_mobile/presentation/screens/main_screen.dart';
import 'package:test_mobile/data/services/ble_peripheral_service.dart';
import 'package:test_mobile/data/services/data_services.dart';
import 'package:test_mobile/data/services/file_hosting_services.dart';
import 'package:test_mobile/data/services/security_service.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:device_info_plus/device_info_plus.dart';

// REPOSITORY AND BLOC IMPORTS
import 'package:test_mobile/logic/di/injection_container.dart' as di;
import 'package:test_mobile/logic/cubits/session/session_cubit.dart';
import 'package:test_mobile/data/repositories/file_repository.dart';
import 'package:test_mobile/logic/cubits/popup_cubit.dart';

void _logConnection(String functionName, String message, {Object? error, StackTrace? stackTrace}) {
  log(message, name: functionName, error: error, stackTrace: stackTrace);
}

class AndroidFunction {
  static const platform = MethodChannel('com.olildu.hotdrop.wifi_direct/channel');

  Future<Map<String, String>?> startHosting() async {
    try {
      await WiFiForIoTPlugin.forceWifiUsage(false);
      await WiFiForIoTPlugin.disconnect();
      await Future.delayed(const Duration(seconds: 1));

      await platform.invokeMethod('stopLocalOnlyHotspot');
      await Future.delayed(const Duration(seconds: 1));

      final Map<dynamic, dynamic>? creds = await platform.invokeMethod('startLocalOnlyHotspot');

      if (creds != null) {
        String ssid = creds['ssid'] ?? "";
        String password = creds['password'] ?? "";
        _logConnection('startHosting', "Hotspot Started: $ssid");

        String hostIp = await FileHostingService().getLocalIpAddress();

        await DartFunction().startServer(hostIp);

        // Generate a random 4-digit PIN for BLE encryption
        final String pin = (1000 + (9000 * (DateTime.now().millisecondsSinceEpoch % 1000) / 1000)).toInt().toString();
        
        final rawData = {"ssid": ssid, "password": password, "ip": hostIp};
        final encryptedPayload = SecurityService().encryptBleData(rawData, pin);

        await BlePeripheralService().startAdvertising({"payload": encryptedPayload});

        final connectionData = {...rawData, "blePin": pin};
        return connectionData;
      }
    } on PlatformException catch (e) {
      _logConnection('startHosting', "Failed to start hotspot: '${e.message}'.", error: e);
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
      _logConnection('connectToHostHotspot', "Attempting to connect to Hotspot: $ssid (Auto: $isAuto)");

      // 1. Attempt programmatic connection
      bool connected = await WiFiForIoTPlugin.connect(
        ssid,
        password: password,
        security: NetworkSecurity.WPA,
        withInternet: false,
        joinOnce: true,
      );

      if (connected) {
        _logConnection('connectToHostHotspot', "Successfully connected to Hotspot Wi-Fi!");
        await WiFiForIoTPlugin.forceWifiUsage(true);
        // Wait for DHCP - shorter for auto
        await Future.delayed(Duration(seconds: isAuto ? 2 : 4));

        return await connectToHostSocket(hostIp, isAuto: isAuto);
      } else {
        // FAIL FAST on Auto-reconnect to avoid blocking the app
        if (isAuto) {
          _logConnection('connectToHostHotspot', "Auto-reconnect Wi-Fi failed. Aborting to prevent UI lag.");
          return false;
        }

        // --- MANUAL FALLBACK (Only for user-initiated) ---
        _logConnection('connectToHostHotspot', "Triggering manual fallback for user-initiated connection.");
        if (navigatorKey.currentContext != null) {
          await Clipboard.setData(ClipboardData(text: password));
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            SnackBar(content: Text("Auto-connect blocked. Password '$password' copied!")),
          );
        }

        // Long polling loop (30 seconds)
        for (int i = 0; i < 30; i++) {
          await Future.delayed(const Duration(seconds: 1));
          String? currentSsid = await WiFiForIoTPlugin.getSSID();
          if ((currentSsid?.replaceAll('"', '') ?? '') == ssid) {
            await Future.delayed(const Duration(seconds: 2));
            return await connectToHostSocket(hostIp, isAuto: isAuto);
          }
        }
        return false;
      }
    } catch (e) {
      _logConnection('connectToHostHotspot', "Error connecting to Wi-Fi", error: e);
      return false;
    }
  }

  Future<bool> connectToHostSocket(String hostIp, {bool isAuto = false}) async {
    // Reduce retries for background auto-reconnect
    int maxRetries = isAuto ? 2 : 5;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        retryCount++;
        // Delay before attempt - skip on first auto attempt
        if (retryCount > 1 || !isAuto) await Future.delayed(const Duration(seconds: 2));

        String? gatewayIp = await NetworkInfo().getWifiGatewayIP();
        String targetIp = (gatewayIp != null && gatewayIp != "0.0.0.0") ? gatewayIp : hostIp;

        _logConnection('connectToHostSocket', "Socket Attempt $retryCount: Connecting to $targetIp:42069...");

        final context = await SecurityService().getClientContext();
        socket = await SecureSocket.connect(
          targetIp,
          42069,
          timeout: const Duration(seconds: 3),
          context: context,
          onBadCertificate: (cert) => true, // Allow self-signed certificates
        );
        connectedToPort = true;

        di.sl<SessionCubit>().updateConnectionStatus(true);
        _logConnection('connectToHostSocket', "Connected to Host Socket!");

        _sendPairingRequest();

        socket!.listen(
          (data) {
            final message = String.fromCharCodes(data).trim();
            ReceivedDataParser(di.sl<FileRepository>()).parseData(message);
          },
          onError: (e) {
            connectedToPort = false;
            di.sl<SessionCubit>().updateConnectionStatus(false);
            di.sl<PopupCubit>().hide();
          },
          onDone: () {
            connectedToPort = false;
            di.sl<SessionCubit>().updateConnectionStatus(false);
            di.sl<PopupCubit>().hide();
          },
        );
        return true;
      } catch (e) {
        _logConnection('connectToHostSocket', 'Socket attempt $retryCount failed', error: e);
      }
    }
    return false;
  }

  Future<bool> tryAutoReconnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? ssid = prefs.getString('last_ssid');
      String? password = prefs.getString('last_password');
      String? hostIp = prefs.getString('last_host_ip');

      if (ssid != null && password != null && hostIp != null) {
        _logConnection('tryAutoReconnect', "Previous session found. Attempting background reconnect...");
        // isAuto: true triggers the high-speed logic
        return await connectToHostHotspot(ssid, password, hostIp, isAuto: true);
      }
    } catch (e) {
      _logConnection('tryAutoReconnect', "Auto-reconnect aborted", error: e);
    }
    return false;
  }

  Future<void> _sendPairingRequest() async {
    String deviceName = "Unknown Mobile";
    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        deviceName = "${info.manufacturer} ${info.model}";
      } else if (Platform.isIOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        deviceName = info.name;
      }
    } catch (e) {
      deviceName = Platform.localHostname;
    }

    if (socket != null) {
      socket!.write(jsonEncode({
        "type": "pairing_request",
        "deviceName": deviceName,
      }) + '\n');
    }
  }
}

class DartFunction {
  dynamic _serverSocket; // Can be ServerSocket or SecureServerSocket

  Future<void> startServer(String hostIp, {int port = 42069}) async {
    if (_serverSocket != null) return;

    int retryCount = 0;
    while (retryCount < 5) {
      try {
        final context = await SecurityService().getServerContext();
        _serverSocket = await SecureServerSocket.bind(
          InternetAddress.anyIPv4,
          port,
          context,
          shared: true,
        );
        _logConnection('startServer', "Secure TCP Server listening on $hostIp:$port");

        _serverSocket!.listen((SecureSocket client) {
          _logConnection('startServer', "New secure connection from ${client.remoteAddress.address}");
          handleClient(client);
        });
        return;
      } catch (e) {
        retryCount++;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  void handleClient(Socket client) {
    socket = client;
    connectedToPort = true;

    // ---> FIX: Notify UI of connection
    di.sl<SessionCubit>().updateConnectionStatus(true);

    BlePeripheralService().stopAdvertising();

    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MainScreen()),
      (route) => false,
    );

    _sendPairingRequest();
    _sendInitData();

    socket!.listen(
      (data) {
        final message = String.fromCharCodes(data).trim();
        _logConnection('handleClient', 'Received: $message');

        // ---> FIX: Pass Repositories to Parser
        ReceivedDataParser(di.sl<FileRepository>()).parseData(message);
      },
      onError: (e) {
        _logConnection('handleClient', "Socket Error", error: e);
        connectedToPort = false;
        di.sl<SessionCubit>().updateConnectionStatus(false);
        di.sl<PopupCubit>().hide();
      },
      onDone: () {
        _logConnection('handleClient', "Client disconnected");
        connectedToPort = false;
        di.sl<SessionCubit>().updateConnectionStatus(false);
        di.sl<PopupCubit>().hide();
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
        _logConnection('sendDataToSocket', "Sent: $message");
      } catch (e) {
        _logConnection('sendDataToSocket', "Send Error", error: e);
      }
    }
  }

  Future<void> _sendPairingRequest() async {
    String deviceName = "Unknown Mobile";
    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        deviceName = "${info.manufacturer} ${info.model}";
      } else if (Platform.isIOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        deviceName = info.name;
      }
    } catch (e) {
      deviceName = Platform.localHostname;
    }

    sendDataToSocket(jsonEncode({
      "type": "pairing_request",
      "deviceName": deviceName,
    }));
  }
}

class Permissions {
  Future<void> requestPermissions() async {
    List<Permission> permissions = [Permission.location, Permission.contacts, Permission.camera];
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      if (sdkInt >= 31) {
        permissions.addAll([Permission.bluetoothScan, Permission.bluetoothAdvertise, Permission.bluetoothConnect, Permission.nearbyWifiDevices]);
      } else {
        permissions.add(Permission.bluetooth);
      }
      if (sdkInt < 33) permissions.add(Permission.storage);
    }
    await permissions.request();
  }

  Future<void> ensureBlePermissions() async {
    bool isGranted = true;
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 31) {
        final scan = await Permission.bluetoothScan.request();
        final connect = await Permission.bluetoothConnect.request();
        if (scan != PermissionStatus.granted || connect != PermissionStatus.granted) isGranted = false;
      } else {
        final location = await Permission.location.request();
        if (location != PermissionStatus.granted) isGranted = false;
      }
    }
    if (!isGranted) throw Exception("BLE permissions not granted");
  }
}
