import 'dart:convert';
import 'dart:developer' as dev;
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
  void _log(String functionName, String message, {Object? error, StackTrace? stackTrace}) {
    dev.log(message, name: functionName, error: error, stackTrace: stackTrace);
  }

  void parseData(String data) async {
    _log('parseData', 'Received raw socket data (${data.length} chars)');
    // FIX: Handle clumped JSON objects (e.g., "{...}{...}")
    String sanitizedData = data.replaceAll('}{', '}\n{');
    List<String> messages = sanitizedData.split('\n');

    for (String msg in messages) {
      if (msg.trim().isEmpty) continue;

      try {
        var parsedData = jsonDecode(msg);

        // Handle Incoming Messages
        if (parsedData["type"] == "message") {
          _log('parseData', 'Handling incoming chat message');
          sl<PopupCubit>().show("You have a new message", Icons.message_rounded);
          sl<MessageCubit>().addMessage(MessageModel(
            message: parsedData["content"],
            sender: "Other",
          ));
        }

        // Handle Incoming Contacts
        else if (parsedData["type"] == "contacts") {
          _log('parseData', 'Handling incoming contacts payload');
          final contacts = sl<ContactRepository>().parseRawContacts(parsedData["content"]);
          sl<ContactCubit>().replaceContacts(contacts);
        }

        // Handle Incoming HotDrop Files (Mobile -> Desktop)
        else if (parsedData["type"] == "HotDropFile") {
          _log('parseData', 'Handling incoming HotDrop file metadata');
          sl<HotdropCubit>().addFile(FileModel.fromMap(parsedData));
        }

        // --- NEW: Handle Outgoing Progress (Desktop -> Mobile) ---
        else if (parsedData["type"] == "progress") {
          _log('parseData', 'Handling outgoing transfer progress update');
          final String rawPercent = parsedData["progress_percent"]?.toString() ?? "0.0";
          double progressValue = double.tryParse(rawPercent) ?? 0.0;

          // Convert 0-100% to 0.0-1.0 for the progress bar
          double normalizedProgress = (progressValue / 100.0).clamp(0.0, 1.0);

          sl<HotdropCubit>().updateOutgoingProgress(parsedData["name"] ?? parsedData["file_name"] ?? "", normalizedProgress);
        }

        // --- NEW: Handle Outgoing Completion (Desktop -> Mobile) ---
        else if (parsedData["type"] == "downloadComplete") {
          _log('parseData', 'Handling outgoing transfer completion update');
          sl<HotdropCubit>().completeOutgoingTransfer(
            parsedData["name"] ?? "",
            (parsedData["transfer_speed"] ?? 0.0).toDouble(),
            parsedData["size"] ?? 0,
          );
        }
      } catch (e) {
        _log('parseData', 'Failed to parse incoming message chunk', error: e);
        // Ignore JSON parsing errors for partial chunks
      }
    }
  }
}

class OutgoingDataParser {
  // Messages are now handled directly by the MessageCubit and its Repository
  void parseMessages(String message) {
    dev.log('Forwarding outgoing chat message (${message.length} chars)', name: 'parseMessages');
    sl<MessageCubit>().sendMessage(message);
  }
}
