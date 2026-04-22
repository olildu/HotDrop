import 'dart:ui';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/ble_interop_service.dart';
import '../services/connection_services.dart';

enum AppLifecycleStatus { idle, cleaning, cleaned, failed }

class AppLifecycleState {
  final AppLifecycleStatus status;
  final String? error;

  const AppLifecycleState({
    this.status = AppLifecycleStatus.idle,
    this.error,
  });

  AppLifecycleState copyWith({
    AppLifecycleStatus? status,
    String? error,
  }) {
    return AppLifecycleState(
      status: status ?? this.status,
      error: error,
    );
  }
}

class AppLifecycleCubit extends Cubit<AppLifecycleState> {
  final BleInteropService _bleInteropService;

  AppLifecycleCubit(this._bleInteropService) : super(const AppLifecycleState());

  Future<AppExitResponse> requestAppExit() async {
    emit(state.copyWith(status: AppLifecycleStatus.cleaning));

    try {
      shutdownHotspotSync();
      await _bleInteropService.dispose();
      emit(state.copyWith(status: AppLifecycleStatus.cleaned));
      return AppExitResponse.exit;
    } catch (e) {
      emit(state.copyWith(status: AppLifecycleStatus.failed, error: e.toString()));
      return AppExitResponse.exit;
    }
  }
}
