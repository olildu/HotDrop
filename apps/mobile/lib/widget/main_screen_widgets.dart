import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:test_mobile/providers/file_detail_provider.dart';
import 'package:test_mobile/screens/connection_screen.dart';
import 'package:test_mobile/screens/hotdrop_screen.dart';
import 'package:test_mobile/screens/messaging_screen.dart';

Widget detailWidgets(BuildContext context, double squareSize, int index, Map<String, dynamic> data) {
  return Container(
    width: double.infinity,
    margin: EdgeInsets.symmetric(vertical: 10.h),
    height: squareSize,
    child: Row(
      children: [
        if (index != 1) ...[
          GestureDetector(
            onTap: () {
              if (data["connectionStatus"] != 1) {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ConnectionScreen()));
              }
            },
            child: Container(
              width: squareSize,
              height: squareSize,
              padding: EdgeInsets.all(12.sp),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.sp),
                border: Border.all(color: const Color(0xFFE8E8E8), width: 1.w),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    data["connectionStatus"] == 1
                        ? Icons.laptop_rounded
                        : Icons.wifi_tethering_off_outlined,
                    size: 90.sp,
                    color: const Color(0xFF49454F),
                  ),
                  Gap(10.h),
                  Text(
                    data["connectionStatus"] == 1 ? "Connected to Olildu" : "Not Connected",
                    style: GoogleFonts.poppins(fontSize: 14.sp, color: const Color(0xFF49454F)),
                    textAlign: TextAlign.center,
                  )
                ],
              ),
            ),
          ),
          Gap(15.w),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  flex: 5,
                  child: GestureDetector(
                    onTap: () {
                      if (data["connectionStatus"] == 1) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => MessagingScreen(data: data),
                          ),
                        );
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF49454F),
                        borderRadius: BorderRadius.circular(12.sp),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Transform.rotate(
                            angle: -95,
                            child: Icon(Icons.send, size: 36.sp, color: Colors.white),
                          ),
                          Gap(8.w),
                          Text("Messages", style: GoogleFonts.poppins(fontSize: 16.sp, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
                Gap(8.h),
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF49454F),
                      borderRadius: BorderRadius.circular(12.sp),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.network_check, size: 28.sp, color: Colors.white),
                        Gap(10.w),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Avg Speed", style: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.white)),
                            
                            Consumer<FileDetailProvider>(
                              builder: (context, fileService, _) => Text(
                                "${fileService.getDataStats()["average_transfer_speed"] ?? '0 MB'}/s", 
                                style: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.white)
                              )
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Expanded(
            child: Column(
              children: [
                Expanded(
                  flex: 5,
                  child: GestureDetector(
                    onTap: () {
                      if (data["connectionStatus"] == 1) {
                        Navigator.of(context).push(MaterialPageRoute(builder: (context) => HotdopScreenScreen()));
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF49454F),
                        borderRadius: BorderRadius.circular(12.sp),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_tethering_rounded, size: 42.sp, color: Colors.white),
                          Gap(8.w),
                          Text("HotDrop", style: GoogleFonts.poppins(fontSize: 16.sp, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
                Gap(8.h),
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF49454F),
                      borderRadius: BorderRadius.circular(12.sp),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.article_rounded, size: 28.sp, color: Colors.white),
                        Gap(10.w),
                        Consumer<FileDetailProvider>(
                          builder: (context, fileDetails, _) => Text(
                            "${fileDetails.files.length} Files Shared",
                            style: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.white),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Gap(15.w),
          Container(
            width: squareSize,
            height: squareSize,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.sp),
              border: Border.all(color: const Color(0xFFE8E8E8), width: 1.w),
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Text("Statistics", style: GoogleFonts.poppins(fontSize: 15.sp, color: const Color(0xFF49454F))),
                ),
                Expanded(
                  child: Center(
                    child: Icon(Icons.donut_large_rounded, size: 90.sp, color: const Color(0xFF49454F)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

Widget recentFilesTitleSearchBar() {
  return SizedBox(
    height: 50.h,
    child: Row(
      children: [
        Text(
          "Recent Files",
          style: GoogleFonts.poppins(fontSize: 20.sp, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.all(10.sp),
            decoration: const BoxDecoration(
              color: Color(0xFFE2E2E2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search_rounded, size: 22.sp, color: Colors.black),
          ),
        ),
      ],
    ),
  );
}
