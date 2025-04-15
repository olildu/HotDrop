import 'dart:convert';
import 'package:flutter_contacts/contact.dart';
import 'package:provider/provider.dart';
import 'package:test_mobile/constants/globals.dart';
import 'package:test_mobile/providers/file_detail_provider.dart';
import 'package:test_mobile/providers/message_provider.dart';
import 'package:test_mobile/screens/hotdrop_screen.dart';
import 'package:test_mobile/services/connection_services.dart';
import 'package:test_mobile/services/file_storage_service.dart';
import 'package:test_mobile/services/message_storage_service.dart';

class ReceivedDataParser {
  void parseData(String data) {
    var parsedData = jsonDecode(data);

    if (parsedData["type"] == "message") {
      String messageContent = parsedData["content"];
      Provider.of<MessageProvider>(navigatorKey.currentContext!, listen: false).addMessage(messageContent, false);
      MessageStorageService().saveMessage(messageContent, false, DateTime.now());
    }

    else if (parsedData["type"] == "downloadComplete") {
      if (hotdropScreenKey.currentState != null) {
        HotdopScreenScreenState hotdopScreenScreenState = hotdropScreenKey.currentState!;
        hotdopScreenScreenState.uploadComplete = true;
        hotdopScreenScreenState.isUploading = false;
        hotdopScreenScreenState.updateState(hotdopScreenScreenState.uploadComplete);

        FileDetailProvider fileDetailProvider = Provider.of<FileDetailProvider>(navigatorKey.currentContext!, listen: false);
        
        fileDetailProvider.addFileDetail(
          fileName: parsedData["name"],
          fileSize: parsedData["size"],
          isSent : true,
          timestamp: DateTime.now(),
          transferSpeed: parsedData["transfer_speed"]
        );
      }
    }
  }

}

class OutgoingDataParser {
  void parseMessages(String message){
    Provider.of<MessageProvider>(navigatorKey.currentContext!, listen: false).addMessage(message, true);
    DartFunction().sendDataToSocket(
      jsonEncode({
        "type" : "message", 
        "format" : "string", 
        "content" : message
      })
    );
  }

  Future<void> parseContacts(List<Contact> contacts) async {
    DartFunction().sendDataToSocket(jsonEncode({
      "type": "contacts",
      "format": "list",
      "content": contacts.map((contact) => {
        "id": contact.id,
        "displayName": contact.displayName,
        "normalizedNumber": contact.phones.isNotEmpty ? jsonEncode(contact.phones[0].normalizedNumber) : null,
      }).toList(),
    }));
  }
}