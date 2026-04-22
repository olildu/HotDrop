import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:test_mobile/blocs/hotdrop_cubit.dart';
import 'package:test_mobile/core/theme/app_colors.dart';

class ActiveSessionCard extends StatelessWidget {
  const ActiveSessionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BlocBuilder<HotDropCubit, HotDropState>(
      builder: (context, state) {
        // Show active view if uploading OR complete (for the 3s delay)
        final isActive = state.status == HotDropStatus.uploading || state.status == HotDropStatus.complete;

        return Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(32.r),
            border: Border.all(
              color: isActive ? colorScheme.primary.withOpacity(0.3) : Colors.transparent,
              width: 1.w,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("ACTIVE SESSION", style: textTheme.labelSmall?.copyWith(letterSpacing: 1.5)),

                  // NEW: Dynamic Percentage
                  if (isActive) Text("${(state.progress * 100).toInt()}%", style: textTheme.labelSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                ],
              ),
              Gap(20.h),
              if (isActive) ...[
                _buildProgressView(state, colorScheme, textTheme),
              ] else ...[
                _buildIdleView(context, colorScheme, textTheme),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressView(HotDropState state, ColorScheme colorScheme, TextTheme textTheme) {
    final isComplete = state.status == HotDropStatus.complete;

    return Column(
      children: [
        Row(
          children: [
            CircleAvatar(
                backgroundColor: isComplete ? AppColors.successAccent.withOpacity(0.1) : colorScheme.primary.withOpacity(0.1),
                child: Icon(isComplete ? Icons.check_circle_rounded : Icons.folder_zip_rounded, color: isComplete ? AppColors.successAccent : colorScheme.primary)),
            Gap(16.w),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  isComplete ? "Transfer Successful!" : (state.selectedFiles.isNotEmpty ? state.selectedFiles.first.path.split('/').last : "Transferring..."),
                  style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text("Direct P2P Tunnel", style: textTheme.labelSmall),
              ]),
            ),
          ],
        ),
        Gap(20.h),
        // NEW: Real-time dynamic Progress Indicator
        LinearProgressIndicator(
          value: state.progress,
          minHeight: 4,
          backgroundColor: colorScheme.surfaceContainerHighest,
          color: isComplete ? AppColors.successAccent : colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildIdleView(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      children: [
        Text("Ready to beam data to connected peer.", style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
        Gap(20.h),
        ElevatedButton.icon(
          onPressed: () async {
            final result = await FilePicker.platform.pickFiles(allowMultiple: true);
            if (result != null) context.read<HotDropCubit>().hostFiles(result.files.map((f) => File(f.path!)).toList());
          },
          icon: Icon(Icons.add_rounded, size: 20.sp),
          label: const Text("SELECT FILES"),
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.surface,
            minimumSize: Size(double.infinity, 48.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          ),
        ),
      ],
    );
  }
}
