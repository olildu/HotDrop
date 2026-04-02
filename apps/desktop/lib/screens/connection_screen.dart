import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:test/constants/globals.dart';
import 'package:test/services/connection_services.dart';

enum HotspotStatus { success, requiresAdmin, noInternet, error }

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  String? qrData;
  String loadingStatus = "Initializing...";
  bool isAdminError = false;

  // Variables to hold the fetched Hotspot credentials
  String? _hotspotSsid;
  String? _hotspotPassword;

  @override
  void initState() {
    super.initState();
    _initializeServer();
  }

  Future<void> _initializeServer() async {
    if (Platform.isWindows) {
      setState(() => loadingStatus = "Checking permissions...");

      final hasAdmin = await _ensureAdminPrivileges();
      if (!hasAdmin) {
        setState(() {
          isAdminError = true;
        });
        return;
      }

      setState(() => loadingStatus = "Enabling Mobile Hotspot...");
      final hotspotStatus = await _enableWindowsHotspot();
      if (hotspotStatus == HotspotStatus.noInternet) {
        log("No internet to share. Will attempt to bind to standard Wi-Fi.");
      }

      setState(() => loadingStatus = "Waiting for adapter...");
      await Future.delayed(const Duration(seconds: 2));
    }
    // ---- NEW: LINUX HOTSPOT LOGIC ----
    else if (Platform.isLinux) {
      setState(() => loadingStatus = "Enabling Linux Hotspot...");

      final hotspotStatus = await _enableLinuxHotspot();
      if (hotspotStatus != HotspotStatus.success) {
        log("Could not create Linux Hotspot. Falling back to existing Wi-Fi network.");
      }

      setState(() => loadingStatus = "Waiting for adapter...");
      await Future.delayed(const Duration(seconds: 2));
    }

    setState(() => loadingStatus = "Fetching IP Address...");
    await _getHostInfo();
  }

  // --- LINUX HOTSPOT FUNCTION ---
  Future<HotspotStatus> _enableLinuxHotspot() async {
    try {
      // 1. Check if nmcli is installed
      final checkNmcli = await Process.run('which', ['nmcli']);
      if (checkNmcli.exitCode != 0) {
        log("nmcli is not installed. Cannot manage hotspot.");
        return HotspotStatus.error;
      }

      // 2. Generate a clean SSID and secure password for the session
      // Removing special chars from hostname to ensure valid SSID
      String safeHostname = Platform.localHostname.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      String ssid = "HotDrop_$safeHostname";
      String password = "HotDrop${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";

      // 3. Command NetworkManager to create/start the hotspot
      // nmcli automatically figures out the correct Wi-Fi interface (e.g., wlan0)
      log("Executing nmcli to create hotspot...");
      final result = await Process.run('nmcli', ['device', 'wifi', 'hotspot', 'ssid', ssid, 'password', password]);

      if (result.exitCode == 0) {
        _hotspotSsid = ssid;
        _hotspotPassword = password;
        log("Linux Hotspot started successfully: SSID: $ssid");
        return HotspotStatus.success;
      } else {
        log("Failed to start Linux hotspot: ${result.stderr}");
        return HotspotStatus.error;
      }
    } catch (e) {
      log("Error executing nmcli: $e");
      return HotspotStatus.error;
    }
  }

  // --- WINDOWS PRIVILEGE LOGIC ---
  Future<bool> _ensureAdminPrivileges() async {
    const checkAdmin =
        '(New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)';

    try {
      final result = await Process.run('powershell.exe', ['-Command', checkAdmin]);

      if (result.stdout.toString().trim() == 'True') {
        return true;
      }

      final executablePath = Platform.resolvedExecutable;
      await Process.run('powershell.exe', ['-Command', 'Start-Process -FilePath "$executablePath" -Verb RunAs']);

      exit(0);
    } catch (e) {
      log("Error checking or elevating privileges: $e");
      return false;
    }
  }

  // --- WINDOWS HOTSPOT FUNCTION ---
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
      final result = await Process.run('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', psScript]);

      final stdoutStr = result.stdout.toString();
      final ssidMatch = RegExp(r'HOTSPOT_SSID:(.*)').firstMatch(stdoutStr);
      final passMatch = RegExp(r'HOTSPOT_PASS:(.*)').firstMatch(stdoutStr);

      if (ssidMatch != null) _hotspotSsid = ssidMatch.group(1)?.trim();
      if (passMatch != null) _hotspotPassword = passMatch.group(1)?.trim();

      if (result.stderr.toString().contains("NO_INTERNET")) {
        return HotspotStatus.noInternet;
      }

      if (result.exitCode == 0) return HotspotStatus.success;
      return HotspotStatus.error;
    } catch (e) {
      log("Error executing PowerShell: $e");
      return HotspotStatus.error;
    }
  }

  // --- IP FETCHING LOGIC ---
  Future<void> _getHostInfo() async {
    String? ipAddress;
    try {
      List<NetworkInterface> interfaces = await NetworkInterface.list();

      // 1. Check for Windows Hotspot
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

      // 2. Check for Standard Wi-Fi / Linux Hotspot
      // On Linux, nmcli binds the hotspot to the standard wlan0/wlp2s0 interface
      // and usually assigns it an IP of 10.42.0.1
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

      // 3. Final fallback
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
      log("Error getting IP: $e");
    }

    setState(() {
      currentServerIp = ipAddress;

      bool hasHotspot = _hotspotSsid != null && _hotspotPassword != null;

      qrData = jsonEncode({
        "ip": ipAddress ?? "127.0.0.1",
        "isDesktop": !hasHotspot, // Automatically triggers Mobile's Wi-Fi IoT plugin
        "ssid": _hotspotSsid,
        "password": _hotspotPassword,
      });
    });

    DartFunction().openPort(context: navigatorKey.currentContext!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: isAdminError ? _buildAdminErrorUI() : _buildQRUI(),
      ),
    );
  }

  Widget _buildAdminErrorUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.admin_panel_settings_rounded, size: 80.sp, color: Colors.redAccent),
        Gap(20.h),
        Text(
          "Administrator Privileges Required",
          style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold),
        ),
        Gap(10.h),
        SizedBox(
          width: 400.w,
          child: Text(
            "To automatically enable the Windows Mobile Hotspot, this app needs to be run as an Administrator. Please close the app, right-click the icon, and select 'Run as Administrator'.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  Widget _buildQRUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        qrData == null
            ? Column(
                children: [
                  const CircularProgressIndicator(),
                  Gap(20.h),
                  Text(loadingStatus, style: TextStyle(fontSize: 16.sp, color: Colors.grey[600])),
                ],
              )
            : QrImageView(
                data: qrData!,
                version: QrVersions.auto,
                size: 320.sp,
                gapless: false,
              ),
        Gap(50.h),
        if (qrData != null)
          Text(
            "Connect to get started",
            style: TextStyle(fontSize: 23.sp),
          ),
        if (currentServerIp != null)
          Padding(
            padding: EdgeInsets.only(top: 10.h),
            child: Text("IP: $currentServerIp", style: TextStyle(color: Colors.grey, fontSize: 14.sp)),
          ),
      ],
    );
  }
}
