import 'dart:math' as math;

import '../../auth/domain/user_profile.dart';
import '../domain/post.dart';
import '../domain/post_filter.dart';
import 'post_repository.dart';

/// Tag contoh (urutan dan nama sama dengan seed.sql).
const List<PostTag> kFakeTags = [
  PostTag(id: 1, name: 'Kuesioner', slug: 'kuesioner'),
  PostTag(id: 2, name: 'Informasi', slug: 'informasi'),
  PostTag(id: 3, name: 'Organisasi', slug: 'organisasi'),
  PostTag(id: 4, name: 'Tugas', slug: 'tugas'),
  PostTag(id: 5, name: 'WTB', slug: 'wtb'),
  PostTag(id: 6, name: 'Event/Lomba', slug: 'event-lomba'),
  PostTag(id: 7, name: 'Akademik', slug: 'akademik'),
  PostTag(id: 8, name: 'Magang/Loker', slug: 'magang-loker'),
  PostTag(id: 9, name: 'Kehilangan/Penemuan', slug: 'kehilangan-penemuan'),
  PostTag(id: 10, name: 'Diskusi', slug: 'diskusi'),
  PostTag(id: 11, name: 'Lainnya', slug: 'lainnya'),
];

PostTag _tag(int id) => kFakeTags.firstWhere((t) => t.id == id);

/// Implementasi lokal di memori dengan data contoh.
class FakePostRepository implements PostRepository {
  FakePostRepository({
    required this.currentUser,
    this.latency = const Duration(milliseconds: 500),
    this.minGap = Duration.zero,
    DateTime? now,
  }) : _posts = _seed(now ?? DateTime.now());

  final UserProfile? Function() currentUser;
  final Duration latency;

  /// Jeda minimum antar posting (backend: 30 detik). Nol = nonaktif agar
  /// mudah diuji; isi `Duration(seconds: 30)` untuk menguji batas.
  final Duration minGap;
  final List<Post> _posts;
  DateTime? _lastPostAt;
  int _counter = 0;
  final Set<String> _saved = {};

  /// Isi `true` untuk menguji tampilan error (mis. di preview).
  bool failNext = false;

  Future<void> _delay() async {
    await Future<void>.delayed(latency);
    if (failNext) {
      failNext = false;
      throw const PostException(
        'Gagal memuat. Periksa koneksimu.',
        code: 'network',
      );
    }
  }

  /// Bentuk yang dilihat UI: penulis "saya" diisi dari profil, status simpan
  /// dari daftar simpanan.
  Post _view(Post p) {
    var v = p.copyWith(isSaved: _saved.contains(p.id));
    if (p.isMine) {
      final u = currentUser();
      v = v.copyWith(
        authorUsername: p.isAnonymous ? null : u?.username,
        authorProdi: p.isAnonymous ? null : u?.prodiName,
        authorAvatar: p.isAnonymous ? null : u?.avatarPath,
      );
    }
    return v;
  }

  double _hot(Post p, DateTime now) {
    final hours = now.difference(p.createdAt).inMinutes / 60;
    final s = p.score.toDouble();
    return s / math.pow(hours + 2, 1.5);
  }

  @override
  Future<FeedPage> fetchFeed({
    required PostSort sort,
    int? tagId,
    String? query,
    PostFilter filter = const PostFilter(),
    int offset = 0,
    int limit = 10,
  }) async {
    await _delay();
    final now = DateTime.now();

    var list = _posts.where((p) => !p.isExpired(now)).toList();
    final window = filter.range.window;
    if (window != null) {
      final since = now.subtract(window);
      list = list.where((p) => p.createdAt.isAfter(since)).toList();
    }
    if (filter.onlyWithImages) {
      list = list.where((p) => p.images.isNotEmpty).toList();
    }
    if (filter.hideClosed) {
      list = list.where((p) => !p.isClosed).toList();
    }
    if (tagId != null) {
      list = list.where((p) => p.tags.any((t) => t.id == tagId)).toList();
    }
    final words = (query ?? '')
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isNotEmpty) {
      list = list.where((p) {
        final haystack = '${p.caption} ${p.tags.map((t) => t.name).join(' ')}'
            .toLowerCase();
        return words.every(haystack.contains);
      }).toList();
    }

