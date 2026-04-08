import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test/constants/globals.dart' as globals;
import 'package:test/providers/popup_provider.dart';

class MessageProvider with ChangeNotifier {
  final List<dynamic> _messages = [];

  List<dynamic> get messages => _messages;

  void addMessage(Map message) {
    if (globals.navigatorKey.currentContext != null) {
      Provider.of<PopupProvider>(globals.navigatorKey.currentContext!, listen: false).show("You have a new message", Icons.message_rounded);
    }

    _messages.add(message);

    log(_messages.toString(), name: "MessageProvider");

    notifyListeners();
  }
}
