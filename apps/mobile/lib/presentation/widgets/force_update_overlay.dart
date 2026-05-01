import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

class ForceUpdateOverlay extends StatelessWidget {
  const ForceUpdateOverlay({super.key});

  Future<void> _launchPlayStore() async {
    const url = 'https://play.google.com/store/apps/details?id=com.hotdrop.app'; // Replace with actual ID
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      color: Colors.black.withOpacity(0.95),
      padding: EdgeInsets.all(40.w),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.system_update_rounded,
              color: theme.colorScheme.primary,
              size: 80.sp,
            ),
            Gap(32.h),
            Text(
              'Update Required',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Gap(16.h),
            Text(
              'A critical update is required to continue using HotDrop. This ensures compatibility for secure P2P transfers.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            Gap(48.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _launchPlayStore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'Update Now',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
