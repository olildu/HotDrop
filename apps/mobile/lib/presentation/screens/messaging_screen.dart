import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:test_mobile/logic/cubits/message_cubit.dart';
import 'package:test_mobile/logic/cubits/session/session_cubit.dart';
import 'package:test_mobile/presentation/theme/app_colors.dart';
import 'package:test_mobile/data/models/message_model.dart';

class MessagingScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const MessagingScreen({required this.data, super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final didSend = context.read<MessageCubit>().sendMessageIfValid(_messageController.text);
    if (didSend) {
      _messageController.clear();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _buildAppBar(context),
      body: BlocBuilder<SessionCubit, SessionState>(
        builder: (context, sessionState) {
          final isConnected = context.read<SessionCubit>().isConnectedState(sessionState);

          return Column(
            children: [
              // Connection Status Banner
              if (!isConnected)
                Container(
                  width: double.infinity,
                  color: AppColors.errorAccent.withOpacity(0.1),
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Text(
                    "DISCONNECTED - MESSAGING UNAVAILABLE",
                    textAlign: TextAlign.center,
                    style: textTheme.labelSmall?.copyWith(color: AppColors.errorAccent, fontWeight: FontWeight.bold),
                  ),
                ),

              // Message List
              Expanded(
                child: BlocConsumer<MessageCubit, MessageState>(
                  listener: (context, state) => _scrollToBottom(),
                  builder: (context, state) {
                    if (state.messages.isEmpty) {
                      return _buildEmptyState(textTheme);
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.all(24.w),
                      itemCount: state.messages.length,
                      itemBuilder: (context, index) => _MessageBubble(message: state.messages[index]),
                    );
                  },
                ),
              ),

              // Input Area
              _buildInputArea(isConnected),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: const BackButton(color: AppColors.onSurface),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Direct Workspace", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18.sp)),
          Text("End-to-End Encrypted Tunnel", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 64.sp, color: AppColors.surfaceContainerHighest),
          Gap(16.h),
          Text("No signals detected in this channel.", style: textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isConnected) {
    return Container(
      padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 12.h),
      decoration: const BoxDecoration(color: AppColors.surface),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 60.h,
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(28.r),
              ),
              child: Center(
                child: TextField(
                  controller: _messageController,
                  enabled: isConnected,
                  style: const TextStyle(color: AppColors.onSurface),
                  decoration: InputDecoration(
                    hintText: isConnected ? "Enter kinetic pulse..." : "Waiting for connection...",
                    border: InputBorder.none,
                    filled: false,
                    focusedBorder: InputBorder.none,
                    hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withOpacity(0.5)),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
          ),
          Gap(12.w),
          GestureDetector(
            onTap: isConnected ? _sendMessage : null,
            child: CircleAvatar(
              radius: 28.r,
              backgroundColor: isConnected ? AppColors.primary : AppColors.surfaceContainerHighest,
              child: Icon(Icons.send_rounded, color: isConnected ? AppColors.surface : AppColors.onSurfaceVariant, size: 22.sp),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isSent;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        constraints: BoxConstraints(maxWidth: 0.75.sw),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24.r),
            topRight: Radius.circular(24.r),
            bottomLeft: Radius.circular(isMe ? 24.r : 4.r),
            bottomRight: Radius.circular(isMe ? 4.r : 24.r),
          ),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isMe ? AppColors.surface : AppColors.onSurface,
            fontSize: 15.sp,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
