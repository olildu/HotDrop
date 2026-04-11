import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/message_model.dart';

class MessageStorageService {
  static const _key = 'chat_messages';

  Future<void> saveMessage(MessageModel message) async {
    final prefs = await SharedPreferences.getInstance();
    final messages = await loadMessages();
    messages.add(message);
    await prefs.setString(_key, jsonEncode(messages.map((m) => m.toJson()).toList()));
  }

  Future<List<MessageModel>> loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null) return [];
    return (jsonDecode(data) as List).map((m) => MessageModel.fromJson(m)).toList();
  }
}