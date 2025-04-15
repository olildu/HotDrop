import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:test_mobile/services/connection_services.dart';

class FileHostingService {
  List<File> _selectedFiles = [];
  HttpServer? _server;
  List<String> _downloadUrls = [];
  final int _port = 8080;

  Future<void> startHosting(List<File> files) async {
    _selectedFiles = files;
    try {
      await _stopHosting();
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      dev.log("Server running on port ${_server!.port}", name: "FileHosting");

      final ip = await _getLocalIpAddress();
      _downloadUrls = List.generate(files.length, (index) => 'http://$ip:${_server!.port}/download/$index');

      // Send file info for each file
      for (int i = 0; i < files.length; i++) {
        DartFunction().sendDataToSocket(
          jsonEncode({
            "type": "HotDropFile",
            "name": files[i].path.split('/').last,
            "size": files[i].lengthSync(),
            "url": _downloadUrls[i],
            "file_type": files[i].path.split('.').last,
          }),
        );
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Handle incoming requests
      await for (HttpRequest request in _server!) {
        try {
          if (request.uri.path.startsWith('/download/')) {
            final index = int.tryParse(request.uri.pathSegments[1]) ?? -1;
            if (index >= 0 && index < _selectedFiles.length) {
              final file = _selectedFiles[index];
              dev.log("Serving file: ${file.path}", name: "FileHosting");
              
              final fileLength = file.lengthSync();
              
              request.response.headers.contentType = ContentType.binary;
              request.response.headers.contentLength = fileLength;
              request.response.headers.add(
                'Content-Disposition',
                'attachment; filename="${file.path.split('/').last}"',
              );
              
              await request.response.addStream(file.openRead());
            } else {
              request.response.statusCode = HttpStatus.notFound;
            }
          } else {
            request.response.statusCode = HttpStatus.notFound;
          }
          await request.response.close();
        } catch (e) {
          dev.log("Error handling request: $e", name: "FileHosting");
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        }
      }
    } catch (e) {
      dev.log("Error starting server: $e", name: "FileHosting");
      _downloadUrls.clear();
      rethrow;
    }
  }

  Future<void> _stopHosting() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      dev.log("Server stopped", name: "FileHosting");
    }
    _downloadUrls.clear();
  }

  Future<String> _getLocalIpAddress() async {
    final interfaces = await NetworkInterface.list();
    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
          return addr.address;
        }
      }
    }
    return '0.0.0.0';
  }

  List<String> get downloadUrls => _downloadUrls;
  List<File> get selectedFiles => _selectedFiles;

  Future<void> dispose() async {
    await _stopHosting();
    _selectedFiles.clear();
    _downloadUrls.clear();
    _server = null;
    dev.log("FileHostingService disposed", name: "FileHosting");
  }
}