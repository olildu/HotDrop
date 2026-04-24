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
    // FIX: Handle clumped JSON objects (e.g., "{...}{...}")
    String sanitizedData = data.replaceAll('}{', '}\n{');
    List<String> messages = sanitizedData.split('\n');

    for (String msg in messages) {
      if (msg.trim().isEmpty) continue;

      try {
        var parsedData = jsonDecode(msg);

        // Handle Incoming Messages
        if (parsedData["type"] == "message") {
          sl<PopupCubit>().show("You have a new message", Icons.message_rounded);
          sl<MessageCubit>().addMessage(MessageModel(
            message: parsedData["content"],
            sender: "Other",
          ));
        }

        // Handle Incoming Contacts
        else if (parsedData["type"] == "contacts") {
          final contacts = sl<ContactRepository>().parseRawContacts(parsedData["content"]);
          sl<ContactCubit>().replaceContacts(contacts);
        }

        // Handle Incoming HotDrop Files (Mobile -> Desktop)
        else if (parsedData["type"] == "HotDropFile") {
          sl<HotdropCubit>().addFile(FileModel.fromMap(parsedData));
        }

        // --- NEW: Handle Outgoing Progress (Desktop -> Mobile) ---
        else if (parsedData["type"] == "progress") {
          final String rawPercent = parsedData["progress_percent"]?.toString() ?? "0.0";
          double progressValue = double.tryParse(rawPercent) ?? 0.0;

          // Convert 0-100% to 0.0-1.0 for the progress bar
          double normalizedProgress = (progressValue / 100.0).clamp(0.0, 1.0);

          sl<HotdropCubit>().updateOutgoingProgress(parsedData["name"] ?? parsedData["file_name"] ?? "", normalizedProgress);
        }

        // --- NEW: Handle Outgoing Completion (Desktop -> Mobile) ---
        else if (parsedData["type"] == "downloadComplete") {
          sl<HotdropCubit>().completeOutgoingTransfer(
            parsedData["name"] ?? "",
            (parsedData["transfer_speed"] ?? 0.0).toDouble(),
            parsedData["size"] ?? 0,
          );
        }
      } catch (e) {
        // Ignore JSON parsing errors for partial chunks
      }
    }
  }
}

class OutgoingDataParser {
  // Messages are now handled directly by the MessageCubit and its Repository
  void parseMessages(String message) {
    sl<MessageCubit>().sendMessage(message);
  }
}
