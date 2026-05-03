import 'dart:io';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:test/logic/cubits/connection_cubit.dart';
import 'package:test/presentation/screens/main_screen_view_model.dart';
import 'package:test/presentation/theme/app_colors.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MainScreenReceiveView extends StatefulWidget {
  const MainScreenReceiveView({super.key});

  @override
  State<MainScreenReceiveView> createState() => _MainScreenReceiveViewState();
}

class _MainScreenReceiveViewState extends State<MainScreenReceiveView> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  void _showQrCodeDialog(BuildContext context, String qrData) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(
                color: AppColors.primaryContainer.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Scan to Connect',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Gap(20.h),
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 250.h,
                    gapless: false,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
                Gap(20.h),
                Text(
                  'Use the HotDrop mobile app to scan this code.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: BlocBuilder<ConnectionCubit, ConnectionState>(
        builder: (context, state) {
          final viewModel = MainScreenViewModel.fromState(state);
          final String hostName = Platform.localHostname;

          return SafeArea(
            child: Stack(
              children: [
                // Main Content
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Gap(40.h),

                                // Radar Animation
                                SizedBox(
                                  height: 250.h,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      AnimatedBuilder(
                                        animation: _pulseController,
                                        builder: (context, child) {
                                          return CustomPaint(
                                            size: Size(250.h, 250.h),
                                            painter: _RadarPulsePainter(_pulseController.value, Colors.grey.shade400),
                                          );
                                        },
                                      ),
                                      // The Hero target in the center of the radar
                                      Hero(
                                        tag: 'receive_hub_icon',
                                        child: Material(
                                          color: Colors.transparent,
                                          child: Container(
                                            width: 100.h,
                                            height: 100.h,
                                            decoration: BoxDecoration(
                                              color: AppColors.surface, // Inner dark circle
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AppColors.primaryContainer.withValues(alpha: 0.8),
                                                width: 6.w,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.primaryContainer.withValues(alpha: 0.2),
                                                  blurRadius: 40,
                                                  spreadRadius: 10,
                                                )
                                              ],
                                            ),
                                            child: Icon(Icons.cell_tower_rounded, color: Colors.white, size: 40.sp),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Gap(40.h),

                                // Typography
                                Text(
                                  'VISIBLE TO\nEVERYONE',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 60.sp,
                                    fontWeight: FontWeight.w900,
                                    height: 0.9,
                                    letterSpacing: -1,
                                  ),
                                ),
                                Gap(20.h),
                                Text.rich(
                                  TextSpan(
                                    text: 'Nearby devices can see you as ',
                                    style: TextStyle(color: Colors.grey, fontSize: 16.sp),
                                    children: [
                                      TextSpan(
                                        text: hostName,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                      const TextSpan(text: '. Make sure your WiFi and Bluetooth are active.'),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                Gap(20.h),

                                // PIN Display
                                if (state.blePin != null && !state.isPaired) ...[
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(20.r),
                                      border: Border.all(
                                        color: AppColors.primaryContainer.withValues(alpha: 0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'SECURITY PIN',
                                              style: TextStyle(
                                                color: AppColors.primaryContainer,
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 2,
                                              ),
                                            ),
                                            Text(
                                              'Confirm on sender',
                                              style: TextStyle(color: Colors.grey, fontSize: 10.sp),
                                            ),
                                          ],
                                        ),
                                        Gap(40.w),
                                        Text(
                                          state.blePin!,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 36.sp,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 6,
                                          ),
                                        ),
                                        if (state.qrData != null) ...[
                                          Gap(25.w),
                                          Container(
                                            width: 1,
                                            height: 40.h,
                                            color: Colors.white.withValues(alpha: 0.2),
                                          ),
                                          Gap(25.w),
                                          MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: GestureDetector(
                                              onTap: () => _showQrCodeDialog(context, state.qrData!),
                                              child: Container(
                                                padding: EdgeInsets.all(10.w),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryContainer.withValues(alpha: 0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(Icons.qr_code_2_rounded, color: AppColors.primaryContainer, size: 28.sp),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Gap(20.h),
                                ],

                                // Loading Status
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20.w,
                                      height: 20.w,
                                      child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
                                    ),
                                    Gap(15.w),
                                    Text(
                                      viewModel.loadingStatus.toUpperCase(),
                                      style: TextStyle(color: Colors.grey, fontSize: 12.sp, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                                    ),
                                  ],
                                ),
                                Gap(40.h),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Back Button (Top Left)
                Positioned(
                  top: 40.h,
                  left: 40.w,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        context.read<ConnectionCubit>().disconnect();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24.sp),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RadarPulsePainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadarPulsePainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 4; i++) {
      double ringProgress = (progress + (i * 0.25)) % 1.0;
      double radius = ringProgress * maxRadius;

      // Fades out as it expands
      final opacity = (1.0 - ringProgress).clamp(0.0, 1.0) * 0.3;
      paint.color = color.withValues(alpha: opacity);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPulsePainter oldDelegate) => oldDelegate.progress != progress;
}
