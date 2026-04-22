import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:test_mobile/logic/cubits/connection/connection_cubit.dart';
import 'package:test_mobile/logic/cubits/hotdrop_cubit.dart';
import 'package:test_mobile/logic/cubits/session/session_cubit.dart';
import 'package:test_mobile/data/constants/globals.dart';
import 'package:test_mobile/logic/cubits/file_detail_cubit.dart';
import 'package:test_mobile/logic/cubits/message_cubit.dart';
import 'package:test_mobile/presentation/theme/app_theme.dart';
import 'package:test_mobile/data/repositories/connection_repository.dart';
import 'package:test_mobile/data/repositories/file_repository.dart';
import 'package:test_mobile/logic/di/injection_container.dart' as di;
import 'package:test_mobile/presentation/screens/main_screen.dart';
import 'package:test_mobile/data/services/connection_services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  await Permissions().requestPermissions();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => di.sl<SessionCubit>()..initializeApp()),
        BlocProvider(create: (context) => di.sl<MessageCubit>()),
        BlocProvider(
          create: (context) => FileDetailCubit(di.sl<FileRepository>())..loadFileDetails(),
        ),
        BlocProvider(
          create: (context) => ConnectionCubit(di.sl<ConnectionRepository>()),
        ),
        BlocProvider(create: (context) => di.sl<HotDropCubit>()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(392.72727272727275, 848.7272727272727),
      splitScreenMode: true,
      minTextAdapt: true,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: AppTheme.darkTheme,
        home: const MainScreen(),
      ),
    );
  }
}
