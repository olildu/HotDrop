import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gemma/core/api/flutter_gemma.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:test_mobile/blocs/connection/connection_cubit.dart';
import 'package:test_mobile/blocs/hotdrop_cubit.dart';
import 'package:test_mobile/blocs/session/session_cubit.dart';
import 'package:test_mobile/constants/globals.dart';
import 'package:test_mobile/blocs/file_detail_cubit.dart';
import 'package:test_mobile/blocs/message_cubit.dart';
import 'package:test_mobile/core/theme/app_theme.dart';
import 'package:test_mobile/data/repositories/connection_repository.dart';
import 'package:test_mobile/data/repositories/file_repository.dart';
import 'package:test_mobile/injection_container.dart' as di;
import 'package:test_mobile/screens/main_screen.dart';
import 'package:test_mobile/services/connection_services.dart';

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
