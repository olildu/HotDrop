import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:test/presentation/screens/main_screen.dart';

import 'logic/cubits/app_lifecycle_cubit.dart';
import 'logic/cubits/connection_cubit.dart';
import 'logic/constants/globals.dart';
import 'logic/injection_container.dart' as di;
import 'data/services/connection_services.dart';
import 'package:test/presentation/theme/app_theme.dart';
import 'package:test/presentation/widgets/main_screen/top_popup.dart';
import 'logic/utils/update_utils.dart';

import 'logic/cubits/message_cubit.dart';
import 'logic/cubits/contact_cubit.dart';
import 'logic/cubits/contact_ui_cubit.dart';
import 'logic/cubits/hotdrop_cubit.dart';
import 'logic/cubits/popup_cubit.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://cad7fdad3d7e76d5c49a24ed0b06018c@o4511313817436160.ingest.de.sentry.io/4511313827266640';
      options.maxCacheItems = 50;
      options.compressPayload = true;
      options.enableAutoPerformanceTracing = true;
      options.tracesSampleRate = 1.0;
    },
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();

      assert(() {
        debugPaintBaselinesEnabled = false;
        return true;
      }());

      // 1. Initialize Dependency Injection Container
      await di.init();

      // 2. Perform startup cleanup and update check
      hardCleanupOnStartup();
      await UpdateUtils.initializeAutoUpdater();

      runApp(
        // 3. Replace MultiProvider with MultiBlocProvider
        MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => di.sl<AppLifecycleCubit>()),
            BlocProvider(create: (_) => di.sl<ConnectionCubit>()),
            BlocProvider(create: (_) => di.sl<MessageCubit>()),
            BlocProvider(create: (_) => di.sl<ContactCubit>()),
            BlocProvider(create: (_) => di.sl<ContactUiCubit>()),
            BlocProvider(create: (_) => di.sl<HotdropCubit>()),
            BlocProvider(create: (_) => di.sl<PopupCubit>()),
          ],
          child: const DesktopSide(),
        ),
      );
    },
  );
}

class DesktopSide extends StatefulWidget {
  const DesktopSide({super.key});

  @override
  State<DesktopSide> createState() => _DesktopSideState();
}

class _DesktopSideState extends State<DesktopSide> with WidgetsBindingObserver {
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
  Future<AppExitResponse> didRequestAppExit() async {
    debugPrint('Window close detected. Delegating app exit cleanup...');
    return context.read<AppLifecycleCubit>().requestAppExit();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(1265.6, 682.4),
      minTextAdapt: true,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        builder: (context, child) {
          return Stack(
            children: [
              if (child != null) child,
              const TopPopup(),
            ],
          );
        },
        home: const MainScreen(),
      ),
    );
  }
}
