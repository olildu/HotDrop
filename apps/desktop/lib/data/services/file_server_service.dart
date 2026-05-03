import 'dart:io';
import 'dart:developer' as dev;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';
import 'security_service.dart';
import 'firewall_service.dart';
import 'package:test/logic/constants/globals.dart' as globals;

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

      final context = await SecurityService().getServerContext();
      
      try {
        _log('startFileServer', 'Attempting to bind to primary file server port 42070');
        _server = await io.serve(handler, InternetAddress.anyIPv4, 42070, securityContext: context);
      } catch (e) {
        _log('startFileServer', 'Primary file server port 42070 is unavailable, binding to a random port');
        _server = await io.serve(handler, InternetAddress.anyIPv4, 0, securityContext: context);
      }
      
      globals.httpPort = _server!.port;

      _log('startFileServer', 'Secure file server running at https://${_server!.address.host}:${_server!.port}');
      
      // Ensure firewall rules are set for the file server port
      await FirewallService().ensureRules(port: globals.httpPort);
      
      // URI encode the filename to handle spaces/special characters
      final encodedName = Uri.encodeComponent(fileName);
      _log('startFileServer', 'Generated secure file URL for $fileName');
      return "https://$ip:${globals.httpPort}/$encodedName";
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