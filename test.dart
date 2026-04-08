import 'dart:io';

Future<void> main() async {
  print("=== Testing Windows Wi-Fi Connection ===");
  
  String testSsid = "CHERRY 7077"; 
  String testPassword = "password";

  bool isConnected = await _connectToWindowsWifi(testSsid, testPassword);
  
  if (isConnected) {
    print("\n✅ SUCCESS: Actually connected to $testSsid");
  } else {
    print("\n❌ FAILED: Could not connect to $testSsid");
  }
}

Future<bool> _connectToWindowsWifi(String ssid, String password) async {
  print("Generating dynamic XML profile for: $ssid...");

  final psScript = '''
    \$ErrorActionPreference = 'Stop'
    \$ssid = "$ssid"
    \$password = "$password"
    
    Write-Output "Scanning network security type..."
    \$authType = "WPA2PSK" # Default fallback
    
    # Check if the network is broadcasting as WPA3
    \$networks = netsh wlan show networks
    \$currentSsid = ""
    foreach (\$line in \$networks) {
        if (\$line -match "SSID\\s+\\d+\\s+:\\s+(.*)") {
            \$currentSsid = \$matches[1].Trim()
        }
        if (\$currentSsid -eq \$ssid -and \$line -match "Authentication\\s+:\\s+(.*)") {
            \$authRaw = \$matches[1].Trim()
            if (\$authRaw -match "WPA3") {
                \$authType = "WPA3SAE"
            }
            break
        }
    }

    Write-Output "Detected Auth Type: \$authType"

    # Convert SSID to Hex to avoid XML parsing errors with spaces/special characters
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
    
    \$xmlPath = "\$env:TEMP\\hotdrop_wifi_profile.xml"
    
    # Write the file using .NET to prevent PowerShell from adding a UTF-8 BOM
    [System.IO.File]::WriteAllText(\$xmlPath, \$xml)
    
    Write-Output "Adding profile to Windows..."
    netsh wlan add profile filename="\$xmlPath" | Out-Null
    
    Write-Output "Attempting to connect..."
    \$connectOutput = netsh wlan connect name="\$ssid" 2>&1
    Write-Output \$connectOutput
    
    Remove-Item -Path \$xmlPath

    Write-Output "Verifying actual connection state (waiting up to 10s)..."
    \$connected = \$false
    for (\$i = 0; \$i -lt 10; \$i++) {
        Start-Sleep -Seconds 1
        \$status = netsh wlan show interfaces
        
        # Check if the interface state is 'connected' AND the SSID matches
        if (\$status -match "State\\s+:\\s+connected" -and \$status -match "SSID\\s+:\\s+\$ssid") {
            \$connected = \$true
            break
        }
    }

    if (-not \$connected) {
        Write-Error "Failed to verify connection to \$ssid. Network might be out of range, or password incorrect."
    }
  ''';

  try {
    print("Running PowerShell script...");
    final result = await Process.run('powershell.exe', ['-NoProfile', '-Command', psScript]);
    
    if (result.stdout.toString().isNotEmpty) {
      print("\n--- Output ---");
      print(result.stdout.toString().trim());
    }

    if (result.exitCode == 0) {
      return true;
    } else {
      print("\nWi-Fi connection failed: \n${result.stderr.toString().trim()}");
      return false;
    }
  } catch (e) {
    print("Error executing Wi-Fi PowerShell script: $e");
    return false;
  }
}