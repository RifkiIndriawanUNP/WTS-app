import 'package:wts/core/utils/fake_store.dart';
import 'package:wts/features/notifications/domain/app_notification.dart';

class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository() {
    _items.addAll(_seed());
  }

  final List<AppNotification> _items = [];
  final FakeStore _store = FakeStore();
  int _seq = 100;

  List<AppNotification> _snapshot() {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final list = _items.where((n) => n.createdAt.isAfter(cutoff)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(list);
  }

  @override
  Stream<List<AppNotification>> watch() => _store.watch(
        _snapshot,
        initialDelay: const Duration(milliseconds: 400),
      );

  /// Dipanggil repository chat palsu saat "lawan bicara" bertindak.
  void add({
    required NotifType type,
    required NotifCategory category,
    required String title,
    required String body,
    String? actorId,
    String? route,
  }) {
    final isOffer = type == NotifType.offer;
    _items.add(
      AppNotification(
        id: 'n${_seq++}',
        type: type,
        category: category,
        title: title,
        body: body,
        createdAt: DateTime.now(),
        actorId: actorId,
        route: route,
        tag: isOffer ? 'Perlu tindakan' : null,
        actions: isOffer
            ? const [NotifAction.approve, NotifAction.view]
            : const [],
      ),
    );
    _store.notify();
  }

  @override
  Future<void> markRead(String id) async {
    final i = _items.indexWhere((n) => n.id == id);
    if (i < 0 || _items[i].isRead) return;
    _items[i] = _items[i].copyWith(isRead: true);
    _store.notify();
  }

  @override
  Future<void> markAllRead() async {
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(isRead: true);
    }
    _store.notify();
  }

  @override
  Future<void> resolve(String id) async {
    final i = _items.indexWhere((n) => n.id == id);
    if (i < 0) return;
    _items[i] = _items[i].copyWith(isRead: true, clearActions: true);
    _store.notify();
  }

  List<AppNotification> _seed() {
    final now = DateTime.now();
    AppNotification n(
      String id,
      NotifType type,
      NotifCategory cat,
      String title,
      String body,
      Duration ago, {
      String? route,
      bool read = false,
      String? tag,
      List<NotifAction> actions = const [],
    }) {
      return AppNotification(
        id: id,
        type: type,
        category: cat,
        title: title,
        body: body,
        createdAt: now.subtract(ago),
        route: route,
        isRead: read,
        tag: tag,
        actions: actions,
      );
    }

    return [
      n(
        'n1',
        NotifType.offer,
        NotifCategory.market,
        'Nadia mengubah kesepakatan',
        'Rp 160.000 · Sel, 24 Nov · 10.00 · Perpustakaan',
        const Duration(minutes: 2),
        route: '/chat/market/c1',
        tag: 'Perlu tindakan',
        actions: const [NotifAction.approve, NotifAction.view],
      ),
      n(
        'n2',
        NotifType.reminder,
        NotifCategory.market,
        'Ketemu Nadia 1 jam lagi',
        'Kalkulator Casio · Perpustakaan kampus. Tombol Berangkat sudah aktif.',
        const Duration(minutes: 40),
        route: '/chat/market/c1',
        actions: const [NotifAction.depart],
      ),
      n(
        'n3',
        NotifType.comment,
        NotifCategory.general,
        '5 komentar baru di postinganmu',
        'Rekomendasi materi & kisi-kisi UTS Kalkulus Lanjut Pak Bambang?',
        const Duration(minutes: 70),
        route: '/home/post/x1',
      ),
      n(
        'n4',
        NotifType.upvote,
        NotifCategory.general,
        'Paket ESP32 di-love 12 orang',
        'Barangmu mulai diminati. Cek penawaran yang masuk.',
        const Duration(days: 1, hours: 1),
        route: '/market/product/p1',
        read: true,
      ),
      n(
        'n5',
        NotifType.system,
        NotifCategory.general,
        'Nomor WhatsApp terverifikasi',
        'Kamu sekarang bisa memposting barang dan mengajukan kesepakatan.',
        const Duration(days: 1, hours: 2),
        read: true,
      ),
    ];
  }
}