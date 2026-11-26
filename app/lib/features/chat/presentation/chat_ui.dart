import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wts/core/utils/format.dart';
import 'package:wts/features/chat/domain/chat_models.dart';
import 'package:wts/shared/models/app_user.dart';
import 'package:wts/shared/widgets/common_widgets.dart';

/// Font desain chat (Plus Jakarta Sans). Daftarkan di pubspec bila tersedia;
/// bila tidak, Flutter otomatis memakai font bawaan.
const kChatFont = 'PlusJakartaSans';

/// Lokasi foto profil di folder aset: assets/images/avatars/<userId>.png
/// (bila tidak ada, otomatis jatuh ke avatar inisial).
String avatarAsset(String userId) => 'assets/images/avatars/$userId.png';

class ChatColors {
  ChatColors._();

  static const bg = Color(0xFFEEF1FA);
  static const blue = Color(0xFF2563EB);
  static const segBlue = Color(0xFF2554FF);
  static const mine = Color(0xFF2D62EA);
  static const ink = Color(0xFF141928);
  static const text2 = Color(0xFF4B5563);
  static const muted = Color(0xFF6B7385);
  static const hint = Color(0xFF8B93A7);
  static const line = Color(0xFFECEEF1);
  static const border = Color(0xFFD9DEEA);
  static const cardBorder = Color(0xFFE6EAF3);
  static const blueSoft = Color(0xFFEEF2FF);
  static const blueTint = Color(0xFFEFF6FF);
  static const amberBg = Color(0xFFFFF4DC);
  static const amberText = Color(0xFFB45309);
  static const amber = Color(0xFFF59E0B);
  static const orange = Color(0xFFE65100);
  static const green = Color(0xFF16A34A);
  static const greenBg = Color(0xFFDDF5E6);
  static const greenText = Color(0xFF0F7B45);
  static const online = Color(0xFF22C55E);
  static const activeGreen = Color(0xFF10B981);
  static const red = Color(0xFFE53935);
  static const redBg = Color(0xFFFDE8E8);
}

// ------------------------------------------------------------------ format

const _daysShort = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const _daysLong = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];
const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String _p2(int n) => n.toString().padLeft(2, '0');

/// 9:05 -> "09.05" (titik, sesuai desain).
String dotClock(DateTime t) => '${_p2(t.hour)}.${_p2(t.minute)}';

/// 185000 -> "Rp 185.000" (dengan spasi, sesuai desain kartu).
String chatRp(int v) => 'Rp ${formatThousands(v)}';

/// "Sel, 24 Nov"
String dayShort(DateTime t) =>
    '${_daysShort[t.weekday - 1]}, ${t.day} ${_monthsShort[t.month - 1]}';

/// "Selasa, 24 Nov"
String dayLong(DateTime t) =>
    '${_daysLong[t.weekday - 1]}, ${t.day} ${_monthsShort[t.month - 1]}';

/// "Sel 10.00"
String slotLabel(DateTime t) => '${_daysShort[t.weekday - 1]} ${dotClock(t)}';

/// "SEL" / "NOV" untuk blok tanggal.
String dayAbbr(DateTime t) => _daysShort[t.weekday - 1].toUpperCase();
String monthAbbr(DateTime t) => _monthsShort[t.month - 1].toUpperCase();

/// Waktu di daftar chat: Baru saja / 09.12 / Kemarin / 24 Nov.
String chatListTime(DateTime t) {
  final now = DateTime.now();
  final diff = now.difference(t);
  if (!diff.isNegative && diff.inMinutes < 1) return 'Baru saja';
  if (sameDay(t, now)) return dotClock(t);
  if (sameDay(t, now.subtract(const Duration(days: 1)))) return 'Kemarin';
  return '${t.day} ${_monthsShort[t.month - 1]}';
}

/// Selisih hari kalender: Hari ini / Besok / "2 hari lagi".
String daysUntilLabel(DateTime t) {
  final now = DateTime.now();
  final a = DateTime(now.year, now.month, now.day);
  final b = DateTime(t.year, t.month, t.day);
  final n = b.difference(a).inDays;
  if (n <= 0) return 'Hari ini';
  if (n == 1) return 'Besok';
  return '$n hari lagi';
}

String firstName(AppUser u) => u.name.trim().split(RegExp(r'\s+')).first;

// ------------------------------------------------------------------ theme

/// Menerapkan font chat ke seluruh turunan (Text maupun TextField).
class ChatThemed extends StatelessWidget {
  const ChatThemed({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: kChatFont),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: kChatFont),
        child: child,
      ),
    );
  }
}

