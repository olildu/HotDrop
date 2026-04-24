import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_filex/open_filex.dart';
import 'package:test/logic/constants/globals.dart' as globals;
import 'package:test/data/models/file_model.dart';
import 'package:test/data/repositories/file_repository.dart';
import 'package:test/data/services/common_functions.dart';
import 'package:test/data/services/connection_services.dart';
import 'package:test/data/services/file_server_service.dart';

class TransferHistoryItem {
  final String fileName;
  final String sizeLabel;
  final String? speedLabel;
  final double progress;
  final bool isActive;
  final String? location;
  final bool isAvailable;
  final int lastUpdatedMillis;
  final bool isSent;

  const TransferHistoryItem({
    required this.fileName,
    required this.sizeLabel,
    required this.progress,
    required this.isActive,
    this.location,
    this.isAvailable = true,
    int? lastUpdatedMillis,
    this.speedLabel,
    this.isSent = false,
  }) : lastUpdatedMillis = lastUpdatedMillis ?? 0;

  TransferHistoryItem copyWith({
    String? fileName,
    String? sizeLabel,
    String? speedLabel,
    double? progress,
    bool? isActive,
    String? location,
    bool? isAvailable,
    int? lastUpdatedMillis,
    bool? isSent,
  }) {
    return TransferHistoryItem(
      fileName: fileName ?? this.fileName,
      sizeLabel: sizeLabel ?? this.sizeLabel,
      speedLabel: speedLabel ?? this.speedLabel,
      progress: progress ?? this.progress,
      isActive: isActive ?? this.isActive,
      location: location ?? this.location,
      isAvailable: isAvailable ?? this.isAvailable,
      lastUpdatedMillis: lastUpdatedMillis ?? this.lastUpdatedMillis,
      isSent: isSent ?? this.isSent,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fileName': fileName,
      'sizeLabel': sizeLabel,
      'speedLabel': speedLabel,
      'progress': progress,
      'isActive': isActive,
      'location': location,
      'isAvailable': isAvailable,
      'lastUpdatedMillis': lastUpdatedMillis,
      'isSent': isSent,
    };
  }

  factory TransferHistoryItem.fromMap(Map<String, dynamic> map) {
    return TransferHistoryItem(
      fileName: map['fileName']?.toString() ?? '',
      sizeLabel: map['sizeLabel']?.toString() ?? 'Unknown size',
      speedLabel: map['speedLabel']?.toString(),
      progress: (map['progress'] as num?)?.toDouble() ?? 1,
      isActive: map['isActive'] == true,
      location: map['location']?.toString(),
      isAvailable: map['isAvailable'] != false,
      lastUpdatedMillis: (map['lastUpdatedMillis'] as num?)?.toInt() ?? 0,
      isSent: map['isSent'] == true,
    );
  }

  String get statusLabel => isAvailable ? 'Completed' : 'Removed from folder';
}

class HotdropState {
  final List<FileModel> files;
  final TransferHistoryItem? activeTransfer;
  final List<TransferHistoryItem> completedTransfers;
  final int totalBytesTransferred;
  final double totalSpeedBps;
  final int transferCount;

  const HotdropState({
    required this.files,
    required this.activeTransfer,
    required this.completedTransfers,
    this.totalBytesTransferred = 0,
    this.totalSpeedBps = 0.0,
    this.transferCount = 0,
  });

  factory HotdropState.initial() {
    return const HotdropState(
      files: <FileModel>[],
      activeTransfer: null,
      completedTransfers: <TransferHistoryItem>[],
      totalBytesTransferred: 0,
      totalSpeedBps: 0.0,
      transferCount: 0,
    );
  }

  HotdropState copyWith({
    List<FileModel>? files,
    TransferHistoryItem? activeTransfer,
    bool clearActiveTransfer = false,
    List<TransferHistoryItem>? completedTransfers,
    int? totalBytesTransferred,
    double? totalSpeedBps,
    int? transferCount,
  }) {
    return HotdropState(
      files: files ?? this.files,
      activeTransfer: clearActiveTransfer ? null : activeTransfer ?? this.activeTransfer,
      completedTransfers: completedTransfers ?? this.completedTransfers,
      totalBytesTransferred: totalBytesTransferred ?? this.totalBytesTransferred,
      totalSpeedBps: totalSpeedBps ?? this.totalSpeedBps,
      transferCount: transferCount ?? this.transferCount,
    );
  }
}

class HotdropCubit extends Cubit<HotdropState> {
  final FileRepository _fileRepository;
  StreamSubscription<FileSystemEvent>? _folderWatcher;
  bool _historyLoaded = false;

