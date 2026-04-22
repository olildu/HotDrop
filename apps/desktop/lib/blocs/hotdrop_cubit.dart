import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_filex/open_filex.dart';
import '../constants/globals.dart' as globals;
import '../data/models/file_model.dart';
import '../data/repositories/file_repository.dart';
import '../services/common_functions.dart';
import '../services/connection_services.dart';
import '../services/file_server_service.dart';

class HotdropCubit extends Cubit<List<FileModel>> {
  final FileRepository _fileRepository;
  StreamSubscription<FileSystemEvent>? _folderWatcher;

  HotdropCubit(this._fileRepository) : super([]) {
    loadExistingFiles();
  }

  Future<void> loadExistingFiles() async {
    final files = await _fileRepository.getLocalFiles();
    emit(files);
    _startWatchingFolder();
  }

  Future<void> _startWatchingFolder() async {
    _folderWatcher?.cancel();
    final directory = await CommonFunctions().getHotDropDirectory();

    if (await directory.exists()) {
      _folderWatcher = directory.watch().listen((event) {
        loadExistingFiles();
      });
    }
  }

  Future<void> addFile(FileModel file) async {
    final location = await _fileRepository.downloadFile(file);
    if (location != null) {
      loadExistingFiles(); // Refresh list after download
    }
  }

  Future<void> pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) {
      return;
    }

    final filePath = result.files.single.path!;
    final fileName = result.files.single.name;
    final file = File(filePath);
    final fileSize = await file.length();

    final currentIp = globals.currentServerIp;
    if (currentIp == null) {
      return;
    }

    final fileUrl = await FileServerService().startFileServer(filePath, currentIp);
    if (fileUrl == null) {
      return;
    }

    await DartFunction().sendMessage(jsonEncode({
      'type': 'HotDropFile',
      'name': fileName,
      'size': fileSize,
      'url': fileUrl,
    }));
  }

  Future<void> openLocalFile(FileModel file) async {
    if (file.location == null) {
      return;
    }

    await OpenFilex.open(file.location!);
  }

  @override
  Future<void> close() {
    _folderWatcher?.cancel();
    return super.close();
  }
}
