import 'dart:convert';
import 'package:test/data/services/connection_services.dart';

class ChatRepository {
  Future<void> sendMessage(String message) async {
    final payload = jsonEncode({
      "type": "message",
      "format": "string",
      "content": message,
    });
    await DartFunction().sendMessage(payload);
  }
}


