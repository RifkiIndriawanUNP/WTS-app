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

  List<AppNotification> _seed() {
    final now = DateTime.now();
    AppNotification n(
      String id,
      NotifType type,
      NotifCategory cat,
      String title,
      String body,
      Duration ago, {
      String? actor,
      String? route,
      bool read = false,
    }) {
      return AppNotification(
        id: id,
        type: type,
        category: cat,
        title: title,
        body: body,
        createdAt: now.subtract(ago),
        actorId: actor,
        route: route,
        isRead: read,
      );
    }

    return [
      n(
        'n1',
        NotifType.offer,
        NotifCategory.market,
        'Nadia Putri',
        'mengirim tawaran Rp160.000 untuk Kalkulator Casio fx-991ID Plus',
        const Duration(hours: 2),
        actor: 'u_nadia',
        route: '/chat/market/c1',
      ),
      n(
        'n2',
        NotifType.comment,
        NotifCategory.general,
        '@la_ode',
        'meninggalkan komentar di postinganmu',
        const Duration(hours: 2, minutes: 10),
        route: '/home/post/x1',
      ),
      n(
        'n3',
        NotifType.message,
        NotifCategory.general,
        'Rian Pratama',
        'Makasih rangkumannya, kak!',
        const Duration(hours: 5),
        actor: 'u_rian',
        route: '/chat/dm/d1',
      ),
      n(
        'n4',
        NotifType.status,
        NotifCategory.market,
        'Dimas Maulana',
        'menyetujui harga Rp130.000 untuk Paket ESP32 Starter Kit',
        const Duration(days: 1, hours: 2),
        actor: 'u_dimas',
        route: '/chat/market/c2',
        read: true,
      ),
      n(
        'n5',
        NotifType.mention,
        NotifCategory.mention,
        '@la_ode',
        'menyebutmu di sebuah komentar',
        const Duration(days: 2),
        route: '/home/post/x2',
      ),
      n(
        'n6',
        NotifType.reminder,
        NotifCategory.market,
        'Pengingat masa tayang',
        'Produk "Almamater Nusa Putra Ukuran M" akan hilang 3 hari lagi. '
            'Perpanjang sekarang.',
        const Duration(days: 3),
        route: '/market/product/p8',
        read: true,
      ),
      n(
        'n7',
        NotifType.upvote,
        NotifCategory.general,
        'Postinganmu populer',
        'Postinganmu mencapai 10 upvote.',
        const Duration(days: 4),
        route: '/home/post/x3',
        read: true,
      ),
      n(
        'n8',
        NotifType.system,
        NotifCategory.general,
        'Selamat datang di WTS',
        'Baca aturan komunitas agar jual beli dan berbagi informasi tetap aman.',
        const Duration(days: 9),
        read: true,
      ),
    ];
  }
}
