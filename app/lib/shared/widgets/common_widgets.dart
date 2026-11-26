import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:wts/core/theme/app_theme.dart';
import 'package:wts/shared/models/app_user.dart';
import 'package:wts/shared/widgets/app_icons.dart';

const _tones = <List<Color>>[
  [Color(0xFF60A5FA), Color(0xFF2563EB)],
  [Color(0xFF34D399), Color(0xFF059669)],
  [Color(0xFFF472B6), Color(0xFFDB2777)],
  [Color(0xFFFBBF24), Color(0xFFD97706)],
  [Color(0xFFA78BFA), Color(0xFF7C3AED)],
  [Color(0xFF22D3EE), Color(0xFF0891B2)],
];

List<Color> toneFor(int seed) => _tones[seed.abs() % _tones.length];

int seedOf(String text) =>
    text.codeUnits.fold<int>(0, (sum, c) => sum + c);

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.user,
    this.size = 44,
    this.showOnline = false,
  });

  final AppUser user;
  final double size;
  final bool showOnline;

  @override
  Widget build(BuildContext context) {
    final tone = toneFor(seedOf(user.id));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: tone,
            ),
          ),
          child: Text(
            user.initials,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: size * .36,
            ),
          ),
        ),
        if (showOnline && user.online)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * .28,
              height: size * .28,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// Pengganti foto (belum ada image_picker / storage): gradien + ikon gambar.
class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({
    super.key,
    required this.seed,
    this.icon = WtsIcons.image,
    this.iconSize = 36,
  });

  final int seed;
  final WtsIcon icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final tone = toneFor(seed);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tone[0].withValues(alpha: .55),
            tone[1].withValues(alpha: .75),
          ],
        ),
      ),
      child: Center(
        child: AppIcon(
          icon,
          size: iconSize,
          color: Colors.white.withValues(alpha: .9),
        ),
      ),
    );
  }
}

/// Logo WTS digambar langsung dengan CustomPainter (tas belanja + huruf W)
/// sesuai desain pada Dokumentasi WTS, bukan foto tempel.
class WtsLogoMark extends StatelessWidget {
  const WtsLogoMark({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WtsLogoPainter(
          primary: AppColors.primary,
          accent: const Color(0xFF0F296B),
        ),
      ),
    );
  }
}

class _WtsLogoPainter extends CustomPainter {
  _WtsLogoPainter({required this.primary, required this.accent});

  final Color primary;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final handlePaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.085
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromLTWH(w * 0.31, h * 0.06, w * 0.38, h * 0.24),
      3.14,
      3.14,
      false,
      handlePaint,
    );

    final bagRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, h * 0.24, w * 0.76, h * 0.68),
      Radius.circular(w * 0.18),
    );

    final bagPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [primary, accent],
      ).createShader(bagRRect.outerRect);

    canvas.drawRRect(bagRRect, bagPaint);

    final wPath = Path()
      ..moveTo(w * 0.25, h * 0.43)
      ..lineTo(w * 0.35, h * 0.74)
      ..lineTo(w * 0.50, h * 0.54)
      ..lineTo(w * 0.65, h * 0.74)
      ..lineTo(w * 0.75, h * 0.43);

    final wPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(wPath, wPaint);
  }

  @override
  bool shouldRepaint(covariant _WtsLogoPainter oldDelegate) =>
      oldDelegate.primary != primary || oldDelegate.accent != accent;
}

/// Visual foto produk lokal (in-memory / tanpa package eksternal & tanpa folder baru)
/// dengan ilustrasi barang sesuai judul/kategori dan sudut pandang foto.
class ProductPhotoView extends StatelessWidget {
  const ProductPhotoView({
    super.key,
    required this.seed,
    this.category,
    this.title,
    this.angleIndex = 0,
    this.iconSize = 38,
  });

  final int seed;
  final String? category;
  final String? title;
  final int angleIndex;
  final double iconSize;

