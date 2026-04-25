import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:test_mobile/data/services/connection_services.dart';

class FileHostingService {
  List<File> _selectedFiles = [];
  HttpServer? _server;
  List<String> _downloadUrls = [];
  final int _port = 8080;

  // ---> THIS IS THE MISSING FIELD <---
  void Function(double)? onProgress;

  Future<void> startHosting(List<File> files) async {
    _selectedFiles = files;
    try {
      await _stopHosting();
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      dev.log("Server running on port ${_server!.port}", name: "FileHosting");

      final ip = await getLocalIpAddress();
      _downloadUrls = List.generate(files.length, (index) => 'http://$ip:${_server!.port}/download/$index');

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
        await Future.delayed(const Duration(milliseconds: 200));
      }

      int totalBytes = files.fold(0, (sum, f) => sum + f.lengthSync());
      int bytesSent = 0;

      _server!.listen((HttpRequest request) async {
        try {
          if (request.uri.path.startsWith('/download/')) {
            final index = int.tryParse(request.uri.pathSegments[1]) ?? -1;
            if (index >= 0 && index < _selectedFiles.length) {
              final file = _selectedFiles[index];
              dev.log("Serving file: ${file.path}", name: "FileHosting");

              request.response.headers.contentType = ContentType.binary;
              request.response.headers.contentLength = file.lengthSync();
              request.response.headers.add(
                'Content-Disposition',
                'attachment; filename="${file.path.split('/').last}"',
              );

              await for (var chunk in file.openRead()) {
                request.response.add(chunk);
                bytesSent += chunk.length;
                if (totalBytes > 0) {
                  // ---> THIS TRIGGERS THE PROGRESS BAR <---
                  onProgress?.call(bytesSent / totalBytes);
                }
              }
            } else {
              request.response.statusCode = HttpStatus.notFound;
            }
          } else {
            request.response.statusCode = HttpStatus.notFound;
          }
          await request.response.close();
        } catch (e) {
          dev.log("Error serving file: $e", name: "FileHosting");
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        }
      });
    } catch (e) {
      dev.log("Error starting server: $e", name: "FileHosting");
      _downloadUrls.clear();
      rethrow;
    }
  }

  Future<void> _stopHosting() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    _downloadUrls.clear();
  }

  Future<String> getLocalIpAddress() async {
    final interfaces = await NetworkInterface.list();
    String? hotspotIp;
    String? wifiIp;
    String? fallback;

    for (var interface in interfaces) {
      dev.log(interface.name, name: "FileHostingService");
      dev.log(interface.addresses.toString(), name: "FileHostingService");
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          final ip = addr.address;

          // 1. HIGHEST PRIORITY: Interface contains 'ap', 'softap', or 'wlan1'
          if (interface.name.contains('ap') || interface.name.contains('wlan1') || interface.name.contains('softap')) {
            return ip;
          }

          // 2. SECOND PRIORITY: Subnets typical for Android Hotspots
          if (ip.startsWith('192.168.43.') || ip.startsWith('192.168.44.')) {
            hotspotIp = ip;
          }

          // 3. THIRD PRIORITY: Other local Wi-Fi
          else if (ip.startsWith('192.168.')) {
            wifiIp = ip;
          }

          // 4. LAST RESORT: Any non-loopback IP
          else {
            fallback = ip;
          }
        }
      }
    }

    return hotspotIp ?? wifiIp ?? fallback ?? '0.0.0.0';
  }

  List<String> get downloadUrls => _downloadUrls;
  List<File> get selectedFiles => _selectedFiles;

  void dispose() {
    _stopHosting();
    _selectedFiles.clear();
  }
}
