import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:test_mobile/core/theme/app_colors.dart';
import 'package:test_mobile/screens/messaging_screen.dart';

class DirectCommsCard extends StatelessWidget {
  final bool isConnected;
  const DirectCommsCard({required this.isConnected, super.key});

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
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(radius: 36.r, backgroundColor: colorScheme.surfaceContainerHighest, child: Icon(Icons.person, size: 36.sp)),
              if (isConnected) Container(width: 16.w, height: 16.h, decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle, border: Border.all(color: AppColors.surfaceContainerLow, width: 3.w))),
            ],
          ),
          Gap(16.h),
          Text("DIRECT COMMS", style: textTheme.labelSmall),
          Gap(32.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                if (isConnected) Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MessagingScreen(data: {})));
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colorScheme.surfaceContainerHighest, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              ),
              child: Text("OPEN WORKSPACE", style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurface)),
            ),
          )
        ],
      ),
    );
  }
}