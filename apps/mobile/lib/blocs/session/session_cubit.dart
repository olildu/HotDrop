import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/connection_repository.dart';
import '../../data/repositories/contact_repository.dart';
import '../../services/connection_services.dart';

enum SessionStatus { initializing, idle, connected }

class SessionState {
  final SessionStatus status;
  final bool isContactsSynced;

  SessionState({required this.status, this.isContactsSynced = false});

  SessionState copyWith({SessionStatus? status, bool? isContactsSynced}) {
    return SessionState(
      status: status ?? this.status,
      isContactsSynced: isContactsSynced ?? this.isContactsSynced,
    );
  }
}

class SessionCubit extends Cubit<SessionState> {
  final ConnectionRepository _connectionRepo;
  final ContactRepository _contactRepo;
  final ClientServices _clientServices = ClientServices();

  SessionCubit(this._connectionRepo, this._contactRepo) 
      : super(SessionState(status: SessionStatus.initializing));

  Future<void> initializeApp() async {
    // 1. Attempt Silent Reconnect
    final reconnected = await _clientServices.tryAutoReconnect();
    
    // 2. Sync Contacts
    final contacts = await _contactRepo.fetchContacts();
    await _contactRepo.syncContacts(contacts);
    
    // 3. Update Status
    emit(state.copyWith(
      status: reconnected ? SessionStatus.connected : SessionStatus.idle,
      isContactsSynced: true,
    ));
  }

  void updateConnectionStatus(bool isConnected) {
    emit(state.copyWith(status: isConnected ? SessionStatus.connected : SessionStatus.idle));
  }

  void cleanupSession() {
    _connectionRepo.performCleanup(); // Logic moved to Repository
  }
}