import 'package:wts/core/supabase/failure.dart';
import 'package:wts/core/utils/fake_store.dart';
import 'package:wts/features/chat/domain/chat_models.dart';
import 'package:wts/features/chat/domain/dm.dart';
import 'package:wts/shared/models/app_user.dart';

/// DM palsu (memori). Aturan meniru backend: permintaan pesan, privasi DM,
/// blokir, batas 30 pesan/menit & 20 percakapan baru/hari, pesan > 3 hari
/// otomatis tidak tampil (retensi rolling), plus simulasi balasan otomatis.
class FakeDmRepository implements DmRepository {
  FakeDmRepository({String meId = kMeId}) : _me = meId {
    _items.addAll(_seed());
  }

  final String _me;
  final List<DmConversation> _items = [];
  final Set<String> _blocked = {};
  final FakeStore _store = FakeStore();
  final RateLimiter _msgLimit = RateLimiter(30, const Duration(minutes: 1));
  final RateLimiter _convLimit = RateLimiter(20, const Duration(days: 1));
  int _seq = 100;

  static const _retention = Duration(days: 3);

  DmConversation? _find(String id) {
    for (final c in _items) {
      if (c.id == id) return c;
    }
    return null;
  }

  DmConversation _get(String id) {
    final c = _find(id);
    if (c == null) {
      throw const Failure('not_found', 'Percakapan tidak ditemukan.');
    }
    return c;
  }

  void _save(DmConversation c) {
    final i = _items.indexWhere((x) => x.id == c.id);
    if (i >= 0) _items[i] = c;
    _store.notify();
  }

  /// Pesan > 3 hari disembunyikan (di backend dihapus job tiap jam).
  DmConversation _trimmed(DmConversation c) {
    final cutoff = DateTime.now().subtract(_retention);
    return c.copyWith(
      messages: c.messages.where((m) => m.createdAt.isAfter(cutoff)).toList(),
    );
  }

  List<DmConversation> _visible() {
    final list = _items.map(_trimmed).toList()
      ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return List.unmodifiable(list);
  }

  @override
  Stream<List<DmConversation>> watchConversations() => _store.watch(
        _visible,
        initialDelay: const Duration(milliseconds: 400),
      );

  @override
  Stream<DmConversation?> watchConversation(String id) =>
      _store.watch<DmConversation?>(() {
        for (final c in _visible()) {
          if (c.id == id) return c;
        }
        return null;
      });

  @override
  Future<String> startDm(String userId) async {
    final other = userById(userId);
    if (_blocked.contains(userId)) {
      throw const Failure('blocked', 'Tidak dapat melakukan aksi ini.');
    }
    if (!other.dmEnabled) {
      throw const Failure('dm_disabled', 'Pengguna ini menonaktifkan pesan.');
    }
    for (final c in _items) {
      if (c.otherId == userId) return c.id;
    }
    if (!_convLimit.tryHit()) {
      throw const Failure(
        'rate_limit_exceeded',
        'Batas 20 percakapan baru per hari tercapai.',
      );
    }
    final conv = DmConversation(
      id: 'd${_seq++}',
      otherId: userId,
      requesterId: _me,
      status: DmStatus.request,
      messages: const [],
      lastMessageAt: DateTime.now(),
    );
    _items.add(conv);
    _store.notify();
    return conv.id;
  }

  @override
  Future<void> accept(String id) async {
    final c = _get(id);
    if (c.status != DmStatus.request || c.requesterId == _me) {
      throw const Failure(
        'invalid_state',
        'Aksi tidak valid pada status saat ini.',
      );
    }
    _save(c.copyWith(status: DmStatus.accepted));
  }

  @override
  Future<void> ignore(String id) async {
    _items.removeWhere((c) => c.id == id);
    _store.notify();
  }

  @override
  Future<void> block(String id) async {
    final c = _get(id);
    _blocked.add(c.otherId);
    _items.removeWhere((x) => x.id == id);
    _store.notify();
  }

  String _autoReplyText(String? sentBody) {
    final text = (sentBody ?? '').toLowerCase();
    if (text.contains('cod') ||
        text.contains('ketemu') ||
        text.contains('dimana') ||
        text.contains('di mana')) {
      return 'Oke, aku bisa di perpustakaan atau lobby kampus. Kabarin aja ya!';
    }
    if (text.contains('harga') || text.contains('nego') || text.contains('tawar')) {
      return 'Boleh kok, coba aja ajukan penawarannya.';
    }
    if (text.contains('jam') || text.contains('kapan') || text.contains('besok')) {
      return 'Siap, nanti aku kabarin lagi pas waktunya dekat.';
    }
    const replies = [
      'Oke, siap! Terima kasih ya.',
      'Noted, aku cek dulu ya.',
      'Sip, masuk akal. Gimana kelanjutannya?',
      'Oke baik, kabarin kalau ada update.',
    ];
    return replies[_seq % replies.length];
  }

