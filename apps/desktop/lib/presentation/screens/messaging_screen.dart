import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:test/logic/cubits/message_cubit.dart';
import 'package:test/data/models/message_model.dart';
import 'package:test/presentation/theme/app_colors.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  MessagingScreenState createState() => MessagingScreenState();
}

class MessagingScreenState extends State<MessagingScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSend() {
    if (_messageController.text.trim().isNotEmpty) {
      context.read<MessageCubit>().sendMessage(_messageController.text.trim());
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // Modern Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 20.h),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(
                  color: AppColors.surfaceContainerHighest,
                  width: 1.h,
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18.sp, color: Colors.grey),
                  onPressed: () {
                    Navigator.pop(context);
                  }, // Add navigation logic if required
                ),
                Gap(15.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "SECURE COMMS",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Gap(2.h),
                    Text(
                      "Encrypted P2P Channel",
                      style: TextStyle(color: Colors.grey, fontSize: 10.sp),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8.w,
                        height: 8.w,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Gap(8.w),
                      Text(
                        'LINK ACTIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Message List
          Expanded(
            child: BlocBuilder<MessageCubit, List<MessageModel>>(
              builder: (context, messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No transmissions yet. Initiate link.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12.sp, letterSpacing: 1),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _MessageBubble(
                      message: messages[index].message,
                      isSent: messages[index].sender == "Me",
                    );
                  },
                );
              },
            ),
          ),

          // Input Area
          Container(
            padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 20.h),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              border: Border(
                top: BorderSide(color: AppColors.surfaceContainerHighest, width: 1.h),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(30.r),
                      border: Border.all(color: AppColors.surfaceContainerHighest),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      cursorColor: AppColors.primaryContainer,
                      decoration: InputDecoration(
                        filled: false,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        hintText: "Transmit message...",
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 14.sp),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                ),
                Gap(15.w),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _handleSend,
                    child: Container(
                      padding: EdgeInsets.all(14.w),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.send_rounded, color: Colors.white, size: 18.sp),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String message;
  final bool isSent;

  const _MessageBubble({required this.message, required this.isSent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 8.h),
      child: Align(
        alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
          decoration: BoxDecoration(
            color: isSent ? AppColors.primaryContainer : AppColors.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20.r),
              topRight: Radius.circular(20.r),
              bottomLeft: isSent ? Radius.circular(20.r) : Radius.circular(4.r),
              bottomRight: isSent ? Radius.circular(4.r) : Radius.circular(20.r),
            ),
            border: isSent ? null : Border.all(color: AppColors.surfaceContainerHighest),
          ),
          child: Text(
            message,
            style: TextStyle(
              color: isSent ? Colors.white : Colors.grey.shade200,
              fontSize: 14.sp,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}
