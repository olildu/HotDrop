import 'package:flutter/material.dart';

class MessageProvider with ChangeNotifier {
  final List<dynamic> _messages = [];

  List<dynamic> get messages => _messages;

  void addMessage(String message, bool isSent) {
    final exists = _messages.any((m) => m["message"] == message && m["sender"] == (isSent ? "Me" : "Other"));
    if (!exists) {
      _messages.add({
        "message": message,
        "sender": isSent ? "Me" : "Other",
      });
      notifyListeners();
    }
  }
}
