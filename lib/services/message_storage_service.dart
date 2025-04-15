import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MessageStorageService {
  static const _messagesKey = 'chat_messages';

  Future<void> saveMessage(String content, bool isSent, DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    final existingMessages = await loadMessages();

    existingMessages.add({
      'content': content,
      'isSent': isSent,
      'timestamp': timestamp.toIso8601String(),
    });

    final jsonString = jsonEncode(existingMessages);
    await prefs.setString(_messagesKey, jsonString);
  }

  Future<List<Map<String, dynamic>>> loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_messagesKey);
    if (jsonString != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(jsonString));
    }
    return [];
  }

  Future<void> clearMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_messagesKey);
  }
}
