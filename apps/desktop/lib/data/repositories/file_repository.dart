import 'dart:io';
import 'dart:developer' as dev;
import 'package:test/data/services/http_functions.dart';
import 'package:test/data/services/common_functions.dart';
import 'package:test/data/models/file_model.dart';

class FileRepository {
  final HttpFunctions _httpFunctions = HttpFunctions();

  Future<String?> downloadFile(
    FileModel file, {
    void Function(double progress)? onProgress,
  }) async {
    if (file.url == null) {
      dev.log('File URL is null for ${file.name}', name: 'downloadFile');
      return null;
    }
    dev.log('Downloading file ${file.name} from ${file.url}', name: 'downloadFile');
    return await _httpFunctions.downloadFile(
      file.url!,
      file.name,
      onProgress: onProgress,
    );
  }

  Future<List<FileModel>> getLocalFiles() async {
    dev.log('Loading local files from HotDrop directory', name: 'getLocalFiles');
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
