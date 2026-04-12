import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../components/main_screen/top_popup.dart';
import '../constants/globals.dart';
import '../screens/contacts_screen.dart';
import '../screens/hotdrop_screen.dart';
import '../screens/messaging_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Navigation state managed locally via setState as it only affects this widget's layout
  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [const HotdropScreen(), const ContactScreen(), const MessagingScreen()];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: const Color.fromARGB(255, 231, 231, 231),
                  width: 1.w,
                ),
              ),
            ),
            child: Drawer(
              width: 250.w,
              backgroundColor: const Color.fromARGB(255, 248, 248, 248),
              child: ListView(
                children: [
                  Gap(10.h),
                  ListTile(leading: Icon(Icons.android, size: 60.sp)),
                  const Gap(20),
                  _buildSectionHeader("Favourites"),
                  _buildNavTile("HotDrop", Icons.wifi_tethering, 0),
                  _buildNavTile("Contacts", Icons.contacts_outlined, 1),
                  _buildNavTile("Messaging", Icons.chat_outlined, 2),
                  Gap(20.h),
                  _buildSectionHeader("Devices"),
                  const ListTile(
                    title: Text("Ebin's Android", style: TextStyle(fontWeight: FontWeight.w500)),
                    leading: Icon(Icons.phone_android),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: pages[selectedIndex]),
                const TopPopup() // Now internally uses BlocBuilder
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(color: const Color.fromARGB(255, 86, 86, 86), fontSize: 18.sp, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildNavTile(String title, IconData icon, int index) {
    return ListTile(
      mouseCursor: SystemMouseCursors.click,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      leading: Icon(icon),
      selected: selectedIndex == index,
      onTap: () => setState(() => selectedIndex = index),
      splashColor: const Color.fromARGB(255, 165, 165, 165).withOpacity(0.3),
    );
  }
}
