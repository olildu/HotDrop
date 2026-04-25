import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_mobile/data/models/message_model.dart';
import 'package:test_mobile/data/repositories/chat_repository.dart';

class MessageState {
  final List<MessageModel> messages;
  MessageState({required this.messages});
  MessageState copyWith({List<MessageModel>? messages}) {
    return MessageState(messages: messages ?? this.messages);
  }
}

class MessageCubit extends Cubit<MessageState> {
  final ChatRepository _chatRepository;
  StreamSubscription? _messageSubscription;

  MessageCubit(this._chatRepository) : super(MessageState(messages: [])) {
    dev.log('Initializing MessageCubit', name: 'MessageCubit');
    // FIX: Listen to the repository stream for BOTH incoming and outgoing sync
    _messageSubscription = _chatRepository.incomingMessages.listen((message) {
      dev.log('Received new message in stream', name: '_messageSubscription');
      final updatedMessages = List<MessageModel>.from(state.messages)..add(message);
      emit(state.copyWith(messages: updatedMessages));
    });
  }

  // Future<void> loadHistory() async {
  //   final history = await _chatRepository.getHistory();
  //   emit(state.copyWith(messages: history));
  // }

  // FIX: Call the actual network method in the repository
  void sendMessage(String content) {
    dev.log('Sending message of length ${content.length}', name: 'sendMessage');
    _chatRepository.sendMessage(content);
  }

  bool sendMessageIfValid(String rawInput) {
    final content = rawInput.trim();
    if (content.isEmpty) return false;
    sendMessage(content);
    return true;
  }

  @override
  Future<void> close() {
    dev.log('Closing MessageCubit', name: 'close');
    _messageSubscription?.cancel();
    return super.close();
  }
}
