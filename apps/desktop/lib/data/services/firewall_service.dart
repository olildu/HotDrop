import 'dart:io';
import 'dart:developer' as dev;
import 'package:path/path.dart' as p;

class FirewallService {
  static final FirewallService _instance = FirewallService._internal();
  factory FirewallService() => _instance;
  FirewallService._internal();

  // Track ports we've already configured to avoid redundant pkexec prompts
  final Set<int> _configuredPorts = {};
  
  // Prevent concurrent configuration runs
  Future<void>? _ongoingConfiguration;

  Future<void> ensureRules({int? port}) async {
    if (port != null) {
      await ensureRulesForPorts([port]);
    } else {
      await ensureRulesForPorts([42069]); // Default port
    }
  }

  void markPortsAsConfigured(List<int> ports) {
    _configuredPorts.addAll(ports);
    dev.log('Ports ${ports.join(', ')} marked as configured.', name: 'FirewallService');
  }

  Future<void> ensureRulesForPorts(List<int> ports) async {
    // If there's an ongoing configuration, wait for it
    if (_ongoingConfiguration != null) {
      await _ongoingConfiguration;
    }

    // After waiting, check again if we still need to configure anything
    final portsToConfigure = ports.where((p) => !_configuredPorts.contains(p)).toList();
    if (portsToConfigure.isEmpty) return;

    _ongoingConfiguration = _executeConfiguration(portsToConfigure);
    try {
      await _ongoingConfiguration;
    } finally {
      _ongoingConfiguration = null;
    }
  }

  Future<void> _executeConfiguration(List<int> portsToConfigure) async {
    if (Platform.isWindows) {
      await _setupWindowsFirewall();
    } else if (Platform.isLinux) {
      await _setupLinuxFirewall(ports: portsToConfigure);
    }
    _configuredPorts.addAll(portsToConfigure);
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

  Future<void> _setupLinuxFirewall({required List<int> ports}) async {
    try {
      // Find the bundled script
      final String baseDir = p.dirname(Platform.resolvedExecutable);
      
      // Production path (bundled app)
      String scriptPath = p.join(baseDir, 'data', 'flutter_assets', 'assets', 'bin', 'setup-firewall.sh');
      
      // Development path fallback
      if (!File(scriptPath).existsSync()) {
        final String debugPath = p.join(baseDir, 'assets', 'bin', 'setup-firewall.sh');
        if (File(debugPath).existsSync()) {
          scriptPath = debugPath;
        } else {
          dev.log('Firewall script not found at $scriptPath', name: 'FirewallService');
          return;
        }
      }

      // The --check mode was triggering Polkit prompts on some distributions.
      // We rely entirely on the _configuredPorts lock/cache to prevent redundant prompts.
      dev.log('Running Linux firewall script via pkexec for ports: ${ports.join(', ')}', name: 'FirewallService');
      
      // 2. Run with pkexec if check failed
      try {
        final List<String> setupArgs = ['bash', scriptPath] + ports.map((p) => p.toString()).toList();
        final result = await Process.run('pkexec', setupArgs);
        
        if (result.exitCode != 0) {
          dev.log('Firewall setup failed (exit ${result.exitCode}): ${result.stderr}', name: 'FirewallService');
        } else {
          dev.log('Firewall setup complete: ${result.stdout}', name: 'FirewallService');
        }
      } catch (e) {
        dev.log('Error running firewall setup', name: 'FirewallService', error: e);
      }
    } catch (e) {
      dev.log('Failed to setup Linux firewall', name: 'FirewallService', error: e);
    }
  }
}
