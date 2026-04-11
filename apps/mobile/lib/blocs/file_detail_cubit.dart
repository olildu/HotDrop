import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_mobile/data/repositories/file_repository.dart';
import '../data/models/file_model.dart';
import '../services/file_storage_service.dart';

class FileDetailState {
  final List<FileModel> files;
  FileDetailState({this.files = const []});

  FileDetailState copyWith({List<FileModel>? files}) => FileDetailState(files: files ?? this.files);
}

class FileDetailCubit extends Cubit<FileDetailState> {
  final FileRepository _fileRepository;
  StreamSubscription? _subscription;

  FileDetailCubit(this._fileRepository) : super(FileDetailState()) {
    _subscription = _fileRepository.fileUpdates.listen((file) {
      emit(state.copyWith(files: List<FileModel>.from(state.files)..add(file)));
    });
  }

  Future<void> loadFileDetails() async {
    final files = await _fileRepository.getFileHistory();
    emit(state.copyWith(files: files));
  }

  void addFile(FileModel file) {
    emit(state.copyWith(files: List<FileModel>.from(state.files)..add(file)));
    FileStorageService().saveFileDetail(file);
  }

  // FIX: Updated keys to match UI expectations
  Map<String, String> getStats() {
    double totalSize = state.files.fold(0, (sum, f) => sum + f.size);
    double avgSpeed = state.files.isEmpty ? 0 : state.files.fold(0.0, (sum, f) => sum + f.transferSpeed) / state.files.length;

    return {
      'total_data': formatDataSize(totalSize),
      'average_transfer_speed': formatDataSize(avgSpeed),
    };
  }

  String formatDataSize(double bytes) {
    if (bytes < 1024) {
      return '${bytes.toStringAsFixed(0)} B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}
