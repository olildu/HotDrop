import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:test/logic/cubits/message_cubit.dart';
import 'package:test/data/models/message_model.dart';

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
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: const Color.fromARGB(255, 231, 231, 231),
                width: 1.w,
              ),
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.white,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, size: 15.sp), onPressed: () {}),
                IconButton(icon: Icon(Icons.arrow_forward_ios_rounded, size: 15.sp), onPressed: () {}),
                Gap(20.w),
                Text("Messaging", style: TextStyle(fontSize: 20.sp)),
              ],
            ),
          ),
        ),
        Expanded(
          child: BlocBuilder<MessageCubit, List<MessageModel>>(
            builder: (context, messages) {
              return ListView.builder(
                controller: _scrollController,
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
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(top: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              Expanded(
                child: RawKeyboardListener(
                  focusNode: FocusNode(),
                  onKey: (event) {
                    if (event.logicalKey == LogicalKeyboardKey.enter && event is RawKeyDownEvent) {
                      _handleSend();
                    }
                  },
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                    style: TextStyle(fontSize: 16.sp),
                  ),
                ),
              ),
              Gap(8.w),
              IconButton(
                icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
                onPressed: _handleSend,
              ),
            ],
          ),
        ),
      ],
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
      padding: EdgeInsets.symmetric(horizontal: 15.w),
      child: Align(
        alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSent ? Theme.of(context).primaryColor : Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            message,
            style: TextStyle(color: isSent ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }
}

