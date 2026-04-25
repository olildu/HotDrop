import 'dart:convert';
import 'dart:developer' as dev;
import 'package:test/data/services/connection_services.dart';

class ChatRepository {
  Future<void> sendMessage(String message) async {
    dev.log('Preparing outbound message (${message.length} chars)', name: 'sendMessage');
    final payload = jsonEncode({
      "type": "message",
      "format": "string",
      "content": message,
    });
    await DartFunction().sendMessage(payload);
    dev.log('Outbound message forwarded to socket service', name: 'sendMessage');
  }
}


