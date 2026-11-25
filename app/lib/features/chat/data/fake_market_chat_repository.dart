import 'package:wts/core/supabase/failure.dart';
import 'package:wts/core/utils/fake_store.dart';
import 'package:wts/core/utils/format.dart';
import 'package:wts/features/chat/domain/chat_models.dart';
import 'package:wts/features/chat/domain/market_chat.dart';
import 'package:wts/features/chat/domain/market_chat_repository.dart';
import 'package:wts/features/market/domain/market_repository.dart';
import 'package:wts/features/market/domain/product.dart';
import 'package:wts/features/notifications/domain/app_notification.dart';
import 'package:wts/shared/models/app_user.dart';

typedef NotifyFn = void Function(
  NotifType type,
  NotifCategory category,
  String title,
  String body,
  String? actorId,
  String? route,
);

/// Aksi "lawan bicara" untuk simulasi di mode preview (menu titik tiga).
enum PeerAction {
  reply,
  sendOffer,
  acceptOffer,
  rejectOffer,
  counterOffer,
  depart,
  arrive,
  markSold,
}

/// Repository chat market palsu (memori). Aturan meniru backend:
/// satu tawaran aktif, hanya satu chat SEPAKAT per produk, terjual menutup
/// chat lain, retensi 3/7 hari, batas 30 pesan/menit, plus balasan otomatis.
class FakeMarketChatRepository implements MarketChatRepository {
  FakeMarketChatRepository({
    required MarketRepository market,
    String meId = kMeId,
    this.onNotify,
  })  : _market = market,
        _me = meId {
    _chats.addAll(_seed());
  }

  final MarketRepository _market;
  final String _me;
  final NotifyFn? onNotify;
  final List<MarketChat> _chats = [];
  final FakeStore _store = FakeStore();
  final RateLimiter _limit = RateLimiter(30, const Duration(minutes: 1));
  int _seq = 100;

  String _id(String prefix) => '$prefix${_seq++}';

  // ---------------------------------------------------------------- helpers

  MarketChat? _find(String id) {
    for (final c in _chats) {
      if (c.id == id) return c;
    }
    return null;
  }

  MarketChat _get(String id) {
    final c = _find(id);
    if (c == null) {
      throw const Failure('not_found', 'Chat tidak ditemukan.');
    }
    return c;
  }

  void _save(MarketChat c) {
    final i = _chats.indexWhere((x) => x.id == c.id);
    if (i >= 0) _chats[i] = c;
    _store.notify();
  }

  ChatMessage _msg(
    String? sender,
    MessageType type, {
    String? body,
    Map<String, Object?> meta = const {},
    bool read = false,
  }) {
    return ChatMessage(
      id: _id('m'),
      senderId: sender,
      type: type,
      body: body,
      meta: meta,
      createdAt: DateTime.now(),
      readByOther: read,
    );
  }

  ChatMessage _system(String text) =>
      _msg(null, MessageType.system, body: text);

  /// Tambah pesan ke chat. [by] = pelaku; jika bukan saya, kirim notifikasi.
  MarketChat _post(MarketChat c, ChatMessage m, {String? by}) {
    final fromPeer = by != null && by != _me;
    if (fromPeer) _emit(c, m, by);
    return c.copyWith(
      messages: [...c.messages, m],
      lastActivityAt: m.createdAt,
      unread: fromPeer ? c.unread + 1 : c.unread,
      deleteAt: c.status == MarketChatStatus.negotiating
          ? m.createdAt.add(const Duration(days: 3))
          : c.deleteAt,
    );
  }

  void _emit(MarketChat c, ChatMessage m, String by) {
    final notify = onNotify;
    if (notify == null) return;
    final productTitle = _market.findById(c.productId)?.title ?? 'produk';
    String body;
    NotifType type;
    switch (m.type) {
      case MessageType.offer:
        body = 'mengirim tawaran ${m.body} untuk $productTitle';
        type = NotifType.offer;
      case MessageType.system:
        body = m.body ?? '';
        type = NotifType.status;
      case MessageType.text:
        body = m.body ?? '';
        type = NotifType.message;
      default:
        body = 'mengirim ${m.preview}';
        type = NotifType.message;
    }
    notify(
      type,
      NotifCategory.market,
      userById(by).name,
      body,
      by,
      '/chat/market/${c.id}',
    );
  }

  void _guardWrite(MarketChat c) {
    if (c.isReadOnly) {
      throw const Failure('chat_closed', 'Chat ini sudah ditutup.');
    }
  }

