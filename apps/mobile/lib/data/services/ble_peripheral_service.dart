import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/services.dart';

class BlePeripheralService {
  static final BlePeripheralService _instance = BlePeripheralService._internal();
  factory BlePeripheralService() => _instance;
  BlePeripheralService._internal();

  // Links directly to the new channel in MainActivity.kt
  static const MethodChannel _channel = MethodChannel('com.example.ble_poc/peripheral');

  Future<void> startAdvertising(Map<String, String> connectionData) async {
    try {
      final String payload = jsonEncode(connectionData);
      
      // Pass the payload string to the native side
      await _channel.invokeMethod('startAdvertising', {'payload': payload});
      dev.log("BLE Native Host Started with payload: $payload", name: "startAdvertising");
    } on PlatformException catch (e) {
      dev.log("BLE Native Host Error: '${e.message}'.", name: "startAdvertising", error: e);
    }
  }

  // (Optional) Call this if you ever need to push fresh Hotspot data without restarting advertising
  Future<void> updatePayload(Map<String, String> connectionData) async {
    try {
      final String payload = jsonEncode(connectionData);
      await _channel.invokeMethod('updatePayload', {'payload': payload});
      dev.log("BLE Native Payload Updated: $payload", name: "updatePayload");
    } on PlatformException catch (e) {
      dev.log("BLE Native Update Error: '${e.message}'.", name: "updatePayload", error: e);
    }
  }

  Future<void> stopAdvertising() async {
    try {
      await _channel.invokeMethod('stopAdvertising');
      dev.log("BLE Native Host Stopped", name: "stopAdvertising");
    } on PlatformException catch (e) {
      dev.log("Failed to stop advertising: '${e.message}'.", name: "stopAdvertising", error: e);
    }
  }
}