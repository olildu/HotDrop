// lib/screens/hotdrop_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // Add this
import 'package:file_picker/file_picker.dart';
import 'package:test_mobile/blocs/hotdrop_cubit.dart'; // Add this
import 'package:test_mobile/core/theme/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

class HotdopScreenScreen extends StatefulWidget {
  const HotdopScreenScreen({super.key});
  @override
  HotdopScreenScreenState createState() => HotdopScreenScreenState();
}

class HotdopScreenScreenState extends State<HotdopScreenScreen> {
  // REMOVE: final FileHostingService fileHostingService = FileHostingService();

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);

    if (result != null && result.files.isNotEmpty) {
      final files = result.files.map((file) => File(file.path!)).toList();
      // Use the global Cubit to start hosting
      context.read<HotDropCubit>().hostFiles(files);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HotDropCubit, HotDropState>(
      builder: (context, state) {
        // Map Cubit state to local UI logic
        final isUploading = state.status == HotDropStatus.uploading;
        final uploadComplete = state.status == HotDropStatus.complete;

        return Scaffold(
          backgroundColor: AppColors.white,
          appBar: AppBar(
            backgroundColor: AppColors.white,
            title: Text('HotDrop', style: TextStyle(color: AppColors.legacyNeutralStrong, fontSize: 20.sp, fontWeight: FontWeight.bold)),
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
                        color: uploadComplete ? AppColors.success : AppColors.legacyNeutralStrong,
                      ),
                      Gap(24.h),
                      Text(uploadComplete ? 'Files Sent!' : 'HotDrop', style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, color: AppColors.legacyNeutralStrong)),
                      Gap(16.h),
                      Text(
                        uploadComplete ? 'Your files have been successfully shared' : 'Select files to share instantly',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16.sp, color: AppColors.legacyNeutralStrong),
                      ),
                      Gap(40.h),

                      // Progress Bar based on global state
                      if (isUploading) ...[
                        LinearProgressIndicator(
                          value: state.progress,
                          backgroundColor: AppColors.legacyProgressTrack,
                          color: AppColors.legacyNeutralStrong,
                        ),
                        Gap(16.h),
                        Text("${(state.progress * 100).toInt()}% Transferred", style: TextStyle(color: AppColors.legacyNeutralStrong, fontSize: 14.sp)),
                      ],

                      if (!uploadComplete && !isUploading)
                        ElevatedButton(
                          onPressed: _pickFile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.legacyNeutralStrong,
                            foregroundColor: AppColors.white,
                            minimumSize: Size(double.infinity, 50.h),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          ),
                          child: Text('SELECT FILES', style: TextStyle(fontSize: 16.sp)),
                        ),

                      if (uploadComplete)
                        ElevatedButton(
                          onPressed: () => context.read<HotDropCubit>().reset(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.legacyNeutralStrong,
                            foregroundColor: AppColors.white,
                            minimumSize: Size(double.infinity, 50.h),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          ),
                          child: Text('SEND MORE FILES', style: TextStyle(fontSize: 16.sp)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
