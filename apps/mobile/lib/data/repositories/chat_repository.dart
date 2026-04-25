import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:test_mobile/data/models/message_model.dart';
import 'package:test_mobile/data/services/message_storage_service.dart';
import 'package:test_mobile/data/services/connection_services.dart';

class ChatRepository {
  final MessageStorageService _storageService = MessageStorageService();
  final _messageStreamController = StreamController<MessageModel>.broadcast();
  Stream<MessageModel> get incomingMessages => _messageStreamController.stream;

  // Handles incoming messages from the socket
  void onMessageReceived(String content) {
    dev.log('Received message of length ${content.length}', name: 'onMessageReceived');
    final message = MessageModel(
      content: content,
      isSent: false,
      timestamp: DateTime.now(),
    );
    _messageStreamController.add(message);
    _storageService.saveMessage(message);
  }

  // Handles outgoing messages from the UI
  Future<void> sendMessage(String content) async {
    dev.log('Sending message of length ${content.length}', name: 'sendMessage');
    final message = MessageModel(
      content: content,
      isSent: true,
      timestamp: DateTime.now(),
    );

    // 1. Send via Socket
    await DartFunction().sendDataToSocket(jsonEncode({"type": "message", "content": content}));

    // 2. Broadcast to UI
    _messageStreamController.add(message);

    // 3. Persist to Storage
    await _storageService.saveMessage(message);
  }

  Future<List<MessageModel>> getHistory() {
    dev.log('Loading chat history', name: 'getHistory');
    return _storageService.loadMessages();
  }

  void dispose() {
    dev.log('Disposing ChatRepository', name: 'dispose');
    _messageStreamController.close();
  }
}
