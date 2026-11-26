import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Folder ikon SVG (isi folder wts_ikon dari Figma).
const String kAppIconDir = 'assets/icons';

/// Satu ikon aplikasi: file SVG di [kAppIconDir], atau ikon Material
/// sebagai cadangan untuk bentuk yang belum ada di set ikon desain.
class WtsIcon {
  const WtsIcon(
    this.asset, {
    this.turns = 0,
    this.scale = 1,
    this.dx = 0,
    this.dy = 0,
  }) : material = null;

  /// Cadangan sementara. Ganti ke SVG begitu ikonnya tersedia di desain.
  const WtsIcon.material(IconData this.material)
      : asset = null,
        turns = 0,
        scale = 1,
        dx = 0,
        dy = 0;

  /// Nama file tanpa `.svg`, mis. `home-gray`.
  final String? asset;
  final IconData? material;

  /// Putaran searah jarum jam dalam kelipatan 90° (mis. titik tiga vertikal).
  final int turns;

  /// Penyesuaian optis. SVG digambar [scale] kali ukuran kotak agar sisi
  /// terpanjangnya setara ikon Material di ukuran yang sama, lalu digeser
  /// ([dx], [dy] = pecahan ukuran gambar) agar tepat di tengah kotak.
  final double scale;
  final double dx;
  final double dy;
}

/// Pengganti `Icon(...)`: parameternya sama (ikon, size, color), tapi
/// menggambar SVG. Warna diterapkan ke seluruh ikon (ikon garis satu warna).
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  /// Boleh null: ikon kosong digambar sebagai ruang kosong seukuran [size].
  final WtsIcon? icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24;
    final c = color ?? theme.color ?? const Color(0xFF111827);

    final icon = this.icon;
    if (icon == null) return SizedBox(width: s, height: s);

    final material = icon.material;
    if (material != null) {
      return Icon(material, size: s, color: c, semanticLabel: semanticLabel);
    }

    final box = s * icon.scale;
    Widget svg = SvgPicture.asset(
      '$kAppIconDir/${icon.asset}.svg',
      width: box,
      height: box,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
      placeholderBuilder: (_) => SizedBox(width: box, height: box),
    );
    if (icon.dx != 0 || icon.dy != 0) {
      svg = Transform.translate(
        offset: Offset(icon.dx * box, icon.dy * box),
        child: svg,
      );
    }
    if (icon.turns % 4 != 0) {
      svg = RotatedBox(quarterTurns: icon.turns, child: svg);
    }
    // Kotak tetap [s] x [s] supaya tata letak tidak berubah; gambar boleh
    // sedikit lebih besar/kecil di dalamnya.
    return SizedBox(
      width: s,
      height: s,
      child: OverflowBox(
        minWidth: 0,
        minHeight: 0,
        maxWidth: box,
        maxHeight: box,
        child: svg,
      ),
    );
  }
}

/// Daftar ikon yang dipakai di seluruh aplikasi.
/// Ganti file di sini kalau mau mengubah ikon di semua layar sekaligus.
class WtsIcons {
  WtsIcons._();

  // --- Navigasi & aksi umum ---
  static const home = WtsIcon('home-gray', scale: 0.84, dy: 0.021);
  static const store = WtsIcon('store-blue-24', scale: 0.86, dy: 0.021);
  static const chat = WtsIcon('message-circle-blue-24', scale: 0.86);
  static const bell = WtsIcon('bell-gray-20-64748b', scale: 0.9);
  static const user = WtsIcon('user-dark-25-334155', scale: 1.02, dy: -0.07);
  static const settings = WtsIcon('settings-black-24-sw2', scale: 0.86);
  static const search = WtsIcon('search-dark-24');
  static const filter = WtsIcon('funnel', scale: 0.82);
  static const plus = WtsIcon('plus-dark-24-334155-sw2_2', scale: 0.76);
  static const minus = WtsIcon('minus-dark-20-475569-sw2_08333', scale: 0.75);
  static const close = WtsIcon('x-black', scale: 0.58);
  static const check = WtsIcon('check-white-16-sw2', scale: 0.82);
  static const checkAll = WtsIcon('check-check-gray', scale: 0.89);
  static const chevronLeft = WtsIcon('chevron-left-black-24', scale: 0.85);
  static const chevronRight =
      WtsIcon('chevron-right-lightgray-20-94a3b8-sw1_83333', scale: 0.84);
  static const chevronDown = WtsIcon('chevron-down-black-24', scale: 0.85);
  static const chevronUp = WtsIcon('chevron-up-black-24', scale: 0.85);
  static const moreVert = WtsIcon('ellipsis-black-24', turns: 1, scale: 0.89);
  static const arrowUpLeft = WtsIcon('arrow-up-left');
  static const squareEdit = WtsIcon('square-pen', scale: 0.87, dx: -0.02, dy: 0.02);
  static const trash = WtsIcon('trash', scale: 0.82);
  static const reply = WtsIcon('reply-dark', scale: 0.9);
  static const send = WtsIcon('send-gray', scale: 0.84);

