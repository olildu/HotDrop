import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Wi-Fi Direct',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class FileTransferStatus {
  final String fileName;
  final double progress;
  final double speed; // MB/s
  final bool isUpload;

  FileTransferStatus({
    required this.fileName,
    required this.progress,
    required this.speed,
    required this.isUpload,
  });
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const platform = MethodChannel('com.example.wifidirecttest/wifi');
  String? _groupOwnerAddress;
  Socket? socket;
  final TextEditingController _messageController = TextEditingController();
  final List<String> _messages = [];
  final List<FileTransferStatus> _transfers = [];
  final ScrollController _scrollController = ScrollController();
  Timer? _speedUpdateTimer;
  
  // File transfer tracking
  int _bytesSent = 0;
  int _lastBytesSent = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _startSpeedUpdateTimer();

    // platform.setMethodCallHandler((call) async {
    //   if (call.method == "onConnected") {
    //     setState(() {
    //       _groupOwnerAddress = call.arguments;
    //     });
    //     print("Connected to Group Owner at: $_groupOwnerAddress");
    //     await connectToPort(_groupOwnerAddress!, 42069);
    //   }
    // });
  }

  void _startSpeedUpdateTimer() {
    _speedUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_transfers.isNotEmpty) {
        setState(() {
          // Update transfer speeds
          final bytesDiff = _bytesSent - _lastBytesSent;
          final speedMBps = bytesDiff / (1024 * 1024); // Convert to MB/s
          _lastBytesSent = _bytesSent;
          
          if (_transfers.isNotEmpty) {
            // Update the latest transfer with new speed
            final lastTransfer = _transfers.last;
            _transfers[_transfers.length - 1] = FileTransferStatus(
              fileName: lastTransfer.fileName,
              progress: lastTransfer.progress,
              speed: speedMBps,
              isUpload: lastTransfer.isUpload,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _speedUpdateTimer?.cancel();
    socket?.close();
    super.dispose();
  }

  Future<void> connectToPort(String ipAddress, int port) async {
    try {
      socket = await Socket.connect(ipAddress, port);
      print("Connected to $ipAddress on port $port");

      socket!.listen(
        (data) async {
          // Check if it's a file transfer or regular message
          if (data.length > 4 && data[0] == 1 && data[1] == 1 && data[2] == 1 && data[3] == 1) {
            // File transfer
            await _handleIncomingFile(data.sublist(4));
          } else {
            // Regular message
            final message = String.fromCharCodes(data);
            setState(() {
              _messages.add("Received: $message");
            });
            _scrollToBottom();
          }
        },
        onError: (error) {
          print("Socket error: $error");
          setState(() {
            _groupOwnerAddress = null;
          });
        },
        onDone: () {
          print("Socket closed");
          setState(() {
            _groupOwnerAddress = null;
          });
        },
      );
    } catch (e) {
      print("Error connecting to $ipAddress on port $port: $e");
    }
  }

  Future<void> _handleIncomingFile(List<int> data) async {
    try {
      // First 8 bytes contain the file size
      final fileSize = _bytesToInt(data.sublist(0, 8));
      final fileNameLength = _bytesToInt(data.sublist(8, 12));
      final fileName = String.fromCharCodes(data.sublist(12, 12 + fileNameLength));
      final fileData = data.sublist(12 + fileNameLength);

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(fileData);

      setState(() {
        _messages.add("Received file: $fileName (${_formatFileSize(fileSize)})");
        _transfers.add(FileTransferStatus(
          fileName: fileName,
          progress: 100,
          speed: fileData.length / (1024 * 1024), // MB/s
          isUpload: false,
        ));
      });
      _scrollToBottom();
    } catch (e) {
      print("Error handling incoming file: $e");
    }
  }

  Future<void> _sendFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      
      if (result != null && socket != null) {
        File file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final fileBytes = await file.readAsBytes();
        final fileSize = fileBytes.length;

        // Reset transfer tracking
        _bytesSent = 0;
        _lastBytesSent = 0;

        // Prepare file transfer header
        final header = List<int>.filled(4, 1); // File transfer marker
        final fileSizeBytes = _intToBytes(fileSize);
        final fileNameBytes = fileName.codeUnits;
        final fileNameLengthBytes = _intToBytes(fileNameBytes.length, 4);

        // Combine all parts
        final fullData = [
          ...header,
          ...fileSizeBytes,
          ...fileNameLengthBytes,
          ...fileNameBytes,
          ...fileBytes,
        ];

        // Send the file
        int bytesSent = 0;
        final chunkSize = 1024 * 16; // 16KB chunks
        
        for (var i = 0; i < fullData.length; i += chunkSize) {
          final end = (i + chunkSize < fullData.length) ? i + chunkSize : fullData.length;
          final chunk = fullData.sublist(i, end);
          socket!.add(chunk);
          bytesSent += chunk.length;
          
          setState(() {
            _bytesSent = bytesSent;
            final progress = (bytesSent / fullData.length) * 100;
            
            if (_transfers.isEmpty || _transfers.last.fileName != fileName) {
              _transfers.add(FileTransferStatus(
                fileName: fileName,
                progress: progress,
                speed: 0,
                isUpload: true,
              ));
            } else {
              _transfers[_transfers.length - 1] = FileTransferStatus(
                fileName: fileName,
                progress: progress,
                speed: _transfers.last.speed,
                isUpload: true,
              );
            }
          });
          
          await Future.delayed(const Duration(milliseconds: 1)); // Prevent UI freeze
        }

        setState(() {
          _messages.add("Sent file: $fileName (${_formatFileSize(fileSize)})");
        });
        _scrollToBottom();
      }
    } catch (e) {
      print("Error sending file: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send file: $e')),
      );
    }
  }

  List<int> _intToBytes(int value, [int bytes = 8]) {
    final data = List<int>.filled(bytes, 0);
    for (var i = 0; i < bytes; i++) {
      data[bytes - i - 1] = (value >> (8 * i)) & 0xFF;
    }
    return data;
  }

  int _bytesToInt(List<int> bytes) {
    int value = 0;
    for (var i = 0; i < bytes.length; i++) {
      value = (value << 8) | bytes[i];
    }
    return value;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _sendMessage() {
    if (_messageController.text.isEmpty || socket == null) return;

    try {
      socket!.write(_messageController.text);
      setState(() {
        _messages.add("Sent: ${_messageController.text}");
        _messageController.clear();
      });
      _scrollToBottom();
    } catch (e) {
      print("Error sending message: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
      Permission.storage,
    ].request();
  }

  Future<void> _discoverPeers() async {
    try {
      await platform.invokeMethod('discoverPeers');
    } on PlatformException catch (e) {
      print("Failed to discover peers: '${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi Direct Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: _sendFile,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: _discoverPeers,
              child: const Text('Discover Peers'),
            ),
          ),
          if (_groupOwnerAddress != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Connected to: $_groupOwnerAddress",
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (_transfers.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: _transfers.map((transfer) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${transfer.isUpload ? "Sending" : "Receiving"}: ${transfer.fileName}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    LinearProgressIndicator(value: transfer.progress / 100),
                    Text('${transfer.progress.toStringAsFixed(1)}% - ${transfer.speed.toStringAsFixed(2)} MB/s'),
                  ],
                )).toList(),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Enter message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}