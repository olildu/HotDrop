import 'dart:developer';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_mobile/services/file_hosting_services.dart';

enum HotDropStatus { idle, picking, uploading, complete, error }

class HotDropState {
  final HotDropStatus status;
  final List<File> selectedFiles;
  final String? errorMessage;
  final double progress;

  HotDropState({
    required this.status,
    this.selectedFiles = const [],
    this.errorMessage,
    this.progress = 0.0,
  });

  HotDropState copyWith({
    HotDropStatus? status,
    List<File>? selectedFiles,
    String? errorMessage,
    double? progress,
  }) {
    return HotDropState(
      status: status ?? this.status,
      selectedFiles: selectedFiles ?? this.selectedFiles,
      errorMessage: errorMessage ?? this.errorMessage,
      progress: progress ?? this.progress,
    );
  }
}

class HotDropCubit extends Cubit<HotDropState> {
  final FileHostingService _hostingService;

  HotDropCubit(this._hostingService) : super(HotDropState(status: HotDropStatus.idle));

  Future<void> hostFiles(List<File> files) async {
    emit(state.copyWith(status: HotDropStatus.uploading, selectedFiles: files, progress: 0.0));
    try {
      await _hostingService.startHosting(files);
      // Notice: We no longer auto-complete here. We wait for the Desktop's ACK over the socket.
    } catch (e) {
      emit(state.copyWith(status: HotDropStatus.error, errorMessage: e.toString()));
    }
  }

  void updateProgress(double progress) {
    // Status must be 'uploading' for progress to be accepted
    if (state.status == HotDropStatus.uploading) {
      log("Cubit emitting progress: $progress", name: "HotDropCubit");
      emit(state.copyWith(progress: progress));
    } else {
      log("Progress ignored. Status is ${state.status}", name: "HotDropCubit");
    }
  }

  // Called by ReceivedDataParser when Windows sends {"type": "downloadComplete"}
  void completeTransfer() {
    emit(state.copyWith(status: HotDropStatus.complete, progress: 1.0));

    // Revert to Idle after showing "Complete" for 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (state.status == HotDropStatus.complete) reset();
    });
  }

  void reset() {
    _hostingService.dispose();
    emit(HotDropState(status: HotDropStatus.idle));
  }
}
