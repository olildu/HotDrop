import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart'; // ✅ changed
import 'package:provider/provider.dart';
import 'package:test_mobile/providers/file_detail_provider.dart';

class SharedFilesScreen extends StatelessWidget {
  const SharedFilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 248, 248, 248),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF49454F)),
        title: Text(
          "Shared Files",
          style: GoogleFonts.poppins(
            color: const Color(0xFF49454F),
            fontWeight: FontWeight.bold,
            fontSize: 20.sp,
          ),
        ),
      ),
      body: Consumer<FileDetailProvider>(
        builder: (context, fileProvider, child) {
          final allFiles = fileProvider.files;

          if (allFiles.isEmpty) {
            return Center(
              child: Text(
                "No files shared yet",
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16.sp),
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.all(20.sp),
            itemCount: allFiles.length,
            separatorBuilder: (context, index) => Gap(12.h),
            itemBuilder: (context, index) {
              final file = allFiles[index];
              final bool isSent = file["is_sent"] ?? false;

              return GestureDetector(
                onTap: () async {
                  final String? filePath = file["file_path"];

                  if (filePath != null && await File(filePath).exists()) {
                    final result = await OpenFilex.open(filePath); // ✅ changed

                    if (result.type != ResultType.done) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Could not open file: ${result.message}",
                          ),
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("File not found on device"),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: EdgeInsets.all(15.sp),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: const Color(0xFFE8E8E8)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10.sp),
                        decoration: BoxDecoration(
                          color: isSent ? const Color(0xFF49454F) : Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSent ? Icons.upload_file_rounded : Icons.download_for_offline_rounded,
                          color: Colors.white,
                          size: 24.sp,
                        ),
                      ),
                      Gap(15.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file["file_name"] ?? "Unknown File",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 15.sp,
                                color: const Color(0xFF49454F),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "${fileProvider.formatDataSize(file["file_size"].toDouble())} • ${DateFormat('MMM d, h:mm a').format(DateTime.parse(file["timestamp"]))}",
                              style: GoogleFonts.poppins(
                                fontSize: 12.sp,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (file["transfer_speed"] != null)
                        Text(
                          "${fileProvider.formatDataSize(file["transfer_speed"])}/s",
                          style: GoogleFonts.poppins(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.green,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
