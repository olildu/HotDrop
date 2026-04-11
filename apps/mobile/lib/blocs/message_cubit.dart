import 'dart:async';
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
    // FIX: Listen to the repository stream for BOTH incoming and outgoing sync
    _messageSubscription = _chatRepository.incomingMessages.listen((message) {
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
    _chatRepository.sendMessage(content);
  }

  @override
  Future<void> close() {
    _messageSubscription?.cancel();
    return super.close();
  }
}