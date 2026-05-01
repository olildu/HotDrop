import 'dart:developer' as dev;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_mobile/data/repositories/connection_repository.dart';
import 'package:test_mobile/data/repositories/contact_repository.dart';
import 'package:test_mobile/data/services/connection_services.dart';

enum SessionStatus { initializing, idle, connected }

class SessionState {
  final SessionStatus status;
  final bool isContactsSynced;
  final bool isPaired;

  SessionState({
    required this.status,
    this.isContactsSynced = false,
    this.isPaired = false,
  });

  SessionState copyWith({
    SessionStatus? status,
    bool? isContactsSynced,
    bool? isPaired,
  }) {
    return SessionState(
      status: status ?? this.status,
      isContactsSynced: isContactsSynced ?? this.isContactsSynced,
      isPaired: isPaired ?? this.isPaired,
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
}
