import 'dart:io';

// Mocking the globals and logging for the test
class Globals {
  bool isHotspotActive = false;
}

final globals = Globals();

void _log(String name, String msg, {dynamic error}) {
  print('[$name] $msg ${error ?? ''}');
}

Future<String?> getBestIpAddress(List<MockInterface> interfaces) async {
  _log('_getBestIpAddress', 'Searching for the best local IP address...');
  String? selectedIp;
  int bestScore = -10000;

  for (final interface in interfaces) {
    final name = interface.name.toLowerCase();
    int baseScore = 0;

    // 1. Prioritize Wi-Fi and Hotspot interfaces
    if (name.contains('wi-fi') || name.contains('wifi') || name.contains('wlan') || name.contains('wlp') || name.contains('ap') || name.contains('uap')) {
      baseScore += 100;
    }
    // 2. Secondary priority for Ethernet
    else if (name.contains('eth') || name.contains('enp') || name.contains('eno')) {
      baseScore += 50;
    }
    // 3. De-prioritize or exclude virtual/bridge/tunnel interfaces
    if (name.contains('docker') ||
        name.contains('veth') ||
        name.contains('vbox') ||
        name.contains('vmware') ||
        name.contains('virtual') ||
        name.contains('tailscale') ||
        name.contains('zerotier') ||
        name.contains('br-') ||
        name.contains('tun') ||
        name.contains('tap') ||
        name.contains('wg') ||
        name.contains('anyconnect')) {
      baseScore -= 1000;
    }

    // 4. Windows specific hotspot names
    if (interface.name.contains('Local Area Connection*')) {
      baseScore += 150;
    }

    for (final addr in interface.addresses) {
      if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
        int currentScore = baseScore;

        // Link-local is almost never what we want
        if (addr.address.startsWith('169.254.')) {
          currentScore -= 500;
        }

        // If hotspot is active, prioritize known gateway IPs
        if (globals.isHotspotActive) {
          if (addr.address == '10.42.0.1' || addr.address == '192.168.137.1') {
            currentScore += 200;
          }
        }

        _log('_getBestIpAddress', 'Candidate: ${addr.address} on ${interface.name} (Score: $currentScore)');

        if (currentScore > bestScore) {
          bestScore = currentScore;
          selectedIp = addr.address;
        }
      }
    }
  }

  _log('_getBestIpAddress', 'Final selection: ${selectedIp ?? 'none'} (Best Score: $bestScore)');
  return selectedIp;
}

class MockInterface {
  final String name;
  final List<MockAddress> addresses;
  MockInterface(this.name, this.addresses);
}

class MockAddress {
  final String address;
  final InternetAddressType type;
  final bool isLoopback;
  MockAddress(this.address, {this.type = InternetAddressType.IPv4, this.isLoopback = false});
}

void main() async {
  print('--- Test Scenario 1: Normal WiFi ---');
  globals.isHotspotActive = false;
  final test1 = [
    MockInterface('lo', [MockAddress('127.0.0.1', isLoopback: true)]),
    MockInterface('eno1', [MockAddress('192.168.1.10')]),
    MockInterface('wlan0', [MockAddress('192.168.1.15')]),
  ];
  await getBestIpAddress(test1);

  print('\n--- Test Scenario 2: WiFi + Docker ---');
  final test2 = [
    MockInterface('wlan0', [MockAddress('192.168.1.15')]),
    MockInterface('docker0', [MockAddress('172.17.0.1')]),
  ];
  await getBestIpAddress(test2);

  print('\n--- Test Scenario 3: Linux Hotspot Active ---');
  globals.isHotspotActive = true;
  final test3 = [
    MockInterface('wlan0', [MockAddress('10.42.0.1')]),
    MockInterface('docker0', [MockAddress('172.17.0.1')]),
  ];
  await getBestIpAddress(test3);

  print('\n--- Test Scenario 4: Windows Hotspot Name ---');
  globals.isHotspotActive = true;
  final test4 = [
    MockInterface('Local Area Connection* 1', [MockAddress('192.168.137.1')]),
    MockInterface('Wi-Fi', [MockAddress('192.168.1.10')]),
  ];
  await getBestIpAddress(test4);

  print('\n--- Test Scenario 5: Virtual Interface matching wlan (edge case) ---');
  globals.isHotspotActive = false;
  final test5 = [
    MockInterface('vbox-wlan-bridge', [MockAddress('10.0.2.15')]),
    MockInterface('wlan0', [MockAddress('192.168.1.15')]),
  ];
  await getBestIpAddress(test5);
}
