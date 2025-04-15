import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test/providers/message_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:test/services/data_services.dart';

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

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // AppBar and messages list
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
            title: SizedBox(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    onPressed: () {},
                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 15.sp),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    onPressed: () {},
                    icon: Icon(Icons.arrow_forward_ios_rounded, size: 15.sp),
                  ),
                  Gap(20.w),
                  Text(
                    "Messaging", 
                    style: TextStyle(fontSize: 20.sp),
                  ),
                ],
              ),
            ),
          ),
        ),
    
        // ListView of messages
        Expanded(
          child: Consumer<MessageProvider>(
            builder: (context, messageProvider, child) {
              return ListView.builder(
                controller: _scrollController,
                itemCount: messageProvider.messages.length,
                itemBuilder: (context, index) {
                  log(messageProvider.messages.toString());
                  return _MessageBubble(
                    message: messageProvider.messages[index]["message"],
                    isSent: messageProvider.messages[index]["sender"] == "Me",
                  );
                },
              );
            },
          ),
        ),
    
        // Input bar section
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(
              top: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (event) {
                    if (event.logicalKey == LogicalKeyboardKey.enter) {
                      OutgoingDataParser().parseMessages(_messageController.text, context);
    
                      setState(() {
                        if (_messageController.text.isNotEmpty) {
                          _messageController.clear();
                        }
                      });
                      _scrollToBottom();
                    }
                  },
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    style: TextStyle(fontSize: 16.sp),
                  ),
                ),
              ),
              Gap(8.w),
              IconButton(
                icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
                onPressed: () {
                  OutgoingDataParser().parseMessages(_messageController.text, context);
    
                  setState(() {
                    if (_messageController.text.isNotEmpty) {
                      _messageController.clear();
                    }
                  });
                  _scrollToBottom();
                },
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
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSent ? Theme.of(context).primaryColor : Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            message,
            style: TextStyle(
              color: isSent ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
