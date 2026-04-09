import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data'; // Required for Uint8List
import 'package:ble_peripheral/ble_peripheral.dart';

class BlePeripheralService {
  static final BlePeripheralService _instance = BlePeripheralService._internal();
  factory BlePeripheralService() => _instance;
  BlePeripheralService._internal();

  // Same UUIDs from your Python script
  static const String serviceUuid = "0000FFFF-0000-1000-8000-00805F9B34FB";
  static const String charUuid = "0000FFFE-0000-1000-8000-00805F9B34FB";

  String _currentPayload = "{}";

  Future<void> startAdvertising(Map<String, String> connectionData) async {
    try {
      _currentPayload = jsonEncode(connectionData);

      // 1. Initialize
      await BlePeripheral.initialize();

      // 2. Define Service & Characteristic
      // Note: Use .index as the package expects integers for properties/permissions
      final service = BleService(
        uuid: serviceUuid,
        primary: true,
        characteristics: [
          BleCharacteristic(
            uuid: charUuid,
            properties: [CharacteristicProperties.read.index],
            permissions: [AttributePermissions.readable.index],
            value: Uint8List.fromList(utf8.encode(_currentPayload)),
          ),
        ],
      );

      await BlePeripheral.addService(service);

      // 3. Set Read Request Callback (FIX: Removed 'async' to make it synchronous)
      // 3. Set Read Request Callback (FIX: Added the 4th parameter 'value')
      BlePeripheral.setReadRequestCallback((deviceId, characteristicId, offset, value) {
        log("BLE Read Request from: $deviceId for: $characteristicId", name: "BLE-Host");

        if (characteristicId.toLowerCase() == charUuid.toLowerCase()) {
          log("BLE: Sending credentials to client: $_currentPayload");
          return ReadRequestResult(
            value: Uint8List.fromList(utf8.encode(_currentPayload)),
            offset: 0,
          );
        }

        return ReadRequestResult(value: Uint8List.fromList([]), offset: 0);
      });

      // 4. Start Advertising
      await BlePeripheral.startAdvertising(
        services: [serviceUuid],
        localName: "HotDrop-Android-Host",
      );

      log("BLE Host Started", name: "BLE-Host");
    } catch (e) {
      log("BLE Host Error: $e", name: "BLE-Host");
    }
  }

  Future<void> stopAdvertising() async {
    await BlePeripheral.stopAdvertising();
  }
}
