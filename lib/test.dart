
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:async';
import 'dart:isolate';


typedef StartDiscoveryFunc = Pointer<Utf8> Function();
typedef StartDiscovery = Pointer<Utf8> Function();

Isolate? discoveryIsolate;
Isolate? dummyIsolate;

class HelloWorldBridge {
  void discoveryFunction(SendPort sendPort) {
    try {
      final lib = DynamicLibrary.open('Tset.dll');
      final startDiscovery = lib.lookupFunction<StartDiscoveryFunc, StartDiscovery>('StartDiscovery');

      final result = startDiscovery();
      final message = result.address == 0 ? 'Null response' : result.toDartString();
      calloc.free(result);
      sendPort.send(message);
    } catch (e) {
      sendPort.send('Error: $e');
    }
  }

  Future<void> startDiscovery() async {
    final receivePort = ReceivePort();
    discoveryIsolate = await Isolate.spawn(discoveryFunction, receivePort.sendPort);

    receivePort.listen((message) {
      receivePort.close();
    });
  }

  String stopDiscovery() {
    try {
      final lib = DynamicLibrary.open('Tset.dll');
      final stopDiscovery = lib.lookupFunction<StartDiscoveryFunc, StartDiscovery>('StopDiscovery');
      final result = stopDiscovery();
      if (result.address == 0) return 'Null response';
      final message = result.toDartString();
      calloc.free(result);
      return message;
    } catch (e) {
      return 'Error: $e';
    }
  }


  void dummyFunction(SendPort sendPort) {
    int counter = 0;
    Timer.periodic(Duration(milliseconds: 500), (timer) {
      counter++;
      print("Isolate running... Count: $counter");
    });
  }

  Future<void> startDummyIsolate() async {
    final receivePort = ReceivePort();

    dummyIsolate = await Isolate.spawn(dummyFunction, receivePort.sendPort);

    receivePort.listen((message) {
      print("Main received: $message");
      receivePort.close();
    });
  }

  void dispose() {
    stopDiscovery();
  }
}