  // --- Konten ---
  static const bag = WtsIcon('shopping-bag-dark', scale: 0.8);
  static const heart = WtsIcon('heart-dark-16', scale: 0.8);
  static const heartFilled = WtsIcon('heart-filled', scale: 0.8);
  static const image = WtsIcon('image-blue-24-2563eb', scale: 0.91);
  static const camera = WtsIcon('camera-blue', scale: 0.83);
  static const pin = WtsIcon('map-pin-blue', scale: 0.94);
  static const tag = WtsIcon('tag-gray', scale: 0.82);
  static const clock = WtsIcon('clock-dark-24', scale: 0.9);
  static const calendar = WtsIcon('calendar', scale: 0.9);
  static const calendarDays = WtsIcon('calendar-days', scale: 0.9, dy: 0.021);
  static const calendarX = WtsIcon('calendar-x', scale: 0.9, dx: -0.021, dy: 0.021);
  static const lock = WtsIcon('lock-gray', scale: 0.9);
  static const info = WtsIcon('info-blue-20-2b5bf6', scale: 0.9);
  static const eye = WtsIcon('eye-indigo-20-4f46e5', scale: 0.94);
  static const verified = WtsIcon('badge-check');
  static const zap = WtsIcon('zap-amber-20-f59e0b-sw1_66667', scale: 0.87);
  static const chatUnread = WtsIcon('message-square-dot', scale: 0.86, dy: -0.021);
  static const circleCheck = WtsIcon('circle-check-green', scale: 0.97);
  static const circlePlus = WtsIcon('circle-plus-dark', scale: 0.9);
  static const circleX = WtsIcon('circle-x', scale: 0.99);
  static const package = WtsIcon('package', scale: 0.75);

  // --- Pengganti terdekat untuk kategori produk ---
  static const fileText = WtsIcon('file-text-brown', scale: 0.82);
  static const plug = WtsIcon('plug', scale: 0.9);
  static const gridDots = WtsIcon('grip-dots', scale: 0.88);

  // --- Belum ada di set ikon desain (cadangan Material) ---
  static const link = WtsIcon.material(Icons.link_rounded);
  static const phone = WtsIcon.material(Icons.phone_in_talk_outlined);
  static const star = WtsIcon.material(Icons.star_rounded);
  static const starBorder = WtsIcon.material(Icons.star_border_rounded);
  static const refresh = WtsIcon.material(Icons.refresh_rounded);
  static const wifiOff = WtsIcon.material(Icons.wifi_off_rounded);
  static const handshake = WtsIcon.material(Icons.handshake_outlined);
  static const calculator = WtsIcon.material(Icons.calculate_rounded);
  static const laptop = WtsIcon.material(Icons.laptop_mac_rounded);
  static const mouse = WtsIcon.material(Icons.mouse_rounded);
  static const videocam = WtsIcon.material(Icons.videocam_rounded);
  static const memory = WtsIcon.material(Icons.memory_rounded);
  static const clothes = WtsIcon.material(Icons.checkroom_rounded);
  static const science = WtsIcon.material(Icons.science_rounded);
  static const devices = WtsIcon.material(Icons.devices_other_rounded);
  static const draw = WtsIcon.material(Icons.draw_rounded);
  static const chair = WtsIcon.material(Icons.chair_alt_rounded);
}