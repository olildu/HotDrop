import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:test/constants/globals.dart';
import 'package:test/providers/contact_provider.dart';
import 'package:test/providers/hotdrop_provider.dart';
import 'package:test/providers/message_provider.dart';
import 'package:test/providers/popup_provider.dart';
import 'package:test/screens/connection_screen.dart';
import 'package:test/services/connection_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await hardCleanupOnStartup();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MessageProvider()),
        ChangeNotifierProvider(create: (_) => ContactProvider()),
        ChangeNotifierProvider(create: (_) => HotdropProvider()),
        ChangeNotifierProvider(create: (_) => PopupProvider()),
      ],
      child: const DesktopSide(),
    ),
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
    print("Window close detected. Cleaning up background tasks...");

    shutdownHotspotSync();
    await bleInteropService.dispose();

    return AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(1265.6, 682.4),
      minTextAdapt: true,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'Poppins',
          textTheme: GoogleFonts.poppinsTextTheme(),
        ),
        home: const ConnectionScreen(),
      ),
    );
  }
}
