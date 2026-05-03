import 'dart:io';

void main() async {
  final interfaces = await NetworkInterface.list();
  for (final interface in interfaces) {
    print('Interface: ${interface.name}');
    for (final addr in interface.addresses) {
      print('  Address: ${addr.address} (Type: ${addr.type}, Loopback: ${addr.isLoopback})');
    }
  }
}
