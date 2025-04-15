import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:test/constants/globals.dart';
import 'package:test/services/connection_services.dart';
import 'package:test/test.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  late String hostname;

  // Get hostname 
  void getHostName() async {
    hostname = Platform.localHostname;
    DartFunction().openPort(context: navigatorKey.currentContext!);
    // HelloWorldBridge().startDiscovery();
  }
  
  @override
  void initState(){
    super.initState();
    getHostName();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            QrImageView(
              data: hostname,
              version: QrVersions.auto,
              size: 320.sp,
              gapless: false,
            ),
        
            Gap(50.h),
        
            GestureDetector(
              onTap: () async {
                log("Trying to kill");

                HelloWorldBridge().stopDiscovery();

              },
              child: Text(
                "Connect to get started",
                style: TextStyle(
                  fontSize: 23.sp
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}