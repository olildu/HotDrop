import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:test/logic/constants/globals.dart' as globals;
import 'package:test/data/services/connection_services.dart';

enum ConnectionRole { none, host, join }

enum HotspotStatus { success, requiresAdmin, noInternet, error }

class ConnectionRepository {
  String? _hotspotSsid;
  String? _hotspotPassword;

  String? qrData;

  void _log(String functionName, String message, {Object? error, StackTrace? stackTrace}) {
    dev.log(message, name: functionName, error: error, stackTrace: stackTrace);
  }

  Future<void> startHosting() async {
    _log('startHosting', 'Starting hosting workflow');
    await _initializeServer(); // Triggers existing setup logic
  }

  Future<void> _initializeServer() async {
    _log('_initializeServer', 'Initializing server for platform ${Platform.operatingSystem}');
    if (Platform.isWindows) {
      // final hasAdmin = await _ensureAdminPrivileges();
      // if (!hasAdmin) {
      //   setState(() {
      //     isAdminError = true;
      //   });
      //   return;
      // }

      final hotspotStatus = await _enableWindowsHotspot();
      if (hotspotStatus == HotspotStatus.noInternet) {
        _log('_initializeServer', 'No internet to share. Will attempt to bind to standard Wi-Fi.');
      }

      await Future.delayed(const Duration(seconds: 2));
    } else if (Platform.isLinux) {
      final hotspotStatus = await _enableLinuxHotspot();
      if (hotspotStatus != HotspotStatus.success) {
        _log('_initializeServer', 'Could not create Linux hotspot. Falling back to existing Wi-Fi network.');
      }

      await Future.delayed(const Duration(seconds: 2));
    }

    await _getHostInfo();
  }

  Future<HotspotStatus> _enableLinuxHotspot() async {
    try {
      final checkNmcli = await Process.run('which', ['nmcli']);
      if (checkNmcli.exitCode != 0) {
        _log('_enableLinuxHotspot', 'nmcli is not installed. Cannot manage hotspot.');
        return HotspotStatus.error;
      }

      String safeHostname = Platform.localHostname.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      String ssid = "HotDrop_$safeHostname";
      String password = "HotDrop${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";

      _log('_enableLinuxHotspot', 'Executing nmcli to create hotspot');
      final result = await Process.run('nmcli', ['device', 'wifi', 'hotspot', 'ssid', ssid, 'password', password]);

      if (result.exitCode == 0) {
        _hotspotSsid = ssid;
        _hotspotPassword = password;

        globals.isHotspotActive = true;
        globals.activeHotspotSsid = ssid;

        _log('_enableLinuxHotspot', 'Linux hotspot started successfully: SSID=$ssid');
        return HotspotStatus.success;
      } else {
        _log('_enableLinuxHotspot', 'Failed to start Linux hotspot: ${result.stderr}');
        return HotspotStatus.error;
      }
    } catch (e) {
      _log('_enableLinuxHotspot', 'Error executing nmcli', error: e);
      return HotspotStatus.error;
    }
  }

