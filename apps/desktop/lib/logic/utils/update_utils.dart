import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/foundation.dart';

class UpdateUtils {
  static Future<void> initializeAutoUpdater() async {
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) return;

    try {
      const String rawFeedUrl = 'https://raw.githubusercontent.com/olildu/HotDrop/main/app-update.json';
      final response = await http.get(Uri.parse(rawFeedUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> updateData = jsonDecode(response.body);
        
        if (updateData.containsKey('desktop')) {
          final Map<String, dynamic> desktopFeed = updateData['desktop'];
          
          final tempDir = await getTemporaryDirectory();
          final feedFile = File('${tempDir.path}/hotdrop_desktop_feed.json');
          await feedFile.writeAsString(jsonEncode(desktopFeed));
          
          final String localFeedUrl = 'file://${feedFile.path}';
          
          await autoUpdater.setFeedURL(localFeedUrl);
          await autoUpdater.setScheduledCheckInterval(3600);
          
          await autoUpdater.checkForUpdates();
        }
      }
    } catch (e) {
      debugPrint('Error initializing auto updater: $e');
    }
  }
}
