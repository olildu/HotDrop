import 'dart:io';
import 'dart:developer' as dev;
import 'package:path/path.dart' as p;

class FirewallService {
  static final FirewallService _instance = FirewallService._internal();
  factory FirewallService() => _instance;
  FirewallService._internal();

  Future<void> ensureRules() async {
    if (Platform.isWindows) {
      await _setupWindowsFirewall();
    } else if (Platform.isLinux) {
      await _setupLinuxFirewall();
    }
  }

  Future<void> _setupWindowsFirewall() async {
    try {
      // Check if rule exists
      final checkResult = await Process.run('netsh', [
        'advfirewall',
        'firewall',
        'show',
        'rule',
        'name=HotDrop P2P'
      ]);

      if (checkResult.exitCode == 0) {
        dev.log('Firewall rule already exists on Windows', name: 'FirewallService');
        return;
      }

      dev.log('Creating Windows firewall rule...', name: 'FirewallService');
      
      // We use 'powershell' to trigger the UAC prompt via Start-Process -Verb RunAs
      // This command adds a rule for the port range we use
      final command = 'netsh advfirewall firewall add rule name="HotDrop P2P" dir=in action=allow protocol=TCP localport=1024-65535 profile=any';
      
      await Process.run('powershell', [
        '-Command',
        'Start-Process powershell -ArgumentList "-Command $command" -Verb RunAs'
      ]);
      
    } catch (e) {
      dev.log('Failed to setup Windows firewall', name: 'FirewallService', error: e);
    }
  }

  Future<void> _setupLinuxFirewall() async {
    try {
      // Find the bundled script
      final String baseDir = p.dirname(Platform.resolvedExecutable);
      final String scriptPath = p.join(baseDir, 'data', 'flutter_assets', 'assets', 'bin', 'setup-firewall.sh');
      
      if (!File(scriptPath).existsSync()) {
        dev.log('Firewall script not found at $scriptPath', name: 'FirewallService');
        return;
      }

      dev.log('Running Linux firewall script via pkexec...', name: 'FirewallService');
      
      // pkexec will show a graphical sudo prompt
      await Process.run('pkexec', ['bash', scriptPath]);
      
    } catch (e) {
      dev.log('Failed to setup Linux firewall', name: 'FirewallService', error: e);
    }
  }
}
