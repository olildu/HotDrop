import 'package:flutter/material.dart';

class DeviceInfo {
  final String name;
  final bool isOnline;

  DeviceInfo({required this.name, this.isOnline = false});
}

class ListItemModel {
  final String id;
  final String primaryText;
  final String secondaryText;
  final IconData icon;
  final List<DeviceInfo> devices;
  final bool isCurrentDevice;

  ListItemModel({
    required this.id,
    required this.primaryText,
    required this.secondaryText,
    required this.icon,
    this.devices = const [],
    this.isCurrentDevice = false,
  });
}