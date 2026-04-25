import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:test/logic/injection_container.dart';
import 'package:test/logic/cubits/popup_cubit.dart';
import 'package:test/data/services/common_functions.dart';
import 'package:test/data/services/connection_services.dart';

class HttpFunctions {
  void _log(String functionName, String message, {Object? error, StackTrace? stackTrace}) {
    dev.log(message, name: functionName, error: error, stackTrace: stackTrace);
  }

  Future<String?> downloadFile(
    String url,
    String fileName, {
    void Function(double progress)? onProgress,
  }) async {
    _log('downloadFile', 'Starting download from $url for $fileName');
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

        // Use PopupCubit via sl instead of Provider
        sl<PopupCubit>().show("Receiving file...", Icons.download, progress: 0);

        await response.stream.listen(
          (chunk) {
            downloadedBytes += chunk.length;
            sink.add(chunk);

            if (totalBytes > 0) {
              final progress = downloadedBytes / totalBytes;
              final progressPercent = (progress * 100).toStringAsFixed(2);

              // Notify remote peer of progress
              DartFunction().sendMessage(jsonEncode({
                "type": "progress",
                "progress_percent": progressPercent,
                "file_name": fileName,
              }));

              sl<PopupCubit>().updateProgress(progress);
              onProgress?.call(progress);
            }
          },
          onError: (e) {
            _log('downloadFile', 'Error while streaming file response', error: e);
            sl<PopupCubit>().hide();
          },
          cancelOnError: true,
        ).asFuture();

        await sink.flush();
        await sink.close();
        stopwatch.stop();

        final elapsedTimeInSeconds = stopwatch.elapsedMilliseconds / 1000;
        final downloadSpeed = downloadedBytes / elapsedTimeInSeconds;
        _log('downloadFile', 'Download completed in ${elapsedTimeInSeconds.toStringAsFixed(2)}s at ${downloadSpeed.toStringAsFixed(2)} B/s');

        sl<PopupCubit>().show("Download complete!", Icons.check_circle_outline);

        // Notify remote peer of completion
        DartFunction().sendMessage(jsonEncode({"type": "downloadComplete", "transfer_speed": downloadSpeed, "name": fileName, "size": totalBytes}));

        return filePath;
      } else {
        _log('downloadFile', 'Download failed with status code ${response.statusCode}');
        sl<PopupCubit>().show("Download failed", Icons.error_outline);
        return null;
      }
    } catch (e) {
      _log('downloadFile', 'Error downloading file', error: e);
      sl<PopupCubit>().show("Download error", Icons.error_outline);
      return null;
    }
  }
}
