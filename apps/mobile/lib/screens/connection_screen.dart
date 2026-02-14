import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:qr_code_dart_scan/qr_code_dart_scan.dart';
import 'package:test_mobile/services/connection_services.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  double opacityValue = 1;  
  bool connectingStatus = false;
  bool _isDisposed = false;
  late String hostDeviceName;
  QRCodeDartScanController? controller;

  @override
  void initState() {
    super.initState();
    controller = QRCodeDartScanController();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopCamera();
    super.dispose();
  }

  Future<void> _stopCamera() async {
    try {
      await controller?.stopScan();
      
      await Future.delayed(const Duration(milliseconds: 300));
      if (!_isDisposed) {
        controller?.dispose();
        controller = null;
      }
    } catch (e) {
      log('Error stopping camera: $e');
    }
  }

  Future<void> _handleQRCodeCapture(Result result) async {
    if (connectingStatus) return;
    
    hostDeviceName = result.toString();
    setState(() {
      opacityValue = 0;
      connectingStatus = true;
    });

    try {
      await _stopCamera();
      
      AndroidFunction().setTargetDeviceName(hostDeviceName);
      AndroidFunction().discoverPeers();
    } catch (e) {
      log('Error in QR code capture: $e');
      if (!_isDisposed) {
        setState(() {
          opacityValue = 1;
          connectingStatus = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Stack(
          children: [
            if (controller != null)
              AnimatedOpacity(
                opacity: opacityValue,
                duration: const Duration(seconds: 1),
                child: QRCodeDartScanView(
                  scanInvertedQRCode: true,
                  controller: controller!,
                  typeScan: TypeScan.live,
                  onCapture: _handleQRCodeCapture,
                ),
              ),

            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 250,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, 
                        crossAxisSpacing: 100,
                        mainAxisSpacing: 100,
                      ),
                      itemCount: 4,
                      itemBuilder: (context, index) {
                        int row = index ~/ 2;
                        int col = index % 2;
                        return Container(
                          decoration: BoxDecoration(
                            border: Border(
                              top: row == 0
                                ? const BorderSide(color: Colors.white, width: 1)
                                : BorderSide.none,
                              bottom: row == 1
                                ? const BorderSide(color: Colors.white, width: 1)
                                : BorderSide.none,
                              left: col == 0
                                ? const BorderSide(color: Colors.white, width: 1)
                                : BorderSide.none,
                              right: col == 1
                                ? const BorderSide(color: Colors.white, width: 1)
                                : BorderSide.none,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                
                  const Gap(30),
                  const Text("Scan to get started", style: TextStyle(color: Colors.white),)
                ],
              )
            ),

            if (connectingStatus)
              Center(
                child: Text("Attempting to connect to $hostDeviceName"),
              ),
          ],
        ),
      ),
    );
  }
}