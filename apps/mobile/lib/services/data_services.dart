import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter_contacts/contact.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:test_mobile/constants/globals.dart';
import 'package:test_mobile/providers/file_detail_provider.dart';
import 'package:test_mobile/providers/message_provider.dart';
import 'package:test_mobile/screens/hotdrop_screen.dart';
import 'package:test_mobile/services/connection_services.dart';
import 'package:test_mobile/services/message_storage_service.dart';

class ReceivedDataParser {
  void parseData(String data) {
    // Handle potentially grouped JSON strings separated by newlines
    List<String> messages = data.split('\n');
    
    for (String msg in messages) {
      if (msg.trim().isEmpty) continue;
      
      try {
        var parsedData = jsonDecode(msg);

        if (parsedData["type"] == "message") {
          String messageContent = parsedData["content"];
          Provider.of<MessageProvider>(navigatorKey.currentContext!, listen: false).addMessage(messageContent, false);
          MessageStorageService().saveMessage(messageContent, false, DateTime.now());
        }
        else if (parsedData["type"] == "HotDropFile") {
          // Trigger HTTP Download
          _downloadFileFromHost(
            parsedData["url"], 
            parsedData["name"], 
            parsedData["size"]
          );
        }
        else if (parsedData["type"] == "downloadComplete") {
          if (hotdropScreenKey.currentState != null) {
            HotdopScreenScreenState state = hotdropScreenKey.currentState!;
            state.uploadComplete = true;
            state.isUploading = false;
            state.updateState(state.uploadComplete);

            FileDetailProvider fileProvider = Provider.of<FileDetailProvider>(navigatorKey.currentContext!, listen: false);
            fileProvider.addFileDetail(
              fileName: parsedData["name"],
              fileSize: parsedData["size"],
              isSent : true,
              timestamp: DateTime.now(),
              transferSpeed: parsedData["transfer_speed"] ?? 0.0
            );
          }
        }
      } catch (e) {
        log("Error parsing data: $e");
      }
    }
  }

  Future<void> _downloadFileFromHost(String url, String fileName, int fileSize) async {
    try {
      log("Starting download for $fileName from $url", name: "Downloader");
      final stopwatch = Stopwatch()..start();
      
      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);

      if (response.statusCode == 200) {
        // Save to app's document directory (or Downloads folder)
        final directory = await getApplicationDocumentsDirectory();
        final savePath = '${directory.path}/HotDrop';
        final dir = Directory(savePath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        final file = File('$savePath/$fileName');
        final sink = file.openWrite();

        int downloadedBytes = 0;

        await response.stream.listen(
          (chunk) {
            downloadedBytes += chunk.length;
            sink.add(chunk);
            // Optionally update a progress provider here
          },
          onError: (e) => log("Error while streaming: $e"),
          cancelOnError: true,
        ).asFuture();

        await sink.flush();
        await sink.close();
        stopwatch.stop();

        final elapsedTimeInSeconds = stopwatch.elapsedMilliseconds / 1000;
        final downloadSpeed = (downloadedBytes / elapsedTimeInSeconds);

        log("File downloaded successfully to ${file.path}");
        
        // Save to FileDetailProvider
        Provider.of<FileDetailProvider>(navigatorKey.currentContext!, listen: false).addFileDetail(
          fileName: fileName,
          fileSize: fileSize,
          isSent: false,
          timestamp: DateTime.now(),
          transferSpeed: downloadSpeed,
        );

        // Notify Host that download is complete
        DartFunction().sendDataToSocket(jsonEncode({
          "type": "downloadComplete",
          "name": fileName,
          "size": fileSize,
          "transfer_speed": downloadSpeed
        }));

      } else {
        log("Failed to download file: ${response.statusCode}");
      }
    } catch (e) {
      log("Error downloading file: $e");
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
        "normalizedNumber": contact.phones.isNotEmpty ? contact.phones[0].normalizedNumber : null,
      }).toList(),
    }));
  }
}