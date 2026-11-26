import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wts/core/utils/format.dart';
import 'package:wts/core/utils/guard.dart';
import 'package:wts/features/notifications/domain/app_notification.dart';
import 'package:wts/features/notifications/presentation/notification_providers.dart';
import 'package:wts/features/notifications/presentation/notification_style.dart';
import 'package:wts/shared/widgets/common_widgets.dart';
import 'package:wts/shared/widgets/glass.dart';

/// Ganti sesuai lokasi aset maskot di proyekmu (harus didaftarkan di pubspec).
/// Jika file tidak ditemukan, otomatis tampil logo WTS sebagai pengganti.
const kNotifEmptyIllustration = 'assets/images/notif_empty.png';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  NotifTab _tab = NotifTab.all;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectTab(NotifTab t) {
    setState(() => _tab = t);
    _pageController.animateToPage(
      t.index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _open(AppNotification n) async {
    await ref.read(notificationRepositoryProvider).markRead(n.id);
    final route = n.route;
    if (route == null || !mounted) return;
    // Hanya rute milik fitur ini yang sudah ada; sisanya milik tim lain.
    if (route.startsWith('/chat') || route.startsWith('/market')) {
      context.push(route);
    } else {
      showSnack(context, 'Halaman tujuan belum tersedia (fitur tim lain).');
    }
  }

  Future<void> _act(AppNotification n, NotifAction a) async {
    switch (a) {
      case NotifAction.view:
        await _open(n);
      case NotifAction.approve:
        await ref.read(notificationRepositoryProvider).resolve(n.id);
        if (mounted) showSnack(context, 'Kesepakatan disetujui.');
      case NotifAction.depart:
        await ref.read(notificationRepositoryProvider).resolve(n.id);
        if (mounted) showSnack(context, 'Status: kamu sedang berangkat.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEEF4FF), Colors.white],
            stops: [0, .2],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(onSettings: () => context.push('/notifications/settings')),
              _TabBar(
                selected: _tab,
                onSelect: _selectTab,
                pageController: _pageController,
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (i) =>
                      setState(() => _tab = NotifTab.values[i]),
                  children: [
                    for (final tab in NotifTab.values) _pageFor(async, tab),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageFor(AsyncValue<List<AppNotification>> async, NotifTab tab) {
    return async.when(
      loading: () => ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        itemCount: 5,
        separatorBuilder: (context, i) => const SizedBox(height: 12),
        itemBuilder: (context, i) =>
            const SkeletonBox(height: 84, radius: 16),
      ),
      error: (e, _) => ErrorState(
        onRetry: () => ref.invalidate(notificationsProvider),
      ),
      data: (all) {
        final list = all.where(tab.matches).toList();
        if (list.isEmpty) return const _EmptyView();
        return ListView(
          padding: EdgeInsets.only(bottom: navSpace(context)),
          children: _grouped(list),
        );
      },
    );
  }

  List<Widget> _grouped(List<AppNotification> list) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final groups = <String, List<AppNotification>>{
      'Hari ini': [],
      'Kemarin': [],
      'Minggu ini': [],
      'Lebih lama': [],
    };
    for (final n in list) {
      if (sameDay(n.createdAt, now)) {
        groups['Hari ini']!.add(n);
      } else if (sameDay(n.createdAt, yesterday)) {
        groups['Kemarin']!.add(n);
      } else if (now.difference(n.createdAt).inDays < 7) {
        groups['Minggu ini']!.add(n);
      } else {
        groups['Lebih lama']!.add(n);
      }
    }
    final widgets = <Widget>[];
    groups.forEach((label, items) {
      if (items.isEmpty) return;
      widgets.add(_GroupLabel(label));
      for (final n in items) {
        widgets.add(
          _NotificationRow(
            notification: n,
            onTap: () => _open(n),
            onAction: (a) => _act(n, a),
          ),
        );
      }
    });
    return widgets;
  }
}

// ---------------------------------------------------------------- header --

class _Header extends StatelessWidget {
  const _Header({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 16, 14),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Notifikasi',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: NotifColors.navy,
                height: 1.2,
              ),
            ),
          ),
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 6,
            shadowColor: const Color(0x331F3FA0),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onSettings,
              child: const SizedBox(
                width: 52,
                height: 52,
                child: Icon(
                  Icons.settings_outlined,
                  size: 26,
                  color: NotifColors.navy,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ tabs --

class _TabBar extends ConsumerStatefulWidget {
  const _TabBar({
    required this.selected,
    required this.onSelect,
    required this.pageController,
  });

  final NotifTab selected;
  final ValueChanged<NotifTab> onSelect;
  final PageController pageController;

  @override
  ConsumerState<_TabBar> createState() => _TabBarState();
}

class _TabBarState extends ConsumerState<_TabBar> {
  final _stackKey = GlobalKey();
  final _keys = [for (final _ in NotifTab.values) GlobalKey()];
  List<Rect?> _rects = List.filled(NotifTab.values.length, null);

  /// Ukur posisi tiap tab supaya garis indikator bisa mengikuti geseran.
  void _measure() {
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || !stack.attached) return;
    final next = <Rect?>[];
    for (final k in _keys) {
      final box = k.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) {
        next.add(null);
        continue;
      }
      final origin = box.localToGlobal(Offset.zero, ancestor: stack);
      next.add(origin & box.size);
    }
    var changed = false;
    for (var i = 0; i < next.length; i++) {
      if (next[i] != _rects[i]) changed = true;
    }
    if (changed && mounted) setState(() => _rects = next);
  }

  Rect? _indicator(double page) {
    final lo = page.floor().clamp(0, _rects.length - 1);
    final hi = page.ceil().clamp(0, _rects.length - 1);
    final a = _rects[lo];
    final b = _rects[hi];
    if (a == null || b == null) return null;
    return Rect.lerp(a, b, page - lo);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final counts = [
      for (final t in NotifTab.values) ref.watch(notifTabUnreadProvider(t)),
    ];

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: NotifColors.divider)),
      ),
      padding: const EdgeInsets.only(left: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Stack(
          key: _stackKey,
          children: [
            Row(
              children: [
                for (final t in NotifTab.values) ...[
                  _TabItem(
                    key: _keys[t.index],
                    label: t.label,
                    count: counts[t.index],
                    selected: t == widget.selected,
                    onTap: () => widget.onSelect(t),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: widget.pageController,
                  builder: (context, _) {
                    final c = widget.pageController;
                    final page = (c.hasClients &&
                            c.position.haveDimensions &&
                            c.page != null)
                        ? c.page!
                        : widget.selected.index.toDouble();
                    final r = _indicator(page);
                    if (r == null) return const SizedBox.shrink();
                    return Stack(
                      children: [
                        Positioned(
                          left: r.left,
                          width: r.width,
                          bottom: 0,
                          height: 2.5,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              color: NotifColors.blue,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const dur = Duration(milliseconds: 220);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: dur,
              curve: Curves.easeOut,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? NotifColors.navy : const Color(0xFF5B6478),
              ),
              child: Text(label),
            ),
            AnimatedSize(
              duration: dur,
              curve: Curves.easeOut,
              alignment: Alignment.centerLeft,
              child: count > 0
                  ? Padding(
                      padding: const EdgeInsets.only(left: 7),
                      child: AnimatedContainer(
                        duration: dur,
                        curve: Curves.easeOut,
                        constraints: const BoxConstraints(minWidth: 22),
                        height: 22,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? NotifColors.blue
                              : NotifColors.blueSoft,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: AnimatedDefaultTextStyle(
                          duration: dur,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : NotifColors.blue,
                          ),
                          child: Text('$count'),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ list --

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: NotifColors.groupBg,
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: NotifColors.body,
        ),
      ),
    );
  }
}

(IconData, NotifTone) _visual(NotifType t) {
  switch (t) {
    case NotifType.offer:
      return (Icons.shopping_bag_outlined, NotifTone.blue);
    case NotifType.reminder:
      return (Icons.schedule_outlined, NotifTone.orange);
    case NotifType.comment:
      return (Icons.textsms_outlined, NotifTone.purple);
    case NotifType.message:
      return (Icons.chat_bubble_outline_rounded, NotifTone.purple);
    case NotifType.mention:
      return (Icons.alternate_email_rounded, NotifTone.purple);
    case NotifType.upvote:
      return (Icons.favorite_border_rounded, NotifTone.red);
    case NotifType.status:
      return (Icons.local_shipping_outlined, NotifTone.green);
    case NotifType.system:
      return (Icons.call_outlined, NotifTone.green);
  }
}

String _stamp(DateTime t) {
  final now = DateTime.now();
  String dotted(DateTime x) => clock(x).replaceAll(':', '.');
  if (sameDay(t, now)) {
    final m = now.difference(t).inMinutes;
    if (m < 1) return 'Baru saja';
    if (m < 60) return '$m menit lalu';
    return dotted(t);
  }
  if (sameDay(t, now.subtract(const Duration(days: 1)))) {
    return 'Kemarin, ${dotted(t)}';
  }
  return dateShort(t);
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.onTap,
    required this.onAction,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final ValueChanged<NotifAction> onAction;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final (icon, tone) = _visual(n.type);
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: NotifColors.divider)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 22, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NotifIconTile(icon: icon, tone: tone),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: NotifColors.navy,
                              height: 1.25,
                            ),
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            margin: const EdgeInsets.only(left: 8, top: 5),
                            width: 11,
                            height: 11,
                            decoration: const BoxDecoration(
                              color: NotifColors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (n.tag != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDEBC0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          n.tag!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      n.body,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: NotifColors.body,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _stamp(n.createdAt),
                      style: const TextStyle(
                        fontSize: 13,
                        color: NotifColors.hint,
                      ),
                    ),
                    if (n.actions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          for (final a in n.actions) ...[
                            _ActionButton(
                              action: a,
                              onTap: () => onAction(a),
                            ),
                            const SizedBox(width: 10),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.onTap});

  final NotifAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final filled = action != NotifAction.view;
    final label = switch (action) {
      NotifAction.approve => 'Setujui',
      NotifAction.view => 'Lihat',
      NotifAction.depart => 'Berangkat',
    };
    const text = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);
    const pad = EdgeInsets.symmetric(horizontal: 24);
    return SizedBox(
      height: 40,
      child: filled
          ? FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: NotifColors.blue,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: pad,
                textStyle: text,
              ),
              child: Text(label),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: NotifColors.blue,
                side: const BorderSide(color: Color(0xFFBBD0F6)),
                shape: const StadiumBorder(),
                padding: pad,
                textStyle: text,
              ),
              child: Text(label),
            ),
    );
  }
}

// ----------------------------------------------------------------- empty --

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(25, 0, 25, navSpace(context)),
      child: Column(
        children: [
          const SizedBox(height: 56),
          SizedBox(
            height: 150,
            child: Image.asset(
              kNotifEmptyIllustration,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Center(child: WtsLogoMark(size: 110)),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Belum ada notifikasi',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: NotifColors.navy,
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 34),
            child: Text(
              'Tawaran, pengingat jadwal COD, dan balasan di postinganmu '
              'akan muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.5,
                height: 1.5,
                color: NotifColors.body,
              ),
            ),
          ),
          const SizedBox(height: 30),
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4D2358E6),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: FilledButton(
              onPressed: () => context.go('/market'),
              style: FilledButton.styleFrom(
                backgroundColor: NotifColors.blue,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Jelajahi Market'),
            ),
          ),
        ],
      ),
    );
  }
}