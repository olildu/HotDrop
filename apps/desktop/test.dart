import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:async';
import 'dart:isolate';

typedef StartDiscoveryFunc = Pointer<Utf8> Function();
typedef StartDiscovery = Pointer<Utf8> Function();
int counter = 1;
Isolate? _discoveryIsolate;

void main() {
  HelloWorldBridge().startDiscovery1();
}

class HelloWorldBridge {
  static final HelloWorldBridge _instance = HelloWorldBridge._internal();
  late DynamicLibrary _lib;
  static RawReceivePort? _keepAlivePort;

  factory HelloWorldBridge() {
    return _instance;
  }

  HelloWorldBridge._internal() {
    try {
      _lib = DynamicLibrary.open('Tset.dll');
      _keepAlivePort = RawReceivePort((dynamic message) {});
    } catch (e) {
      print('Failed to load library: $e');
    }
  }

  Future<void> startDiscovery1() async {
    final receivePort = ReceivePort();
    _discoveryIsolate = await Isolate.spawn(_startDiscoveryIsolate, receivePort.sendPort);

    receivePort.listen((data) {
      print("Received from isolate: $data");
    });

    // Kill the isolate after 5 seconds
    Timer(Duration(seconds: 5), () {
      _discoveryIsolate?.kill(priority: Isolate.immediate);
      print("Discovery Isolate killed after 5 seconds.");
    });
  }

  static Future<void> _startDiscoveryIsolate(SendPort sendPort) async {
    final bridge = HelloWorldBridge();
    final message = bridge.startDiscovery(counter);
    sendPort.send(message);
  }

  String startDiscovery(int interval) {
    try {
      final startDiscovery = _lib.lookupFunction<StartDiscoveryFunc, StartDiscovery>('StartDiscovery');
      final startDiscoveryResult = startDiscovery();
      if (startDiscoveryResult.address == 0) return 'Null response';
      final message = startDiscoveryResult.toDartString();
      calloc.free(startDiscoveryResult);
      return message;
    } catch (e) {
      return 'Error: $e';
    }
  }

  String stopDiscovery() {
    try {
      final stopDiscovery = _lib.lookupFunction<StartDiscoveryFunc, StartDiscovery>('StopDiscovery');
      final result = stopDiscovery();
      if (result.address == 0) return 'Null response';
      final message = result.toDartString();
      calloc.free(result);
      return message;
    } catch (e) {
      return 'Error: $e';
    }
  }

  void dispose() {
    _keepAlivePort?.close();
    stopDiscovery();
  }
}
