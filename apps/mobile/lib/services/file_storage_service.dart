import 'dart:convert';
import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';

class FileStorageService {
  static const _messagesKey = 'file_storage_details';

  Future<void> saveFileDetails({required String fileName, required int fileSize, required DateTime timestamp, required double transferSpeed, required bool isSent}) async {
    final prefs = await SharedPreferences.getInstance();
    final existingMessages = await loadFileDetails();

    existingMessages.add({
      'file_name': fileName,
      'file_size': fileSize,
      'timestamp': timestamp.toIso8601String(),
      "is_sent": isSent,
      "transfer_speed": transferSpeed,
    });

    final jsonString = jsonEncode(existingMessages);
    await prefs.setString(_messagesKey, jsonString);

    log('File details saved: $fileName', name: 'FileStorageService');
  }

  Future<List<Map<String, dynamic>>> loadFileDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_messagesKey);
    if (jsonString != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(jsonString));
    }
    return [];
  }
}
