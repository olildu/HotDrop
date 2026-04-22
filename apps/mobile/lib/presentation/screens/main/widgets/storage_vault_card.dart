import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:test_mobile/logic/cubits/file_detail_cubit.dart';
import 'package:test_mobile/presentation/theme/app_colors.dart';

class StorageVaultCard extends StatelessWidget {
  const StorageVaultCard({super.key});

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
      child: BlocBuilder<FileDetailCubit, FileDetailState>(
        builder: (context, state) {
          // stats['total_data'] retrieves the sum of all sent and received file sizes
          final stats = context.read<FileDetailCubit>().getStats();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "DATA TRANSFERRED", // Changed from STORAGE VAULT
                    style: textTheme.labelSmall?.copyWith(letterSpacing: 1.5, color: colorScheme.onSurfaceVariant),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Text(
                      "LIVE STATS",
                      style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
              Gap(12.h),
              Text.rich(
                TextSpan(
                  text: "${stats['total_data']} ",
                  style: textTheme.headlineMedium?.copyWith(fontSize: 32.sp),
                  children: [
                    TextSpan(
                      text: 'Beamed', // Changed from Used to match "The Kinetic Void" theme
                      style: textTheme.headlineMedium?.copyWith(
                        fontSize: 24.sp,
                        color: colorScheme.primary.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
