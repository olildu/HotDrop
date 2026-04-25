import 'dart:convert';
import 'dart:developer' as dev;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_mobile/data/models/file_model.dart';

class FileStorageService {
  static const _key = 'file_storage_details';

  // Updated to accept the model
  Future<void> saveFileDetail(FileModel file) async {
    final prefs = await SharedPreferences.getInstance();
    final existingFiles = await loadFileDetails();
    
    existingFiles.add(file);

    final jsonString = jsonEncode(existingFiles.map((f) => f.toJson()).toList());
    await prefs.setString(_key, jsonString);

    dev.log('File detail saved: ${file.name}', name: 'saveFileDetail');
  }

  // Updated to return a list of Models
  Future<List<FileModel>> loadFileDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString != null) {
      final List<dynamic> decoded = jsonDecode(jsonString);
      dev.log('Loaded ${decoded.length} file details', name: 'loadFileDetails');
      return decoded.map((item) => FileModel.fromJson(item)).toList();
    }
    dev.log('No existing file details found', name: 'loadFileDetails');
    return [];
  }
}