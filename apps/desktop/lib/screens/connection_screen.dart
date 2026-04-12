import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../constants/globals.dart' as globals;
import '../services/connection_services.dart';

enum ConnectionRole { none, host, join }

enum HotspotStatus { success, requiresAdmin, noInternet, error }

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  ConnectionRole selectedRole = ConnectionRole.none;
  List<dynamic> availableHosts = [];
  String loadingStatus = "Choose Connection Mode";
  bool isProcessing = false;
  bool isAdminError = false;
  String? qrData;

  // Variables to hold the fetched Hotspot credentials
  String? _hotspotSsid;
  String? _hotspotPassword;

  @override
  void initState() {
    super.initState();
    // No longer auto-initializing; waits for role selection
  }

  @override
  void dispose() {
    super.dispose();
  }

  // --- HOST LOGIC ---
  Future<void> _startHosting() async {
    setState(() {
      selectedRole = ConnectionRole.host;
      isProcessing = true;
    });
    await _initializeServer(); // Triggers existing setup logic
    setState(() => isProcessing = false);
  }

  // --- JOIN LOGIC (CONTINUOUS STREAMING) ---
  Future<void> _startJoining() async {
    if (!mounted) return; // General safety
    setState(() {
      selectedRole = ConnectionRole.join;
      isProcessing = false;
      loadingStatus = "Scanning for nearby peers...";
      availableHosts = [];
    });

    await globals.bleInteropService.streamAvailableHosts(
      (newHost) {
        if (!mounted) return; // Already present in your code
        setState(() {
          int index = availableHosts.indexWhere((h) => h['address'] == newHost['address']);
          if (index != -1) {
            availableHosts[index] = newHost;
          } else {
            availableHosts.add(newHost);
          }
        });
      },
      () {
        // --- ADDED THIS LINE TO FIX YOUR ERROR ---
        if (!mounted) return;

        setState(() {
          loadingStatus = availableHosts.isEmpty ? "No peers found." : "Scan complete. Select a computer.";
        });
      },
      (msg) => log(msg, name: "BLE_STREAM"),
    );
  }

  Future<void> _connectToPeer(String address, String name) async {
    if (!mounted) return;
    setState(() {
      isProcessing = true;
      loadingStatus = "Fetching connection data from $name...";
    });

    final data = await globals.bleInteropService.fetchConnectionData(address, (msg) => log(msg));

    // Check mounted after every 'await' in an async method
    if (!mounted) return;

    if (data != null && data['ip'] != null) {
      final String? ssid = data['ssid'];
      final String? password = data['password'];

      if (ssid != null && password != null && ssid.isNotEmpty && password.isNotEmpty) {
        bool wifiConnected = await _connectToWindowsWifi(ssid, password);
        if (!mounted) return; // Check again
        if (!wifiConnected) {
          setState(() {
            isProcessing = false;
            loadingStatus = "Failed to join Host's Wi-Fi network.";
          });
          return;
        }
      }

      globals.currentServerIp = await _getBestIpAddress();
      if (!mounted) return; // Check again

      setState(() => loadingStatus = "Establishing secure connection...");

      try {
        await DartFunction().connectToHost(data['ip'], context: context);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          isProcessing = false;
          loadingStatus = "Socket connection failed. Are you on the same network?";
        });
      }
    } else {
      if (!mounted) return;
      setState(() {
        isProcessing = false;
        loadingStatus = "Connection Failed: No data received.";
      });
    }
  }

  // --- INTERNAL INITIALIZATION LOGIC ---
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
    } else if (Platform.isLinux) {
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

  Future<HotspotStatus> _enableLinuxHotspot() async {
    try {
      final checkNmcli = await Process.run('which', ['nmcli']);
      if (checkNmcli.exitCode != 0) {
        log("nmcli is not installed. Cannot manage hotspot.");
        return HotspotStatus.error;
      }

      String safeHostname = Platform.localHostname.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      String ssid = "HotDrop_$safeHostname";
      String password = "HotDrop${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";

      log("Executing nmcli to create hotspot...");
      final result = await Process.run('nmcli', ['device', 'wifi', 'hotspot', 'ssid', ssid, 'password', password]);

      if (result.exitCode == 0) {
        _hotspotSsid = ssid;
        _hotspotPassword = password;

        globals.isHotspotActive = true;
        globals.activeHotspotSsid = ssid;

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

  Future<bool> _connectToWindowsWifi(String ssid, String password) async {
    setState(() => loadingStatus = "Connecting to Wi-Fi: $ssid...");

    // PowerShell script to generate a profile, connect, and VERIFY using string output
    final psScript = '''
    \$ErrorActionPreference = 'SilentlyContinue'
    \$ssid = "$ssid"
    \$password = "$password"
    
    Write-Output "Step 1: Preparing profile for \$ssid"
    \$authType = "WPA2PSK" 

    # Convert SSID to Hex to avoid XML parsing errors
    \$hexSsid = [System.BitConverter]::ToString([System.Text.Encoding]::UTF8.GetBytes(\$ssid)).Replace('-', '')

    \$xml = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>\$ssid</name>
    <SSIDConfig>
        <SSID>
            <hex>\$hexSsid</hex>
            <name>\$ssid</name>
        </SSID>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <MSM>
        <security>
            <authEncryption>
                <authentication>\$authType</authentication>
                <encryption>AES</encryption>
                <useOneX>false</useOneX>
            </authEncryption>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>false</protected>
                <keyMaterial>\$password</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
</WLANProfile>
"@
    
    try {
        \$xmlPath = "\$env:TEMP\\hotdrop_wifi_profile.xml"
        [System.IO.File]::WriteAllText(\$xmlPath, \$xml)
        
        Write-Output "Step 2: Adding profile to Windows..."
        netsh wlan add profile filename="\$xmlPath" | Out-Null
        Remove-Item -Path \$xmlPath

        Write-Output "Step 3: Sending connect command..."
        \$connectOutput = netsh wlan connect name="\$ssid" 2>&1
        Write-Output "Connect Command Output: \$connectOutput"

        Write-Output "Step 4: Verifying actual connection state (waiting up to 25s)..."
        \$connected = \$false
        for (\$i = 1; \$i -le 25; \$i++) {
            Start-Sleep -Seconds 1
            
            # FIX: We must use '| Out-String' so that \$status is a single string.
            # Without this, netsh returns an array, and \$matches[1] will crash.
            \$status = netsh wlan show interfaces | Out-String
            
            \$currentState = "unknown"
            if (\$status -match "State\\s+:\\s+(.*)") {
                \$currentState = \$matches[1].Trim()
            }
            
            Write-Output "  [Sec \$i] State: \$currentState"

            if (\$currentState -eq "connected" -and \$status -match "SSID\\s+:\\s+\$ssid") {
                \$connected = \$true
                Write-Output "Success: Connected to \$ssid"
                break
            }
        }

        if (-not \$connected) {
            Write-Output "Error: Failed to verify connection to \$ssid. Final state: \$currentState"
            exit 1
        }
    } catch {
        Write-Output "Exception occurred: \$(\$_.ToString())"
        exit 1
    }
  ''';

    try {
      final result = await Process.run('powershell.exe', ['-NoProfile', '-Command', psScript]);

      if (result.stdout.toString().isNotEmpty) {
        log("--- Wi-Fi Connection Log ---\n${result.stdout.toString().trim()}", name: "WIFI_DEBUG");
      }

      if (result.exitCode == 0) {
        log("Successfully verified connection to Wi-Fi: $ssid");
        return true;
      } else {
        log("Wi-Fi connection failed. Stderr: \n${result.stderr}");
        return false;
      }
    } catch (e) {
      log("Error executing Wi-Fi PowerShell script: $e");
      return false;
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
      final result = await Process.run('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', psScript]);

      final stdoutStr = result.stdout.toString();
      final ssidMatch = RegExp(r'HOTSPOT_SSID:(.*)').firstMatch(stdoutStr);
      final passMatch = RegExp(r'HOTSPOT_PASS:(.*)').firstMatch(stdoutStr);

      if (ssidMatch != null) _hotspotSsid = ssidMatch.group(1)?.trim();
      if (passMatch != null) _hotspotPassword = passMatch.group(1)?.trim();

      if (result.stderr.toString().contains("NO_INTERNET")) {
        return HotspotStatus.noInternet;
      }

      if (result.exitCode == 0) {
        globals.isHotspotActive = true;
        globals.activeHotspotSsid = _hotspotSsid;
        return HotspotStatus.success;
      }
      return HotspotStatus.error;
    } catch (e) {
      log("Error executing PowerShell: $e");
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
      log("Error getting IP: $e");
    }
    return ipAddress;
  }

  Future<void> _getHostInfo() async {
    String? ipAddress = await _getBestIpAddress();

    setState(() {
      globals.currentServerIp = ipAddress;

      bool hasHotspot = _hotspotSsid != null && _hotspotPassword != null;

      qrData = jsonEncode({
        "ip": ipAddress ?? "127.0.0.1",
        "isDesktop": !hasHotspot,
        "ssid": _hotspotSsid,
        "password": _hotspotPassword,
      });

      loadingStatus = "Starting BLE Broadcast...";
    });

    if (qrData != null) {
      await globals.bleInteropService.startAdvertising(qrData!, (msg) => log(msg, name: "BLE"));
    }

    DartFunction().openPort(context: globals.navigatorKey.currentContext!);
  }

  // --- UI BUILDING METHODS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: selectedRole == ConnectionRole.none ? _buildSelectionUI() : _buildActiveUI(),
      ),
    );
  }

  Widget _buildSelectionUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("HotDrop Windows", style: TextStyle(fontSize: 30.sp, fontWeight: FontWeight.bold)),
        Gap(50.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _choiceCard("Be the Host", Icons.wifi_tethering, _startHosting),
            Gap(30.w),
            _choiceCard("Join a Peer", Icons.search, _startJoining),
          ],
        ),
      ],
    );
  }

  Widget _choiceCard(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(30.sp),
        decoration: BoxDecoration(border: Border.all(color: Colors.blue), borderRadius: BorderRadius.circular(15.r)),
        child: Column(children: [Icon(icon, size: 50.sp, color: Colors.blue), Gap(10.h), Text(title)]),
      ),
    );
  }

  Widget _buildActiveUI() {
    if (isProcessing) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [const CircularProgressIndicator(), Gap(20.h), Text(loadingStatus)],
      );
    }

    if (isAdminError) return _buildAdminErrorUI();

    if (selectedRole == ConnectionRole.host) return _buildQRUI();

    // The Stream UI for the Joiner
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(loadingStatus, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
        if (loadingStatus == "Scanning for nearby peers...")
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: LinearProgressIndicator(),
          ),
        Gap(20.h),
        SizedBox(
          height: 350.h,
          width: 500.w,
          child: availableHosts.isEmpty && loadingStatus != "Scanning for nearby peers..."
              ? Center(child: Text("No devices found.", style: TextStyle(color: Colors.grey[600])))
              : ListView.builder(
                  itemCount: availableHosts.length,
                  itemBuilder: (context, index) {
                    final h = availableHosts[index];
                    return ListTile(
                      leading: const Icon(Icons.computer, color: Colors.blue),
                      title: Text(h['name']),
                      subtitle: Text(h['address']),
                      onTap: () => _connectToPeer(h['address'], h['name']),
                      trailing: const Icon(Icons.arrow_forward_ios),
                    );
                  },
                ),
        ),
        TextButton(onPressed: _startJoining, child: const Text("Rescan")),
        TextButton(onPressed: () => setState(() => selectedRole = ConnectionRole.none), child: const Text("Go Back")),
      ],
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
          Column(
            children: [
              Text("Connect to get started", style: TextStyle(fontSize: 23.sp)),
              Gap(10.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bluetooth_audio, size: 20.sp, color: Colors.blue),
                  Gap(5.w),
                  Text("Broadcasting via BLE", style: TextStyle(color: Colors.blue, fontSize: 14.sp)),
                ],
              )
            ],
          ),
        if (globals.currentServerIp != null)
          Padding(
            padding: EdgeInsets.only(top: 10.h),
            child: Text("IP: ${globals.currentServerIp}", style: TextStyle(color: Colors.grey, fontSize: 14.sp)),
          ),
      ],
    );
  }
}
