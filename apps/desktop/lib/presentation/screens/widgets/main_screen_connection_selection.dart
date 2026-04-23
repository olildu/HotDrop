import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:test/presentation/screens/main_screen_view_model.dart';
// Note: Make sure to import your send view here if it's named differently now!
import 'package:test/presentation/screens/widgets/main_screen_send_view.dart';
import 'package:test/presentation/screens/widgets/main_screen_receive_view.dart';
import 'package:test/presentation/theme/app_colors.dart';

class MainScreenConnectionSelection extends StatelessWidget {
  final MainScreenViewModel viewModel;
  final MainScreenActions actions;

  const MainScreenConnectionSelection({
    super.key,
    required this.viewModel,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(30.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(30.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Establish Secure Link',
            style: TextStyle(color: Colors.white, fontSize: 24.sp, fontWeight: FontWeight.bold),
          ),
          Gap(5.h),
          Text(
            'Select a protocol to initialize the Kinetic Void.',
            style: TextStyle(color: Colors.grey, fontSize: 12.sp),
          ),
          Gap(30.h),
          if (viewModel.isProcessing) ...[
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                Gap(12.w),
                Expanded(
                  child: Text(
                    viewModel.loadingStatus,
                    style: TextStyle(color: Colors.white, fontSize: 12.sp),
                  ),
                ),
              ],
            ),
            Gap(20.h),
          ],
          if (viewModel.isAdminError) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Administrator privileges are required to host a hotspot on Windows.',
                style: TextStyle(color: Colors.redAccent.shade100, fontSize: 12.sp),
              ),
            ),
            Gap(20.h),
          ],
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  title: 'SEND',
                  subtitle: 'Scan the network for active beams.',
                  icon: Icons.upload_rounded,
                  enabled: !viewModel.isProcessing,
                  heroTag: 'send_hub_icon',
                  onTap: () {
                    actions.startJoining();
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => const MainScreenSendView(),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                      ),
                    );
                  },
                ),
              ),
              Gap(20.w),
              Expanded(
                child: _ActionCard(
                  title: 'RECEIVE',
                  subtitle: 'Host a secure drop point for peers.',
                  icon: Icons.download_rounded,
                  enabled: !viewModel.isProcessing,
                  heroTag: 'receive_hub_icon',
                  onTap: () {
                    actions.startHosting();
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => const MainScreenReceiveView(),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final String heroTag;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.enabled,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 20.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.surfaceContainerHighest, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Hero(
                tag: heroTag,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: AppColors.primaryContainer, size: 40.sp),
                  ),
                ),
              ),
              Gap(20.h),
              Text(
                title,
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.white54,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              Gap(10.h),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: enabled ? Colors.grey : Colors.grey.shade600, fontSize: 11.sp, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
