import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:test/constants/globals.dart';
import 'package:test/providers/popup_provider.dart';
import 'package:test/services/http_functions.dart';

class HotdropProvider with ChangeNotifier {
  final List<dynamic> _files = [];
  StreamSubscription<FileSystemEvent>? _folderWatcher;

  List<dynamic> get files => _files;

  HotdropProvider() {
    _loadExistingFiles();
  }

  Future<void> addFile(var file) async {
    log("Adding file: $file");

    String? location = await HttpFunctions().downloadFile(file["url"], file["name"]);
    if (location != null) {
      file["location"] = location;
      _files.add(file);

      Provider.of<PopupProvider>(navigatorKey.currentContext!, listen: false).show(
        "You have a new file",
        Icons.attach_file_rounded,
      );

      notifyListeners();
    }
  }

  Future<void> _loadExistingFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final folderPath = '${directory.path}/NDrop/HotDrop';
    final folder = Directory(folderPath);

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    _files.clear();
    final existingFiles = folder.listSync();
    for (var entity in existingFiles) {
      if (entity is File) {
        final fileName = entity.path.split(Platform.pathSeparator).last;
        _files.add({
          "name": fileName,
          "location": entity.path,
          "url": null,
        });
      }
    }
    notifyListeners();
    _watchFolder(folder);
  }

  void _watchFolder(Directory folder) {
    _folderWatcher?.cancel();

    _folderWatcher = folder.watch(events: FileSystemEvent.all).listen((event) async {
      await _loadExistingFiles(); 
    });
  }

  @override
  void dispose() {
    _folderWatcher?.cancel();
    super.dispose();
  }
}
