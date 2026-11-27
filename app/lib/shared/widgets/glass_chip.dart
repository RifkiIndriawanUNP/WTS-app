import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'glass_container.dart';

/// Chip kaca yang bisa dipilih (angkatan, tag, filter).
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final fg = selected ? Colors.white : theme.colorScheme.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GlassContainer(
        radius: 100,
        blur: 12,
        shadow: false,
        tint: selected ? (dark ? AppColors.secondary : AppColors.navy) : null,
        tintOpacity: 0.92,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: fg),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
