import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:test/components/main_screen/top_popup.dart';
import 'package:test/constants/globals.dart';
import 'package:test/screens/contacts_screen.dart';
import 'package:test/screens/hotdrop_screen.dart';
import 'package:test/screens/messaging_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {

  @override
  Widget build(BuildContext context) {
    List pages = [
      const HotdropScreen(),
      const ContactScreen(),
      const MessagingScreen()
    ];

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
            
                  ListTile(
                    leading: Icon(Icons.android, size: 60.sp,),
                  ),
            
                  const Gap(20),
            
                  ListTile(
                    title: Text(
                      "Favourites",
                      style: TextStyle(
                        color: const Color.fromARGB(255, 86, 86, 86),
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w500
                      ),
                    ),
                  ),

                  ListTile(
                    mouseCursor: SystemMouseCursors.click,
                    title: const Text(
                      "HotDrop",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    leading: const Icon(Icons.wifi_tethering),
                    onTap: () {
                      setState(() {
                        selectedIndex = 0;
                      });
                    },
                    splashColor: const Color.fromARGB(255, 165, 165, 165).withValues(alpha: 0.3),
                  ),

                  ListTile(
                    mouseCursor: SystemMouseCursors.click,
                    title: const Text(
                      "Contacts",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    leading: const Icon(Icons.contacts_outlined),
                    onTap: () {
                      setState(() {
                        selectedIndex = 1;
                      });
                    },
                    splashColor: const Color.fromARGB(255, 165, 165, 165).withValues(alpha: 0.3),
                  ),

                  ListTile(
                    mouseCursor: SystemMouseCursors.click,
                    title: const Text(
                      "Messaging",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    leading: const Icon(Icons.chat_outlined),
                    onTap: () {
                      setState(() {
                        selectedIndex = 2;
                      });
                    },
                    splashColor: const Color.fromARGB(255, 165, 165, 165).withValues(alpha: 0.3),
                  ),

                  Gap(20.h),
                  
                  ListTile(
                    title: Text(
                      "Devices",
                      style: TextStyle(
                        color: const Color.fromARGB(255, 86, 86, 86),
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w500
                      ),
                    ),
                  ),
                  const ListTile( 
                    title: Text("Ebin's Android", style: TextStyle(fontWeight: FontWeight.w500),),
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
                TopPopup()
              ],
            ),
          )
        
        
        ],
      ),
    );
  }
}