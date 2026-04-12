import 'dart:io';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

class FileServerService {
  static HttpServer? _server;

  Future<String?> startFileServer(String filePath, String ip) async {
    try {
      // If a server is already running, close it first
      await stopServer();

      final file = File(filePath);
      if (!await file.exists()) return null;

      final fileName = file.path.split(Platform.pathSeparator).last;
      
      // Serve the specific directory where the file lives
      var handler = createStaticHandler(
        file.parent.path, 
        defaultDocument: fileName
      );

      // Use port 8081 for the file transfer
      _server = await io.serve(handler, InternetAddress.anyIPv4, 8081);
      
      print('File Server running at http://${_server!.address.host}:${_server!.port}');
      
      // URI encode the filename to handle spaces/special characters
      final encodedName = Uri.encodeComponent(fileName);
      return "http://$ip:8081/$encodedName";
    } catch (e) {
      print("Error starting file server: $e");
      return null;
    }
  }

  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
  }
}