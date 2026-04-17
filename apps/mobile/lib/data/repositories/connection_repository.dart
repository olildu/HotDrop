import 'dart:async';
import 'dart:convert';
import 'dart:developer'; // FIX: Add for log
import 'package:test_mobile/constants/globals.dart'; // FIX: Add for socket/connectedToPort
import 'package:test_mobile/constants/globals.dart' as globals;
import 'package:test_mobile/services/connection_services.dart';
import 'package:test_mobile/services/ble_peripheral_service.dart';

class ConnectionRepository {
  final AndroidFunction _hostService = AndroidFunction();
  final ClientServices _clientService = ClientServices();

  Future<Map<String, String>?> hostSession() async {
    return await _hostService.startHosting();
  }

  Future<bool> joinSession(String rawCredentials) async {
    try {
      final creds = jsonDecode(rawCredentials);
      if (creds['isDesktop'] == true) {
        return await _clientService.connectToHostSocket(creds['ip']);
      } else {
        return await _clientService.connectToHostHotspot(
          creds['ssid'],
          creds['password'],
          creds['ip'] ?? "192.168.43.1",
        );
      }
    } catch (e) {
      return false;
    }
  }

  void performCleanup() {
    try {
      BlePeripheralService().stopAdvertising();
      if (globals.connectedToPort == false) {
        AndroidFunction.platform.invokeMethod('stopLocalOnlyHotspot');
      }
      // Now these identifiers are recognized
      if (socket != null) {
        socket!.destroy();
        socket = null;
        connectedToPort = false;
      }
    } catch (e) {
      log("Cleanup error: $e");
    }
  }
}
