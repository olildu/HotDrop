import 'dart:convert';
import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/file_model.dart';

class FileStorageService {
  static const _key = 'file_storage_details';

  // Updated to accept the model
  Future<void> saveFileDetail(FileModel file) async {
    final prefs = await SharedPreferences.getInstance();
    final existingFiles = await loadFileDetails();
    
    existingFiles.add(file);

    final jsonString = jsonEncode(existingFiles.map((f) => f.toJson()).toList());
    await prefs.setString(_key, jsonString);

    log('File detail saved: ${file.name}', name: 'FileStorageService');
  }

  // Updated to return a list of Models
  Future<List<FileModel>> loadFileDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString != null) {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((item) => FileModel.fromJson(item)).toList();
    }
    return [];
  }
}