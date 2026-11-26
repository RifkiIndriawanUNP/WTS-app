import 'package:flutter/material.dart';
import 'package:wts/features/market/domain/product.dart';

/// Warna & komponen kecil khusus tampilan Market (desain baru).
/// Ikon memakai Material Icons sebagai padanan terdekat ikon desain.
class MC {
  MC._();

  static const bg = Color(0xFFFCFCFA);
  static const coolTop = Color(0xFFF1F5FD);
  static const coolBottom = Color(0xFFEEF2FA);

  static const blue = Color(0xFF2563EB);
  static const blueSoft = Color(0xFFEEF3FF);
  static const blueInfo = Color(0xFFEEF4FF);
  static const iosBlue = Color(0xFF0088FF);
  static const gradA = Color(0xFF4876FD);
  static const gradB = Color(0xFF2541D1);

  static const ink = Color(0xFF0F172A);
  static const text = Color(0xFF1E293B);
  static const slate = Color(0xFF64748B);
  static const slateLight = Color(0xFF94A3B8);
  static const line = Color(0xFFE2E8F0);

  static const orange = Color(0xFFE0531C);
  static const orangeDeep = Color(0xFFC2410C);
  static const orangeIcon = Color(0xFFED7639);
  static const peach = Color(0xFFFDE1CD);
  static const peachCircle = Color(0xFFFEF6F0);
  static const peachButton = Color(0xFFFEF1E8);

  static const green = Color(0xFF047857);
  static const greenBg = Color(0xFFD7F5E9);
  static const red = Color(0xFFDC2626);

  static const kFont = 'PlusJakartaSans';
}

TextStyle mt({
  double size = 14,
  FontWeight weight = FontWeight.w500,
  Color color = MC.text,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: MC.kFont,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

List<BoxShadow> softShadow([double alpha = .08, double blur = 16]) => [
      BoxShadow(
        color: const Color(0xFF0F172A).withValues(alpha: alpha),
        blurRadius: blur,
        offset: const Offset(0, 4),
      ),
    ];

enum MarketBackdropStyle { warm, cool, plain }

/// Latar halaman Market. [warm] = cahaya oranye & biru (beranda Market),
/// [cool] = gradien biru muda (pencarian), [plain] = putih gading (form/list).
class MarketBackdrop extends StatelessWidget {
  const MarketBackdrop({
    super.key,
    required this.child,
    this.style = MarketBackdropStyle.plain,
  });

  final Widget child;
  final MarketBackdropStyle style;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case MarketBackdropStyle.cool:
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [MC.coolTop, MC.coolBottom],
            ),
          ),
          child: child,
        );
      case MarketBackdropStyle.warm:
      case MarketBackdropStyle.plain:
        return ColoredBox(color: MC.bg, child: child);
    }
  }
}

/// Cahaya oranye (kanan atas) + biru (kiri) di belakang header beranda Market.
class WarmGlow extends StatelessWidget {
  const WarmGlow({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: -70,
            right: -70,
            child: _glow(330, const Color(0xFFFEC79B), .95),
          ),
          Positioned(
            top: 70,
            left: -150,
            child: _glow(300, const Color(0xFFC9DCF5), .9),
          ),
        ],
      ),
    );
  }

  Widget _glow(double size, Color color, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: alpha * .45),
            color.withValues(alpha: 0),
          ],
          stops: const [0, .5, 1],
        ),
      ),
    );
  }
}

/// Tombol bulat putih (kembali, favorit, filter, dsb).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.iconSize = 22,
    this.color = MC.ink,
    this.background,
    this.shadow = true,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color color;
  final Color? background;
  final bool shadow;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background ?? Colors.white,
        boxShadow: shadow ? softShadow(.10, 14) : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(child: Icon(icon, size: iconSize, color: color)),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// Header form/list: tombol kembali bulat + judul (mis. "Posting Barang").
class MarketTitleBar extends StatelessWidget {
  const MarketTitleBar({super.key, required this.title, this.onBack, this.trailing});

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 20, 10),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            iconSize: 20,
            size: 46,
            onTap: onBack,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mt(size: 22, weight: FontWeight.w800, color: MC.ink),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Segmented control kapsul (aset "Segmented Control"): trek putih berbingkai,
