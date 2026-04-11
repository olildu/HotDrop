import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:test_mobile/blocs/connection/connection_cubit.dart';
import 'package:test_mobile/core/theme/app_colors.dart';

// --- SHARED RADAR VIEW COMPONENT ---
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

            // --- 1. AirDrop-Style Circular Radar ---
            BlocBuilder<ConnectionCubit, ConnectionCubitState>(builder: (context, state) {
              return SizedBox(
                height: 320.h,
                width: 320.w, // Increased size to fit orbiting nodes
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Pulsing Rings
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return CustomPaint(
                          size: Size(300.w, 300.w),
                          painter: _RadarPulsePainter(
                            progress: _pulseController.value,
                            color: AppColors.primary,
                          ),
                        );
                      },
                    ),

                    // Central Compact Beacon
                    if (state.discoveredDevices.isEmpty)
                      Container(
                        width: 64.w,
                        height: 64.w,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.sensors_rounded, // Replaced arrow with compact beacon
                            color: AppColors.primary,
                            size: 32.sp,
                          ),
                        ),
                      ),

                    // Orbiting Discovered Devices
                    if (!widget.isReceiving)
                      ...state.discoveredDevices.asMap().entries.map((entry) {
                        final index = entry.key;
                        final device = entry.value;
                        final count = state.discoveredDevices.length;

                        // Orbit radius
                        final radius = 130.w;

                        // Calculate angle for arch distribution (top half)
                        double angle;
                        if (count == 1) {
                          angle = -math.pi / 2; // Top center
                        } else {
                          // Spread evenly from -150° to -30°
                          double startAngle = -math.pi + (math.pi / 6);
                          double endAngle = -(math.pi / 6);
                          angle = startAngle + (endAngle - startAngle) * (index / (count - 1));
                        }

                        // Trigonometry for X and Y position
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
                                    style: textTheme.labelSmall?.copyWith(
                                      color: AppColors.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              );
            }),

            Gap(20.h),

            // --- 2. Typography ---
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

            const Spacer(),

            // --- 3. Simplified Status Card ---
            BlocBuilder<ConnectionCubit, ConnectionCubitState>(builder: (context, state) {
              String statusMsg = widget.isReceiving ? "Waiting for connections..." : "Searching for receivers...";
              if (state.status == ConnectionStatus.connecting) statusMsg = "Connecting to peer...";

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
                            child: state.status == ConnectionStatus.connecting
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
            }),
          ],
        ),

        // --- 4. QR Scanner Overlay ---
        if (!widget.isReceiving && _showScanner)
          Positioned.fill(
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
                            if (code != null) {
                              context.read<ConnectionCubit>().joinSession(code);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// --- RECEIVE SCREEN ---
class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ConnectionCubit>().startHosting();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectionCubit, ConnectionCubitState>(
      listener: (context, state) {
        if (state.status == ConnectionStatus.connected) Navigator.pop(context);
        if (state.status == ConnectionStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.errorMessage ?? "Error")));
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: _buildAppBar(context),
        body: const RadarStateView(isReceiving: true),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: const BackButton(color: AppColors.onSurface),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bubble_chart, color: AppColors.primary, size: 28.sp),
          Gap(8.w),
          Text("HotDrop", style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 22.sp)),
        ],
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: 20.w),
          child: Icon(Icons.account_circle_outlined, color: AppColors.onSurface, size: 28.sp),
        ),
      ],
    );
  }
}

// --- SEND SCREEN ---
class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ConnectionCubit>().startScanning();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectionCubit, ConnectionCubitState>(
      listener: (context, state) {
        if (state.status == ConnectionStatus.connected) Navigator.pop(context);
        if (state.status == ConnectionStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.errorMessage ?? "Error")));
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: _buildAppBar(context),
        body: const RadarStateView(isReceiving: false),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: const BackButton(color: AppColors.onSurface),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bubble_chart, color: AppColors.primary, size: 28.sp),
          Gap(8.w),
          Text("HotDrop", style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 22.sp)),
        ],
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: 20.w),
          child: Icon(Icons.account_circle_outlined, color: AppColors.onSurface, size: 28.sp),
        ),
      ],
    );
  }
}

// --- RADAR PULSE PAINTER ---
class _RadarPulsePainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadarPulsePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + (i * 0.333)) % 1.0;
      final radius = maxRadius * math.sin(ringProgress * math.pi / 2);
      final opacity = (1.0 - ringProgress).clamp(0.0, 1.0) * 0.3; // Softer opacity for elegance

      paint.color = color.withOpacity(opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPulsePainter oldDelegate) => oldDelegate.progress != progress;
}