  HotdropCubit(this._fileRepository) : super(HotdropState.initial()) {
    _loadStats();
    loadExistingFiles(loadHistory: true);
  }

  Future<void> _loadStats() async {
    try {
      final historyFile = await CommonFunctions().getHotDropHistoryFile();
      final file = File('${historyFile.parent.path}/hotdrop_stats.json');
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        emit(state.copyWith(
          totalBytesTransferred: data['totalBytes'] ?? 0,
          totalSpeedBps: (data['totalSpeedBps'] ?? 0.0).toDouble(),
          transferCount: data['transferCount'] ?? 0,
        ));
      }
    } catch (_) {}
  }

  Future<void> _saveStats(int bytes, double speed, int count) async {
    try {
      final historyFile = await CommonFunctions().getHotDropHistoryFile();
      final file = File('${historyFile.parent.path}/hotdrop_stats.json');
      await file.writeAsString(jsonEncode({
        'totalBytes': bytes,
        'totalSpeedBps': speed,
        'transferCount': count,
      }));
    } catch (_) {}
  }

  void addTransferStats(int bytes, double speedBps) {
    final newTotalBytes = state.totalBytesTransferred + bytes;
    final newSpeed = state.totalSpeedBps + speedBps;
    final newCount = state.transferCount + 1;
    emit(state.copyWith(
      totalBytesTransferred: newTotalBytes,
      totalSpeedBps: newSpeed,
      transferCount: newCount,
    ));
    _saveStats(newTotalBytes, newSpeed, newCount);
  }

  void addBytesTransferredOnly(int bytes) {
    final newTotalBytes = state.totalBytesTransferred + bytes;
    emit(state.copyWith(totalBytesTransferred: newTotalBytes));
    _saveStats(newTotalBytes, state.totalSpeedBps, state.transferCount);
  }

  Map<String, String> formatBytesForUI(int bytes) {
    if (bytes == 0) return {'value': '0.0', 'unit': 'B'};
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    const tb = gb * 1024;

    if (bytes >= tb) return {'value': (bytes / tb).toStringAsFixed(1), 'unit': 'TB'};
    if (bytes >= gb) return {'value': (bytes / gb).toStringAsFixed(1), 'unit': 'GB'};
    if (bytes >= mb) return {'value': (bytes / mb).toStringAsFixed(1), 'unit': 'MB'};
    if (bytes >= kb) return {'value': (bytes / kb).toStringAsFixed(1), 'unit': 'KB'};
    return {'value': bytes.toString(), 'unit': 'B'};
  }

  Map<String, String> formatAverageSpeedForUI() {
    if (state.transferCount == 0) return {'value': '0.0', 'unit': 'B/S'};
    final avgSpeed = state.totalSpeedBps / state.transferCount;

    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;

    if (avgSpeed >= gb) return {'value': (avgSpeed / gb).toStringAsFixed(1), 'unit': 'GB/S'};
    if (avgSpeed >= mb) return {'value': (avgSpeed / mb).toStringAsFixed(1), 'unit': 'MB/S'};
    if (avgSpeed >= kb) return {'value': (avgSpeed / kb).toStringAsFixed(1), 'unit': 'KB/S'};
    return {'value': avgSpeed.toStringAsFixed(1), 'unit': 'B/S'};
  }

  Future<void> loadExistingFiles({bool loadHistory = false}) async {
    final files = await _fileRepository.getLocalFiles();
    final persistedHistory = loadHistory || !_historyLoaded ? await _loadPersistedHistory() : state.completedTransfers;

    _historyLoaded = true;
    final reconciledHistory = _reconcileHistory(persistedHistory, files);

    emit(
      state.copyWith(
        files: files,
        completedTransfers: reconciledHistory,
      ),
    );

    await _persistHistory(reconciledHistory);
    _startWatchingFolder();
  }

  Future<void> _startWatchingFolder() async {
    _folderWatcher?.cancel();
    final directory = await CommonFunctions().getHotDropDirectory();

    if (await directory.exists()) {
      _folderWatcher = directory.watch().listen((event) {
        if (event is FileSystemMoveEvent) {
          _handleFileMoved(event.path, event.destination!);
        }

        loadExistingFiles();
      });
    }
  }

  Future<void> addFile(FileModel file) async {
    final activeTransfer = TransferHistoryItem(
      fileName: file.name,
      sizeLabel: _formatSize(file.size),
      progress: 0,
      isActive: true,
      lastUpdatedMillis: DateTime.now().millisecondsSinceEpoch,
      isSent: false,
    );

    emit(state.copyWith(activeTransfer: activeTransfer));

    final stopwatch = Stopwatch()..start();

    final location = await _fileRepository.downloadFile(
      file,
      onProgress: (progress) {
        if (isClosed || state.activeTransfer == null) {
          return;
        }

        emit(
          state.copyWith(
            activeTransfer: state.activeTransfer!.copyWith(progress: progress),
          ),
        );
      },
    );

    stopwatch.stop();

    if (location != null) {
      final elapsedSeconds = stopwatch.elapsedMilliseconds / 1000.0;
      final speedBps = elapsedSeconds > 0 ? (file.size ?? 0) / elapsedSeconds : 0.0;
      addTransferStats(file.size ?? 0, speedBps);

      final speedLabel = _formatSpeed(file.size, stopwatch.elapsedMilliseconds);
      final completedTransfer = TransferHistoryItem(
        fileName: file.name,
        sizeLabel: _formatSize(file.size),
        speedLabel: speedLabel,
        progress: 1,
        isActive: false,
        location: location,
        isAvailable: true,
        lastUpdatedMillis: DateTime.now().millisecondsSinceEpoch,
        isSent: false,
      );

      final updatedHistory = <TransferHistoryItem>[
        completedTransfer,
        ...state.completedTransfers.where((item) => item.fileName != completedTransfer.fileName || item.location != completedTransfer.location),
      ].take(50).toList(growable: false);

      emit(
        state.copyWith(
          clearActiveTransfer: true,
          completedTransfers: updatedHistory,
        ),
      );

      await _persistHistory(updatedHistory);
      loadExistingFiles();
    } else {
      emit(state.copyWith(clearActiveTransfer: true));
    }
  }

  Future<bool> sendLocalFilePath(String filePath) async {
    final entityType = FileSystemEntity.typeSync(filePath, followLinks: false);
    if (entityType != FileSystemEntityType.file) {
      return false;
    }

    final file = File(filePath);
    final fileName = filePath.split(Platform.pathSeparator).last;
    final fileSize = await file.length();

    final currentIp = await _resolveSenderIp();
    if (currentIp == null) {
      return false;
    }

    final fileUrl = await FileServerService().startFileServer(filePath, currentIp);
    if (fileUrl == null) {
      return false;
    }

    // --- CHANGED: Don't add to completed immediately, make it active instead ---
    final activeTransfer = TransferHistoryItem(
      fileName: fileName,
      sizeLabel: _formatSize(fileSize),
      progress: 0.0, // Start at 0%
      isActive: true, // Keep it active
      location: filePath,
      isAvailable: true,
      lastUpdatedMillis: DateTime.now().millisecondsSinceEpoch,
      isSent: true,
    );

    emit(state.copyWith(activeTransfer: activeTransfer));

    await DartFunction().sendMessage(jsonEncode({
      'type': 'HotDropFile',
      'name': fileName,
      'size': fileSize,
      'url': fileUrl,
    }));

    return true;
  }

  // --- NEW: Method to handle incoming progress updates ---
  void updateOutgoingProgress(String fileName, double progress) {
    if (state.activeTransfer != null && state.activeTransfer!.fileName == fileName) {
      emit(state.copyWith(
        activeTransfer: state.activeTransfer!.copyWith(progress: progress),
      ));
    }
  }

  // --- NEW: Method to handle the transfer completion ---
  Future<void> completeOutgoingTransfer(String fileName, double speedBps, int size) async {
    if (state.activeTransfer != null && state.activeTransfer!.fileName == fileName) {
      addTransferStats(size, speedBps);

      int elapsedMs = speedBps > 0 ? ((size / speedBps) * 1000).toInt() : 0;

      final completedTransfer = state.activeTransfer!.copyWith(
        progress: 1.0,
        isActive: false,
        speedLabel: _formatSpeed(size, elapsedMs),
        lastUpdatedMillis: DateTime.now().millisecondsSinceEpoch,
      );

      final updatedHistory = <TransferHistoryItem>[
        completedTransfer,
        ...state.completedTransfers.where((item) => item.fileName != completedTransfer.fileName || item.location != completedTransfer.location),
      ].take(50).toList(growable: false);

      emit(state.copyWith(
        clearActiveTransfer: true,
        completedTransfers: updatedHistory,
      ));

      await _persistHistory(updatedHistory);
    }
  }

  Future<void> pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) {
      return;
    }

    await sendLocalFilePath(result.files.single.path!);
  }

  Future<int> sendDroppedFiles(List<String> filePaths) async {
    var sentCount = 0;
    for (final filePath in filePaths) {
      final sent = await sendLocalFilePath(filePath);
      if (sent) {
        sentCount++;
      }
    }

    return sentCount;
  }

  Future<String?> _resolveSenderIp() async {
    if (globals.currentServerIp != null && globals.currentServerIp!.isNotEmpty) {
      return globals.currentServerIp;
    }

    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 && !address.isLoopback) {
            globals.currentServerIp = address.address;
            return address.address;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  Future<void> openLocalFile(FileModel file) async {
    if (file.location == null) {
      return;
    }

    await OpenFilex.open(file.location!);
  }

  @override
  Future<void> close() {
    _folderWatcher?.cancel();
    return super.close();
  }

  Future<List<TransferHistoryItem>> _loadPersistedHistory() async {
    try {
      final historyFile = await CommonFunctions().getHotDropHistoryFile();
      if (!await historyFile.exists()) {
        return const <TransferHistoryItem>[];
      }

      final rawContent = await historyFile.readAsString();
      final decoded = jsonDecode(rawContent);
      if (decoded is! List) {
        return const <TransferHistoryItem>[];
      }

      return decoded.whereType<Map<String, dynamic>>().map(TransferHistoryItem.fromMap).where((item) => !item.isActive).toList(growable: false)
        ..sort((left, right) => right.lastUpdatedMillis.compareTo(left.lastUpdatedMillis));
    } catch (_) {
      return const <TransferHistoryItem>[];
    }
  }

  Future<void> _persistHistory(List<TransferHistoryItem> history) async {
    try {
      final historyFile = await CommonFunctions().getHotDropHistoryFile();
      await historyFile.writeAsString(jsonEncode(history.take(50).map((item) => item.toMap()).toList(growable: false)));
    } catch (_) {}
  }

  List<TransferHistoryItem> _reconcileHistory(List<TransferHistoryItem> history, List<FileModel> files) {
    final reconciled = history.map((item) {
      final location = item.location;
      if (location == null) {
        return item.copyWith(isAvailable: false);
      }

      // Check the actual file system instead of exact string matching to bypass '\' vs '/' issues
      if (File(location).existsSync()) {
        return item.copyWith(isAvailable: true);
      }

      return item.copyWith(isAvailable: false);
    }).toList(growable: false);

    reconciled.sort((left, right) => right.lastUpdatedMillis.compareTo(left.lastUpdatedMillis));
    return reconciled.take(50).toList(growable: false);
  }

  void _handleFileMoved(String sourcePath, String destinationPath) {
    final destinationName = destinationPath.split(Platform.pathSeparator).last;
    final updatedHistory = state.completedTransfers.map((item) {
      final normalizedItemLocation = item.location?.replaceAll('\\', '/');
      final normalizedSourcePath = sourcePath.replaceAll('\\', '/');

      if (normalizedItemLocation == normalizedSourcePath) {
        return item.copyWith(
          fileName: destinationName,
          location: destinationPath,
          isAvailable: true,
          lastUpdatedMillis: DateTime.now().millisecondsSinceEpoch,
        );
      }

      return item;
    }).toList(growable: false);

    emit(state.copyWith(completedTransfers: updatedHistory));
    _persistHistory(updatedHistory);
  }

  String _formatSize(int? sizeInBytes) {
    if (sizeInBytes == null || sizeInBytes <= 0) return 'Unknown size';
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (sizeInBytes >= gb) return '${(sizeInBytes / gb).toStringAsFixed(1)} GB';
    if (sizeInBytes >= mb) return '${(sizeInBytes / mb).toStringAsFixed(1)} MB';
    if (sizeInBytes >= kb) return '${(sizeInBytes / kb).toStringAsFixed(1)} KB';
    return '$sizeInBytes B';
  }

  String _formatSpeed(int? sizeInBytes, int elapsedMilliseconds) {
    if (sizeInBytes == null || sizeInBytes <= 0 || elapsedMilliseconds <= 0) return '0 B/S';
    final bytesPerSecond = sizeInBytes / (elapsedMilliseconds / 1000);
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (bytesPerSecond >= gb) return '${(bytesPerSecond / gb).toStringAsFixed(1)} GB/S';
    if (bytesPerSecond >= mb) return '${(bytesPerSecond / mb).toStringAsFixed(1)} MB/S';
    if (bytesPerSecond >= kb) return '${(bytesPerSecond / kb).toStringAsFixed(1)} KB/S';
    return '${bytesPerSecond.toStringAsFixed(0)} B/S';
  }
}
