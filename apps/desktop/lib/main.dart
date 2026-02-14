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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await DartFunction().openPort();
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

class DesktopSide extends StatelessWidget {
  const DesktopSide({super.key});

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