/// Scaffold datar berlatar lavender (#EEF1FA) sesuai desain.
class ChatScaffold extends StatelessWidget {
  const ChatScaffold({
    super.key,
    required this.body,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget body;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return ChatThemed(
      child: Scaffold(
        backgroundColor: ChatColors.bg,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        body: body,
      ),
    );
  }
}

// ----------------------------------------------------------------- avatar

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.user,
    this.size = 48,
    this.showOnline = false,
  });

  final AppUser user;
  final double size;
  final bool showOnline;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: Image.asset(
              avatarAsset(user.id),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => UserAvatar(user: user, size: size),
            ),
          ),
          if (showOnline && user.online)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: size * .3,
                height: size * .3,
                decoration: BoxDecoration(
                  color: ChatColors.online,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- buttons

/// Lingkaran putih (tombol kembali, menu titik tiga, dsb).
class ChatCircle extends StatelessWidget {
  const ChatCircle({
    super.key,
    required this.icon,
    this.size = 48,
    this.iconSize = 24,
    this.color = ChatColors.ink,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFDDE3F3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x142563EB),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

class ChatCircleButton extends StatelessWidget {
  const ChatCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 48,
    this.iconSize = 24,
    this.color = ChatColors.ink,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ChatCircle(
        icon: icon,
        size: size,
        iconSize: iconSize,
        color: color,
      ),
    );
  }
}

/// Header ruang chat: [<] [avatar + nama + status] [⋮].
class ChatRoomHeader extends StatelessWidget {
  const ChatRoomHeader({
    super.key,
    required this.user,
    required this.subtitle,
    required this.onBack,
    required this.menu,
    this.subtitleColor = ChatColors.activeGreen,
  });

  final AppUser user;
  final String subtitle;
  final Color subtitleColor;
  final VoidCallback onBack;

  /// Biasanya PopupMenuButton dengan child [ChatCircle].
  final Widget menu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          ChatCircleButton(
            icon: Icons.chevron_left_rounded,
            iconSize: 30,
            onTap: onBack,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.only(left: 2, right: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFDDE3F3)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x142563EB),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ChatAvatar(user: user, size: 44),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: ChatColors.ink,
                            height: 1.15,
                          ),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: subtitleColor,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          menu,
        ],
      ),
    );
  }
}

/// Chip kecil berwarna (peran, status).
class ChatPill extends StatelessWidget {
  const ChatPill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
    this.fontSize = 12.5,
    this.radius = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final double fontSize;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 3, color: foreground),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pasangan warna (latar, teks) untuk [ChatTone].
({Color bg, Color fg}) toneColors(ChatTone tone) {
  switch (tone) {
    case ChatTone.info:
      return (bg: const Color(0xFFE8EEFF), fg: const Color(0xFF2F55D4));
    case ChatTone.warning:
      return (bg: const Color(0xFFFEF3C7), fg: const Color(0xFF92400E));
    case ChatTone.success:
      return (bg: ChatColors.greenBg, fg: ChatColors.greenText);
    case ChatTone.danger:
      return (bg: ChatColors.redBg, fg: const Color(0xFFD9382C));
    case ChatTone.muted:
      return (bg: const Color(0xFFEEF0F4), fg: ChatColors.muted);
  }
}

// ------------------------------------------------------------------ cards

BoxDecoration chatCardDecoration({
  double radius = 20,
  Color color = Colors.white,
  Color? border,
  bool shadow = true,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: border == null ? null : Border.all(color: border, width: 1.5),
    boxShadow: shadow
        ? const [
            BoxShadow(
              color: Color(0x0F1E3A8A),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ]
        : null,
  );
}

/// Tombol pil: [filled] biru, atau outline biru.
class ChatButton extends StatelessWidget {
  const ChatButton({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.icon,
    this.height = 48,
    this.radius,
    this.enabled = true,
    this.color = ChatColors.blue,
    this.disabledStyle = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final IconData? icon;
  final double height;

  /// null = pil penuh.
  final double? radius;
  final bool enabled;
  final Color color;

  /// Tampilan abu-abu (mis. "Dia tidak datang" belum aktif).
  final bool disabledStyle;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? height / 2;
    final Color bg;
    final Color fg;
    final Color? border;
    if (disabledStyle) {
      bg = const Color(0xFFE2E8F0);
      fg = const Color(0xFF8A94A8);
      border = null;
    } else if (filled) {
      bg = enabled ? color : color.withValues(alpha: .55);
      fg = Colors.white;
      border = null;
    } else {
      bg = Colors.white;
      fg = color;
      border = color;
    }
    return Opacity(
      opacity: !filled && !enabled && !disabledStyle ? .5 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r),
          side: border == null
              ? BorderSide.none
              : BorderSide(color: border, width: 1.6),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: fg),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: fg,
                        height: 1.2,
                      ),
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

// ------------------------------------------------------------------ sheet

/// Bingkai bottom sheet putih bersudut 28 + handle (sesuai desain sheet).
class ChatSheetFrame extends StatelessWidget {
  const ChatSheetFrame({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.showClose = true,
    this.padding = const EdgeInsets.fromLTRB(24, 12, 24, 20),
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final bool showClose;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return ChatThemed(
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * .94),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: padding.copyWith(
          bottom: padding.bottom + media.viewInsets.bottom + media.padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFC9D1E0),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (title != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title!,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: ChatColors.ink,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              fontSize: 15,
                              color: ChatColors.muted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (showClose) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEEF1F6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: ChatColors.muted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
            ],
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

Future<T?> showChatSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: builder,
  );
}

// ----------------------------------------------------------------- painter

/// Bingkai putus-putus berujung membulat (kartu tawaran lama).
class DashedRRectPainter extends CustomPainter {
  DashedRRectPainter({
    required this.color,
    required this.radius,
    this.dash = 7,
    this.gap = 5,
    this.strokeWidth = 1.6,
  });

  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(strokeWidth / 2);
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          paint,
        );
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}