import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Latar "liquid": gradien lembut + gumpalan warna yang bergerak pelan.
/// Dipasang sekali di MaterialApp.builder, sehingga kaca (blur) pada semua
/// layar punya sesuatu yang bisa diburamkan.
class LiquidBackground extends StatefulWidget {
  const LiquidBackground({super.key, required this.child});

  final Widget child;

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [
                      Color(0xFF0B1224),
                      Color(0xFF0F1E3C),
                      Color(0xFF0B2A44),
                    ]
                  : const [
                      Color(0xFFCDE8FF),
                      Color(0xFFE3F3FF),
                      Color(0xFFD2ECFF),
                    ],
            ),
          ),
        ),
        RepaintBoundary(
          child: CustomPaint(
            painter: _BlobPainter(_controller, dark),
            size: Size.infinite,
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.progress, this.dark) : super(repaint: progress);

  final Animation<double> progress;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final v = progress.value * 2 * math.pi;
    final w = size.width;
    final h = size.height;

    void blob(Offset center, double radius, Color color) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final paint = Paint()
        ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
            .createShader(rect);
      canvas.drawCircle(center, radius, paint);
    }

    blob(
      Offset(w * (0.15 + 0.06 * math.sin(v)), h * (0.10 + 0.04 * math.cos(v))),
      w * 0.75,
      dark
          ? const Color(0xFF0EA5E9).withValues(alpha: 0.28)
          : const Color(0xFF38BDF8).withValues(alpha: 0.50),
    );
    blob(
      Offset(
        w * (0.92 + 0.05 * math.cos(v + 1)),
        h * (0.38 + 0.05 * math.sin(v + 2)),
      ),
      w * 0.65,
      dark
          ? const Color(0xFF2563EB).withValues(alpha: 0.26)
          : const Color(0xFF7DD3FC).withValues(alpha: 0.60),
    );
    blob(
      Offset(
        w * (0.22 + 0.06 * math.sin(v + 3)),
        h * (0.88 + 0.04 * math.cos(v + 1)),
      ),
      w * 0.80,
      dark
          ? const Color(0xFF0EA5E9).withValues(alpha: 0.20)
          : const Color(0xFFBAE6FD).withValues(alpha: 0.70),
    );
    blob(
      Offset(
        w * (0.72 + 0.04 * math.cos(v + 4)),
        h * (0.06 + 0.03 * math.sin(v)),
      ),
      w * 0.45,
      dark
          ? const Color(0xFF6366F1).withValues(alpha: 0.14)
          : Colors.white.withValues(alpha: 0.65),
    );
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) =>
      oldDelegate.dark != dark;
}
