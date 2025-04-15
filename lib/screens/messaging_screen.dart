import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:test_mobile/providers/message_provider.dart';
import 'package:test_mobile/services/data_services.dart';
import 'package:test_mobile/services/message_storage_service.dart';
import 'package:gap/gap.dart';

class Message {
  final String content;
  final bool isSent;
  final DateTime timestamp;

  Message({
    required this.content,
    required this.isSent,
    required this.timestamp,
  });
}

class MessagingScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const MessagingScreen({required this.data, super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MessageStorageService _storageService = MessageStorageService();

  @override
  void initState() {
    super.initState();
    _loadStoredMessages();
  }

  void _loadStoredMessages() async {
    final provider = Provider.of<MessageProvider>(context, listen: false);

    if (provider.messages.isEmpty) {
      final messages = await _storageService.loadMessages();
      for (var msg in messages) {
        provider.addMessage(msg['content'], msg['isSent'] as bool);
      }
    }
  }


  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      OutgoingDataParser().parseMessages(text);
      Provider.of<MessageProvider>(context, listen: false).addMessage(text, true);
      _storageService.saveMessage(text, true, DateTime.now());
      _messageController.clear();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        titleSpacing: 0,
        title: Text(
          'Chat',
          style: TextStyle(
            color: const Color(0xFF49454F),
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
        child: Column(
          children: [
            Expanded(
              child: Consumer<MessageProvider>(
                builder: (context, messageProvider, child) {
                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: messageProvider.messages.length,
                    padding: EdgeInsets.only(bottom: 20.h),
                    itemBuilder: (context, index) {
                      log(messageProvider.messages[index].toString());
                      return _MessageBubble(
                        message: messageProvider.messages[index]["message"],
                        isSent: messageProvider.messages[index]["sender"] == "Me" ? true : false,
                      );
                    },
                  );
                },
              ),
            ),
            Gap(8.h),
            Text(
              'Messages are end-to-end encrypted',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF49454F),
                fontSize: 12.sp,
              ),
            ),
            Gap(12.h),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF6F6F6),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendMessage,
                    color: const Color(0xFF49454F),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 6.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        constraints: BoxConstraints(maxWidth: 0.75.sw),
        decoration: BoxDecoration(
          color: isSent ? const Color(0xFF49454F) : const Color(0xFFF6F6F6),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.r),
            topRight: Radius.circular(16.r),
            bottomLeft: Radius.circular(isSent ? 16.r : 0),
            bottomRight: Radius.circular(isSent ? 0 : 16.r),
          ),
        ),
        child: Text(
          message,
          style: TextStyle(
            color: isSent ? Colors.white : const Color(0xFF49454F),
            fontSize: 14.sp,
          ),
        ),
      ),
    );
  }
}
