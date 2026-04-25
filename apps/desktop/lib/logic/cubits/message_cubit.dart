import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:developer' as dev;
import 'package:test/data/models/message_model.dart';
import 'package:test/data/repositories/chat_repository.dart';

class MessageCubit extends Cubit<List<MessageModel>> {
  final ChatRepository _chatRepository;

  MessageCubit(this._chatRepository) : super([]);

  void addMessage(MessageModel message) {
    dev.log('Adding message from ${message.sender}', name: 'addMessage');
    emit([...state, message]);
  }

  Future<void> sendMessage(String text) async {
    dev.log('Sending message (${text.length} chars)', name: 'sendMessage');
    final newMessage = MessageModel(message: text, sender: "Me");
    addMessage(newMessage);
    await _chatRepository.sendMessage(text);
  }
}

