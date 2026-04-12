import 'dart:io';
import '../../services/http_functions.dart';
import '../../services/common_functions.dart';
import '../models/file_model.dart';

class FileRepository {
  final HttpFunctions _httpFunctions = HttpFunctions();

  Future<String?> downloadFile(FileModel file) async {
    if (file.url == null) return null;
    return await _httpFunctions.downloadFile(file.url!, file.name);
  }

  Future<List<FileModel>> getLocalFiles() async {
    final nDropDir = await CommonFunctions().getHotDropDirectory();
    if (!await nDropDir.exists()) return [];

    return nDropDir.listSync().whereType<File>().map((entity) {
      return FileModel(
        name: entity.path.split(Platform.pathSeparator).last,
        location: entity.path,
      );
    }).toList();
  }
}