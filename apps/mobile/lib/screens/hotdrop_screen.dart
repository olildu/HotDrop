import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:test_mobile/services/file_hosting_services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

final GlobalKey<HotdopScreenScreenState> hotdropScreenKey = GlobalKey();

class HotdopScreenScreen extends StatefulWidget {
  HotdopScreenScreen() : super(key: hotdropScreenKey);
  @override
  HotdopScreenScreenState createState() => HotdopScreenScreenState();
}

class HotdopScreenScreenState extends State<HotdopScreenScreen> {
  final FileHostingService fileHostingService = FileHostingService();
  bool isUploading = false;
  bool uploadComplete = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );
    
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        isUploading = true;
        uploadComplete = false;
      });

      await fileHostingService.startHosting(result.files.map((file) => File(file.path!)).toList());
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        isUploading = false;
        uploadComplete = true;
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      throw Exception('Could not launch $url');
    }
  }

  void updateState(dynamic value) {
    setState(() {});
  }

  @override
  void dispose() {
    fileHostingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        titleSpacing: 0,
        title: Text(
          'HotDrop',
          style: TextStyle(
            color: const Color(0xFF49454F),
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    uploadComplete ? Icons.check_circle : Icons.cloud_upload,
                    size: 80.sp,
                    color: uploadComplete ? Colors.green : const Color(0xFF49454F),
                  ),
                  Gap(24.h),
                  Text(
                    uploadComplete ? 'Files Sent!' : 'HotDrop',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF49454F),
                    ),
                  ),
                  Gap(16.h),
                  Text(
                    uploadComplete
                        ? 'Your files have been successfully shared'
                        : 'Select files to share instantly',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: const Color(0xFF49454F),
                    ),
                  ),
                  Gap(40.h),
                  if (!uploadComplete && !isUploading)
                    ElevatedButton(
                      onPressed: _pickFile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF49454F),
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 50.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                      ),
                      child: Text(
                        'SELECT FILES',
                        style: TextStyle(fontSize: 16.sp),
                      ),
                    ),
                  if (isUploading)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F6F6),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: Column(
                        children: [
                          const LinearProgressIndicator(
                            backgroundColor: Color(0xFFE0E0E0),
                            color: Color(0xFF49454F),
                          ),
                          Gap(16.h),
                          Text(
                            fileHostingService.selectedFiles.length == 1
                                ? 'Sending ${fileHostingService.selectedFiles.first.path.split('/').last}...'
                                : 'Sending ${fileHostingService.selectedFiles.length} files...',
                            style: TextStyle(color: const Color(0xFF49454F), fontSize: 14.sp),
                          ),
                        ],
                      ),
                    ),
                  if (uploadComplete)
                    Column(
                      children: [
                        Container(
                          constraints: BoxConstraints(maxHeight: 200.h),
                          child: SingleChildScrollView(
                            child: Column(
                              children: fileHostingService.selectedFiles.map((file) {
                                final index = fileHostingService.selectedFiles.indexOf(file);
                                return Container(
                                  padding: EdgeInsets.all(16.w),
                                  margin: EdgeInsets.only(bottom: 12.h),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF6F6F6),
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(color: const Color(0xFFE0E0E0)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.insert_drive_file, color: Color(0xFF49454F)),
                                      Gap(12.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              file.path.split('/').last,
                                              style: TextStyle(
                                                color: const Color(0xFF49454F),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14.sp,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Gap(4.h),
                                            Text(
                                              '${(file.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB',
                                              style: TextStyle(color: const Color(0xFF49454F), fontSize: 12.sp),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.share, color: Color(0xFF49454F)),
                                        onPressed: () {
                                          // if (index < fileHostingService.downloadUrl.length) {
                                          //   _launchUrl(fileHostingService.downloadUrls[index]);
                                          // }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        Gap(20.h),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              uploadComplete = false;
                              fileHostingService.dispose();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF49454F),
                            foregroundColor: Colors.white,
                            minimumSize: Size(double.infinity, 50.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                          ),
                          child: Text('SEND MORE FILES', style: TextStyle(fontSize: 16.sp)),
                        ),
                      ],
                    ), 
                ],
              ),
            ),
            if (!uploadComplete)
              Text(
                'Files are transferred directly between devices',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF49454F),
                  fontSize: 12.sp,
                ),
              ),
          ],
        ),
      ),
    );
  }
}