  WtsIcon _iconForProduct() {
    final t = (title ?? '').toLowerCase();
    if (t.contains('kalkulator')) return WtsIcons.calculator;
    if (t.contains('laptop') || t.contains('asus')) {
      return WtsIcons.laptop;
    }
    if (t.contains('mouse')) return WtsIcons.mouse;
    if (t.contains('proyektor')) return WtsIcons.videocam;
    if (t.contains('esp32') || t.contains('breadboard') || category == 'IoT') {
      return WtsIcons.memory;
    }
    if (t.contains('jas') || t.contains('almamater')) {
      return WtsIcons.clothes;
    }
    if (t.contains('buku') ||
        t.contains('modul') ||
        category == 'Buku/Modul') {
      return WtsIcons.fileText;
    }
    switch (category) {
      case 'Alat Praktikum':
        return WtsIcons.science;
      case 'Jas Lab':
      case 'Pakaian/Almamater':
        return WtsIcons.clothes;
      case 'Laptop & Aksesoris':
        return WtsIcons.laptop;
      case 'Elektronik':
        return WtsIcons.devices;
      case 'Alat Tulis/Gambar':
        return WtsIcons.draw;
      case 'Perlengkapan Kos':
        return WtsIcons.chair;
      default:
        return WtsIcons.package;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = toneFor(seed + angleIndex);
    const angles = [
      'Foto Utama',
      'Detail Kondisi',
      'Kelengkapan',
      'Sisi Samping',
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tone[0].withValues(alpha: .82),
            tone[1].withValues(alpha: .95),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -14,
            bottom: -14,
            child: AppIcon(
              _iconForProduct(),
              size: iconSize * 2.1,
              color: Colors.white.withValues(alpha: .16),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .22),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .45),
                    ),
                  ),
                  child: AppIcon(
                    _iconForProduct(),
                    size: iconSize,
                    color: Colors.white,
                  ),
                ),
                if (iconSize >= 48) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      angles[angleIndex % angles.length],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Chip pilihan (filter, kategori, dsb).
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
  final WtsIcon? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : Colors.white.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : Colors.white.withValues(alpha: .9),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              AppIcon(
                icon,
                size: 16,
                color: selected ? Colors.white : AppColors.ink,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final WtsIcon icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, size: 56, color: AppColors.primary.withValues(alpha: .6)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.onRetry, this.message});

  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: WtsIcons.wifiOff,
      title: 'Gagal memuat data',
      message: message ?? 'Periksa koneksi internet lalu coba lagi.',
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const AppIcon(WtsIcons.refresh),
        label: const Text('Coba lagi'),
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.height, this.width, this.radius = 18});

  final double? height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFDCE4F5),
      highlightColor: const Color(0xFFF5F8FF),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

OutlineInputBorder _border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: color, width: 1.2),
    );

/// Gaya kolom isian bergaya kaca (dipakai di seluruh fitur).
InputDecoration glassInput({
  String? hint,
  String? label,
  WtsIcon? prefix,
  String? prefixText,
  Widget? suffix,
  String? errorText,
}) {
  return InputDecoration(
    hintText: hint,
    labelText: label,
    prefixIcon: prefix == null ? null : AppIcon(prefix, size: 20),
    prefixText: prefixText,
    suffixIcon: suffix,
    errorText: errorText,
    filled: true,
    fillColor: Colors.white.withValues(alpha: .72),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: _border(Colors.transparent),
    enabledBorder: _border(Colors.transparent),
    focusedBorder: _border(AppColors.primary),
    errorBorder: _border(AppColors.danger),
    focusedErrorBorder: _border(AppColors.danger),
  );
}

/// Kolom cari + tombol filter (dipakai Market dan Chat).
class GlassSearchField extends StatelessWidget {
  const GlassSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.onFilterTap,
    this.filterCount = 0,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onFilterTap;
  final int filterCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: glassInput(hint: hint, prefix: WtsIcons.search),
          ),
        ),
        if (onFilterTap != null) ...[
          const SizedBox(width: 10),
          Badge(
            isLabelVisible: filterCount > 0,
            label: Text('$filterCount'),
            child: Material(
              color: Colors.white.withValues(alpha: .72),
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onFilterTap,
                child: const SizedBox(
                  width: 50,
                  height: 50,
                  child: AppIcon(WtsIcons.filter, color: AppColors.ink),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}