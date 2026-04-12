import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:test_mobile/blocs/file_detail_cubit.dart';
import 'package:test_mobile/screens/connection/receive_screen.dart';

// Import screens for navigation within detailWidgets
import 'package:test_mobile/screens/hotdrop_screen.dart';
import 'package:test_mobile/screens/messaging_screen.dart';
import 'package:test_mobile/screens/shared_files_screen.dart';

class MainHeader extends StatelessWidget {
  final String userName;
  const MainHeader({required this.userName, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Welcome back", style: GoogleFonts.poppins(fontSize: 16.sp, color: const Color(0xFF7A7A7A))),
            Text("$userName 👋", style: GoogleFonts.poppins(fontSize: 30.sp, fontWeight: FontWeight.w600, color: const Color(0xFF49454F))),
          ],
        ),
        const Spacer(),
        CircleAvatar(
          radius: 25.r,
          backgroundColor: const Color(0xFF49454F),
          child: Text(userName[0], style: GoogleFonts.poppins(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class TransferStats extends StatelessWidget {
  const TransferStats({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileDetailCubit, FileDetailState>(
      builder: (context, state) {
        final stats = context.read<FileDetailCubit>().getStats();
        return Text.rich(
          TextSpan(
            text: stats["total_data"] ?? "0 MB",
            style: GoogleFonts.poppins(fontSize: 30.sp),
            children: [
              TextSpan(
                text: ' Transferred',
                style: GoogleFonts.poppins(fontSize: 30.sp, color: const Color.fromARGB(255, 133, 133, 133)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class RecentFilesList extends StatelessWidget {
  const RecentFilesList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileDetailCubit, FileDetailState>(
      builder: (context, state) {
        final receivedFiles = state.files.where((file) => file.isSent == true).toList();

        if (receivedFiles.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 20.h),
            child: Center(child: Text("No files received yet.", style: GoogleFonts.poppins(fontSize: 14.sp, color: Colors.grey))),
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
                  border: Border.all(color: const Color.fromARGB(255, 235, 235, 235)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(15.sp),
                      decoration: const BoxDecoration(color: Color.fromARGB(255, 73, 69, 79), shape: BoxShape.circle),
                      child: const Icon(Icons.photo_camera_outlined, color: Colors.white),
                    ),
                    Gap(20.w),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 180.w,
                          child: Text(file.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 19.sp), overflow: TextOverflow.ellipsis),
                        ),
                        Text(DateFormat('dd/MM/yy h:mm a').format(file.timestamp), style: GoogleFonts.poppins(fontSize: 12.sp)),
                      ],
                    ),
                    const Spacer(),
                    IconButton(onPressed: () {}, icon: const Icon(Icons.delete_rounded))
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// RESTORED: detailWidgets helper function
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
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ReceiveScreen()));
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
                    data["connectionStatus"] == 1 ? Icons.laptop_rounded : Icons.wifi_tethering_off_outlined,
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
                          MaterialPageRoute(builder: (context) => MessagingScreen(data: data)),
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
                            BlocBuilder<FileDetailCubit, FileDetailState>(
                              builder: (context, state) => Text(
                                "${context.read<FileDetailCubit>().getStats()["average_transfer_speed"] ?? '0 MB'}/s",
                                style: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.white),
                              ),
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
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SharedFilesScreen()));
                    },
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
                          BlocBuilder<FileDetailCubit, FileDetailState>(
                            builder: (context, state) => Text(
                              "${state.files.length} Files Shared",
                              style: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.white),
                            ),
                          )
                        ],
                      ),
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

// RESTORED: recentFilesTitleSearchBar helper function
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
