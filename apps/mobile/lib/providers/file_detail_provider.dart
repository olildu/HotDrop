import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:test_mobile/services/file_storage_service.dart';

class FileDetailProvider with ChangeNotifier {
  final List<Map> _files = [];

  List<Map> get files => _files;


  int _lastFileCount = -1;
  Map<String, String>? _cachedStats;

  void addFileDetail({required String fileName, required int fileSize, required DateTime timestamp, required double transferSpeed, required bool isSent}) {
    _files.add({
      'file_name': fileName,
      'file_size': fileSize,
      'timestamp': timestamp.toIso8601String(),
      "is_sent": isSent,
      "transfer_speed": transferSpeed,
    });

    log('File added: $fileName to provider', name: 'FileDetailProvider');

    FileStorageService().saveFileDetails(
      fileName: fileName,
      fileSize: fileSize, 
      timestamp: timestamp,
      isSent: isSent,
      transferSpeed: transferSpeed,
    );

    notifyListeners();
  }

  String formatDataSize(double bytes) {
    if (bytes < 1024) {
      return '${bytes.toStringAsFixed(0)} B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }


  Map<String, String> getDataStats() {
    if (_files.length == _lastFileCount && _cachedStats != null) {
      return _cachedStats!;
    }

    double totalSize = 0;
    double totalSpeed = 0;

    for (var file in _files) {
      totalSize += file['file_size'];
      totalSpeed += file['transfer_speed'];
    }

    double avgSpeed = _files.isNotEmpty ? totalSpeed / _files.length : 0;

    _cachedStats = {
      'total_data': formatDataSize(totalSize),
      'average_transfer_speed': formatDataSize(avgSpeed),
    };
    _lastFileCount = _files.length;

    return _cachedStats!;
  }



  void loadFileDetails() {
    FileStorageService().loadFileDetails().then((fileDetails) {
      _files.clear();
      _files.addAll(fileDetails);
      log('File details loaded from storage', name: 'FileDetailProvider');
      notifyListeners();
    });
  }
}
