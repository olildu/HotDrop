import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_filex/open_filex.dart';
import 'package:test_mobile/data/repositories/file_repository.dart';
import 'package:test_mobile/data/models/file_model.dart';
import 'package:test_mobile/data/services/file_storage_service.dart';

enum FileHistoryFilter { all, sent, received }

class FileDetailState {
  final List<FileModel> files;
  final FileHistoryFilter selectedFilter;

  FileDetailState({this.files = const [], this.selectedFilter = FileHistoryFilter.all});

  FileDetailState copyWith({List<FileModel>? files, FileHistoryFilter? selectedFilter}) => FileDetailState(files: files ?? this.files, selectedFilter: selectedFilter ?? this.selectedFilter);
}

class FileDetailCubit extends Cubit<FileDetailState> {
  final FileRepository _fileRepository;
  StreamSubscription? _subscription;

  FileDetailCubit(this._fileRepository) : super(FileDetailState()) {
    dev.log('Initializing FileDetailCubit', name: 'FileDetailCubit');
    _subscription = _fileRepository.fileUpdates.listen((file) {
      dev.log('Received file update: ${file.name}', name: '_subscription');
      emit(state.copyWith(files: List<FileModel>.from(state.files)..add(file)));
    });
  }

  Future<void> loadFileDetails() async {
    dev.log('Loading file details', name: 'loadFileDetails');
    final files = await _fileRepository.getFileHistory();
    emit(state.copyWith(files: files));
  }

  void addFile(FileModel file) {
    dev.log('Adding file: ${file.name}', name: 'addFile');
    emit(state.copyWith(files: List<FileModel>.from(state.files)..add(file)));
    FileStorageService().saveFileDetail(file);
  }

  void setHistoryFilter(FileHistoryFilter filter) {
    dev.log('Setting history filter to $filter', name: 'setHistoryFilter');
    if (state.selectedFilter == filter) return;
    emit(state.copyWith(selectedFilter: filter));
  }

  List<FileModel> getFilteredFiles() {
    final files = state.files.reversed.toList();
    switch (state.selectedFilter) {
      case FileHistoryFilter.sent:
        return files.where((f) => f.isSent).toList();
      case FileHistoryFilter.received:
        return files.where((f) => !f.isSent).toList();
      case FileHistoryFilter.all:
        return files;
    }
  }

  Future<void> openFile(FileModel file) async {
    dev.log('Opening file: ${file.name}', name: 'openFile');
    final path = file.path;
    if (path == null) return;
    if (await File(path).exists()) {
      await OpenFilex.open(path);
    }
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

  @override
  Future<void> close() {
    dev.log('Closing FileDetailCubit', name: 'close');
    _subscription?.cancel();
    return super.close();
  }
}