  void _scheduleAutoReply(String conversationId, String? sentBody) {
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      final current = _find(conversationId);
      if (current == null) return;
      _save(current.copyWith(peerTyping: true));
      Future<void>.delayed(const Duration(milliseconds: 1400), () {
        if (_find(conversationId) == null) return;
        simulateReply(conversationId, replyText: _autoReplyText(sentBody));
      });
    });
  }

  @override
  Future<void> send(
    String id,
    MessageType type, {
    String? body,
    Map<String, Object?> meta = const {},
  }) async {
    final c = _get(id);
    if (type == MessageType.offer || type == MessageType.system) {
      throw const Failure(
        'invalid_state',
        'Aksi tidak valid pada status saat ini.',
      );
    }
    if (c.status == DmStatus.request) {
      if (c.requesterId != _me) {
        throw const Failure(
          'invalid_state',
          'Terima permintaan pesan dulu untuk membalas.',
        );
      }
      if (c.messages.any((m) => m.senderId == _me)) {
        throw const Failure(
          'invalid_state',
          'Menunggu persetujuan penerima.',
        );
      }
    }
    if (!_msgLimit.tryHit()) {
      throw const Failure(
        'rate_limit_exceeded',
        'Terlalu sering. Coba lagi sebentar lagi.',
      );
    }
    final now = DateTime.now();
    final msg = ChatMessage(
      id: 'dm${_seq++}',
      senderId: _me,
      type: type,
      body: body,
      meta: meta,
      createdAt: now,
      readByOther: userById(c.otherId).online,
    );
    _save(c.copyWith(messages: [...c.messages, msg], lastMessageAt: now));
    _scheduleAutoReply(id, body);
  }

  @override
  Future<void> deleteMessage(String id, String messageId) async {
    final c = _get(id);
    final m = c.messages.where((x) => x.id == messageId).firstOrNull;
    if (m == null) return;
    if (m.senderId != _me ||
        DateTime.now().difference(m.createdAt) > const Duration(minutes: 15)) {
      throw const Failure(
        'forbidden',
        'Pesan hanya bisa dihapus dalam 15 menit oleh pengirim.',
      );
    }
    _save(
      c.copyWith(messages: c.messages.where((x) => x.id != messageId).toList()),
    );
  }

  @override
  Future<void> markRead(String id) async {
    final c = _get(id);
    if (c.unread == 0) return;
    _save(c.copyWith(unread: 0));
  }

  /// Lawan bicara membalas (menerima dulu bila perlu).
  Future<void> simulateReply(
    String id, {
    String replyText = 'Oke, siap! Terima kasih ya.',
  }) async {
    final existing = _find(id);
    if (existing == null) return;
    var c = existing;
    if (c.status == DmStatus.request && c.requesterId == _me) {
      c = c.copyWith(status: DmStatus.accepted);
    }
    final now = DateTime.now();
    final msg = ChatMessage(
      id: 'dm${_seq++}',
      senderId: c.otherId,
      type: MessageType.text,
      body: replyText,
      createdAt: now,
    );
    _save(
      c.copyWith(
        messages: [...c.messages, msg],
        lastMessageAt: now,
        unread: c.unread + 1,
        peerTyping: false,
      ),
    );
  }

  List<DmConversation> _seed() {
    final now = DateTime.now();
    ChatMessage m(
      String id,
      String sender,
      String text,
      Duration age, {
      bool read = true,
    }) {
      return ChatMessage(
        id: id,
        senderId: sender,
        type: MessageType.text,
        body: text,
        createdAt: now.subtract(age),
        readByOther: read,
      );
    }

    return [
      DmConversation(
        id: 'd1',
        otherId: 'u_rian',
        requesterId: _me,
        status: DmStatus.accepted,
        unread: 2,
        lastMessageAt: now.subtract(const Duration(hours: 5)),
        messages: [
          m('a1', _me, 'Kak, ini rangkuman materi kuis kemarin.',
              const Duration(days: 2)),
          m('a2', 'u_rian', 'Wah makasih banyak!', const Duration(hours: 6)),
          m('a3', 'u_rian', 'Makasih rangkumannya, kak!',
              const Duration(hours: 5)),
        ],
      ),
      DmConversation(
        id: 'd2',
        otherId: 'u_dimas',
        requesterId: 'u_dimas',
        status: DmStatus.accepted,
        lastMessageAt: now.subtract(const Duration(days: 1)),
        messages: [
          m('b1', 'u_dimas', 'Besok jadi ketemu di perpustakaan?',
              const Duration(days: 1, hours: 1)),
          m('b2', _me, 'Oke, nanti aku kabarin ya.', const Duration(days: 1)),
        ],
      ),
      DmConversation(
        id: 'd3',
        otherId: 'u_fajar',
        requesterId: _me,
        status: DmStatus.accepted,
        lastMessageAt: now.subtract(const Duration(days: 2, hours: 3)),
        messages: [
          m('c1', _me, 'Besok kuliah jam berapa?',
              const Duration(days: 2, hours: 3)),
        ],
      ),
      DmConversation(
        id: 'd4',
        otherId: 'u_anisa',
        requesterId: 'u_anisa',
        status: DmStatus.request,
        unread: 1,
        lastMessageAt: now.subtract(const Duration(minutes: 40)),
        messages: [
          m('e1', 'u_anisa',
              'Halo kak, boleh tanya soal jas lab yang kamu jual?',
              const Duration(minutes: 40)),
        ],
      ),
    ];
  }
}