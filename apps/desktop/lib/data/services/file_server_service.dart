import 'dart:io';
import 'dart:developer' as dev;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

class FileServerService {
  static HttpServer? _server;

  void _log(String functionName, String message, {Object? error, StackTrace? stackTrace}) {
    dev.log(message, name: functionName, error: error, stackTrace: stackTrace);
  }

  Future<String?> startFileServer(String filePath, String ip) async {
    _log('startFileServer', 'Requested file server for path: $filePath and ip: $ip');
    try {
      // If a server is already running, close it first
      await stopServer();

      final file = File(filePath);
      if (!await file.exists()) {
        _log('startFileServer', 'File does not exist: $filePath');
        return null;
      }

      final fileName = file.path.split(Platform.pathSeparator).last;
      
      // Serve the specific directory where the file lives
      var handler = createStaticHandler(
        file.parent.path, 
        defaultDocument: fileName
      );

      // Use port 8081 for the file transfer
      _server = await io.serve(handler, InternetAddress.anyIPv4, 8081);

      _log('startFileServer', 'File server running at http://${_server!.address.host}:${_server!.port}');
      
      // URI encode the filename to handle spaces/special characters
      final encodedName = Uri.encodeComponent(fileName);
      _log('startFileServer', 'Generated file URL for $fileName');
      return "http://$ip:8081/$encodedName";
    } catch (e) {
      _log('startFileServer', 'Error starting file server', error: e);
      return null;
    }
  }

  Future<void> stopServer() async {
    if (_server != null) {
      _log('stopServer', 'Stopping active file server');
      await _server!.close(force: true);
      _server = null;
      _log('stopServer', 'File server stopped');
    }
  }
}