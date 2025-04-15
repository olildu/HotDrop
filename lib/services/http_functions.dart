import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:test/constants/globals.dart';
import 'package:test/services/common_functions.dart';
import 'package:test/providers/popup_provider.dart';
import 'package:test/services/connection_services.dart';

class HttpFunctions {

  Future<String?> downloadFile(String url, String fileName) async {
    try {
      final stopwatch = Stopwatch()..start();
      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);

      if (response.statusCode == 200) {
        final nDropDir = await CommonFunctions().getHotDropDirectory();
        if (!await nDropDir.exists()) {
          await nDropDir.create(recursive: true);
        }

        final filePath = '${nDropDir.path}/$fileName';
        final file = File(filePath);
        final sink = file.openWrite();

        int downloadedBytes = 0;
        final totalBytes = response.contentLength ?? 0;

        // Show popup at start
        navigatorKey.currentContext!.read<PopupProvider>().show("Receiving file...", Icons.download, progress: 0);

        await response.stream.listen(
          (chunk) {
            downloadedBytes += chunk.length;
            sink.add(chunk);

            if (totalBytes > 0) {
              final progress = downloadedBytes / totalBytes;
              final progressPercent = (progress * 100).toStringAsFixed(2);
              log("Downloading... $progressPercent%");
              navigatorKey.currentContext!.read<PopupProvider>().updateProgress(progress);
            } else {
              log("Downloading... unknown%");
            }
          },
          onError: (e) {
            log("Error while streaming: $e");
            navigatorKey.currentContext!.read<PopupProvider>().hide();
          },
          cancelOnError: true,
        ).asFuture();

        await sink.flush();
        await sink.close();
        stopwatch.stop();

        final elapsedTimeInSeconds = stopwatch.elapsedMilliseconds / 1000;
        final downloadSpeed = downloadedBytes / elapsedTimeInSeconds;

        log("File downloaded successfully to $filePath");
        log("Average download speed: ${(downloadSpeed / 1024).toStringAsFixed(2)} KB/s");

        navigatorKey.currentContext!.read<PopupProvider>().show("Download complete!", Icons.check_circle_outline);
        
        DartFunction().sendMessage(jsonEncode({"type": "downloadComplete", "transfer_speed" : downloadSpeed, "name": fileName, "size" : totalBytes}));

        return filePath;
      } else {
        log("Failed to download file: ${response.statusCode}");
        navigatorKey.currentContext!.read<PopupProvider>().show("Download failed", Icons.error_outline);
        return null;
      }
    } catch (e) {
      log("Error downloading file: $e");
      navigatorKey.currentContext!.read<PopupProvider>().show("Download error", Icons.error_outline);
      return null;
    }
  }
}
