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

/// Kategori lama (dipakai repository chat). Filter tab di UI memakai
/// [NotifTab] (Semua / Transaksi / Postingan) di notification_providers.dart.
enum NotifCategory { general, mention, market }

/// Tombol aksi yang tampil di bawah kartu notifikasi.
enum NotifAction { approve, view, depart }

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
    this.tag,
    this.actions = const [],
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

  /// Label kecil di bawah judul, mis. "Perlu tindakan".
  final String? tag;

  /// Tombol aksi (Setujui / Lihat / Berangkat). Kosong = tidak ada tombol.
  final List<NotifAction> actions;

  AppNotification copyWith({bool? isRead, bool clearActions = false}) =>
      AppNotification(
        id: id,
        type: type,
        category: category,
        title: title,
        body: body,
        createdAt: createdAt,
        actorId: actorId,
        route: route,
        isRead: isRead ?? this.isRead,
        tag: clearActions ? null : tag,
        actions: clearActions ? const [] : actions,
      );
}

/// Kontrak notifikasi. Nanti: tabel `notifications` + Realtime + FCM.
abstract class NotificationRepository {
  Stream<List<AppNotification>> watch();

  Future<void> markRead(String id);

  Future<void> markAllRead();

  /// Dipanggil setelah tombol aksi ditekan: tandai dibaca dan hapus tombol.
  Future<void> resolve(String id);
}