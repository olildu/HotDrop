import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:test_mobile/core/theme/app_colors.dart';

class ConnectionStatusCard extends StatelessWidget {
  final bool isConnected;
  const ConnectionStatusCard({required this.isConnected, super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 32.h, horizontal: 24.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(32.r),
      ),
      child: Column(
        children: [
          Icon(Icons.hub_rounded, size: 48.sp, color: isConnected ? colorScheme.primary : colorScheme.onSurfaceVariant),
          Gap(16.h),
          Text(
            isConnected ? "Velocity Core-7" : "Disconnected",
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Gap(8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8.w,
                height: 8.h,
                decoration: BoxDecoration(
                  color: isConnected ? colorScheme.primary : AppColors.errorAccent,
                  shape: BoxShape.circle,
                ),
              ),
              Gap(8.w),
              Text(
                isConnected ? "STABLE CONNECTION" : "AWAITING SIGNAL",
                style: textTheme.labelSmall?.copyWith(color: isConnected ? colorScheme.primary : colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          Gap(12.h),
          Text(
            isConnected ? "Latent-free P2P tunnel active" : "Host or join a network to begin",
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
