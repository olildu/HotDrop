import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../constants/globals.dart' as globals;
import '../services/connection_services.dart';

enum ConnectionRole { none, host, join }

enum HotspotStatus { success, requiresAdmin, noInternet, error }

class ConnectionState {
  final ConnectionRole selectedRole;
  final List<Map<String, dynamic>> availableHosts;
  final String loadingStatus;
  final bool isProcessing;
  final bool isAdminError;
  final String? qrData;
  final String? currentServerIp;

  const ConnectionState({
    this.selectedRole = ConnectionRole.none,
    this.availableHosts = const <Map<String, dynamic>>[],
    this.loadingStatus = 'Choose Connection Mode',
    this.isProcessing = false,
    this.isAdminError = false,
    this.qrData,
    this.currentServerIp,
  });

  ConnectionState copyWith({
    ConnectionRole? selectedRole,
    List<Map<String, dynamic>>? availableHosts,
    String? loadingStatus,
    bool? isProcessing,
    bool? isAdminError,
    String? qrData,
    bool clearQrData = false,
    String? currentServerIp,
  }) {
    return ConnectionState(
      selectedRole: selectedRole ?? this.selectedRole,
      availableHosts: availableHosts ?? this.availableHosts,
      loadingStatus: loadingStatus ?? this.loadingStatus,
      isProcessing: isProcessing ?? this.isProcessing,
      isAdminError: isAdminError ?? this.isAdminError,
      qrData: clearQrData ? null : qrData ?? this.qrData,
      currentServerIp: currentServerIp ?? this.currentServerIp,
    );
  }
}

class ConnectionCubit extends Cubit<ConnectionState> {
  String? _hotspotSsid;
  String? _hotspotPassword;

  ConnectionCubit() : super(const ConnectionState());

  Future<void> startHosting() async {
    emit(
      state.copyWith(
        selectedRole: ConnectionRole.host,
        isProcessing: true,
        isAdminError: false,
        availableHosts: const <Map<String, dynamic>>[],
        clearQrData: true,
        loadingStatus: 'Preparing connection services...',
      ),
    );

    await _initializeServer();

    if (isClosed) {
      return;
    }

    emit(state.copyWith(isProcessing: false));
  }

  Future<void> startJoining() async {
    emit(
      state.copyWith(
        selectedRole: ConnectionRole.join,
        isProcessing: false,
        isAdminError: false,
        availableHosts: const <Map<String, dynamic>>[],
        clearQrData: true,
        loadingStatus: 'Scanning for nearby peers...',
      ),
    );

    await globals.bleInteropService.streamAvailableHosts(
      (newHost) {
        if (isClosed) {
          return;
        }

        final hosts = List<Map<String, dynamic>>.from(state.availableHosts);
        final normalizedHost = Map<String, dynamic>.from(newHost);
        final index = hosts.indexWhere((host) => host['address'] == normalizedHost['address']);

        if (index != -1) {
          hosts[index] = normalizedHost;
        } else {
          hosts.add(normalizedHost);
        }

        emit(state.copyWith(availableHosts: hosts));
      },
      () {
        if (isClosed) {
          return;
        }

        emit(
          state.copyWith(
            loadingStatus: state.availableHosts.isEmpty ? 'No peers found.' : 'Scan complete. Select a computer.',
          ),
        );
      },
      (msg) => log(msg, name: 'BLE_STREAM'),
    );
  }

  Future<void> connectToPeer(String address, String name) async {
    emit(
      state.copyWith(
        isProcessing: true,
        loadingStatus: 'Fetching connection data from $name...',
      ),
    );

    final data = await globals.bleInteropService.fetchConnectionData(address, (msg) => log(msg));

    if (isClosed) {
      return;
    }

    if (data == null || data['ip'] == null) {
      emit(
        state.copyWith(
          isProcessing: false,
          loadingStatus: 'Connection Failed: No data received.',
        ),
      );
      return;
    }

    final String? ssid = data['ssid'];
    final String? password = data['password'];

    if (Platform.isWindows && ssid != null && password != null && ssid.isNotEmpty && password.isNotEmpty) {
      final wifiConnected = await _connectToWindowsWifi(ssid, password);

      if (isClosed) {
        return;
      }

      if (!wifiConnected) {
        emit(
          state.copyWith(
            isProcessing: false,
            loadingStatus: 'Failed to join Host\'s Wi-Fi network.',
          ),
        );
        return;
      }
    }

    final bestIpAddress = await _getBestIpAddress();

    if (isClosed) {
      return;
    }

    globals.currentServerIp = bestIpAddress;

    emit(
      state.copyWith(
        currentServerIp: bestIpAddress,
        loadingStatus: 'Establishing secure connection...',
      ),
    );

    final context = globals.navigatorKey.currentContext;
    if (context == null) {
      emit(
        state.copyWith(
          isProcessing: false,
          loadingStatus: 'Unable to open the connection screen.',
        ),
      );
      return;
    }

    try {
      await DartFunction().connectToHost(data['ip'], context: context);
    } catch (e) {
      if (isClosed) {
        return;
      }

      emit(
        state.copyWith(
          isProcessing: false,
          loadingStatus: 'Socket connection failed. Are you on the same network?',
        ),
      );
    }
  }

  void reset() {
    emit(const ConnectionState());
  }

