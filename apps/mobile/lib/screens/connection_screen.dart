import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:test_mobile/services/connection_services.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> with SingleTickerProviderStateMixin {
  String? _qrData;
  bool _isHosting = false;
  bool _isReceiving = false;
  bool _isConnecting = false;

  // Status text for UI feedback
  String _statusMessage = "Initializing...";

  // BLE specific variables
  bool _isScanningBle = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  List<ScanResult> _discoveredDevices = [];

  final String _serviceUuid = "0000FFFF-0000-1000-8000-00805F9B34FB";
  final String _charUuid = "0000FFFE-0000-1000-8000-00805F9B34FB";

  // Animation controller for the radar pulse effect
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _startHost() async {
    setState(() => _isHosting = true);
    final creds = await AndroidFunction().startHosting();
    if (creds != null && mounted) {
      setState(() {
        _qrData = jsonEncode(creds);
      });
    }
  }

  void _startClient() {
    setState(() {
      _isReceiving = true;
      _isScanningBle = true;
      _discoveredDevices.clear();
      _statusMessage = "Searching for HotDrop hosts...";
    });
    _pulseController.repeat();
    _scanForBleDevices();
  }

  void _switchToQrScanner() {
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    _pulseController.stop();
    if (mounted) {
      setState(() {
        _isScanningBle = false;
        _isConnecting = false;
        _statusMessage = "Scan Host's QR Code";
      });
    }
  }

  Future<void> _scanForBleDevices() async {
    try {
      if (await FlutterBluePlus.isSupported == false) {
        _switchToQrScanner();
        return;
      }
      await Permissions().ensureBlePermissions();

      await FlutterBluePlus.startScan(
        withServices: [Guid(_serviceUuid)],
        timeout: const Duration(seconds: 15),
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (mounted) {
          setState(() {
            _discoveredDevices = results;
          });
        }
      });

      Future.delayed(const Duration(seconds: 15), () {
        if (mounted && _isScanningBle && _discoveredDevices.isEmpty && !_isConnecting) {
          _switchToQrScanner();
        }
      });
    } catch (e) {
      _switchToQrScanner();
    }
  }

  void logBle(String message) {
    final time = DateTime.now().toIso8601String();
    print("[$time][BLE] $message");
  }

  Future<void> _connectToBleDevice(BluetoothDevice device) async {
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    _pulseController.stop();

    setState(() {
      _isConnecting = true;
      _statusMessage = "Connecting to ${device.platformName.isNotEmpty ? device.platformName : 'Host'}...";
    });

    try {
      await device.connect(timeout: const Duration(seconds: 5), license: License.free);

      if (mounted) setState(() => _statusMessage = "Discovering services...");
      List<BluetoothService> services = await device.discoverServices();

      for (var service in services) {
        if (service.uuid == Guid(_serviceUuid)) {
          logBle("✅ TARGET SERVICE FOUND");

          for (var char in service.characteristics) {
            if (char.uuid == Guid(_charUuid)) {
              logBle("✅ TARGET CHARACTERISTIC FOUND");

              if (mounted) setState(() => _statusMessage = "Reading credentials...");
              try {
                List<int> value = await char.read();
                String jsonStr = utf8.decode(value);
                logBle("✅ FINAL DATA → $jsonStr");

                await device.disconnect();
                _processConnectionCredentials(jsonStr);
                return;
              } catch (e) {
                logBle("❌ READ ERROR → $e");
              }
            }
          }
        }
      }

      logBle("❌ TARGET NOT FOUND");
      await device.disconnect();
      _switchToQrScanner();
    } catch (e) {
      _switchToQrScanner();
    } finally {
      if (mounted && _isConnecting) {
        setState(() => _isConnecting = false);
      }
    }
  }

  void _onDetectQR(BarcodeCapture capture) async {
    if (_isConnecting) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        _processConnectionCredentials(barcode.rawValue!);
        break;
      }
    }
  }

  Future<void> _processConnectionCredentials(String rawData) async {
    setState(() {
      _isConnecting = true;
      _statusMessage = "Joining network...";
    });

    try {
      final creds = jsonDecode(rawData);

      if (creds['isDesktop'] == true) {
        String hostIp = creds['ip'];
        bool connected = await ClientServices().connectToHostSocket(hostIp);
        if (connected && mounted) Navigator.pop(context);
      } else {
        String ssid = creds['ssid'];
        String pass = creds['password'];
        String hostIp = creds['ip'] ?? "192.168.43.1";

        bool connected = await ClientServices().connectToHostHotspot(ssid, pass, hostIp);
        if (connected && mounted) {
          Navigator.pop(context);
        } else {
          if (mounted) {
            setState(() {
              _isConnecting = false;
              _isReceiving = false;
            });
          }
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection Failed")));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _isReceiving = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Invalid Credentials: $e")));
    }
  }

  Widget _buildPulseRadar() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 100.w + (_pulseController.value * 150.w),
              height: 100.w + (_pulseController.value * 150.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(1.0 - _pulseController.value),
              ),
            ),
            Container(
              width: 100.w + ((_pulseController.value * 150.w) / 2),
              height: 100.w + ((_pulseController.value * 150.w) / 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity((1.0 - _pulseController.value) * 0.5),
              ),
            ),
            CircleAvatar(
              radius: 40.r,
              backgroundColor: Colors.white,
              child: Icon(Icons.wifi_tethering, color: const Color(0xFF49454F), size: 40.sp),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF49454F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Text("Connect Device", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500)),
      ),
      body: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _buildCurrentState(),
        ),
      ),
    );
  }

  Widget _buildCurrentState() {
    // --- 1. IDLE STATE ---
    if (!_isHosting && !_isReceiving) {
      return Column(
        key: const ValueKey("IdleState"),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.devices_rounded, size: 100.sp, color: Colors.white70),
          Gap(40.h),
          ElevatedButton.icon(
            onPressed: _startHost,
            icon: const Icon(Icons.send_rounded, color: Color(0xFF49454F)),
            label: Text("Host Connection", style: GoogleFonts.poppins(color: const Color(0xFF49454F), fontSize: 16.sp, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              minimumSize: Size(250.w, 55.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
              elevation: 5,
            ),
          ),
          Gap(20.h),
          ElevatedButton.icon(
            onPressed: _startClient,
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            label: Text("Join Connection", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF67636F), // Slightly lighter than background
              minimumSize: Size(250.w, 55.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
              elevation: 0,
            ),
          ),
        ],
      );
    }

    // --- 2. HOSTING STATE ---
    if (_isHosting) {
      return Column(
        key: const ValueKey("HostingState"),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Waiting for receiver...", style: GoogleFonts.poppins(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w600)),
          Gap(10.h),
          Text("Scan this QR code on the joining device", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14.sp)),
          Gap(40.h),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _qrData == null
                ? const CircularProgressIndicator(color: Colors.white)
                : Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25.r),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 2)],
                    ),
                    child: QrImageView(
                      data: _qrData!,
                      version: QrVersions.auto,
                      size: 220.w,
                    ),
                  ),
          ),
        ],
      );
    }

    // --- 3. RECEIVING STATE ---
    if (_isReceiving) {
      // 3A. Connecting
      if (_isConnecting) {
        return Column(
          key: const ValueKey("ConnectingState"),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            Gap(30.h),
            Text(_statusMessage, style: GoogleFonts.poppins(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w500)),
            Gap(10.h),
            Text("Please wait, finalizing connection details.", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14.sp)),
          ],
        );
      }

      // 3B. Scanning BLE
      if (_isScanningBle) {
        return Column(
          key: const ValueKey("ScanningState"),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 250.h,
              child: _buildPulseRadar(),
            ),
            Gap(20.h),
            Text(_statusMessage, style: GoogleFonts.poppins(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w600)),
            Gap(30.h),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              height: _discoveredDevices.isEmpty ? 0 : 250.h,
              width: 320.w,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: Colors.white24),
              ),
              child: _discoveredDevices.isEmpty
                  ? const SizedBox()
                  : ListView.separated(
                      padding: EdgeInsets.all(10.w),
                      itemCount: _discoveredDevices.length,
                      separatorBuilder: (_, __) => Divider(color: Colors.white24, height: 1.h),
                      itemBuilder: (context, index) {
                        final device = _discoveredDevices[index].device;
                        final name = device.platformName.isNotEmpty ? device.platformName : "Unknown Device";

                        return ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                          leading: CircleAvatar(
                            backgroundColor: Colors.white24,
                            child: Icon(Icons.computer_rounded, color: Colors.white, size: 22.sp),
                          ),
                          title: Text(name, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15.sp)),
                          subtitle: Text("Tap to connect", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12.sp)),
                          trailing: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16.sp),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                          onTap: () => _connectToBleDevice(device),
                        );
                      },
                    ),
            ),
            Gap(_discoveredDevices.isEmpty ? 80.h : 20.h),
            TextButton.icon(
              onPressed: _switchToQrScanner,
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              label: Text("Scan QR Code Instead",
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 15.sp, decoration: TextDecoration.underline)),
            )
          ],
        );
      }

      // 3C. QR Fallback
      return Column(
        key: const ValueKey("QrState"),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_statusMessage, style: GoogleFonts.poppins(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w600)),
          Gap(10.h),
          Text("Align the host's QR code within the frame", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14.sp)),
          Gap(40.h),
          Container(
            height: 300.h,
            width: 300.w,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30.r),
              border: Border.all(color: Colors.white54, width: 3.w),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 5)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(27.r),
              child: MobileScanner(
                onDetect: _onDetectQR,
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox();
  }
}
