import 'dart:convert';
import 'dart:io';

class CommonServices {
  Future<String> encodeFileToBase64(File file) async {
    final bytes = await file.readAsBytes(); 
    return base64Encode(bytes); 
  }
}
