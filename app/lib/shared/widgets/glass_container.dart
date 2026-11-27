import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Permukaan kaca (liquid glass): blur latar + isian gradien tembus pandang
/// + tepi berkilau + bayangan lembut. Dasar semua kartu, tombol, dan input.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.radius = 24,
    this.blur = 18,
    this.tint,
    this.tintOpacity,
    this.borderColor,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final double blur;

  /// Warna isian. Null = kaca bening putih.
  final Color? tint;
  final double? tintOpacity;

  /// Warna tepi tunggal (mis. fokus/error). Null = tepi berkilau.
  final Color? borderColor;
  final bool shadow;

  static const double _edge = 1.2;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    final Color fillA;
    final Color fillB;
    if (tint != null) {
      final a = tintOpacity ?? 0.85;
      fillA = tint!.withValues(alpha: a);
      fillB = tint!.withValues(alpha: a * 0.72);
    } else {
      fillA = Colors.white.withValues(alpha: dark ? 0.16 : 0.66);
      fillB = Colors.white.withValues(alpha: dark ? 0.06 : 0.30);
    }

    final List<Color> edgeColors = borderColor != null
        ? [borderColor!, borderColor!]
        : [
            Colors.white.withValues(alpha: dark ? 0.42 : 0.95),
            Colors.white.withValues(alpha: dark ? 0.08 : 0.35),
            Colors.white.withValues(alpha: dark ? 0.22 : 0.60),
          ];

    final innerRadius = BorderRadius.circular(
      radius > _edge ? radius - _edge : 0,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: (dark ? Colors.black : AppColors.navy).withValues(
                    alpha: dark ? 0.25 : 0.08,
                  ),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: CustomPaint(
        foregroundPainter: _EdgePainter(
          radius: radius,
          width: borderColor != null ? 1.8 : _edge,
          colors: edgeColors,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: innerRadius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [fillA, fillB],
                ),
              ),
              child: padding == null
                  ? child
                  : Padding(padding: padding!, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  const _EdgePainter({
    required this.radius,
    required this.width,
    required this.colors,
  });

  final double radius;
  final double width;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      bounds.deflate(width / 2),
      Radius.circular(radius > width / 2 ? radius - width / 2 : 0),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(bounds);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) =>
      old.radius != radius ||
      old.width != width ||
      !listEquals(old.colors, colors);
}
