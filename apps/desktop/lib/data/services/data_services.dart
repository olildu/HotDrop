import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:test/logic/injection_container.dart';
import 'package:test/logic/cubits/message_cubit.dart';
import 'package:test/logic/cubits/contact_cubit.dart';
import 'package:test/logic/cubits/hotdrop_cubit.dart';
import 'package:test/logic/cubits/popup_cubit.dart';
import 'package:test/data/models/message_model.dart';
import 'package:test/data/models/file_model.dart';
import 'package:test/data/repositories/contact_repository.dart';

class ReceivedDataParser {
  void parseData(String data) async {
    var parsedData = jsonDecode(data);

    // Handle Incoming Messages
    if (parsedData["type"] == "message") {
      sl<PopupCubit>().show("You have a new message", Icons.message_rounded);
      sl<MessageCubit>().addMessage(MessageModel(
        message: parsedData["content"],
        sender: "Other",
      ));
    }

    // Handle Incoming Contacts
    if (parsedData["type"] == "contacts") {
      final contacts = sl<ContactRepository>().parseRawContacts(parsedData["content"]);
      sl<ContactCubit>().replaceContacts(contacts);
    }

    // Handle Incoming HotDrop Files
    if (parsedData["type"] == "HotDropFile") {
      sl<HotdropCubit>().addFile(FileModel.fromMap(parsedData));
    }
  }
}

class OutgoingDataParser {
  // Messages are now handled directly by the MessageCubit and its Repository
  void parseMessages(String message) {
    sl<MessageCubit>().sendMessage(message);
  }
}


