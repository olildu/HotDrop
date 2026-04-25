import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:test_mobile/data/constants/globals.dart'; // FIX: Add for socket/connectedToPort
import 'package:test_mobile/data/constants/globals.dart' as globals;
import 'package:test_mobile/data/services/connection_services.dart';
import 'package:test_mobile/data/services/ble_peripheral_service.dart';

class ConnectionRepository {
  final AndroidFunction _hostService = AndroidFunction();
  final ClientServices _clientService = ClientServices();

  Future<Map<String, String>?> hostSession() async {
    dev.log('Hosting session...', name: 'hostSession');
    return await _hostService.startHosting();
  }

  Future<bool> joinSession(String rawCredentials) async {
    dev.log('Joining session...', name: 'joinSession');
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
      dev.log('Failed to join session', name: 'joinSession', error: e);
      return false;
    }
  }

  void performCleanup() {
    dev.log('Performing connection cleanup', name: 'performCleanup');
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
      dev.log("Cleanup error", name: 'performCleanup', error: e);
    }
  }
}
