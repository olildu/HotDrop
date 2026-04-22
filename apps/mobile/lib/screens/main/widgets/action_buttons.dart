import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:test_mobile/core/theme/app_colors.dart';
import 'package:test_mobile/screens/connection/receive_screen.dart';
import 'package:test_mobile/screens/connection/send_screen.dart';

class ActionButtons extends StatelessWidget {
  final bool isConnected;
  const ActionButtons({required this.isConnected, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildButton(
          context,
          label: "SEND",
          icon: Icons.send_rounded,
          isPrimary: true,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const SendScreen(),
            ),
          ),
        ),
        Gap(16.h),
        _buildButton(
          context,
          label: "RECEIVE",
          icon: Icons.download_for_offline_rounded,
          isPrimary: false,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ReceiveScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildButton(BuildContext context, {required String label, required IconData icon, required bool isPrimary, required VoidCallback onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32.r),
          gradient: isPrimary ? LinearGradient(colors: [colorScheme.primary, colorScheme.primaryContainer]) : null,
          color: isPrimary ? null : AppColors.actionButtonSecondary,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isPrimary ? colorScheme.surface : colorScheme.onSurface, size: 24.sp),
            Gap(12.w),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: isPrimary ? colorScheme.surface : colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
