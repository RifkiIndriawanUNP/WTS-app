import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'glass_container.dart';

/// primary = aksi utama, secondary = aksi pendukung, danger = aksi merusak.
enum GlassButtonVariant { primary, secondary, danger }

/// Tombol kaca lebar penuh. `onPressed == null` = nonaktif (abu-abu).
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = GlassButtonVariant.primary,
    this.icon,
    this.leading,
    this.loading = false,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final GlassButtonVariant variant;
  final IconData? icon;
  final Widget? leading;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final disabled = onPressed == null;

    Color? tint;
    double? tintOpacity;
    Color fg;
    if (variant != GlassButtonVariant.secondary) {
      if (disabled) {
        tint = AppColors.neutral;
        tintOpacity = 0.55;
        fg = Colors.white.withValues(alpha: 0.85);
      } else {
        tint = variant == GlassButtonVariant.danger
            ? AppColors.error
            : (dark ? AppColors.secondary : AppColors.navy);
        tintOpacity = 0.92;
        fg = Colors.white;
      }
    } else {
      fg = theme.colorScheme.onSurface.withValues(alpha: disabled ? 0.45 : 1);
    }

    final Widget content = loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 10),
              ] else if (icon != null) ...[
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      enabled: !disabled && !loading,
      label: label,
      child: GlassContainer(
        radius: 100,
        blur: 14,
        tint: tint,
        tintOpacity: tintOpacity,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: (disabled || loading) ? null : onPressed,
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
  }
}
