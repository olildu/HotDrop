import 'dart:async';
import '../models/file_model.dart';
import '../../services/file_storage_service.dart';

class FileRepository {
  final FileStorageService _storageService = FileStorageService();
  
  // Broadcasts new files (received or sent) to the Cubit
  final _fileStreamController = StreamController<FileModel>.broadcast();
  Stream<FileModel> get fileUpdates => _fileStreamController.stream;

  // Called when a file is successfully downloaded or sent
  void onFileProcessed(FileModel file) {
    _fileStreamController.add(file);
    _storageService.saveFileDetail(file);
  }

  Future<List<FileModel>> getFileHistory() => _storageService.loadFileDetails();

  void dispose() {
    _fileStreamController.close();
  }
}