import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Folder ikon SVG (isi folder wts_ikon dari Figma).
const kIconDir = 'assets/icons';

/// Ikon SVG dari aset. [name] = nama file tanpa `.svg`, mis. `bell-blue-20-2563eb`.
class NotifSvg extends StatelessWidget {
  const NotifSvg(this.name, {super.key, this.size, this.color});

  final String name;
  final double? size;

  /// Jika diisi, ikon diwarnai ulang (hanya untuk ikon garis satu warna).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      '$kIconDir/$name.svg',
      width: size,
      height: size,
      colorFilter:
          color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
      placeholderBuilder: (_) => SizedBox(width: size, height: size),
    );
  }
}

/// Warna khusus layar Notifikasi (mengikuti desain Figma).
class NotifColors {
  NotifColors._();

  static const navy = Color(0xFF111B45);
  static const body = Color(0xFF4B5563);
  static const hint = Color(0xFF9CA3AF);
  static const blue = Color(0xFF2358E6);
  static const blueSoft = Color(0xFFE3ECFC);
  static const divider = Color(0xFFEEF1F6);
  static const groupBg = Color(0xFFF3F6FB);
  static const pageBlue = Color(0xFFEFF3FD);
}

/// Pasangan warna latar + ikon untuk kotak ikon.
class NotifTone {
  const NotifTone(this.bg, this.fg);

  final Color bg;
  final Color fg;

  static const blue = NotifTone(Color(0xFFE6EDFB), Color(0xFF2F63E0));
  static const orange = NotifTone(Color(0xFFFEF1D6), Color(0xFFE8890C));
  static const purple = NotifTone(Color(0xFFF1E7FD), Color(0xFF9333EA));
  static const red = NotifTone(Color(0xFFFDE4E6), Color(0xFFEF4444));
  static const green = NotifTone(Color(0xFFDFF6E7), Color(0xFF16A34A));
  static const gray = NotifTone(Color(0xFFF1F3F7), Color(0xFF6B7280));
  static const yellow = NotifTone(Color(0xFFFEF6DC), Color(0xFFF59E0B));
}

/// Kotak ikon persegi membulat berwarna lembut.
class NotifIconTile extends StatelessWidget {
  const NotifIconTile({
    super.key,
    required this.svg,
    required this.tone,
    this.size = 48,
    this.radius = 14,
    this.iconSize = 24,
  });

  /// Nama file ikon (tanpa `.svg`) di folder [kIconDir].
  final String svg;
  final NotifTone tone;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: NotifSvg(svg, size: iconSize),
    );
  }
}
