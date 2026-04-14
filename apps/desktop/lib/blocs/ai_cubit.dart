import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/local_ai_service.dart';
import '../data/models/message_model.dart';
import '../data/repositories/file_repository.dart'; // <-- 1. NEW IMPORT

abstract class AiState {}

class AiInitial extends AiState {}

class AiCheckingStatus extends AiState {}

class AiReady extends AiState {
  final List<MessageModel> messages;
  final bool isGenerating;

  AiReady({required this.messages, this.isGenerating = false});
}

class AiError extends AiState {
  final String errorMessage;
  AiError(this.errorMessage);
}

class AiCubit extends Cubit<AiState> {
  final LocalAiService _aiService;
  final FileRepository _fileRepo; // <-- 2. ADD FILE REPOSITORY
  final List<MessageModel> _chatHistory = [];

  // Update constructor to require both dependencies
  AiCubit(this._aiService, this._fileRepo) : super(AiInitial());

  Future<void> initializeAi() async {
    emit(AiCheckingStatus());
    final isReady = await _aiService.checkAiStatus();

    if (isReady) {
      _chatHistory.add(MessageModel(
        sender: 'AI_Assistant',
        message: 'Hello! I am your HotDrop Local AI. You can ask me about the files you have received!',
      ));
      emit(AiReady(messages: List.from(_chatHistory)));
    } else {
      emit(AiError("AI Engine is not running or model failed to load."));
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // 1. Add user message to UI immediately
    _chatHistory.add(MessageModel(
      sender: 'User',
      message: text,
    ));

    emit(AiReady(messages: List.from(_chatHistory), isGenerating: true));

    // --- RAG INTEGRATION (Retrieval-Augmented Generation) ---

    // 2. Fetch the current list of received files
    final files = await _fileRepo.getLocalFiles();

    // 3. Format the file list into a context string
    String fileContext = files.isEmpty
        ? "The user has not received any files yet in this directory."
        : "The user has received the following files:\n" + files.map((f) => "- ${f.name}").join("\n");

    // 4. Inject the context silently into the prompt sent to the python backend
    String augmentedPrompt = """
[SYSTEM CONTEXT]:
$fileContext

[USER QUESTION]:
$text
""";

    // 5. Send the augmented prompt to the local AI
    final aiResponseText = await _aiService.generateResponse(augmentedPrompt);

    // 6. Add AI's response to the UI
    _chatHistory.add(MessageModel(
      sender: 'AI_Assistant',
      message: aiResponseText,
    ));

    emit(AiReady(messages: List.from(_chatHistory), isGenerating: false));
  }
}
