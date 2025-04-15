
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:test_mobile/constants/globals.dart';
import 'package:test_mobile/providers/file_detail_provider.dart';
import 'package:test_mobile/providers/message_provider.dart';
import 'package:test_mobile/screens/main_screen.dart';
import 'package:test_mobile/services/connection_services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AndroidFunction().initialize();
  await Permissions().requestPermissions();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MessageProvider()),
        ChangeNotifierProvider(create: (_) => FileDetailProvider()),
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
        theme: ThemeData(
          primarySwatch: Colors.blue,
          textTheme: GoogleFonts.poppinsTextTheme(),
        ),
        home: const MainScreen(),
      ),
    );
  }
}
