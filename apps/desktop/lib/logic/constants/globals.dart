import 'package:flutter/material.dart';
import 'package:test/data/services/ble_interop_service.dart';

int selectedIndex = 0;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

enum AppScreen {
  main,
  messaging,
}

AppScreen currentScreen = AppScreen.main;

Map imageData = {};
String? currentServerIp;

bool isHotspotActive = false;
String? activeHotspotSsid;

final BleInteropService bleInteropService = BleInteropService();
