import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:test_mobile/logic/cubits/connection/connection_cubit.dart';
import 'package:test_mobile/presentation/theme/app_colors.dart';
import 'radar_pulse_painter.dart';

class RadarStateView extends StatefulWidget {
  final bool isReceiving;

  const RadarStateView({super.key, required this.isReceiving});

  @override
  State<RadarStateView> createState() => _RadarStateViewState();
}

class _RadarStateViewState extends State<RadarStateView> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _showScanner = false;

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
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      children: [
        Column(
          children: [
            Gap(40.h),
            _buildRadar(context),
            Gap(20.h),
            _buildTypography(textTheme),
            const Spacer(),
            _buildStatusCard(context, textTheme),
          ],
        ),
        if (!widget.isReceiving && _showScanner) _buildScannerOverlay(context, textTheme),
      ],
    );
  }

  Widget _buildRadar(BuildContext context) {
    return BlocBuilder<ConnectionCubit, ConnectionCubitState>(builder: (context, state) {
      return SizedBox(
        height: 320.h,
        width: 320.w,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(300.w, 300.w),
                  painter: RadarPulsePainter(
                    progress: _pulseController.value,
                    color: AppColors.primary,
                  ),
                );
              },
            ),
            if (state.discoveredDevices.isEmpty)
              Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(Icons.sensors_rounded, color: AppColors.primary, size: 32.sp),
                ),
              ),
            if (!widget.isReceiving) ...state.discoveredDevices.asMap().entries.map((entry) => _buildOrbitalNode(context, entry.key, entry.value, state.discoveredDevices.length)),
          ],
        ),
      );
    });
  }

  Widget _buildOrbitalNode(BuildContext context, int index, DiscoveredDevice device, int count) {
    final radius = 130.w;
    double angle;
    if (count == 1) {
      angle = -math.pi / 2;
    } else {
      double startAngle = -math.pi + (math.pi / 6);
      double endAngle = -(math.pi / 6);
      angle = startAngle + (endAngle - startAngle) * (index / (count - 1));
    }

    final dx = radius * math.cos(angle);
    final dy = radius * math.sin(angle);

    return Transform.translate(
      offset: Offset(dx, dy),
      child: GestureDetector(
        onTap: () {
          _pulseController.stop();
          context.read<ConnectionCubit>().connectToDiscoveredDevice(device);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30.r,
              backgroundColor: AppColors.surfaceContainerHigh,
              child: Icon(Icons.person, color: AppColors.primary, size: 32.sp),
            ),
            Gap(8.h),
            SizedBox(
              width: 90.w,
              child: Text(
                device.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypography(TextTheme textTheme) {
    return Column(
      children: [
        Text(
          widget.isReceiving ? "Ready to receive" : "Ready to send",
          style: textTheme.headlineMedium?.copyWith(fontSize: 32.sp),
        ),
        Gap(12.h),
        Text(
          widget.isReceiving ? "Nearby devices can see you as" : "Select a device nearby to share.",
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.normal,
          ),
        ),
        Gap(8.h),
        if (widget.isReceiving)
          Text(
            "HotDrop-Android",
            style: textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context, TextTheme textTheme) {
    return BlocBuilder<ConnectionCubit, ConnectionCubitState>(builder: (context, state) {
      final connectionCubit = context.read<ConnectionCubit>();
      final statusMsg = connectionCubit.statusMessage(isReceiving: widget.isReceiving);

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(32.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: connectionCubit.isConnectingState(state)
                        ? SizedBox(height: 20.sp, width: 20.sp, child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                        : Icon(Icons.wifi_tethering_rounded, color: AppColors.primary, size: 20.sp),
                  ),
                  Gap(16.w),
                  Expanded(
                    child: Text(
                      statusMsg,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 15.sp,
                      ),
                    ),
                  ),
                ],
              ),
              Gap(16.h),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Visibility is limited to your local network.",
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                  if (!widget.isReceiving)
                    GestureDetector(
                      onTap: () => setState(() => _showScanner = true),
                      child: Text(
                        "Scan QR Instead",
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                ],
              )
            ],
          ),
        ),
      );
    });
  }

  Widget _buildScannerOverlay(BuildContext context, TextTheme textTheme) {
    return Positioned.fill(
      child: Container(
        color: AppColors.surface,
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: BackButton(
                color: AppColors.onSurface,
                onPressed: () => setState(() => _showScanner = false),
              ),
              title: Text("Scan QR Code", style: textTheme.titleMedium),
            ),
            Expanded(
              child: Container(
                margin: EdgeInsets.all(40.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32.r),
                  border: Border.all(color: AppColors.surfaceContainerHighest, width: 4.w),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28.r),
                  child: MobileScanner(
                    onDetect: (capture) {
                      final code = capture.barcodes.first.rawValue;
                      context.read<ConnectionCubit>().handleQrScan(code);
                    },
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
