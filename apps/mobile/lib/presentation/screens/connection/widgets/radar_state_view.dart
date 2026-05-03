import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:test_mobile/logic/cubits/connection/connection_cubit.dart';
import 'package:test_mobile/presentation/theme/app_colors.dart';
import 'radar_pulse_painter.dart';

class RadarStateView extends StatefulWidget {
  final bool isReceiving;

  const RadarStateView({super.key, required this.isReceiving});

  @override
  State<RadarStateView> createState() => _RadarStateViewState();
}

class _RadarStateViewState extends State<RadarStateView>
    with SingleTickerProviderStateMixin {
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
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            children: [
              Gap(40.h),
              _buildRadar(context),
              Gap(20.h),
              _buildTypography(textTheme),
              Gap(40.h),
              _buildStatusCard(context, textTheme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRadar(BuildContext context) {
    return BlocBuilder<ConnectionCubit, ConnectionCubitState>(
        builder: (context, state) {
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
                  child: Icon(Icons.sensors_rounded,
                      color: AppColors.primary, size: 32.sp),
                ),
              ),
            if (!widget.isReceiving)
              ...state.discoveredDevices.asMap().entries.map((entry) =>
                  _buildOrbitalNode(context, entry.key, entry.value,
                      state.discoveredDevices.length)),
          ],
        ),
      );
    });
  }

  Widget _buildOrbitalNode(
      BuildContext context, int index, DiscoveredDevice device, int count) {
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
          widget.isReceiving
              ? "Nearby devices can see you as"
              : "Select a device nearby to share.",
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
    return BlocBuilder<ConnectionCubit, ConnectionCubitState>(
        builder: (context, state) {
      final connectionCubit = context.read<ConnectionCubit>();
      final statusMsg =
          connectionCubit.statusMessage(isReceiving: widget.isReceiving);

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
                        ? SizedBox(
                            height: 20.sp,
                            width: 20.sp,
                            child: const CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary))
                        : Icon(Icons.wifi_tethering_rounded,
                            color: AppColors.primary, size: 20.sp),
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
              if (widget.isReceiving && state.blePin != null) ...[
                Gap(20.h),
                Container(
                  width: double.infinity,
                  padding:
                      EdgeInsets.symmetric(vertical: 16.h, horizontal: 5.w),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(24.r),
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Gap(16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "SECURE PAIRING",
                              style: textTheme.labelSmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              "Enter this on the sender device",
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 10.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 14.w, vertical: 8.h),
                        margin: EdgeInsets.only(right: 5.w),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                              width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          state.blePin!,
                          style: GoogleFonts.firaMono(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors
                                .primary, // Make the text primary color for "glow" effect on dark
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: context.read<ConnectionCubit>(),
                              child: const QrScannerPage(),
                            ),
                          ),
                        );
                      },
                      child: Text(
                        "Scan QR Instead",
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (widget.isReceiving)
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: context.read<ConnectionCubit>(),
                            child: const QrDisplayPage(),
                          ),
                        ),
                      ),
                      child: Text(
                        "Show QR Code",
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }
}

class QrScannerPage extends StatelessWidget {
  const QrScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.onSurface),
        title: Text("Scan QR Code", style: textTheme.titleMedium),
      ),
      body: Container(
        margin: EdgeInsets.all(40.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32.r),
          border:
              Border.all(color: AppColors.surfaceContainerHighest, width: 4.w),
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
    );
  }
}

class QrDisplayPage extends StatelessWidget {
  const QrDisplayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.onSurface),
        title: Text("Share QR Code", style: textTheme.titleMedium),
      ),
      body: BlocBuilder<ConnectionCubit, ConnectionCubitState>(
        builder: (context, state) {
          final qrData = state.qrData;
          if (qrData == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hourglass_top_rounded,
                      size: 48.sp, color: AppColors.primary),
                  Gap(16.h),
                  Text(
                    "Generating QR Code...",
                    style: textTheme.titleMedium
                        ?.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                  Gap(8.h),
                  Text(
                    "The hotspot is still starting up.",
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 24.h),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(32.r),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: QrImageView(
                            data: qrData,
                            version: QrVersions.auto,
                            size: 240.w,
                            backgroundColor: Colors.white,
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
                        if (state.blePin != null) ...[
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                                vertical: 14.h, horizontal: 16.w),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                  color: AppColors.primary.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "SECURE PAIRING PIN",
                                      style: textTheme.labelSmall?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    Gap(2.h),
                                    Text(
                                      "Enter on the connecting device",
                                      style: textTheme.bodySmall?.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                        fontSize: 10.sp,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  state.blePin!,
                                  style: GoogleFonts.firaMono(
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    letterSpacing: 3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Gap(12.h),
                        ],
                        Text(
                          "Scan this code with any HotDrop device to connect instantly.",
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
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
