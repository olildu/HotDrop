import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PopupState {
  final bool showPopup;
  final String message;
  final IconData icon;
  final double progress;

  PopupState({
    this.showPopup = false,
    this.message = 'You have a new transfer',
    this.icon = Icons.cloud_download_rounded,
    this.progress = -1,
  });

  PopupState copyWith({
    bool? showPopup,
    String? message,
    IconData? icon,
    double? progress,
  }) {
    return PopupState(
      showPopup: showPopup ?? this.showPopup,
      message: message ?? this.message,
      icon: icon ?? this.icon,
      progress: progress ?? this.progress,
    );
  }
}

class PopupCubit extends Cubit<PopupState> {
  PopupCubit() : super(PopupState()) {
    dev.log('Initializing PopupCubit', name: 'PopupCubit');
  }

  Timer? _hideTimer;

  void show(String message, IconData icon, {double progress = -1}) {
    dev.log('Showing popup: $message (progress: $progress)', name: 'show');
    _hideTimer?.cancel();
    emit(
      state.copyWith(
        message: message,
        icon: icon,
        progress: progress,
        showPopup: true,
      ),
    );

    if (progress == -1) {
      _hideTimer = Timer(const Duration(seconds: 3), hide);
    }
  }

  void updateProgress(double progress) {
    dev.log('Updating popup progress to $progress', name: 'updateProgress');
    _hideTimer?.cancel();
    emit(state.copyWith(progress: progress, showPopup: true));
  }

  void complete(String message, {IconData icon = Icons.check_circle_rounded}) {
    dev.log('Completing popup: $message', name: 'complete');
    _hideTimer?.cancel();
    emit(
      state.copyWith(
        message: message,
        icon: icon,
        progress: 1,
        showPopup: true,
      ),
    );
    _hideTimer = Timer(const Duration(seconds: 2), hide);
  }

  void hide() {
    dev.log('Hiding popup', name: 'hide');
    _hideTimer?.cancel();
    emit(state.copyWith(showPopup: false, progress: -1));
  }

  @override
  Future<void> close() {
    dev.log('Closing PopupCubit', name: 'close');
    _hideTimer?.cancel();
    return super.close();
  }
}
