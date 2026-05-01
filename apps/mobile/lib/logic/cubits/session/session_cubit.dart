import 'dart:developer' as dev;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_mobile/data/repositories/connection_repository.dart';
import 'package:test_mobile/data/repositories/contact_repository.dart';
import 'package:test_mobile/data/services/connection_services.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

enum SessionStatus { initializing, idle, connected }

class SessionState {
  final SessionStatus status;
  final bool isContactsSynced;
  final bool isPaired;
  final bool forceUpdateRequired;

  SessionState({
    required this.status,
    this.isContactsSynced = false,
    this.isPaired = false,
    this.forceUpdateRequired = false,
  });

  SessionState copyWith({
    SessionStatus? status,
    bool? isContactsSynced,
    bool? isPaired,
    bool? forceUpdateRequired,
  }) {
    return SessionState(
      status: status ?? this.status,
      isContactsSynced: isContactsSynced ?? this.isContactsSynced,
      isPaired: isPaired ?? this.isPaired,
      forceUpdateRequired: forceUpdateRequired ?? this.forceUpdateRequired,
    );
  }
}

class SessionCubit extends Cubit<SessionState> {
  final ConnectionRepository _connectionRepo;
  final ContactRepository _contactRepo;
  final ClientServices _clientServices = ClientServices();

  SessionCubit(this._connectionRepo, this._contactRepo) : super(SessionState(status: SessionStatus.initializing)) {
    dev.log('Initializing SessionCubit', name: 'SessionCubit');
  }

  bool get isConnected => state.status == SessionStatus.connected;
  bool isConnectedState(SessionState sessionState) => sessionState.status == SessionStatus.connected;

  Future<void> initializeApp() async {
    dev.log('Initializing App Session', name: 'initializeApp');

    // 0. Check for mandatory updates (Android only)
    await _checkAndForceUpdate();
    await _checkRemoteForceUpdate();

    if (state.forceUpdateRequired) {
      dev.log('Force update required. Blocking app initialization.', name: 'initializeApp');
      return;
    }

    // 1. Attempt Silent Reconnect
    final reconnected = await _clientServices.tryAutoReconnect();
    dev.log('Auto reconnect attempt result: $reconnected', name: 'initializeApp');

    // 2. Sync Contacts
    dev.log('Syncing contacts...', name: 'initializeApp');
    final contacts = await _contactRepo.fetchContacts();
    await _contactRepo.syncContacts(contacts);
    dev.log('Contacts synced successfully', name: 'initializeApp');

    // 3. Update Status
    emit(state.copyWith(
      status: reconnected ? SessionStatus.connected : SessionStatus.idle,
      isContactsSynced: true,
    ));
  }

  void updateConnectionStatus(bool isConnected) {
    dev.log('Updating connection status to isConnected=$isConnected', name: 'updateConnectionStatus');
    emit(state.copyWith(
      status: isConnected ? SessionStatus.connected : SessionStatus.idle,
      isPaired: isConnected ? state.isPaired : false, // Reset pairing on disconnect
    ));
  }

  void setPaired(bool isPaired) {
    dev.log('Setting pairing status to $isPaired', name: 'setPaired');
    emit(state.copyWith(isPaired: isPaired));
  }

  void cleanupSession() {
    dev.log('Cleaning up session', name: 'cleanupSession');
    _connectionRepo.performCleanup(); // Logic moved to Repository
  }

  Future<void> _checkAndForceUpdate() async {
    try {
      dev.log('Checking for updates...', name: 'checkAndForceUpdate');
      final updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        // If an update is available, we force it immediately
        dev.log('Update available! Triggering immediate update.', name: 'checkAndForceUpdate');
        await InAppUpdate.performImmediateUpdate();
      } else {
        dev.log('No updates available.', name: 'checkAndForceUpdate');
      }
    } catch (e) {
      // We fail silently here because if Play Store is unavailable or
      // the API fails, we don't want to block the entire app launch.
      dev.log('Failed to check for updates: $e', name: 'checkAndForceUpdate');
    }
  }

  Future<void> _checkRemoteForceUpdate() async {
    try {
      dev.log('Checking remote version config...', name: 'checkRemoteForceUpdate');
      // Replace with your actual version JSON URL
      const configUrl = 'https://raw.githubusercontent.com/olildu/HotDrop/main/version.json';

      final response = await http.get(Uri.parse(configUrl)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final config = json.decode(response.body);
        final minVersionStr = config['min_required_version'] as String;

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = Version.parse(packageInfo.version);
        final minRequiredVersion = Version.parse(minVersionStr);

        if (currentVersion < minRequiredVersion) {
          dev.log('Remote check: Update required ($currentVersion < $minRequiredVersion)', name: 'checkRemoteForceUpdate');
          emit(state.copyWith(forceUpdateRequired: true));
        }
      }
    } catch (e) {
      dev.log('Remote version check failed (ignoring): $e', name: 'checkRemoteForceUpdate');
    }
  }
}
