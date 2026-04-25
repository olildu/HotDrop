import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test/logic/constants/globals.dart' as globals;

class PopupState {
  final bool showPopup;
  final String message;
  final IconData icon;
  final double progress;

  PopupState({
    this.showPopup = false,
    this.message = "You have a new message",
    this.icon = Icons.message_rounded,
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
  PopupCubit() : super(PopupState());

  Timer? _hideTimer;

  void show(String msg, IconData icon, {double progress = -1}) {
    _hideTimer?.cancel();
    emit(state.copyWith(
      message: msg,
      icon: icon,
      progress: progress,
      showPopup: true,
    ));

    if (progress == -1) {
      _hideTimer = Timer(const Duration(seconds: 3), hide);
    }
  }

  void showMessageNotification(String msg, IconData icon, {double progress = -1}) {
    if (globals.currentScreen != globals.AppScreen.main) {
      return;
    }

    show(msg, icon, progress: progress);
  }

  void showFileNotification(String msg, IconData icon, {double progress = -1}) {
    if (globals.currentScreen != globals.AppScreen.messaging) {
      return;
    }

    show(msg, icon, progress: progress);
  }

  void updateProgress(double value) {
    if (globals.currentScreen != globals.AppScreen.messaging || !state.showPopup) {
      return;
    }

    emit(state.copyWith(progress: value, showPopup: true));
  }

  void hideFileNotification() {
    if (globals.currentScreen != globals.AppScreen.messaging) {
      return;
    }

    hide();
  }

  void hide() {
    emit(state.copyWith(showPopup: false, progress: -1));
  }
}
