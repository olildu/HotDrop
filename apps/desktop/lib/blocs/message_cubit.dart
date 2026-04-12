import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/message_model.dart';
import '../data/repositories/chat_repository.dart';

class MessageCubit extends Cubit<List<MessageModel>> {
  final ChatRepository _chatRepository;

  MessageCubit(this._chatRepository) : super([]);

  void addMessage(MessageModel message) {
    emit([...state, message]);
  }

  Future<void> sendMessage(String text) async {
    final newMessage = MessageModel(message: text, sender: "Me");
    addMessage(newMessage);
    await _chatRepository.sendMessage(text);
  }
}
