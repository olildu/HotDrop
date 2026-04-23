import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:test/logic/cubits/connection_cubit.dart';
import 'package:test/presentation/screens/main_screen_view_model.dart';
import 'package:test/presentation/theme/app_colors.dart';

class MainScreenSendView extends StatefulWidget {
  const MainScreenSendView({super.key});

  @override
  State<MainScreenSendView> createState() => _MainScreenSendViewState();
}

class _MainScreenSendViewState extends State<MainScreenSendView> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
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

          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(40.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header with Back Button
                  Align(
                    alignment: Alignment.topLeft,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          // Stop scanning and pop back
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
                  Gap(20.h),

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
                              painter: _RadarPulsePainter(_pulseController.value, AppColors.primary),
                            );
                          },
                        ),
                        // The Hero target in the center of the radar
                        Hero(
                          tag: 'send_hub_icon', // Same tag as connection selection
                          child: Material(
                            color: Colors.transparent,
                            child: Container(
                              width: 70.h,
                              height: 70.h,
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer.withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryContainer.withValues(alpha: 0.3),
                                    blurRadius: 40,
                                    spreadRadius: 15,
                                  )
                                ],
                              ),
                              child: Icon(Icons.cell_tower_rounded, color: AppColors.surface, size: 35.sp),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Gap(20.h),

                  // Typography
                  Text(
                    'SCANNING FOR DEVICES',
                    style: TextStyle(color: Colors.white, fontSize: 40.sp, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  ),
                  Gap(10.h),
                  Text(
                    viewModel.loadingStatus,
                    style: TextStyle(color: Colors.grey, fontSize: 16.sp),
                  ),
                  Gap(70.h),

                  // Discovered Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'DISCOVERED',
                        style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${viewModel.availableHosts.length} NODES FOUND',
                        style: TextStyle(color: AppColors.primaryContainer, fontSize: 14.sp, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                    ],
                  ),
                  Gap(30.h),

                  // Device Cards Grid/Wrap
                  if (viewModel.availableHosts.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 20.w,
                        runSpacing: 20.h,
                        alignment: WrapAlignment.start,
                        children: viewModel.availableHosts
                            .map((host) => _DeviceCard(
                                  host: host,
                                  onTap: () {
                                    if (viewModel.isProcessing || host.address.isEmpty) return;
                                    context.read<ConnectionCubit>().connectToPeer(host.address, host.name);
                                  },
                                ))
                            .toList(),
                      ),
                    )
                  else
                    Padding(
                      padding: EdgeInsets.only(top: 40.h),
                      child: Text(
                        'No nearby HotDrop nodes found yet...',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final AvailableHostViewModel host;
  final VoidCallback onTap;

  const _DeviceCard({required this.host, required this.onTap});

  IconData _getIconForDevice(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('phone') || lowerName.contains('pixel') || lowerName.contains('iphone')) {
      return Icons.phone_android_rounded;
    }
    if (lowerName.contains('mac') || lowerName.contains('laptop') || lowerName.contains('book')) {
      return Icons.laptop_mac_rounded;
    }
    return Icons.desktop_windows_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final simulatedStrength = 75 + (host.name.hashCode % 25);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 300.w,
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(_getIconForDevice(host.name), color: Colors.white, size: 32.sp),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: const BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
                        ),
                        Gap(8.w),
                        Text(
                          "READY",
                          style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Gap(30.h),
              Text(
                host.name,
                style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Gap(8.h),
              Text(
                "Beaming Strength: $simulatedStrength%",
                style: TextStyle(color: Colors.grey, fontSize: 14.sp),
              ),
            ],
          ),
        ),
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
      ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 4; i++) {
      double ringProgress = (progress + (i * 0.25)) % 1.0;
      double radius = ringProgress * maxRadius;

      final opacity = (1.0 - ringProgress).clamp(0.0, 1.0) * 0.4;
      paint.color = color.withValues(alpha: opacity);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPulsePainter oldDelegate) => oldDelegate.progress != progress;
}
