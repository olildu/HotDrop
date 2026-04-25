import 'package:test/logic/cubits/connection_cubit.dart';

class AvailableHostViewModel {
  final String name;
  final String address;

  const AvailableHostViewModel({required this.name, required this.address});
}

class MainScreenViewModel {
  final ConnectionState rawState;
  final String statusText;
  final bool hasConnection;
  final bool isConnected;
  final bool showTransferHub;
  final bool isProcessing;
  final bool isAdminError;
  final bool isJoinMode;
  final String loadingStatus;
  final List<AvailableHostViewModel> availableHosts;

  const MainScreenViewModel({
    required this.rawState,
    required this.statusText,
    required this.hasConnection,
    required this.isConnected,
    required this.showTransferHub,
    required this.isProcessing,
    required this.isAdminError,
    required this.isJoinMode,
    required this.loadingStatus,
    required this.availableHosts,
  });

  factory MainScreenViewModel.fromState(ConnectionState state) {
    final isConnected = switch (state.selectedRole) {
      ConnectionRole.host => state.hostClientConnected,
      ConnectionRole.join => !state.isProcessing && !state.isAdminError,
      ConnectionRole.none => false,
    };

    return MainScreenViewModel(
      rawState: state,
      statusText: _statusTextFor(state),
      hasConnection: state.selectedRole != ConnectionRole.none,
      isConnected: isConnected,
      showTransferHub: (state.selectedRole == ConnectionRole.host && state.hostClientConnected) || 
                 (state.selectedRole == ConnectionRole.join && !state.isProcessing),
      isProcessing: state.isProcessing,
      isAdminError: state.isAdminError,
      isJoinMode: state.selectedRole == ConnectionRole.join,
      loadingStatus: state.loadingStatus,
      availableHosts: state.availableHosts
          .map(
            (host) => AvailableHostViewModel(
              name: host['name']?.toString() ?? 'Unknown device',
              address: host['address']?.toString() ?? '',
            ),
          )
          .toList(growable: false),
    );
  }

  static String _statusTextFor(ConnectionState state) {
    if (state.isProcessing) {
      return state.loadingStatus;
    }

    switch (state.selectedRole) {
      case ConnectionRole.none:
        return 'Node: Disconnected';
      case ConnectionRole.host:
        return state.hostClientConnected ? 'Active Node: Host' : 'Host: Waiting for peer...';
      case ConnectionRole.join:
        return 'Active Node: Join Mode';
    }
  }
}

class MainScreenActions {
  final ConnectionCubit _cubit;

  MainScreenActions(this._cubit);

  void startHosting() => _cubit.startHosting();

  void startJoining() => _cubit.startJoining();

  void disconnect() => _cubit.disconnect();

  void connectToHost(AvailableHostViewModel host) {
    if (_cubit.state.isProcessing || host.address.isEmpty) {
      return;
    }

    _cubit.connectToPeer(host.address, host.name);
  }
}
