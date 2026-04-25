import 'dart:convert';
import 'dart:developer' as dev;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_mobile/data/models/message_model.dart';

class MessageStorageService {
  static const _key = 'chat_messages';

  Future<void> saveMessage(MessageModel message) async {
    final prefs = await SharedPreferences.getInstance();
    final messages = await loadMessages();
    messages.add(message);
    await prefs.setString(_key, jsonEncode(messages.map((m) => m.toJson()).toList()));
    dev.log('Message saved successfully', name: 'saveMessage');
  }

  Future<List<MessageModel>> loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null) {
      dev.log('No existing messages found', name: 'loadMessages');
      return [];
    }
    final loaded = (jsonDecode(data) as List).map((m) => MessageModel.fromJson(m)).toList();
    dev.log('Loaded ${loaded.length} messages', name: 'loadMessages');
    return loaded;
  }
}