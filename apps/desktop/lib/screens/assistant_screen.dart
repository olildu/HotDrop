import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import '../blocs/ai_cubit.dart';
import '../core/theme/app_colors.dart';
import '../injection_container.dart';

class AssistantScreen extends StatelessWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Provide the AiCubit from your service locator and initialize it automatically
    return BlocProvider(
      create: (_) => sl<AiCubit>()..initializeAi(),
      child: const _AssistantView(),
    );
  }
}

class _AssistantView extends StatefulWidget {
  const _AssistantView();

  @override
  State<_AssistantView> createState() => _AssistantViewState();
}

class _AssistantViewState extends State<_AssistantView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _sendMessage() {
    final text = _textController.text;
    if (text.trim().isNotEmpty) {
      context.read<AiCubit>().sendMessage(text);
      _textController.clear();
      // Scroll to bottom after sending
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // Matching your MainScreen aesthetic
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
            ),
            child: Row(
              children: [
                Icon(Icons.smart_toy, color: AppColors.primaryContainer, size: 28.sp),
                Gap(10.w),
                Text(
                  "HotDrop AI Assistant",
                  style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const Spacer(),
                BlocBuilder<AiCubit, AiState>(
                  builder: (context, state) {
                    if (state is AiCheckingStatus) {
                      return SizedBox(
                        height: 20.sp, 
                        width: 20.sp, 
                        child: const CircularProgressIndicator(strokeWidth: 2)
                      );
                    }
                    if (state is AiReady) {
                      return Row(
                        children: [
                          Icon(Icons.circle, color: Colors.green, size: 12.sp),
                          Gap(5.w),
                          const Text("Online")
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                )
              ],
            ),
          ),

          // Chat Messages Area
          Expanded(
            child: BlocBuilder<AiCubit, AiState>(
              builder: (context, state) {
                if (state is AiCheckingStatus) {
                  return const Center(child: Text("Waking up AI Engine..."));
                } else if (state is AiError) {
                  return Center(child: Text(state.errorMessage, style: const TextStyle(color: Colors.red)));
                } else if (state is AiReady) {
                  return ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.all(20.w),
                    itemCount: state.messages.length + (state.isGenerating ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.messages.length) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text("Assistant is typing...", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                          ),
                        );
                      }

                      final msg = state.messages[index];
                      final isMe = msg.sender == 'User';

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: EdgeInsets.only(bottom: 15.h),
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                          constraints: BoxConstraints(maxWidth: 600.w),
                          decoration: BoxDecoration(
                            color: isMe ? AppColors.primaryContainer : const Color.fromARGB(255, 240, 240, 240),
                            borderRadius: BorderRadius.circular(12).copyWith(
                              bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(12),
                              bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(12),
                            ),
                          ),
                          child: Text(
                            msg.message,
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: isMe ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),

          // Input Field
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 248, 248, 248),
              border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: "Ask the AI Assistant...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
                    ),
                  ),
                ),
                Gap(10.w),
                CircleAvatar(
                  backgroundColor: AppColors.primaryContainer,
                  radius: 25.sp,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}