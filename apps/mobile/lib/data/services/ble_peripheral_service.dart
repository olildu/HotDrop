import 'dart:convert';
import 'dart:developer';
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
      log("BLE Native Host Started with payload: $payload", name: "BLE-Native");
    } on PlatformException catch (e) {
      log("BLE Native Host Error: '${e.message}'.", name: "BLE-Native");
    }
  }

  // (Optional) Call this if you ever need to push fresh Hotspot data without restarting advertising
  Future<void> updatePayload(Map<String, String> connectionData) async {
    try {
      final String payload = jsonEncode(connectionData);
      await _channel.invokeMethod('updatePayload', {'payload': payload});
      log("BLE Native Payload Updated: $payload", name: "BLE-Native");
    } on PlatformException catch (e) {
      log("BLE Native Update Error: '${e.message}'.", name: "BLE-Native");
    }
  }

  Future<void> stopAdvertising() async {
    try {
      await _channel.invokeMethod('stopAdvertising');
      log("BLE Native Host Stopped", name: "BLE-Native");
    } on PlatformException catch (e) {
      log("Failed to stop advertising: '${e.message}'.", name: "BLE-Native");
    }
  }
}