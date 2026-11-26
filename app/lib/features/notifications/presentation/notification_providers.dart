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

/// Tab filter di layar Notifikasi.
enum NotifTab {
  all('Semua'),
  transaction('Transaksi'),
  post('Postingan');

  const NotifTab(this.label);
  final String label;

  bool matches(AppNotification n) {
    switch (this) {
      case NotifTab.all:
        return true;
      case NotifTab.transaction:
        return n.category == NotifCategory.market ||
            n.type == NotifType.offer ||
            n.type == NotifType.status ||
            n.type == NotifType.reminder;
      case NotifTab.post:
        return n.type == NotifType.comment ||
            n.type == NotifType.upvote ||
            n.type == NotifType.mention;
    }
  }
}

/// Jumlah belum dibaca per tab (angka di samping label tab).
final notifTabUnreadProvider = Provider.family<int, NotifTab>((ref, tab) {
  final list = ref.watch(notificationsProvider).value ?? const [];
  return list.where((n) => !n.isRead && tab.matches(n)).length;
});

/// Pengaturan notifikasi.
enum NotifSetting {
  allow,
  badge,
  sound,
  offers,
  codReminder,
  txStatus,
  newMessage,
  lockPreview,
  comments,
  campus,
}

class NotificationSettingsNotifier extends Notifier<Map<NotifSetting, bool>> {
  @override
  Map<NotifSetting, bool> build() => {
        for (final s in NotifSetting.values) s: true,
        NotifSetting.lockPreview: false,
      };

  void set(NotifSetting key, bool value) {
    state = {...state, key: value};
  }
}

/// Sementara disimpan di memori. Nanti: tabel `notification_settings`.
final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, Map<NotifSetting, bool>>(
  NotificationSettingsNotifier.new,
);
