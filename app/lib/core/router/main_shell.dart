import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wts/core/router/nav_collapse.dart';
import 'package:wts/features/chat/presentation/chat_list_providers.dart';
import 'package:wts/features/notifications/presentation/notification_providers.dart';
import 'package:wts/shared/widgets/glass.dart';

const _kNavBlue = Color(0xFF2563EB);
const _kNavIdle = Color(0xFF1F2937);
const _kNavSelectedBg = Color(0xFFE3EEFC);
const _kNavSelectedBorder = Color(0xFFC9DBF8);

/// Kerangka 5 tab dengan navigasi bawah kapsul melayang.
/// Saat [navCollapsedProvider] true, kapsul menyusut ke kiri menjadi
/// lingkaran yang hanya memperlihatkan ikon tab aktif.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatUnread = ref.watch(unreadChatCountProvider);
    final notifUnread = ref.watch(unreadNotificationCountProvider);
    final collapsed = ref.watch(navCollapsedProvider);
    final width = MediaQuery.sizeOf(context).width;
    final fullWidth = width - kNavSideGap * 2;
    final base = navBottomGap(context);

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Positioned.fill(child: navigationShell),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeInOutCubic,
              left: collapsed ? kNavCollapsedLeft : kNavSideGap,
              bottom: collapsed ? navCircleBottom(context) : base,
              width: collapsed ? kNavCircle : fullWidth,
              height: collapsed ? kNavCircle : kNavHeight,
              child: GlassNavBar(
                currentIndex: navigationShell.currentIndex,
                collapsed: collapsed,
                fullWidth: fullWidth,
                badges: {2: chatUnread, 3: notifUnread},
                onExpand: () =>
                    ref.read(navCollapsedProvider.notifier).set(false),
                onTap: (i) => navigationShell.goBranch(
                  i,
                  initialLocation: i == navigationShell.currentIndex,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GlassNavBar extends StatefulWidget {
  const GlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.fullWidth,
    this.collapsed = false,
    this.onExpand,
    this.badges = const {},
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final double fullWidth;
  final bool collapsed;
  final VoidCallback? onExpand;
  final Map<int, int> badges;

  // Ikon placeholder Material (padanan terdekat ikon desain).
  static const items = <({IconData icon, IconData active, String label})>[
    (icon: Icons.home_outlined, active: Icons.home_rounded, label: 'Home'),
    (
      icon: Icons.storefront_outlined,
      active: Icons.storefront_outlined,
      label: 'Market',
    ),
    (
      icon: Icons.chat_bubble_outline_rounded,
      active: Icons.chat_bubble_outline_rounded,
      label: 'Chat',
    ),
    (
      icon: Icons.notifications_none_rounded,
      active: Icons.notifications_none_rounded,
      label: 'Notif',
    ),
    (
      icon: Icons.person_outline_rounded,
      active: Icons.person_outline_rounded,
      label: 'Profil',
    ),
  ];

  @override
  State<GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends State<GlassNavBar> {
  /// true selama jari menekan bar -> seluruh bar sedikit membesar.
  bool _pressed = false;

  static const _pad = 5.0;

  @override
  void didUpdateWidget(covariant GlassNavBar old) {
    super.didUpdateWidget(old);
    if (widget.collapsed && _pressed) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = widget.collapsed;
    final radius = BorderRadius.circular(collapsed ? kNavCircle / 2 : kNavHeight / 2);
    final trackW = widget.fullWidth - _pad * 2;
    final trackH = kNavHeight - _pad * 2;

    return AnimatedScale(
      scale: _pressed ? 1.045 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E293B)
                  .withValues(alpha: _pressed ? .22 : .14),
              blurRadius: _pressed ? 30 : 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: collapsed
                    ? const Color(0xFFFEF1E8).withValues(alpha: .96)
                    : Colors.white.withValues(alpha: .92),
                borderRadius: radius,
                border: Border.all(
                  color: collapsed
                      ? Colors.white
                      : const Color(0xFFE5E7EB).withValues(alpha: .9),
                ),
              ),
              child: Stack(
                children: [
                  // Kapsul penuh (lebarnya tetap, dipotong saat menyusut).
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: widget.fullWidth,
                    child: IgnorePointer(
                      ignoring: collapsed,
                      child: AnimatedOpacity(
                        duration: Duration(milliseconds: collapsed ? 140 : 260),
                        curve: Curves.easeOut,
                        opacity: collapsed ? 0 : 1,
                        child: Padding(
                          padding: const EdgeInsets.all(_pad),
                          child: _NavTrack(
                            width: trackW,
                            height: trackH,
                            currentIndex: widget.currentIndex,
                            badges: widget.badges,
                            onTap: widget.onTap,
                            onPressedChanged: (v) {
                              if (_pressed != v) setState(() => _pressed = v);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Lingkaran: hanya ikon tab aktif.
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !collapsed,
                      child: AnimatedOpacity(
                        duration: Duration(milliseconds: collapsed ? 260 : 120),
                        curve: Curves.easeOut,
                        opacity: collapsed ? 1 : 0,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: widget.onExpand,
                          child: Center(
                            child: Badge(
                              isLabelVisible:
                                  (widget.badges[widget.currentIndex] ?? 0) > 0,
                              smallSize: 8,
                              child: Icon(
                                GlassNavBar.items[widget.currentIndex].active,
                                size: 26,
                                color: _kNavBlue,
                              ),
                            ),
                          ),
                        ),
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

/// Jalur 5 tab dengan indikator biru yang bisa ditahan & digeser.
///
/// - Jari menyentuh: bar membesar sedikit (lewat [onPressedChanged]) dan
///   indikator ikut membesar.
/// - Jari digeser: indikator mengikuti jari, ikon/label di bawahnya menyala,
///   getar ringan tiap pindah tab.
/// - Jari diangkat: indikator meluncur ke tab terdekat lalu tab dibuka.
class _NavTrack extends StatefulWidget {
  const _NavTrack({
    required this.width,
    required this.height,
    required this.currentIndex,
    required this.badges,
    required this.onTap,
    required this.onPressedChanged,
  });

  final double width;
  final double height;
  final int currentIndex;
  final Map<int, int> badges;
  final ValueChanged<int> onTap;
  final ValueChanged<bool> onPressedChanged;

  @override
  State<_NavTrack> createState() => _NavTrackState();
}

class _NavTrackState extends State<_NavTrack> {
  static const _n = 5;

  late int _visual = widget.currentIndex; // tab yang ditandai indikator
  int? _hover; // tab di bawah jari saat ditekan
  double? _dragX; // posisi jari bila sedang digeser
  double _startX = 0;
  bool _moved = false;

  double get _itemW => widget.width / _n;

  int _nearest(double dx) => (dx / _itemW).floor().clamp(0, _n - 1);

  @override
  void didUpdateWidget(covariant _NavTrack old) {
    super.didUpdateWidget(old);
    if (widget.currentIndex != old.currentIndex && _hover == null) {
      _visual = widget.currentIndex;
    }
  }

  void _down(PointerDownEvent e) {
    _startX = e.localPosition.dx;
    _moved = false;
    HapticFeedback.selectionClick();
    setState(() => _hover = _nearest(_startX));
    widget.onPressedChanged(true);
  }

  void _move(PointerMoveEvent e) {
    final dx = e.localPosition.dx;
    if (!_moved && (dx - _startX).abs() > 6) _moved = true;
    final h = _nearest(dx);
    if (h != _hover) HapticFeedback.selectionClick();
    setState(() {
      _hover = h;
      if (_moved) _dragX = dx;
    });
  }

  void _up(PointerUpEvent e) {
    final h = _nearest(e.localPosition.dx);
    setState(() {
      _visual = h;
      _hover = null;
      _dragX = null;
    });
    widget.onPressedChanged(false);
    widget.onTap(h);
  }

  void _cancel(PointerCancelEvent e) {
    setState(() {
      _hover = null;
      _dragX = null;
      _visual = widget.currentIndex;
    });
    widget.onPressedChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    final w = _itemW;
    final highlight = _hover ?? _visual;
    final pressed = _hover != null;
    final dragging = _dragX != null;
    final left = dragging
        ? (_dragX! - w / 2).clamp(0.0, widget.width - w)
        : _visual * w;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _cancel,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration:
                  dragging ? Duration.zero : const Duration(milliseconds: 380),
              curve: Curves.easeOutBack,
              left: left,
              top: 0,
              width: w,
              height: widget.height,
              child: AnimatedScale(
                scale: pressed ? 1.08 : 1,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Container(
                  decoration: BoxDecoration(
                    color: _kNavSelectedBg,
                    borderRadius: BorderRadius.circular(widget.height / 2),
                    border: Border.all(color: _kNavSelectedBorder),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < _n; i++)
                  SizedBox(
                    width: w,
                    height: widget.height,
                    child: _NavItem(
                      icon: i == highlight
                          ? GlassNavBar.items[i].active
                          : GlassNavBar.items[i].icon,
                      label: GlassNavBar.items[i].label,
                      selected: i == highlight,
                      badge: widget.badges[i] ?? 0,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.badge,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _kNavBlue : _kNavIdle;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Badge(
          isLabelVisible: badge > 0,
          smallSize: 8,
          alignment: AlignmentDirectional.topEnd,
          child: AnimatedScale(
            scale: selected ? 1.05 : 1,
            duration: const Duration(milliseconds: 180),
            child: Icon(icon, size: 25, color: color),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: selected
              ? Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                )
              : const SizedBox(width: 0, height: 0),
        ),
      ],
    );
  }
}