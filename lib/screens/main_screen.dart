
import 'dart:developer';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:test_mobile/providers/file_detail_provider.dart';
import 'package:test_mobile/services/connection_services.dart';
import 'package:test_mobile/services/data_services.dart';
import 'package:test_mobile/widget/main_screen_widgets.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State createState() => _MainScreenState();
}

class _MainScreenState extends State {

  @override 
  void initState(){
    super.initState();
    getContacts();
    Provider.of<FileDetailProvider>(context, listen: false).loadFileDetails();
  }

  Future<void> getContacts() async {
    if (await FlutterContacts.requestPermission()) {
      List<Contact> contacts = await FlutterContacts.getContacts(withProperties: true, withThumbnail: true);
      OutgoingDataParser().parseContacts(contacts);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 248, 248, 248),

      body: FutureBuilder<Map<String, dynamic>>(
        future: AndroidFunction().checkConnectionStatus(),
        // future: null,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting){
            return const Center(child: CircularProgressIndicator(),);
          }
          else{
            return Padding(
              padding: EdgeInsets.only(top: 50.h, left: 20.w, right: 20.w),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // User Details
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Welcome back",
                              style: GoogleFonts.poppins(
                                fontSize: 16.sp,
                                color: const Color(0xFF7A7A7A),
                              ),
                            ),
                            Text(
                              "Ebin 👋",
                              style: GoogleFonts.poppins(
                                fontSize: 30.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF49454F),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        
                        CircleAvatar(
                          radius: 25.r,
                          backgroundColor: const Color(0xFF49454F),
                          child: Text(
                            "E",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w500
                            ),
                          ),
                        ),
                      ],
                    ),
                
                    Gap(40.h),
                
                    // Data Transfer Details
                    Consumer<FileDetailProvider>(
                      builder: (context, fileService, _) => Text.rich(
                        TextSpan(
                          text: fileService.getDataStats()["total_data"] ?? "0 MB",
                          style: GoogleFonts.poppins(fontSize: 30.sp),
                          children: [
                            TextSpan(
                              text: ' Transferred',
                              style: GoogleFonts.poppins(fontSize: 30.sp, color: const Color.fromARGB(255, 133, 133, 133)),
                            ),
                          ],
                        ),
                      )
                    ),
                    
                    SizedBox(
                      height: 420.h,
                      child: ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 2,
                        itemBuilder: (context, index) {
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final squareSize = (constraints.maxWidth - 5.h) / 2;
                
                              return detailWidgets(context, squareSize, index, snapshot.data!);
                            },
                          );
                        },
                      ),
                    ),
                
                    Gap(20.h),
            
                    recentFilesTitleSearchBar(),
                
                    Gap(20.h),
            
                    Consumer<FileDetailProvider>(
                      builder: (context, fileService, _) {
                        final receivedFiles = fileService.files.where((file) => file["is_sent"] == true).toList();

                        if (receivedFiles.isEmpty) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 20.h),
                            child: Center(
                              child: Text(
                                "No files received yet.",
                                style: GoogleFonts.poppins(fontSize: 14.sp, color: Colors.grey),
                              ),
                            ),
                          );
                        }

                        return SizedBox(
                          height: math.min(receivedFiles.length * 110.0, 330.0).h,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: math.min(receivedFiles.length, 3),
                            itemBuilder: (context, index) {
                              final file = receivedFiles[index];
                              return Container(
                                width: double.infinity,
                                margin: EdgeInsets.only(bottom: 10.h),
                                padding: EdgeInsets.symmetric(horizontal: 20.sp),
                                height: 100.h,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color.fromARGB(255, 235, 235, 235),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(15.sp),
                                      decoration: const BoxDecoration(
                                        color: Color.fromARGB(255, 73, 69, 79),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.photo_camera_outlined, color: Colors.white),
                                    ),
                                    Gap(20.w),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 180.w,
                                          child: Text(
                                            file["file_name"],
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 19.sp,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        Text(
                                          DateFormat('dd/MM/yy h:mm a').format(DateTime.parse(file["timestamp"])),
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.normal,
                                            fontSize: 12.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      onPressed: () {},
                                      icon: const Icon(Icons.delete_rounded),
                                    )
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    )



                  ],
                ),
              ),
            );
          }
        }
      ),
    );
  }
}
