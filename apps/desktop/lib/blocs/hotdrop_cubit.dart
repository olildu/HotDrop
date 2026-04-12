import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/file_model.dart';
import '../data/repositories/file_repository.dart';
import '../services/common_functions.dart';

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

  @override
  Future<void> close() {
    _folderWatcher?.cancel();
    return super.close();
  }
}