/// segmen aktif biru.
class PillSegmented extends StatelessWidget {
  const PillSegmented({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.height = 46,
    this.selectedColor = MC.iosBlue,
    this.fontSize = 14,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final double height;
  final Color selectedColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: const Color(0xFFE5E9F0)),
        boxShadow: softShadow(.05, 10),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? selectedColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    style: mt(
                      size: fontSize,
                      weight: i == index ? FontWeight.w700 : FontWeight.w600,
                      color: i == index ? Colors.white : MC.ink,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tombol gradien biru (Lanjut, Posting barang, Chat Penjual, Kirim, Terapkan).
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 52,
    this.fontSize = 16,
    this.glow = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;
  final bool glow;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return Opacity(
      opacity: onTap == null ? .5 : 1,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          gradient: const LinearGradient(colors: [MC.gradA, MC.gradB]),
          boxShadow: glow
              ? [
                  BoxShadow(
                    color: MC.gradB.withValues(alpha: .35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(height / 2),
            onTap: enabled ? onTap : null,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: mt(
                        size: fontSize,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol putih berbingkai biru (Tawar, Batal, Atur Ulang).
class OutlineBlueButton extends StatelessWidget {
  const OutlineBlueButton({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 52,
    this.fontSize = 16,
    this.color = MC.blue,
  });

  final String label;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? .5 : 1,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: color, width: 1.2),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(height / 2),
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: mt(size: fontSize, weight: FontWeight.w700, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip pilihan putih berbingkai; aktif = latar biru muda + teks/tepi biru
/// ([filled] = isi biru penuh, dipakai di form Posting Barang).
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.filled = false,
    this.height = 40,
    this.horizontal = 20,
    this.fontSize = 14,
    this.shadow = false,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool filled;
  final double height;
  final double horizontal;
  final double fontSize;
  final bool shadow;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color border;
    if (selected && filled) {
      bg = MC.iosBlue;
      fg = Colors.white;
      border = MC.iosBlue;
    } else if (selected) {
      bg = MC.blueSoft;
      fg = MC.blue;
      border = MC.blue;
    } else {
      bg = Colors.white;
      fg = MC.ink;
      border = const Color(0xFFE2E8F0);
    }
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: height,
        padding: EdgeInsets.symmetric(horizontal: horizontal),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: border, width: selected && !filled ? 1.4 : 1),
          boxShadow: shadow ? softShadow(.05, 10) : null,
        ),
        // widthFactor: 1 -> lebar mengikuti isi (penting di dalam Wrap).
        child: Center(
          widthFactor: 1,
          child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: mt(
                size: fontSize,
                weight: selected ? FontWeight.w700 : FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

/// Warna per jenis penawaran (pil "Dijual"/"Sewa"/"Gratis" & harga).
class ListingStyle {
  const ListingStyle(this.bg, this.fg, this.price);
  final Color bg;
  final Color fg;
  final Color price;
}

ListingStyle listingStyleOf(ListingType t) {
  switch (t) {
    case ListingType.sell:
      return const ListingStyle(Color(0xFFFFE8DA), Color(0xFF9A3412), MC.orange);
    case ListingType.rent:
      return const ListingStyle(Color(0xFFFEF3C7), Color(0xFF92400E), MC.orange);
    case ListingType.free:
      return const ListingStyle(MC.greenBg, MC.green, MC.green);
  }
}

/// Pil jenis di kartu hasil pencarian.
class ListingPill extends StatelessWidget {
  const ListingPill({super.key, required this.type});

  final ListingType type;

  @override
  Widget build(BuildContext context) {
    final s = listingStyleOf(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type.tagLabel,
        style: mt(size: 13, weight: FontWeight.w600, color: s.fg),
      ),
    );
  }
}

/// Placeholder foto: latar peach + lingkaran krem berisi ikon gambar biru.
class PeachPlaceholder extends StatelessWidget {
  const PeachPlaceholder({
    super.key,
    this.circle = 64,
    this.iconSize = 28,
    this.color = MC.peach,
    this.circleColor = MC.peachCircle,
    this.iconColor = MC.blue,
  });

  final double circle;
  final double iconSize;
  final Color color;
  final Color circleColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Center(
        child: Container(
          width: circle,
          height: circle,
          decoration: BoxDecoration(shape: BoxShape.circle, color: circleColor),
          child: Icon(Icons.image_outlined, size: iconSize, color: iconColor),
        ),
      ),
    );
  }
}

/// Foto produk: foto unggahan -> URL -> placeholder peach.
class ProductMedia extends StatelessWidget {
  const ProductMedia({
    super.key,
    required this.product,
    this.index = 0,
    this.circle = 64,
    this.iconSize = 28,
  });

  final Product product;
  final int index;
  final double circle;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final placeholder = PeachPlaceholder(circle: circle, iconSize: iconSize);
    if (index < product.photoBytesList.length) {
      return Image.memory(
        product.photoBytesList[index],
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    if (index < product.imageUrls.length && product.imageUrls[index].isNotEmpty) {
      return Image.network(
        product.imageUrls[index],
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    return placeholder;
  }
}

/// Teks dengan kata kunci pencarian dicetak biru (judul pada hasil pencarian).
TextSpan highlightSpan(
  String text,
  String query, {
  required TextStyle base,
  Color highlight = MC.blue,
}) {
  final q = query.trim();
  if (q.isEmpty) return TextSpan(text: text, style: base);
  final lower = text.toLowerCase();
  final lq = q.toLowerCase();
  final spans = <TextSpan>[];
  var start = 0;
  while (true) {
    final i = lower.indexOf(lq, start);
    if (i < 0) break;
    if (i > start) spans.add(TextSpan(text: text.substring(start, i)));
    spans.add(
      TextSpan(
        text: text.substring(i, i + q.length),
        style: base.copyWith(color: highlight),
      ),
    );
    start = i + q.length;
  }
  if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
  return TextSpan(style: base, children: spans);
}