  static const _invalid =
      Failure('invalid_state', 'Aksi tidak valid pada status saat ini.');

  String _autoPeerText(MarketChat c, String? sentBody) {
    final lower = (sentBody ?? '').toLowerCase();
    final point = _market.findById(c.productId)?.meetingPoint ?? 'titik temu';
    if (lower.contains('cod') ||
        lower.contains('ketemu') ||
        lower.contains('lokasi') ||
        lower.contains('di mana')) {
      return 'Oke, bisa COD di $point ya. Kabarin kalau sudah mau jalan.';
    }
    if (lower.contains('minus') ||
        lower.contains('kondisi') ||
        lower.contains('lecet') ||
        lower.contains('baterai')) {
      return 'Sesuai deskripsi ya kak, masih aman dipakai dan bisa dicek langsung pas COD.';
    }
    if (lower.contains('harga') || lower.contains('nett') || lower.contains('nego')) {
      return 'Boleh kak, silakan ajukan tawaran harga yang cocok.';
    }
    const replies = [
      'Oke kak, siap.',
      'Baik, noted ya kak!',
      'Sip, ditunggu infonya.',
      'Oke, boleh banget.',
    ];
    return replies[_seq % replies.length];
  }

  void _scheduleAutoReply(String chatId, String? sentBody) {
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      final current = _find(chatId);
      if (current == null || current.isReadOnly) return;
      final peer = current.otherId(_me);
      _save(
        _post(
          current,
          _msg(peer, MessageType.text, body: _autoPeerText(current, sentBody)),
          by: peer,
        ),
      );
    });
  }

  // ----------------------------------------------------------------- streams

  List<MarketChat> _visible() {
    final now = DateTime.now();
    final list = _chats
        .where((c) => c.deleteAt == null || c.deleteAt!.isAfter(now))
        .toList()
      ..sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
    return List.unmodifiable(list);
  }

  @override
  Stream<List<MarketChat>> watchChats() => _store.watch(
        _visible,
        initialDelay: const Duration(milliseconds: 400),
      );

  @override
  Stream<MarketChat?> watchChat(String id) => _store.watch<MarketChat?>(() {
        for (final c in _visible()) {
          if (c.id == id) return c;
        }
        return null;
      });

  // ------------------------------------------------------------- public API

  @override
  Future<String> openChat(String productId) async {
    final p = _market.findById(productId);
    if (p == null) {
      throw const Failure('not_found', 'Produk tidak ditemukan.');
    }
    if (p.sellerId == _me) {
      throw const Failure(
        'own_product',
        'Kamu tidak bisa chat produk sendiri.',
      );
    }
    if (p.status == ProductStatus.sold) {
      throw const Failure('product_unavailable', 'Produk tidak tersedia.');
    }
    for (final c in _chats) {
      if (c.productId == productId && c.buyerId == _me) return c.id;
    }
    final now = DateTime.now();
    final chat = MarketChat(
      id: _id('c'),
      productId: productId,
      buyerId: _me,
      sellerId: p.sellerId,
      status: MarketChatStatus.negotiating,
      lastActivityAt: now,
      messages: [_system('Chat dimulai. Kamu bisa menawar harga atau bertanya.')],
      offers: const [],
      deleteAt: now.add(const Duration(days: 3)),
    );
    _chats.add(chat);
    _store.notify();
    return chat.id;
  }

  @override
  Future<void> sendMessage(
    String chatId,
    MessageType type, {
    String? body,
    Map<String, Object?> meta = const {},
  }) async {
    final c = _get(chatId);
    _guardWrite(c);
    if (type == MessageType.offer || type == MessageType.system) {
      throw _invalid;
    }
    if (!_limit.tryHit()) {
      throw const Failure(
        'rate_limit_exceeded',
        'Terlalu sering. Coba lagi sebentar lagi.',
      );
    }
    final read = userById(c.otherId(_me)).online;
    _save(
      _post(
        c,
        _msg(_me, type, body: body, meta: meta, read: read),
        by: _me,
      ),
    );
    _scheduleAutoReply(chatId, body);
  }

  @override
  Future<void> deleteMessage(String chatId, String messageId) async {
    final c = _get(chatId);
    final m = c.messages.where((x) => x.id == messageId).firstOrNull;
    if (m == null) return;
    final age = DateTime.now().difference(m.createdAt);
    if (m.senderId != _me ||
        m.isSystem ||
        m.type == MessageType.offer ||
        age > const Duration(minutes: 15)) {
      throw const Failure(
        'forbidden',
        'Pesan hanya bisa dihapus dalam 15 menit oleh pengirim.',
      );
    }
    _save(
      c.copyWith(
        messages: c.messages.where((x) => x.id != messageId).toList(),
      ),
    );
  }

  @override
  Future<void> sendOffer(String chatId, int price) async =>
      _doSendOffer(chatId, _me, price);

  @override
  Future<void> respondOffer(
    String chatId,
    String offerId,
    OfferAction action, {
    int? counterPrice,
  }) async =>
      _doRespond(chatId, _me, offerId, action, counterPrice);

  @override
  Future<void> setProgress(String chatId, ChatProgress step) async =>
      _doProgress(chatId, _me, step);

  @override
  Future<void> markSold(String chatId) async => _doMarkSold(chatId, _me);

  @override
  Future<void> cancel(String chatId, String reason) async =>
      _doCancel(chatId, _me, reason);

  @override
  Future<void> rate(String chatId, int stars, String? comment) async {
    final c = _get(chatId);
    if (c.status != MarketChatStatus.sold || c.ratedByMe) throw _invalid;
    if (stars < 1 || stars > 5) {
      throw const Failure('invalid_rating', 'Nilai harus 1 sampai 5.');
    }
    _save(c.copyWith(ratedByMe: true));
  }

  @override
  Future<void> markRead(String chatId) async {
    final c = _get(chatId);
    if (c.unread == 0) return;
    _save(c.copyWith(unread: 0));
  }

  // ------------------------------------------------- aturan (sinkron, by = pelaku)

  void _doSendOffer(String chatId, String by, int price) {
    final c = _get(chatId);
    if (c.status != MarketChatStatus.negotiating) throw _invalid;
    final p = _market.findById(c.productId);
    if (p == null || p.status != ProductStatus.available) {
      throw const Failure('product_unavailable', 'Produk tidak tersedia.');
    }
    if (price <= 0 || price > 100000000) {
      throw const Failure('invalid_price', 'Harga tidak valid.');
    }
    if (c.pendingOffer != null) {
      throw const Failure(
        'invalid_state',
        'Masih ada tawaran yang menunggu respons.',
      );
    }
    if (by == _me && !_limit.tryHit()) {
      throw const Failure(
        'rate_limit_exceeded',
        'Terlalu sering. Coba lagi sebentar lagi.',
      );
    }
    final now = DateTime.now();
    final offer = Offer(
      id: _id('o'),
      fromUser: by,
      price: price,
      status: OfferStatus.pending,
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 24)),
    );
    final msg = _msg(
      by,
      MessageType.offer,
      body: formatRp(price),
      meta: {'offerId': offer.id},
    );
    _save(_post(c.copyWith(offers: [...c.offers, offer]), msg, by: by));
  }

  void _doRespond(
    String chatId,
    String by,
    String offerId,
    OfferAction action,
    int? counterPrice,
  ) {
    final c = _get(chatId);
    final o = c.offers.where((x) => x.id == offerId).firstOrNull;
    if (o == null) {
      throw const Failure('not_found', 'Tawaran tidak ditemukan.');
    }
    if (o.fromUser == by) {
      throw const Failure('forbidden', 'Kamu tidak punya akses.');
    }
    if (!o.isActivePending || c.status != MarketChatStatus.negotiating) {
      throw _invalid;
    }

    List<Offer> withStatus(OfferStatus s) =>
        c.offers.map((x) => x.id == offerId ? x.copyWith(status: s) : x).toList();

    switch (action) {
      case OfferAction.accept:
        final p = _market.findById(c.productId);
        if (p == null || p.status == ProductStatus.sold) {
          throw const Failure('product_unavailable', 'Produk tidak tersedia.');
        }
        if (p.status == ProductStatus.booked) {
          throw const Failure(
            'product_booked',
            'Produk sudah dipesan pembeli lain.',
          );
        }
        var next = c.copyWith(
          offers: withStatus(OfferStatus.accepted),
          status: MarketChatStatus.agreed,
          agreedPrice: o.price,
          deleteAt: null,
        );
        next = _post(
          next,
          _system('Harga disepakati ${formatRp(o.price)}'),
          by: by,
        );
        _save(next);
        _market.setStatus(c.productId, ProductStatus.booked);
      case OfferAction.reject:
        _save(
          _post(
            c.copyWith(offers: withStatus(OfferStatus.rejected)),
            _system('Tawaran ${formatRp(o.price)} ditolak'),
            by: by,
          ),
        );
      case OfferAction.counter:
        final price = counterPrice;
        if (price == null || price <= 0 || price > 100000000) {
          throw const Failure('invalid_price', 'Harga tidak valid.');
        }
        final now = DateTime.now();
        final counter = Offer(
          id: _id('o'),
          fromUser: by,
          price: price,
          status: OfferStatus.pending,
          createdAt: now,
          expiresAt: now.add(const Duration(hours: 24)),
        );
        final msg = _msg(
          by,
          MessageType.offer,
          body: formatRp(price),
          meta: {'offerId': counter.id},
        );
        _save(
          _post(
            c.copyWith(
              offers: [...withStatus(OfferStatus.countered), counter],
            ),
            msg,
            by: by,
          ),
        );
    }
  }

  void _doProgress(String chatId, String by, ChatProgress step) {
    final c = _get(chatId);
    final role = by == c.buyerId ? 'Pembeli' : 'Penjual';
    switch (step) {
      case ChatProgress.departed:
        if (c.status != MarketChatStatus.agreed) throw _invalid;
        _save(
          _post(
            c.copyWith(status: MarketChatStatus.onTheWay),
            _system('$role berangkat menuju titik temu'),
            by: by,
          ),
        );
      case ChatProgress.arrived:
        if (c.status != MarketChatStatus.agreed &&
            c.status != MarketChatStatus.onTheWay) {
          throw _invalid;
        }
        _save(
          _post(
            c.copyWith(status: MarketChatStatus.arrived),
            _system('$role sudah sampai di titik temu'),
            by: by,
          ),
        );
    }
  }

  void _doMarkSold(String chatId, String by) {
    final c = _get(chatId);
    if (by != c.sellerId) {
      throw const Failure(
        'forbidden',
        'Hanya penjual yang bisa menandai terjual.',
      );
    }
    if (!c.isActiveDeal) throw _invalid;
    final now = DateTime.now();
    final sold = _post(
      c.copyWith(
        status: MarketChatStatus.sold,
        soldAt: now,
        deleteAt: now.add(const Duration(days: 7)),
      ),
      _system(
        'Barang terjual seharga ${formatRp(c.agreedPrice ?? 0)}. Terima kasih!',
      ),
      by: by,
    );
    _save(sold);
    _market.setStatus(c.productId, ProductStatus.sold);

    // Pesan ke semua chat lain pada produk yang sama.
    final others = _chats
        .where(
          (x) =>
              x.productId == c.productId &&
              x.id != c.id &&
              x.status != MarketChatStatus.sold &&
              x.status != MarketChatStatus.cancelled &&
              x.status != MarketChatStatus.closed,
        )
        .map((x) => x.id)
        .toList();
    for (final id in others) {
      final o = _get(id);
      _save(
        _post(
          o.copyWith(
            status: MarketChatStatus.closed,
            deleteAt: now.add(const Duration(days: 3)),
          ),
          _system('Produk ini sudah terjual'),
          by: o.sellerId,
        ),
      );
    }
  }

  void _doCancel(String chatId, String by, String reason) {
    final c = _get(chatId);
    final cancellable = c.status == MarketChatStatus.negotiating || c.isActiveDeal;
    if (!cancellable) throw _invalid;
    final now = DateTime.now();
    final next = _post(
      c.copyWith(
        status: MarketChatStatus.cancelled,
        cancelledAt: now,
        deleteAt: now.add(const Duration(days: 3)),
        offers: c.offers
            .map(
              (o) => o.isActivePending
                  ? o.copyWith(status: OfferStatus.rejected)
                  : o,
            )
            .toList(),
      ),
      _system('Transaksi dibatalkan. Alasan: $reason'),
      by: by,
    );
    _save(next);
    if (c.isActiveDeal) {
      _market.setStatus(c.productId, ProductStatus.available);
    }
  }

  // ------------------------------------------------------ simulasi lawan bicara

  /// Membuat lawan bicara bertindak agar semua alur (terima/tolak tawaran,
  /// berangkat, sampai, terjual) bisa dicoba sendirian.
  Future<void> simulatePeer(String chatId, PeerAction action) async {
    final c = _get(chatId);
    final peer = c.otherId(_me);
    final product = _market.findById(c.productId);
    switch (action) {
      case PeerAction.reply:
        _guardWrite(c);
        _save(
          _post(
            c,
            _msg(peer, MessageType.text, body: 'Oke kak, siap.'),
            by: peer,
          ),
        );
      case PeerAction.sendOffer:
        final listPrice = product?.price ?? 100000;
        _doSendOffer(chatId, peer, (listPrice * 0.9 / 1000).round() * 1000);
      case PeerAction.acceptOffer:
        _doRespond(chatId, peer, _myPending(c).id, OfferAction.accept, null);
      case PeerAction.rejectOffer:
        _doRespond(chatId, peer, _myPending(c).id, OfferAction.reject, null);
      case PeerAction.counterOffer:
        final o = _myPending(c);
        final base = product?.price ?? o.price;
        final mid = ((o.price + base) / 2 / 1000).round() * 1000;
        _doRespond(chatId, peer, o.id, OfferAction.counter, mid);
      case PeerAction.depart:
        _doProgress(chatId, peer, ChatProgress.departed);
      case PeerAction.arrive:
        _doProgress(chatId, peer, ChatProgress.arrived);
      case PeerAction.markSold:
        _doMarkSold(chatId, peer);
    }
  }

  Offer _myPending(MarketChat c) {
    final o = c.pendingOffer;
    if (o == null || o.fromUser != _me) {
      throw const Failure(
        'invalid_state',
        'Tidak ada tawaranmu yang sedang menunggu.',
      );
    }
    return o;
  }

  // -------------------------------------------------------------------- seed

  List<MarketChat> _seed() {
    final now = DateTime.now();
    DateTime ago(Duration d) => now.subtract(d);
    ChatMessage m(
      String id,
      String? sender,
      MessageType type,
      Duration age, {
      String? body,
      Map<String, Object?> meta = const {},
      bool read = true,
    }) {
      return ChatMessage(
        id: id,
        senderId: sender,
        type: type,
        body: body,
        meta: meta,
        createdAt: ago(age),
        readByOther: read,
      );
    }

    final c1 = MarketChat(
      id: 'c1',
      productId: 'p4',
      buyerId: 'u_nadia',
      sellerId: _me,
      status: MarketChatStatus.negotiating,
      lastActivityAt: ago(const Duration(hours: 2)),
      deleteAt: now.add(const Duration(days: 3)),
      unread: 1,
      messages: [
        m('s1', null, MessageType.system, const Duration(hours: 3),
            body: 'Chat dimulai. Kamu bisa menawar harga atau bertanya.'),
        m('s2', 'u_nadia', MessageType.text, const Duration(hours: 2, minutes: 30),
            body: 'Halo kak, kalkulatornya masih ada?'),
        m('s3', _me, MessageType.text, const Duration(hours: 2, minutes: 20),
            body: 'Masih ada, kondisi mulus dan semua tombol normal.'),
        m('s4', 'u_nadia', MessageType.offer, const Duration(hours: 2),
            body: 'Rp160.000', meta: {'offerId': 'o1'}),
      ],
      offers: [
        Offer(
          id: 'o1',
          fromUser: 'u_nadia',
          price: 160000,
          status: OfferStatus.pending,
          createdAt: ago(const Duration(hours: 2)),
          expiresAt: now.add(const Duration(hours: 22)),
        ),
      ],
    );

    final c2 = MarketChat(
      id: 'c2',
      productId: 'p1',
      buyerId: _me,
      sellerId: 'u_dimas',
      status: MarketChatStatus.agreed,
      agreedPrice: 130000,
      lastActivityAt: ago(const Duration(days: 1)),
      messages: [
        m('t1', null, MessageType.system, const Duration(days: 1, hours: 3),
            body: 'Chat dimulai. Kamu bisa menawar harga atau bertanya.'),
        m('t2', _me, MessageType.text, const Duration(days: 1, hours: 2),
            body: 'Kak, boleh nego jadi 130 ribu?'),
        m('t3', _me, MessageType.offer, const Duration(days: 1, hours: 2),
            body: 'Rp130.000', meta: {'offerId': 'o2'}),
        m('t4', 'u_dimas', MessageType.text, const Duration(days: 1, hours: 1),
            body: 'Boleh, deal. COD di perpustakaan ya.'),
        m('t5', null, MessageType.system, const Duration(days: 1, hours: 1),
            body: 'Harga disepakati Rp130.000'),
      ],
      offers: [
        Offer(
          id: 'o2',
          fromUser: _me,
          price: 130000,
          status: OfferStatus.accepted,
          createdAt: ago(const Duration(days: 1, hours: 2)),
          expiresAt: now.subtract(const Duration(hours: 1)),
        ),
      ],
    );
    return [c1, c2];
  }
}