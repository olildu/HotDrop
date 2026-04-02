import 'dart:io';

// Added missing enum for standalone testing
enum HotspotStatus { success, noInternet, error }

Future<void> main() async {
  print("Testing Windows Hotspot Activation...");
  await _enableWindowsHotspot();
}

Future<HotspotStatus> _enableWindowsHotspot() async {
  String? hotspotSsid;
  String? hotspotPassword;

  const psScript = '''
      \$ErrorActionPreference = 'SilentlyContinue'
      Add-Type -AssemblyName System.Runtime.WindowsRuntime
      
      \$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | ? { 
          \$_.Name -eq 'AsTask' -and \$_.GetParameters().Count -eq 1 -and \$_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' 
      })[0]
      
      Function Await(\$WinRtTask, \$ResultType) {
          \$asTask = \$asTaskGeneric.MakeGenericMethod(\$ResultType)
          \$netTask = \$asTask.Invoke(\$null, @(\$WinRtTask))
          \$netTask.Wait(-1) | Out-Null
      }

      \$connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile()
      
      if (\$null -ne \$connectionProfile) {
          \$tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile(\$connectionProfile)
          Await (\$tetheringManager.StopTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult])
      }
    ''';

  try {
    print("Running PowerShell script...");
    final result = await Process.run('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', psScript]);

    final stdoutStr = result.stdout.toString();

    // Parse the output
    final ssidMatch = RegExp(r'HOTSPOT_SSID:(.*)').firstMatch(stdoutStr);
    final passMatch = RegExp(r'HOTSPOT_PASS:(.*)').firstMatch(stdoutStr);

    if (ssidMatch != null) hotspotSsid = ssidMatch.group(1)?.trim();
    if (passMatch != null) hotspotPassword = passMatch.group(1)?.trim();

    // Print the extracted values to the console
    print("\n--- RESULTS ---");
    print("SSID: $hotspotSsid");
    print("Password: $hotspotPassword");
    print("Exit Code: ${result.exitCode}");

    // Print raw error output if there is any
    if (result.stderr.toString().isNotEmpty) {
      print("StdErr: ${result.stderr}");
    }

    if (result.stderr.toString().contains("NO_INTERNET")) {
      print("Status: Hotspot Status -> NO INTERNET TO SHARE");
      return HotspotStatus.noInternet;
    }

    if (result.exitCode == 0) {
      print("Status: Hotspot Status -> SUCCESS");
      return HotspotStatus.success;
    }

    print("Status: Hotspot Status -> ERROR");
    return HotspotStatus.error;
  } catch (e) {
    print("Error executing PowerShell: $e");
    return HotspotStatus.error;
  }
}
