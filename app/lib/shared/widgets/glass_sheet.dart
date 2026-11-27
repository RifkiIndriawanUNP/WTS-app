import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'glass_button.dart';
import 'glass_container.dart';

Color _sheetTint(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF13213F)
    : Colors.white;

/// Bottom sheet berlapis kaca.
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          0,
          12,
          12 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: GlassContainer(
          radius: 28,
          blur: 30,
          tint: _sheetTint(ctx),
          tintOpacity: 0.82,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Flexible(
                  child: Material(
                    type: MaterialType.transparency,
                    child: builder(ctx),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Memilih satu dari daftar. Mengembalikan:
/// - pilihan yang dipilih,
/// - '' (string kosong) jika "Kosongkan" ditekan (hanya bila [allowClear]),
/// - null jika sheet ditutup tanpa memilih.
Future<String?> showOptionPicker(
  BuildContext context, {
  required String title,
  required List<String> options,
  String? selected,
  bool allowClear = false,
}) {
  return showGlassSheet<String>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (allowClear && selected != null)
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(''),
                    child: const Text('Kosongkan'),
                  ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 12),
              itemCount: options.length,
              itemBuilder: (_, i) {
                final option = options[i];
                final isSelected = option == selected;
                return ListTile(
                  title: Text(
                    option,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.secondary,
                        )
                      : null,
                  onTap: () => Navigator.of(ctx).pop(option),
                );
              },
            ),
          ),
        ],
      );
    },
  );
}

/// Dialog pesan berlapis kaca dengan satu tombol.
Future<void> showGlassMessage(
  BuildContext context, {
  required String title,
  required String message,
  String buttonLabel = 'Mengerti',
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.30),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: GlassContainer(
          radius: 28,
          blur: 30,
          tint: _sheetTint(ctx),
          tintOpacity: 0.84,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              GlassButton(
                label: buttonLabel,
                height: 48,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Dialog konfirmasi dua tombol. Mengembalikan true bila dikonfirmasi.
Future<bool?> showGlassConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Ya',
  String cancelLabel = 'Batal',
  bool destructive = false,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.30),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: GlassContainer(
          radius: 28,
          blur: 30,
          tint: _sheetTint(ctx),
          tintOpacity: 0.84,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: cancelLabel,
                      variant: GlassButtonVariant.secondary,
                      height: 48,
                      onPressed: () => Navigator.of(ctx).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassButton(
                      label: confirmLabel,
                      variant: destructive
                          ? GlassButtonVariant.danger
                          : GlassButtonVariant.primary,
                      height: 48,
                      onPressed: () => Navigator.of(ctx).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
