import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:test_mobile/blocs/session/session_cubit.dart';
import 'package:test_mobile/screens/main/widgets/action_buttons.dart';
import 'package:test_mobile/screens/main/widgets/active_session_card.dart';
import 'package:test_mobile/screens/main/widgets/app_footer.dart';
import 'package:test_mobile/screens/main/widgets/connection_status_card.dart';
import 'package:test_mobile/screens/main/widgets/direct_comms_card.dart';
import 'package:test_mobile/screens/main/widgets/main_app_bar.dart';
import 'package:test_mobile/screens/main/widgets/recent_velocity_card.dart';
import 'package:test_mobile/screens/main/widgets/storage_vault_card.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      context.read<SessionCubit>().cleanupSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: const MainAppBar(),
      body: BlocBuilder<SessionCubit, SessionState>(
        builder: (context, sessionState) {
          final isConnected = sessionState.status == SessionStatus.connected;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isConnected) ...[
                  ActionButtons(isConnected: isConnected),
                  Gap(32.h),
                ],
                if (isConnected) ...[
                  const ActiveSessionCard(),
                  Gap(24.h),
                ],
                const StorageVaultCard(),
                Gap(24.h),
                ConnectionStatusCard(isConnected: isConnected),
                Gap(24.h),
                const RecentVelocityCard(),
                Gap(24.h),
                DirectCommsCard(isConnected: isConnected),
              ],
            ),
          );
        },
      ),
    );
  }
}