  Future<void> _initializeServer() async {
    if (Platform.isWindows) {
      emit(state.copyWith(loadingStatus: 'Checking permissions...'));

      final hasAdmin = await _ensureAdminPrivileges();
      if (!hasAdmin) {
        emit(
          state.copyWith(
            isAdminError: true,
            isProcessing: false,
          ),
        );
        return;
      }

      emit(state.copyWith(loadingStatus: 'Enabling Mobile Hotspot...'));
      final hotspotStatus = await _enableWindowsHotspot();
      if (hotspotStatus == HotspotStatus.noInternet) {
        log('No internet to share. Will attempt to bind to standard Wi-Fi.');
      }

      emit(state.copyWith(loadingStatus: 'Waiting for adapter...'));
      await Future.delayed(const Duration(seconds: 2));
    } else if (Platform.isLinux) {
      emit(state.copyWith(loadingStatus: 'Enabling Linux Hotspot...'));

      final hotspotStatus = await _enableLinuxHotspot();
      if (hotspotStatus != HotspotStatus.success) {
        log('Could not create Linux Hotspot. Falling back to existing Wi-Fi network.');
      }

      emit(state.copyWith(loadingStatus: 'Waiting for adapter...'));
      await Future.delayed(const Duration(seconds: 2));
    }

    emit(state.copyWith(loadingStatus: 'Fetching IP Address...'));
    await _getHostInfo();
  }

  Future<HotspotStatus> _enableLinuxHotspot() async {
    try {
      final checkNmcli = await Process.run('which', ['nmcli']);
      if (checkNmcli.exitCode != 0) {
        log('nmcli is not installed. Cannot manage hotspot.');
        return HotspotStatus.error;
      }

      final safeHostname = Platform.localHostname.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final ssid = 'HotDrop_$safeHostname';
      final password = 'HotDrop${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      log('Executing nmcli to create hotspot...');
      final result = await Process.run('nmcli', ['device', 'wifi', 'hotspot', 'ssid', ssid, 'password', password]);

      if (result.exitCode == 0) {
        _hotspotSsid = ssid;
        _hotspotPassword = password;

        globals.isHotspotActive = true;
        globals.activeHotspotSsid = ssid;

        log('Linux Hotspot started successfully: SSID: $ssid');
        return HotspotStatus.success;
      }

      log('Failed to start Linux hotspot: ${result.stderr}');
      return HotspotStatus.error;
    } catch (e) {
      log('Error executing nmcli: $e');
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
      log('Error checking or elevating privileges: $e');
      return false;
    }
  }

  Future<bool> _connectToWindowsWifi(String ssid, String password) async {
    emit(state.copyWith(loadingStatus: 'Connecting to Wi-Fi: $ssid...'));

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
        log('--- Wi-Fi Connection Log ---\n${result.stdout.toString().trim()}', name: 'WIFI_DEBUG');
      }

      if (result.exitCode == 0) {
        log('Successfully verified connection to Wi-Fi: $ssid');
        return true;
      }

      log('Wi-Fi connection failed. Stderr: \n${result.stderr}');
      return false;
    } catch (e) {
      log('Error executing Wi-Fi PowerShell script: $e');
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

      if (ssidMatch != null) {
        _hotspotSsid = ssidMatch.group(1)?.trim();
      }
      if (passMatch != null) {
        _hotspotPassword = passMatch.group(1)?.trim();
      }

      if (result.stderr.toString().contains('NO_INTERNET')) {
        return HotspotStatus.noInternet;
      }

      if (result.exitCode == 0) {
        globals.isHotspotActive = true;
        globals.activeHotspotSsid = _hotspotSsid;
        return HotspotStatus.success;
      }

      return HotspotStatus.error;
    } catch (e) {
      log('Error executing PowerShell: $e');
      return HotspotStatus.error;
    }
  }

  Future<String?> _getBestIpAddress() async {
    String? ipAddress;
    try {
      final interfaces = await NetworkInterface.list();

      for (final interface in interfaces) {
        if (interface.name.contains('Local Area Connection*')) {
          for (final addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              ipAddress = addr.address;
              break;
            }
          }
        }
        if (ipAddress != null) {
          break;
        }
      }

      if (ipAddress == null) {
        for (final interface in interfaces) {
          final name = interface.name.toLowerCase();
          if (name.contains('wi-fi') || name.contains('wifi') || name.contains('wlan') || name.contains('wlp')) {
            for (final addr in interface.addresses) {
              if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
                ipAddress = addr.address;
                break;
              }
            }
          }
          if (ipAddress != null) {
            break;
          }
        }
      }

      if (ipAddress == null) {
        for (final interface in interfaces) {
          final name = interface.name.toLowerCase();
          if (name.contains('vbox') || name.contains('vmware') || name.contains('virtual')) {
            continue;
          }
          for (final addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              ipAddress = addr.address;
              break;
            }
          }
          if (ipAddress != null) {
            break;
          }
        }
      }
    } catch (e) {
      log('Error getting IP: $e');
    }

    return ipAddress;
  }

  Future<void> _getHostInfo() async {
    final ipAddress = await _getBestIpAddress();

    if (isClosed) {
      return;
    }

    globals.currentServerIp = ipAddress;

    final hasHotspot = _hotspotSsid != null && _hotspotPassword != null;

    final qrData = jsonEncode({
      'ip': ipAddress ?? '127.0.0.1',
      'isDesktop': !hasHotspot,
      'ssid': _hotspotSsid,
      'password': _hotspotPassword,
    });

    emit(
      state.copyWith(
        loadingStatus: 'Starting BLE Broadcast...',
        qrData: qrData,
        currentServerIp: ipAddress,
      ),
    );

    await globals.bleInteropService.startAdvertising(qrData, (msg) => log(msg, name: 'BLE'));

    final context = globals.navigatorKey.currentContext;
    if (context != null) {
      DartFunction().openPort(context: context);
    }
  }
}
