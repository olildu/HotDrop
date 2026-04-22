import 'dart:math' as math;
import 'package:flutter/material.dart';

class RadarPulsePainter extends CustomPainter {
  final double progress;
  final Color color;

  RadarPulsePainter({required this.progress, required this.color});

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
      final opacity = (1.0 - ringProgress).clamp(0.0, 1.0) * 0.3;

      paint.color = color.withOpacity(opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RadarPulsePainter oldDelegate) => oldDelegate.progress != progress;
}
