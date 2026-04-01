import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:test/constants/globals.dart';
import 'package:test/services/connection_services.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  String? qrData;

  // Get Local IP Address and format as JSON
  void getHostInfo() async {
    String? ipAddress;
    try {
      List<NetworkInterface> interfaces = await NetworkInterface.list();

      // 1. Try to find the Wi-Fi interface specifically first
      for (var interface in interfaces) {
        if (interface.name.contains('wlan') || interface.name.contains('eth')) {
          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              ipAddress = addr.address;
              break; // Found our preferred local IP
            }
          }
        }
        if (ipAddress != null) break;
      }

      // 2. Fallback: If no wlan/eth found, pick the first non-loopback, non-Tailscale IPv4
      if (ipAddress == null) {
        for (var interface in interfaces) {
          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback && !addr.address.startsWith('100.')) {
              // Ignore Tailscale range
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
      qrData = jsonEncode({
        "ip": ipAddress ?? "127.0.0.1",
        "isDesktop": true,
      });
    });

    DartFunction().openPort(context: navigatorKey.currentContext!);
  }

  @override
  void initState() {
    super.initState();
    getHostInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            qrData == null
                ? const CircularProgressIndicator()
                : QrImageView(
                    data: qrData!,
                    version: QrVersions.auto,
                    size: 320.sp,
                    gapless: false,
                  ),
            Gap(50.h),
            GestureDetector(
              onTap: () async {
                log("Trying to kill");
              },
              child: Text(
                "Connect to get started",
                style: TextStyle(fontSize: 23.sp),
              ),
            )
          ],
        ),
      ),
    );
  }
}
