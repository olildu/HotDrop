import 'dart:ui';
import 'dart:developer' as dev;
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:test/data/services/ble_interop_service.dart';
import 'package:test/data/services/connection_services.dart';

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
    dev.log('App exit requested; starting cleanup', name: 'requestAppExit');
    emit(state.copyWith(status: AppLifecycleStatus.cleaning));

    try {
      shutdownHotspotSync();
      await _bleInteropService.dispose();
      emit(state.copyWith(status: AppLifecycleStatus.cleaned));
      dev.log('Cleanup completed successfully', name: 'requestAppExit');
      return AppExitResponse.exit;
    } catch (e) {
      emit(state.copyWith(status: AppLifecycleStatus.failed, error: e.toString()));
      dev.log('Cleanup failed during app exit', name: 'requestAppExit', error: e);
      return AppExitResponse.exit;
    }
  }
}


