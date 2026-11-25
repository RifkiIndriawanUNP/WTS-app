import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wts/features/notifications/data/fake_notification_repository.dart';
import 'package:wts/features/notifications/domain/app_notification.dart';

/// Sementara memakai repository palsu. Nanti: tabel `notifications` + Realtime.
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => FakeNotificationRepository(),
);

final notificationsProvider = StreamProvider<List<AppNotification>>(
  (ref) => ref.watch(notificationRepositoryProvider).watch(),
);

/// Jumlah notifikasi belum dibaca (badge tab Notif).
final unreadNotificationCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider).value ?? const [];
  return list.where((n) => !n.isRead).length;
});
