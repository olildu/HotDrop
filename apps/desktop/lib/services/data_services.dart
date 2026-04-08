import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test/constants/globals.dart';
import 'package:test/constants/globals.dart' as globals;
import 'package:test/providers/contact_provider.dart';
import 'package:test/providers/hotdrop_provider.dart';
import 'package:test/providers/message_provider.dart';
import 'package:test/services/connection_services.dart';

int byteCount = 0;
String sdata = "";
String fileName = "";
Stopwatch stopwatch = Stopwatch();

class ReceivedDataParser {
  void parseData(String data) async {
    if (globals.navigatorKey.currentContext == null) return;
    var parsedData = jsonDecode(data);

    if (parsedData["type"] == "message") {
      Provider.of<MessageProvider>(navigatorKey.currentContext!, listen: false).addMessage({
        "message": parsedData["content"],
        "sender": "Other",
      });
    }

    if (parsedData["type"] == "contacts") {
      List contacts = [];

      for (var x in parsedData["content"]) {
        String name = x["displayName"] ?? "Unknown";
        String id = x["id"] ?? "Unknown";
        String normalizedNumber = x["normalizedNumber"] ?? "";
        contacts.add({"name": name, "id": id, "normalizedNumber": normalizedNumber.isNotEmpty ? jsonDecode(normalizedNumber) : null});
      }

      Provider.of<ContactProvider>(navigatorKey.currentContext!, listen: false).replaceContacts(contacts);
    }

    if (parsedData["type"] == "HotDropFile") {
      Provider.of<HotdropProvider>(navigatorKey.currentContext!, listen: false).addFile(parsedData);
    }
  }
}

class OutgoingDataParser {
  // Message handling
  void parseMessages(String message) {
    if (globals.navigatorKey.currentContext == null) return;
    Provider.of<MessageProvider>(navigatorKey.currentContext!, listen: false).addMessage(
      {
        "message": message,
        "sender": "Me",
      },
    );

    DartFunction().sendMessage(jsonEncode({"type": "message", "format": "string", "content": message}));
  }
}