    int byNewest(Post a, Post b) => b.createdAt.compareTo(a.createdAt);
    switch (sort) {
      case PostSort.newest:
        list.sort(byNewest);
      case PostSort.hot:
        list.sort((a, b) {
          final c = _hot(b, now).compareTo(_hot(a, now));
          return c != 0 ? c : byNewest(a, b);
        });
      case PostSort.top:
        list.sort((a, b) {
          final c = b.score.compareTo(a.score);
          return c != 0 ? c : byNewest(a, b);
        });
      case PostSort.mostCommented:
        list.sort((a, b) {
          final c = b.commentCount.compareTo(a.commentCount);
          return c != 0 ? c : byNewest(a, b);
        });
      case PostSort.endingSoon:
        list.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    }
    // Pengumuman resmi selalu di atas (urutan relatif lain tetap).
    final official = list.where((p) => p.isOfficial).toList();
    list = [...official, ...list.where((p) => !p.isOfficial)];

    final page = list.skip(offset).take(limit).map(_view).toList();
    return FeedPage(items: page, hasMore: offset + limit < list.length);
  }

  @override
  Future<List<PostTag>> fetchTags() async {
    await Future<void>.delayed(latency ~/ 2);
    return kFakeTags;
  }

  int _indexOf(String id) {
    final i = _posts.indexWhere((p) => p.id == id);
    if (i < 0) {
      throw const PostException(
        'Postingan sudah tidak tersedia',
        code: 'not_found',
      );
    }
    return i;
  }

  @override
  Future<Post> getPost(String postId) async {
    await _delay();
    final i = _indexOf(postId);
    if (_posts[i].isExpired(DateTime.now())) {
      throw const PostException(
        'Postingan sudah tidak tersedia',
        code: 'not_found',
      );
    }
    return _view(_posts[i]);
  }

  @override
  void applyCommentDelta(String postId, int delta) {
    final i = _posts.indexWhere((p) => p.id == postId);
    if (i < 0) {
      return;
    }
    final next = _posts[i].commentCount + delta;
    _posts[i] = _posts[i].copyWith(commentCount: next < 0 ? 0 : next);
  }

  @override
  Future<Post> setVote(String postId, int vote) async {
    await _delay();
    final i = _indexOf(postId);
    if (_posts[i].isMine) {
      throw const PostException(
        'Kamu tidak bisa memberi suara pada postinganmu sendiri',
        code: 'own_content',
      );
    }
    _posts[i] = _posts[i].withVote(vote.clamp(-1, 1).toInt());
    return _view(_posts[i]);
  }

  final Map<String, Post> _moderated = {};

  /// Moderasi (repo palsu): sembunyikan postingan dari semua daftar, atau
  /// tampilkan lagi. Server memakai status `hidden`.
  void setModerationHidden(String id, {required bool hidden}) {
    if (hidden) {
      final i = _posts.indexWhere((p) => p.id == id);
      if (i >= 0) {
        _moderated[id] = _posts.removeAt(i);
      }
    } else {
      final p = _moderated.remove(id);
      if (p != null) {
        _posts.add(p);
      }
    }
  }

  /// Khusus repo palsu: bersihkan data pengguna saat ini setelah akunnya
  /// dihapus (postingan sendiri, simpanan, dan suara). Di backend nyata ini
  /// dikerjakan server lewat cascade saat akun dihapus.
  void purgeCurrentUserData() {
    _posts.removeWhere((p) => p.isMine);
    _saved.clear();
    for (var i = 0; i < _posts.length; i++) {
      if (_posts[i].myVote != 0) {
        _posts[i] = _posts[i].withVote(0);
      }
    }
  }

  @override
  Future<FeedPage> fetchByAuthor({
    required String username,
    int offset = 0,
    int limit = 10,
  }) async {
    await _delay();
    final now = DateTime.now();
    final own = currentUser()?.username == username;
    final list =
        _posts
            .where((p) => !p.isExpired(now))
            .where(
              (p) => own
                  ? p.isMine
                  : (!p.isAnonymous && p.authorUsername == username),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return FeedPage(
      items: list.skip(offset).take(limit).map(_view).toList(),
      hasMore: offset + limit < list.length,
    );
  }

  @override
  Future<FeedPage> fetchSaved({int offset = 0, int limit = 10}) async {
    await _delay();
    final now = DateTime.now();
    final list = <Post>[
      for (final id in _saved.toList().reversed)
        for (final p in _posts)
          if (p.id == id && !p.isExpired(now)) p,
    ];
    return FeedPage(
      items: list.skip(offset).take(limit).map(_view).toList(),
      hasMore: offset + limit < list.length,
    );
  }

  @override
  Future<bool> toggleSave(String postId) async {
    await _delay();
    _indexOf(postId);
    if (_saved.remove(postId)) {
      return false;
    }
    _saved.add(postId);
    return true;
  }

  @override
  Future<void> deletePost(String postId) async {
    await _delay();
    final i = _indexOf(postId);
    if (!_posts[i].isMine) {
      throw const PostException(
        'Hanya pemilik yang bisa menghapus postingan',
        code: 'forbidden',
      );
    }
    _posts.removeAt(i);
    _saved.remove(postId);
  }

  @override
  Future<Post> closePost(String postId) async {
    await _delay();
    final i = _indexOf(postId);
    if (!_posts[i].isMine) {
      throw const PostException(
        'Hanya pemilik yang bisa menandai selesai',
        code: 'forbidden',
      );
    }
    _posts[i] = _posts[i].copyWith(status: PostStatus.closed);
    return _view(_posts[i]);
  }

  @override
  Future<Post> createPost(PostDraft draft) async {
    await _delay();
    final user = currentUser();
    if (user == null) {
      throw const PostException('Silakan masuk dulu', code: 'forbidden');
    }
    if (PostRules.validateCaption(draft.caption) != null) {
      throw const PostException('Caption tidak valid', code: 'invalid_caption');
    }
    if (draft.tagIds.isEmpty || draft.tagIds.length > PostRules.maxTags) {
      throw const PostException('Pilih 1–2 tag', code: 'tags_required');
    }
    final tags = <PostTag>[];
    for (final id in draft.tagIds.toSet()) {
      final found = kFakeTags.where((t) => t.id == id);
      if (found.isEmpty) {
        throw const PostException('Tag tidak valid', code: 'invalid_tag');
      }
      tags.add(found.first);
    }
    if (draft.images.length > PostRules.maxImages) {
      throw const PostException('Maksimal 5 gambar', code: 'too_many_images');
    }
    if (!PostRules.lifetimeDays.contains(draft.lifetimeDays)) {
      throw const PostException('Durasi tidak valid', code: 'invalid_duration');
    }
    final link = draft.questionnaire?.link;
    if (link != null &&
        !RegExp(r'^https?://', caseSensitive: false).hasMatch(link)) {
      throw const PostException(
        'Tautan harus diawali http:// atau https://',
        code: 'invalid_link',
      );
    }

    final now = DateTime.now();
    final today = _posts
        .where((p) => p.isMine && now.difference(p.createdAt).inHours < 24)
        .length;
    final last = _lastPostAt;
    if (today >= PostRules.dailyLimit ||
        (last != null && now.difference(last) < minGap)) {
      throw const PostException(
        'Kamu terlalu sering memposting. Coba lagi sebentar lagi.',
        code: 'rate_limit_exceeded',
      );
    }
    _lastPostAt = now;

    final post = Post(
      id: 'n${++_counter}',
      caption: draft.caption.trim(),
      tags: tags,
      createdAt: now,
      expiresAt: now.add(Duration(days: draft.lifetimeDays)),
      isAnonymous: draft.isAnonymous,
      images: draft.images,
      questionnaire: draft.questionnaire,
      isMine: true,
    );
    _posts.insert(0, post);
    return _view(post);
  }

  @override
  Future<Post> updateCaption(String postId, String caption) async {
    await _delay();
    final i = _indexOf(postId);
    final old = _posts[i];
    if (!old.isMine) {
      throw const PostException(
        'Hanya pemilik yang bisa mengubah postingan',
        code: 'forbidden',
      );
    }
    if (!old.canEdit(DateTime.now())) {
      throw const PostException(
        'Postingan hanya bisa diubah dalam 24 jam setelah diposting',
        code: 'edit_window',
      );
    }
    if (PostRules.validateCaption(caption) != null) {
      throw const PostException('Caption tidak valid', code: 'invalid_caption');
    }
    _posts[i] = old.copyWith(caption: caption.trim(), editedAt: DateTime.now());
    return _view(_posts[i]);
  }

  // ---- Data contoh -------------------------------------------------------

  static List<Post> _seed(DateTime now) {
    DateTime ago(Duration d) => now.subtract(d);
    DateTime left(Duration d) => now.add(d);

    return [
      Post(
        id: 'p1',
        caption:
            'Pengumuman: Jadwal UTS Genap\n'
            'Jadwal UTS sudah terbit di portal akademik. Cek ruang dan jam ujianmu '
            'paling lambat Jumat. Info lengkap: https://nusaputra.ac.id/akademik',
        tags: [_tag(2)],
        authorUsername: 'wts_resmi',
        isOfficial: true,
        createdAt: ago(const Duration(hours: 5)),
        expiresAt: left(const Duration(days: 20)),
        upvotes: 64,
        commentCount: 7,
      ),
      Post(
        id: 'p2',
        caption:
            'Rekomendasi materi & kisi-kisi UTS Kalkulus Lanjut Pak Bambang?\n'
            'Ada yang punya catatan atau rangkuman bab 3-5? Boleh dibagikan di sini ya, makasih banyak.',
        tags: [_tag(7), _tag(4)],
        isAnonymous: true,
        images: const [
          PostImage(seed: 1),
          PostImage(seed: 2),
          PostImage(seed: 3),
        ],
        createdAt: ago(const Duration(minutes: 15)),
        expiresAt: left(const Duration(days: 29)),
        upvotes: 45,
        downvotes: 3,
        commentCount: 18,
      ),
      Post(
        id: 'p3',
        caption:
            'Mohon bantuan isi kuesioner skripsi\n'
            'Responden: mahasiswa aktif semua prodi. Cuma ±5 menit, terima kasih banyak! '
            'Nanti saya traktir es teh buat 10 responden pertama.',
        tags: [_tag(1)],
        authorUsername: 'nadia_putri',
        authorProdi: 'Sistem Informasi',
        questionnaire: QuestionnaireInfo(
          link: 'https://forms.gle/contoh-kuesioner',
          deadline: left(const Duration(days: 4)),
          durationMin: 5,
        ),
        createdAt: ago(const Duration(hours: 2)),
        expiresAt: left(const Duration(days: 4)),
        upvotes: 21,
        commentCount: 9,
      ),
      Post(
        id: 'p4',
        caption:
            'Cari jas lab ukuran M, bekas juga tidak apa-apa. Area kampus saja, bisa COD. '
            'Budget maksimal 60rb.',
        tags: [_tag(5)],
        authorUsername: 'rian_pratama',
        authorProdi: 'Teknik Informatika',
        createdAt: ago(const Duration(hours: 7)),
        expiresAt: left(const Duration(days: 6)),
        upvotes: 6,
        commentCount: 4,
      ),
      Post(
        id: 'p5',
        caption:
            'Dompet cokelat tertinggal di Gedung B lantai 2\n'
            'Ada KTM atas nama mahasiswa Manajemen. Sudah dititipkan ke satpam gedung B, '
            'silakan diambil dengan menunjukkan KTM.',
        tags: [_tag(9)],
        authorUsername: 'siti_aisyah',
        authorProdi: 'Manajemen',
        images: const [PostImage(seed: 4)],
        createdAt: ago(const Duration(hours: 9)),
        expiresAt: left(const Duration(days: 12)),
        upvotes: 33,
        commentCount: 5,
      ),
      Post(
        id: 'p6',
        caption:
            'Open recruitment BEM periode baru\n'
            'BEM membuka pendaftaran staf divisi kominfo, acara, dan kewirausahaan. '
            'Pendaftaran sampai 25 November, formulir di link bio kami.',
        tags: [_tag(3), _tag(2)],
        authorUsername: 'bem_nusaputra',
        authorProdi: 'Teknik Informatika',
        images: const [PostImage(seed: 5), PostImage(seed: 6)],
        createdAt: ago(const Duration(hours: 20)),
        expiresAt: left(const Duration(days: 10)),
        upvotes: 58,
        commentCount: 12,
      ),
      Post(
        id: 'p7',
        caption:
            'Lomba desain poster tingkat nasional\n'
            'Hadiah total 10 juta, tim maksimal 3 orang. Ada yang mau ikut bareng? '
            'Aku butuh satu orang yang jago ilustrasi.',
        tags: [_tag(6)],
        authorUsername: 'dina_kamila',
        authorProdi: 'Desain Komunikasi Visual',
        images: const [PostImage(seed: 7)],
        createdAt: ago(const Duration(days: 1, hours: 3)),
        expiresAt: left(const Duration(days: 13)),
        upvotes: 17,
        commentCount: 6,
      ),
      Post(
        id: 'p8',
        caption:
            'Mending lulus tepat waktu atau punya banyak pengalaman organisasi?\n'
            'Lagi bimbang nih di semester 5. Boleh minta pendapat kakak-kakak yang sudah lulus '
            'atau yang sedang skripsi.',
        tags: [_tag(10)],
        isAnonymous: true,
        createdAt: ago(const Duration(days: 1, hours: 8)),
        expiresAt: left(const Duration(days: 28)),
        upvotes: 40,
        downvotes: 5,
        commentCount: 31,
      ),
      Post(
        id: 'p9',
        caption:
            'Info magang backend 3 bulan\n'
            'Startup lokal di Sukabumi buka magang backend (Node/Go), bisa remote setengah. '
            'Ada uang saku. DM aku untuk detailnya.',
        tags: [_tag(8)],
        authorUsername: 'fajar_k',
        authorProdi: 'Teknik Informatika',
        createdAt: ago(const Duration(days: 2)),
        expiresAt: left(const Duration(days: 2)),
        upvotes: 27,
        commentCount: 8,
      ),
      Post(
        id: 'p10',
        caption:
            'WTB buku Struktur Data edisi terbaru, boleh fotokopi bersih. '
            'Sudah dapat dari kakak tingkat, terima kasih semua!',
        tags: [_tag(5)],
        authorUsername: 'budi_santoso',
        authorProdi: 'Teknik Informatika',
        status: PostStatus.closed,
        createdAt: ago(const Duration(days: 3)),
        expiresAt: left(const Duration(days: 5)),
        upvotes: 4,
        commentCount: 3,
        editedAt: ago(const Duration(days: 2)),
      ),
      Post(
        id: 'p11',
        caption:
            'Tips lulus praktikum jaringan komputer tanpa begadang? '
            'Modul lab minggu ini lumayan berat buatku.',
        tags: [_tag(7)],
        isMine: true,
        createdAt: ago(const Duration(days: 4)),
        expiresAt: left(const Duration(days: 26)),
        upvotes: 11,
        commentCount: 14,
      ),
      Post(
        id: 'p15',
        caption:
            'Ada yang mau bentuk tim lomba debat antar kampus?\n'
            'Butuh 2 orang lagi, latihan seminggu dua kali di sore hari. Yang berminat boleh komen.',
        tags: [_tag(6), _tag(10)],
        isMine: true,
        createdAt: ago(const Duration(hours: 3)),
        expiresAt: left(const Duration(days: 27)),
        upvotes: 3,
        commentCount: 2,
      ),
      Post(
        id: 'p12',
        caption:
            'Siapa yang punya akses jurnal IEEE? Butuh 2 paper untuk tinjauan pustaka, '
            'nanti saya kirim judulnya lewat chat.',
        tags: [_tag(4), _tag(7)],
        authorUsername: 'maya_lestari',
        authorProdi: 'Sistem Informasi',
        createdAt: ago(const Duration(days: 5)),
        expiresAt: left(const Duration(days: 3)),
        upvotes: 9,
        commentCount: 2,
      ),
      Post(
        id: 'p13',
        caption:
            'Charger laptop ASUS ketinggalan di perpustakaan\n'
            'Warna hitam, ada stiker bintang di kabel. Kalau ada yang menemukan mohon kabari ya.',
        tags: [_tag(9)],
        authorUsername: 'ilham_r',
        authorProdi: 'Teknik Komputer',
        images: const [PostImage(seed: 8)],
        createdAt: ago(const Duration(days: 6)),
        expiresAt: left(const Duration(hours: 20)),
        upvotes: 5,
        commentCount: 1,
      ),
      Post(
        id: 'p14',
        caption:
            'Webinar karier data science gratis, Sabtu ini jam 09.00 via Zoom. '
            'Dapat e-sertifikat. Daftar lewat link di bawah.\n'
            'https://contoh.id/webinar-data',
        tags: [_tag(6), _tag(2)],
        authorUsername: 'himpunan_ti',
        authorProdi: 'Teknik Informatika',
        images: const [
          PostImage(seed: 9),
          PostImage(seed: 10),
          PostImage(seed: 11),
        ],
        createdAt: ago(const Duration(days: 7)),
        expiresAt: left(const Duration(days: 9)),
        upvotes: 36,
        commentCount: 10,
      ),
    ];
  }
}
