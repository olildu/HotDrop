import 'dart:async';
import 'dart:developer' as dev;
import 'package:test_mobile/data/models/file_model.dart';
import 'package:test_mobile/data/services/file_storage_service.dart';

class FileRepository {
  final FileStorageService _storageService = FileStorageService();
  
  // Broadcasts new files (received or sent) to the Cubit
  final _fileStreamController = StreamController<FileModel>.broadcast();
  Stream<FileModel> get fileUpdates => _fileStreamController.stream;

  // Called when a file is successfully downloaded or sent
  void onFileProcessed(FileModel file) {
    dev.log('Processing file: ${file.name}', name: 'onFileProcessed');
    _fileStreamController.add(file);
    _storageService.saveFileDetail(file);
  }

  Future<List<FileModel>> getFileHistory() {
    dev.log('Loading file history', name: 'getFileHistory');
    return _storageService.loadFileDetails();
  }

  void dispose() {
    dev.log('Disposing FileRepository', name: 'dispose');
    _fileStreamController.close();
  }
}