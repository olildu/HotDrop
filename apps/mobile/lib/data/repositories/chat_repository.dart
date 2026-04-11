import 'dart:async';
import 'dart:convert';
import '../models/message_model.dart';
import '../../services/message_storage_service.dart';
import '../../services/connection_services.dart';

class ChatRepository {
  final MessageStorageService _storageService = MessageStorageService();
  final _messageStreamController = StreamController<MessageModel>.broadcast();
  Stream<MessageModel> get incomingMessages => _messageStreamController.stream;

  // Handles incoming messages from the socket
  void onMessageReceived(String content) {
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

  Future<List<MessageModel>> getHistory() => _storageService.loadMessages();

  void dispose() => _messageStreamController.close();
}