  Future<HotspotStatus> _enableWindowsHotspot() async {
    const psScript = '''
      \$ErrorActionPreference = 'Stop'
      Add-Type -AssemblyName System.Runtime.WindowsRuntime
      
      \$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | ? { 
          \$_.Name -eq 'AsTask' -and \$_.GetParameters().Count -eq 1 -and \$_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' 
      })[0]
      
      Function Await(\$WinRtTask, \$ResultType) {
          \$asTask = \$asTaskGeneric.MakeGenericMethod(\$ResultType)
          \$netTask = \$asTask.Invoke(\$null, @(\$WinRtTask))
          \$netTask.Wait(-1) | Out-Null
          \$netTask.Result
      }

      \$connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile()
      
      if (\$null -eq \$connectionProfile) {
          Write-Error "NO_INTERNET"
          exit 1
      }

      \$tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile(\$connectionProfile)
      
      \$result = Await (\$tetheringManager.StartTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult])
      
      \$config = \$tetheringManager.GetCurrentAccessPointConfiguration()
      Write-Output "HOTSPOT_SSID:\$(\$config.Ssid)"
      Write-Output "HOTSPOT_PASS:\$(\$config.Passphrase)"
    ''';

    try {
      _log('_enableWindowsHotspot', 'Attempting to enable Windows hotspot');
      final result = await Process.run('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', psScript]);

      final stdoutStr = result.stdout.toString();
      final ssidMatch = RegExp(r'HOTSPOT_SSID:(.*)').firstMatch(stdoutStr);
      final passMatch = RegExp(r'HOTSPOT_PASS:(.*)').firstMatch(stdoutStr);

      if (ssidMatch != null) _hotspotSsid = ssidMatch.group(1)?.trim();
      if (passMatch != null) _hotspotPassword = passMatch.group(1)?.trim();

      if (result.stderr.toString().contains("NO_INTERNET")) {
        _log('_enableWindowsHotspot', 'No internet connection available for tethering');
        return HotspotStatus.noInternet;
      }

      if (result.exitCode == 0) {
        globals.isHotspotActive = true;
        globals.activeHotspotSsid = _hotspotSsid;
        _log('_enableWindowsHotspot', 'Windows hotspot enabled successfully');
        return HotspotStatus.success;
      }
      _log('_enableWindowsHotspot', 'Windows hotspot command returned non-zero exit code ${result.exitCode}');
      return HotspotStatus.error;
    } catch (e) {
      _log('_enableWindowsHotspot', 'Error executing PowerShell', error: e);
      return HotspotStatus.error;
    }
  }

  Future<String?> _getBestIpAddress() async {
    String? ipAddress;
    try {
      List<NetworkInterface> interfaces = await NetworkInterface.list();

      for (var interface in interfaces) {
        if (interface.name.contains('Local Area Connection*')) {
          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              ipAddress = addr.address;
              break;
            }
          }
        }
        if (ipAddress != null) break;
      }
      if (ipAddress == null) {
        for (var interface in interfaces) {
          final name = interface.name.toLowerCase();
          if (name.contains('wi-fi') || name.contains('wifi') || name.contains('wlan') || name.contains('wlp')) {
            for (var addr in interface.addresses) {
              if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
                ipAddress = addr.address;
                break;
              }
            }
          }
          if (ipAddress != null) break;
        }
      }
      if (ipAddress == null) {
        for (var interface in interfaces) {
          final name = interface.name.toLowerCase();
          if (name.contains('vbox') || name.contains('vmware') || name.contains('virtual')) continue;
          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              ipAddress = addr.address;
              break;
            }
          }
          if (ipAddress != null) break;
        }
      }
    } catch (e) {
      _log('_getBestIpAddress', 'Error getting IP', error: e);
    }
    _log('_getBestIpAddress', 'Selected IP: ${ipAddress ?? 'none'}');
    return ipAddress;
  }

  Future<void> _getHostInfo() async {
    _log('_getHostInfo', 'Gathering host info and creating QR payload');
    String? ipAddress = await _getBestIpAddress();

    globals.currentServerIp = ipAddress;

    bool hasHotspot = _hotspotSsid != null && _hotspotPassword != null;

    qrData = jsonEncode({
      "ip": ipAddress ?? "127.0.0.1",
      "isDesktop": !hasHotspot,
      "ssid": _hotspotSsid,
      "password": _hotspotPassword,
    });

    if (qrData != null) {
      await globals.bleInteropService.startAdvertising(qrData!, (msg) => dev.log(msg, name: 'startAdvertising'));
      _log('_getHostInfo', 'BLE advertising started with generated QR payload');
    }

    DartFunction().openPort(context: globals.navigatorKey.currentContext!);
    _log('_getHostInfo', 'TCP listener opened for incoming peer connection');
  }
}

