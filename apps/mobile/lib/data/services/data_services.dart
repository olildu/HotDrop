import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/contact.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:test_mobile/logic/cubits/hotdrop_cubit.dart'; // Required for progress updates
import 'package:test_mobile/logic/cubits/popup_cubit.dart';
import 'package:test_mobile/data/models/file_model.dart';
import 'package:test_mobile/data/repositories/chat_repository.dart';
import 'package:test_mobile/data/repositories/file_repository.dart';
import 'package:test_mobile/logic/di/injection_container.dart' as di; // Use GetIt
import 'package:test_mobile/data/services/connection_services.dart';
import 'package:test_mobile/data/services/file_hosting_services.dart';

class ReceivedDataParser {
  final FileRepository _fileRepository;

  ReceivedDataParser(this._fileRepository);

  void parseData(String data) {
    // FIX: Handle clumped JSON objects (e.g., "{...}{...}") by inserting newlines before parsing
    String sanitizedData = data.replaceAll('}{', '}\n{');
    List<String> messages = sanitizedData.split('\n');

    for (String msg in messages) {
      if (msg.trim().isEmpty) continue;

      try {
        var parsedData = jsonDecode(msg);

        if (parsedData["type"] == "message") {
          final content = parsedData["content"];
          di.sl<ChatRepository>().onMessageReceived(content);
          di.sl<PopupCubit>().show('New message: $content', Icons.message_rounded);
        } else if (parsedData["type"] == "HotDropFile") {
          final fileName = parsedData["name"]?.toString() ?? 'Incoming file';
          di.sl<PopupCubit>().show('Incoming file: $fileName', Icons.download_rounded, progress: 0);
          _downloadFileFromHost(parsedData["url"], parsedData["name"], parsedData["size"]);
        }
        // FIX: Match the actual type "downloadProgress" seen in logs
        else if (parsedData["type"] == "progress") {
          // Parse string percentage (e.g., "0.27") to double
          final String rawPercent = parsedData["progress_percent"] ?? "0.0";
          double progressValue = double.tryParse(rawPercent) ?? 0.0;

          // Scale 0-100 down to 0.0-1.0 for the LinearProgressIndicator
          double normalizedProgress = (progressValue / 100.0).clamp(0.0, 1.0);

          log("Updating UI progress to: ${(normalizedProgress * 100).toInt()}%", name: "Parser");
          di.sl<HotDropCubit>().updateProgress(normalizedProgress);
          di.sl<PopupCubit>().updateProgress(normalizedProgress);
        } else if (parsedData["type"] == "downloadComplete") {
          di.sl<HotDropCubit>().completeTransfer();

          final hostingService = di.sl<FileHostingService>();
          final String fileName = parsedData["name"];
          di.sl<PopupCubit>().complete('File received: $fileName');

          final hostedFile = hostingService.selectedFiles.firstWhere(
            (file) => file.path.split('/').last == fileName,
            orElse: () => File(''),
          );

          final fileModel = FileModel(
            name: fileName,
            size: parsedData["size"],
            timestamp: DateTime.now(),
            transferSpeed: (parsedData["transfer_speed"] ?? 0.0).toDouble(),
            isSent: true,
            path: hostedFile.path.isNotEmpty ? hostedFile.path : null,
          );

          _fileRepository.onFileProcessed(fileModel);
        }
      } catch (e) {
        log("Error parsing incoming socket data: $e");
      }
    }
  }

  /// Handles the actual HTTP download when another device sends a file to this mobile app
  Future<void> _downloadFileFromHost(String url, String fileName, int fileSize) async {
    try {
      final stopwatch = Stopwatch()..start();
      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);

      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/HotDrop/$fileName');
        if (!await file.parent.exists()) await file.parent.create(recursive: true);

        final sink = file.openWrite();
        int downloadedBytes = 0;
        double lastSentProgress = 0.0; // Track for throttling

        await response.stream.listen((chunk) {
          downloadedBytes += chunk.length;
          sink.add(chunk);

          // IMPLEMENTED: Throttled progress sending
          double currentProgress = (downloadedBytes / fileSize) * 100;
          if (currentProgress - lastSentProgress >= 1.0 || currentProgress >= 99.9) {
            lastSentProgress = currentProgress;
            DartFunction().sendDataToSocket(jsonEncode({
              "type": "progress",
              "progress_percent": currentProgress.toStringAsFixed(2),
              "name": fileName,
            }));
            di.sl<PopupCubit>().updateProgress((currentProgress / 100).clamp(0.0, 1.0));
          }
        }).asFuture();

        await sink.flush();
        await sink.close();
        stopwatch.stop();

        final speed = downloadedBytes / (stopwatch.elapsedMilliseconds / 1000);

        final fileModel = FileModel(
          name: fileName,
          size: fileSize,
          timestamp: DateTime.now(),
          transferSpeed: speed,
          isSent: false,
          path: file.path,
        );

        _fileRepository.onFileProcessed(fileModel);

        // Notify the Sender (Host) that we have finished the download
        DartFunction().sendDataToSocket(jsonEncode({"type": "downloadComplete", "name": fileName, "size": fileSize, "transfer_speed": speed}));
        di.sl<PopupCubit>().complete('File received: $fileName');
      } else {
        di.sl<PopupCubit>().hide();
      }
    } catch (e) {
      log("Download error: $e");
      di.sl<PopupCubit>().hide();
    }
  }
}

class OutgoingDataParser {
  /// Encapsulates a text message into JSON for transmission over the socket
  void parseMessages(String message) {
    DartFunction().sendDataToSocket(jsonEncode({"type": "message", "content": message}));
  }

  /// Encapsulates contact information for initial device handshakes
  Future<void> parseContacts(List<Contact> contacts) async {
    DartFunction().sendDataToSocket(jsonEncode({
      "type": "contacts",
      "format": "list",
      "content": contacts
          .map((contact) => {
                "id": contact.id,
                "displayName": contact.displayName,
                "normalizedNumber": contact.phones.isNotEmpty ? contact.phones[0].normalizedNumber : null,
              })
          .toList(),
    }));
  }
}
