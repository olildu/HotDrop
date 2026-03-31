import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:test_mobile/services/connection_services.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  String? _qrData;
  bool _isHosting = false;
  bool _isReceiving = false;
  bool _isConnecting = false;

  Future<void> _startHost() async {
    setState(() => _isHosting = true);
    final creds = await AndroidFunction().startHosting();
    if (creds != null) {
      setState(() {
        _qrData = jsonEncode(creds);
      });
    }
  }

  void _startClient() {
    setState(() {
      _isReceiving = true;
    });
  }

  void _onDetectQR(BarcodeCapture capture) async {
    if (_isConnecting) return; 
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() => _isConnecting = true);
        try {
          final creds = jsonDecode(barcode.rawValue!);
          String ssid = creds['ssid'];
          String pass = creds['password'];
          // Fallback just in case, but it will use the IP from the QR
          String hostIp = creds['ip'] ?? "192.168.43.1"; 

          bool connected = await ClientServices().connectToHostHotspot(ssid, pass, hostIp);
          if (connected && mounted) {
            Navigator.pop(context); // Go back to MainScreen, connection successful
          } else {
            setState(() => _isConnecting = false);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection Failed")));
          }
        } catch (e) {
          setState(() => _isConnecting = false);
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF49454F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Text("Connect Device", style: GoogleFonts.poppins(color: Colors.white)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_isHosting && !_isReceiving) ...[
              ElevatedButton.icon(
                onPressed: _startHost,
                icon: const Icon(Icons.send, color: Color(0xFF49454F)),
                label: Text("Send (Create Hotspot)", style: TextStyle(color: const Color(0xFF49454F), fontSize: 16.sp)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  minimumSize: Size(250.w, 50.h),
                ),
              ),
              Gap(20.h),
              ElevatedButton.icon(
                onPressed: _startClient,
                icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF49454F)),
                label: Text("Receive (Scan QR)", style: TextStyle(color: const Color(0xFF49454F), fontSize: 16.sp)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  minimumSize: Size(250.w, 50.h),
                ),
              ),
            ] else if (_isHosting) ...[
              Text("Scan this QR on the other device", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16.sp)),
              Gap(20.h),
              _qrData == null
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Container(
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r)),
                      child: QrImageView(
                        data: _qrData!,
                        version: QrVersions.auto,
                        size: 200.w,
                      ),
                    ),
            ] else if (_isReceiving) ...[
              Text(_isConnecting ? "Connecting..." : "Scan Host's QR Code", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16.sp)),
              Gap(20.h),
              SizedBox(
                height: 300.h,
                width: 300.w,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20.r),
                  child: MobileScanner(
                    onDetect: _onDetectQR,
                  ),
                ),
              ),
              if (_isConnecting) ...[
                Gap(20.h),
                const CircularProgressIndicator(color: Colors.white)
              ]
            ]
          ],
        ),
      ),
    );
  }
}