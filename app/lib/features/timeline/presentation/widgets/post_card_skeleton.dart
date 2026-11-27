import 'package:flutter/material.dart';

/// Kerangka kartu saat linimasa pertama kali dimuat (tanpa blur, ringan).
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;

    Widget bar(double? width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: base.withValues(alpha: 0.08),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(120, 12),
                  const SizedBox(height: 6),
                  bar(80, 10),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          bar(double.infinity, 14),
          const SizedBox(height: 8),
          bar(double.infinity, 12),
          const SizedBox(height: 8),
          bar(160, 12),
          const SizedBox(height: 16),
          bar(96, 32),
        ],
      ),
    );
  }
}
