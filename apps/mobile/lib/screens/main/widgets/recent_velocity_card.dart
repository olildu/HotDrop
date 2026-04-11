import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:test_mobile/blocs/file_detail_cubit.dart';
import 'package:test_mobile/core/theme/app_colors.dart';
import 'package:test_mobile/screens/shared_files_screen.dart';

class RecentVelocityCard extends StatelessWidget {
  const RecentVelocityCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(32.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("RECENT VELOCITY", style: textTheme.labelSmall?.copyWith(letterSpacing: 1.5)),
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SharedFilesScreen())),
                child: Text("View All", style: textTheme.labelSmall?.copyWith(color: colorScheme.primary)),
              ),
            ],
          ),
          Gap(24.h),
          BlocBuilder<FileDetailCubit, FileDetailState>(
            builder: (context, state) {
              final files = state.files.reversed.toList();
              if (files.isEmpty) {
                return Center(child: Text("Void is empty", style: textTheme.bodyMedium));
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: math.min(files.length, 3),
                separatorBuilder: (_, __) => Gap(24.h),
                itemBuilder: (context, index) {
                  final file = files[index];
                  return Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        child: Icon(file.isSent ? Icons.upload_file : Icons.download, size: 20.sp),
                      ),
                      Gap(16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(file.name, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                            Text("${file.isSent ? 'Sent' : 'Received'} • ${context.read<FileDetailCubit>().formatDataSize(file.size.toDouble())}", style: textTheme.labelSmall),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}