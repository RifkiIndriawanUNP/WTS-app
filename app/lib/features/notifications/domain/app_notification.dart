enum NotifType {
  comment,
  upvote,
  mention,
  message,
  offer,
  status,
  reminder,
  system,
}

/// Segmen filter di layar Notifikasi: Semua / Mention / Market.
enum NotifCategory { general, mention, market }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.body,
    required this.createdAt,
    this.actorId,
    this.route,
    this.isRead = false,
  });

  final String id;
  final NotifType type;
  final NotifCategory category;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? actorId;

  /// Tujuan deep link, mis. `/chat/market/c1` atau `/market/product/p4`.
  final String? route;
  final bool isRead;

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        category: category,
        title: title,
        body: body,
        createdAt: createdAt,
        actorId: actorId,
        route: route,
        isRead: isRead ?? this.isRead,
      );
}

/// Kontrak notifikasi. Nanti: tabel `notifications` + Realtime + FCM.
abstract class NotificationRepository {
  Stream<List<AppNotification>> watch();

  Future<void> markRead(String id);

  Future<void> markAllRead();
}
