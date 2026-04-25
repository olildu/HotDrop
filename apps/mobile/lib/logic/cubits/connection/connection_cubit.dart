import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:test_mobile/data/repositories/connection_repository.dart';
import 'package:test_mobile/data/services/connection_services.dart';

enum ConnectionStatus { idle, hosting, scanning, connecting, connected, error }

// Model for discovered peers, now including the BluetoothDevice for connection
class DiscoveredDevice {
  final String name;
  final String id;
  final String rawData;
  final BluetoothDevice device;

  DiscoveredDevice({
    required this.name,
    required this.id,
    required this.rawData,
    required this.device,
  });
}

class ConnectionCubitState {
  final ConnectionStatus status;
  final String? qrData;
  final String? errorMessage;
  final List<DiscoveredDevice> discoveredDevices;

  ConnectionCubitState({required this.status, this.qrData, this.errorMessage, this.discoveredDevices = const []});

  ConnectionCubitState copyWith({
    ConnectionStatus? status,
    String? qrData,
    String? errorMessage,
    List<DiscoveredDevice>? discoveredDevices,
  }) {
    return ConnectionCubitState(
      status: status ?? this.status,
      qrData: qrData ?? this.qrData,
      errorMessage: errorMessage ?? this.errorMessage,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
    );
  }
}

class ConnectionCubit extends Cubit<ConnectionCubitState> {
  final ConnectionRepository _repository;
  StreamSubscription? _scanSubscription;

  // UUIDs must match your BlePeripheralService
  static const String _serviceUuid = "0000ABCD-0000-1000-8000-00805F9B34FB";
  static const String _charUuid = "0000FFFE-0000-1000-8000-00805F9B34FB";

  ConnectionCubit(this._repository) : super(ConnectionCubitState(status: ConnectionStatus.idle)) {
    dev.log('Initializing ConnectionCubit', name: 'ConnectionCubit');
  }

  Future<void> initializeScreen({required bool isReceiving}) {
    dev.log('Initializing screen for ${isReceiving ? "receiving" : "sending"}', name: 'initializeScreen');
    return isReceiving ? startHosting() : startScanning();
  }

  bool shouldCloseScreen(ConnectionCubitState currentState) => currentState.status == ConnectionStatus.connected;

  String? errorText(ConnectionCubitState currentState) {
    if (currentState.status != ConnectionStatus.error) return null;
    return currentState.errorMessage ?? "Error";
  }

  bool isConnectingState(ConnectionCubitState currentState) => currentState.status == ConnectionStatus.connecting;

  String statusMessage({required bool isReceiving}) {
    if (state.status == ConnectionStatus.connecting) {
      return "Connecting to peer...";
    }
    return isReceiving ? "Waiting for connections..." : "Searching for receivers...";
  }

  Future<void> handleQrScan(String? rawCode) async {
    if (rawCode == null || rawCode.trim().isEmpty) return;
    await joinSession(rawCode);
  }

  /// Starts the Hotspot and begins BLE Advertising
  Future<void> startHosting() async {
    dev.log('Starting hotspot and BLE advertising', name: 'startHosting');
    stopBleOperations();
    emit(state.copyWith(status: ConnectionStatus.hosting, discoveredDevices: []));

    final creds = await _repository.hostSession();
    if (creds != null) {
      emit(state.copyWith(qrData: Uri.encodeFull(creds.toString())));
    } else {
      emit(state.copyWith(status: ConnectionStatus.error, errorMessage: "Failed to start host"));
    }
  }

  /// Initiates a BLE Scan for nearby HotDrop hosts
  Future<void> startScanning() async {
    dev.log('Starting BLE scan for nearby hosts', name: 'startScanning');
    stopBleOperations();
    emit(state.copyWith(status: ConnectionStatus.scanning, discoveredDevices: []));

    try {
      if (await FlutterBluePlus.isSupported == false) {
        emit(state.copyWith(status: ConnectionStatus.error, errorMessage: "BLE not supported on this device"));
        return;
      }

      // Ensure permissions are granted before starting hardware
      await Permissions().ensureBlePermissions();

      // Start the scan filtered by your unique service UUID
      await FlutterBluePlus.startScan(
        withServices: [Guid(_serviceUuid)],
        timeout: const Duration(seconds: 15),
      );

      // Map scan results into your DiscoveredDevice list
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        final devices = results
            .where((r) => r.device.platformName.isNotEmpty)
            .map((r) => DiscoveredDevice(
                  name: r.device.platformName,
                  id: r.device.remoteId.str,
                  rawData: "",
                  device: r.device,
                ))
            .toList();

        emit(state.copyWith(discoveredDevices: devices));
      });
    } catch (e) {
      emit(state.copyWith(status: ConnectionStatus.error, errorMessage: e.toString()));
    }
  }

  /// Connects to a found BLE peer and reads their Hotspot credentials
  Future<void> connectToDiscoveredDevice(DiscoveredDevice discovered) async {
    dev.log('Connecting to discovered device: ${discovered.name} (${discovered.id})', name: 'connectToDiscoveredDevice');
    stopBleOperations();
    emit(state.copyWith(status: ConnectionStatus.connecting));

    try {
      final device = discovered.device;
      await device.connect(timeout: const Duration(seconds: 5), license: License.free);

      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid == Guid(_serviceUuid)) {
          for (var char in service.characteristics) {
            if (char.uuid == Guid(_charUuid)) {
              // Read the JSON credentials from the peer
              List<int> value = await char.read();
              String jsonStr = utf8.decode(value);

              await device.disconnect();
              joinSession(jsonStr); // Join the Wi-Fi network
              return;
            }
          }
        }
      }
    } catch (e) {
      emit(state.copyWith(status: ConnectionStatus.error, errorMessage: "Failed to read peer credentials"));
    }
  }

  /// Joins the actual Wi-Fi session using credentials from QR or BLE
  Future<void> joinSession(String rawData) async {
    dev.log('Joining session using raw data', name: 'joinSession');
    emit(state.copyWith(status: ConnectionStatus.connecting));
    final success = await _repository.joinSession(rawData);
    if (success) {
      emit(state.copyWith(status: ConnectionStatus.connected));
    } else {
      emit(state.copyWith(status: ConnectionStatus.error, errorMessage: "Network Connection Failed"));
    }
  }

  void stopBleOperations() {
    dev.log('Stopping BLE operations', name: 'stopBleOperations');
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _repository.performCleanup();
    FlutterBluePlus.stopScan();
  }

  @override
  Future<void> close() {
    dev.log('Closing ConnectionCubit', name: 'close');
    stopBleOperations();
    return super.close();
  }
}
