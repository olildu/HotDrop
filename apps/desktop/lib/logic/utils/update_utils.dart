import 'dart:io';
import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/foundation.dart';

class UpdateUtils {
  static Future<void> initializeAutoUpdater() async {
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) return;

    // Replace this with your actual update feed URL
    // This JSON file should follow the format required by auto_updater
    const String feedUrl = 'https://raw.githubusercontent.com/olildu/HotDrop/main/app-update.json';

    await autoUpdater.setFeedURL(feedUrl);
    await autoUpdater.setScheduledCheckInterval(3600); // Check every hour
    
    // Check for updates immediately on launch
    await autoUpdater.checkForUpdates();
  }
}
