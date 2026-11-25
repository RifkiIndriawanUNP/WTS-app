import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wts/core/theme/app_theme.dart';
import 'package:wts/core/utils/format.dart';
import 'package:wts/core/utils/guard.dart';
import 'package:wts/features/notifications/domain/app_notification.dart';
import 'package:wts/features/notifications/presentation/notification_providers.dart';
import 'package:wts/shared/models/app_user.dart';
import 'package:wts/shared/widgets/common_widgets.dart';
import 'package:wts/shared/widgets/glass.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  NotifCategory? _filter; // null = Semua

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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return GlassScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            GlassHeader(
              title: 'Notifikasi',
              subtitle: unread > 0 ? '$unread belum dibaca' : null,
              actions: [
                GlassIconButton(
                  icon: Icons.done_all_rounded,
                  tooltip: 'Tandai semua dibaca',
                  onTap: unread == 0
                      ? null
                      : () => ref
                          .read(notificationRepositoryProvider)
                          .markAllRead(),
                ),
              ],
            ),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  GlassChip(
                    label: 'Semua',
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  const SizedBox(width: 8),
                  GlassChip(
                    label: 'Mention',
                    selected: _filter == NotifCategory.mention,
                    onTap: () =>
                        setState(() => _filter = NotifCategory.mention),
                  ),
                  const SizedBox(width: 8),
                  GlassChip(
                    label: 'Market',
                    selected: _filter == NotifCategory.market,
                    onTap: () => setState(() => _filter = NotifCategory.market),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: async.when(
                loading: () => ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: 6,
                  separatorBuilder: (context, i) => const SizedBox(height: 10),
                  itemBuilder: (context, i) =>
                      const SkeletonBox(height: 72, radius: 20),
                ),
                error: (e, _) => ErrorState(
                  onRetry: () => ref.invalidate(notificationsProvider),
                ),
                data: (all) {
                  final list = all
                      .where((n) => _filter == null || n.category == _filter)
                      .toList();
                  if (list.isEmpty) {
                    return const EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'Belum ada notifikasi',
                      message: 'Notifikasi disimpan selama 30 hari.',
                    );
                  }
                  return ListView(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, navSpace(context)),
                    children: _grouped(list),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _grouped(List<AppNotification> list) {
    final now = DateTime.now();
    final groups = <String, List<AppNotification>>{
      'Hari ini': [],
      'Minggu ini': [],
      'Lebih lama': [],
    };
    for (final n in list) {
      if (sameDay(n.createdAt, now)) {
        groups['Hari ini']!.add(n);
      } else if (now.difference(n.createdAt).inDays < 7) {
        groups['Minggu ini']!.add(n);
      } else {
        groups['Lebih lama']!.add(n);
      }
    }
    final widgets = <Widget>[];
    groups.forEach((label, items) {
      if (items.isEmpty) return;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.muted,
            ),
          ),
        ),
      );
      for (final n in items) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _NotificationTile(notification: n, onTap: () => _open(n)),
          ),
        );
      }
    });
    return widgets;
  }
}

IconData _iconFor(NotifType t) {
  switch (t) {
    case NotifType.comment:
      return Icons.mode_comment_outlined;
    case NotifType.upvote:
      return Icons.arrow_upward_rounded;
    case NotifType.mention:
      return Icons.alternate_email_rounded;
    case NotifType.message:
      return Icons.chat_bubble_outline_rounded;
    case NotifType.offer:
      return Icons.local_offer_outlined;
    case NotifType.status:
      return Icons.local_shipping_outlined;
    case NotifType.reminder:
      return Icons.timer_outlined;
    case NotifType.system:
      return Icons.campaign_outlined;
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final actor = n.actorId == null ? null : userById(n.actorId!);
    return GlassCard(
      blur: 0,
      radius: 20,
      opacity: n.isRead ? .55 : .85,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (actor != null)
            UserAvatar(user: actor, size: 44)
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconFor(n.type), color: AppColors.primary),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${n.title} ',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: n.body),
                    ],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 13.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeAgo(n.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (!n.isRead)
            Container(
              margin: const EdgeInsets.only(left: 8, top: 6),
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
