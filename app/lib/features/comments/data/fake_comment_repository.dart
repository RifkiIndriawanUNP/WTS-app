import '../../auth/domain/user_profile.dart';
import '../../timeline/data/post_repository.dart';
import '../../timeline/domain/post.dart';
import '../domain/comment.dart';
import 'comment_repository.dart';

const List<String> _authors = [
  'rina_putri',
  'budi_santoso',
  'siti_aisyah',
  'dina_kamila',
  'fajar_k',
  'maya_lestari',
  'ilham_r',
];

const List<String> _texts = [
  'Aku punya rangkumannya, nanti aku kirim lewat chat ya.',
  'Coba tanya ke kakak tingkat angkatan atas, biasanya mereka simpan arsip soal.',
  'Setuju banget, aku juga lagi cari info yang sama.',
  'Makasih banyak infonya! Sangat membantu.',
  'Menurutku lebih baik mulai dari bab yang bobotnya paling besar dulu.',
  'Kalau mau, bisa belajar bareng di perpustakaan hari Kamis sore.',
  'Info lengkapnya ada di sini: https://nusaputra.ac.id/akademik',
  'Hati-hati, jangan kasih data pribadi ke orang yang belum dikenal ya.',
  'Sudah beres? Kalau sudah, tandai selesai supaya yang lain tahu.',
  'Aku ikut, jangan lupa kabari kalau jadi.',
  'Terima kasih sudah dibagikan, semoga lancar!',
  'Kalau ada tambahan, kabari aja di sini.',
];

/// Komentar contoh yang dibuat otomatis dari jumlah komentar postingan,
/// dengan balasan sampai 3 tingkat, komentar dihapus, dan penanda OP.
class FakeCommentRepository implements CommentRepository {
  FakeCommentRepository({
    required this.postLookup,
    this.currentUser,
    this.onCountChanged,
    this.latency = const Duration(milliseconds: 500),
  });

  final Future<Post> Function(String postId) postLookup;

  /// Pengguna yang sedang masuk (penulis komentar baru).
  final UserProfile? Function()? currentUser;

  /// Dipanggil saat jumlah komentar sebuah postingan berubah (+1 / -1).
  final void Function(String postId, int delta)? onCountChanged;
  final Duration latency;
  int _counter = 0;

  /// Isi `true` untuk menguji tampilan error.
  bool failNext = false;

  final Map<String, List<Comment>> _byPost = {};

  @override
  Future<List<Comment>> fetchComments(String postId) async {
    await Future<void>.delayed(latency);
    if (failNext) {
      failNext = false;
      throw const CommentException(
        'Gagal memuat komentar. Periksa koneksimu.',
        code: 'network',
      );
    }
    final cached = _byPost[postId];
    if (cached != null) {
      return List.of(cached);
    }
    final post = await _post(postId);
    final generated = _generate(post);
    _byPost[postId] = generated;
    return List.of(generated);
  }

  @override
  Future<Comment> setVote(String commentId, int vote) async {
    await Future<void>.delayed(latency);
    for (final list in _byPost.values) {
      final i = list.indexWhere((c) => c.id == commentId);
      if (i < 0) {
        continue;
      }
      if (list[i].isMine) {
        throw const CommentException(
          'Kamu tidak bisa memberi suara pada komentarmu sendiri',
          code: 'own_content',
        );
      }
      list[i] = list[i].withVote(vote.clamp(-1, 1).toInt());
      return list[i];
    }
    throw const CommentException(
      'Komentar sudah tidak tersedia',
      code: 'not_found',
    );
  }

  Future<Post> _post(String postId) async {
    try {
      return await postLookup(postId);
    } on PostException catch (e) {
      throw CommentException(e.message, code: e.code);
    }
  }

  List<Comment>? _listOf(String commentId) {
    for (final list in _byPost.values) {
      if (list.any((c) => c.id == commentId)) {
        return list;
      }
    }
    return null;
  }

  /// Khusus repo palsu: hapus komentar milik pengguna saat ini setelah akunnya
  /// dihapus. Yang masih punya balasan menjadi "[komentar dihapus]".
  void purgeOwnComments() {
    for (final entry in _byPost.entries) {
      final list = entry.value;
      for (final c in List<Comment>.of(list)) {
        if (!c.isMine || c.isDeleted) {
          continue;
        }
        final i = list.indexWhere((x) => x.id == c.id);
        if (list.any((x) => x.parentId == c.id)) {
          list[i] = c.copyWith(status: CommentStatus.deleted, clearBody: true);
        } else {
          list.removeAt(i);
          onCountChanged?.call(entry.key, -1);
        }
      }
    }
  }

  @override
  Future<Comment> createComment({
    required String postId,
    required String body,
    String? parentId,
  }) async {
    await Future<void>.delayed(latency);
    final user = currentUser?.call();
    if (user == null) {
      throw const CommentException('Silakan masuk dulu', code: 'forbidden');
    }
    if (CommentRules.validateBody(body) != null) {
      throw const CommentException(
        'Isi komentar tidak valid',
        code: 'invalid_body',
      );
    }
    final post = await _post(postId);
    if (post.isClosed) {
      throw const CommentException(
        'Komentar sudah ditutup',
        code: 'comments_closed',
      );
    }
    final list = _byPost.putIfAbsent(postId, () => _generate(post));

    var depth = 0;
    if (parentId != null) {
      final i = list.indexWhere((c) => c.id == parentId);
      if (i < 0 || list[i].isDeleted) {
        throw const CommentException(
          'Komentar yang dibalas sudah tidak ada',
          code: 'not_found',
        );
      }
      depth = list[i].depth + 1;
      if (depth > CommentRules.maxDepth) {
        throw const CommentException(
          'Balasan sudah mencapai batas tingkat',
          code: 'max_depth',
        );
      }
    }

    final isOp = post.isMine;
    final created = Comment(
      id: '${postId}_n${++_counter}',
      postId: postId,
      parentId: parentId,
      depth: depth,
      body: body.trim(),
      authorUsername: isOp && post.isAnonymous ? null : user.username,
      authorAvatar: isOp && post.isAnonymous ? null : user.avatarPath,
      isOp: isOp,
      isAnonymousOp: isOp && post.isAnonymous,
      createdAt: DateTime.now(),
      isMine: true,
    );
    list.add(created);
    onCountChanged?.call(postId, 1);
    return created;
  }

  @override
  Future<Comment> editComment(String commentId, String body) async {
    await Future<void>.delayed(latency);
    final list = _listOf(commentId);
    if (list == null) {
      throw const CommentException(
        'Komentar sudah tidak tersedia',
        code: 'not_found',
      );
    }
    final i = list.indexWhere((c) => c.id == commentId);
    final old = list[i];
    if (!old.isMine) {
      throw const CommentException(
        'Hanya pemilik yang bisa mengubah komentar',
        code: 'forbidden',
      );
    }
    if (!old.canEdit(DateTime.now())) {
      throw const CommentException(
        'Komentar hanya bisa diubah dalam 5 menit setelah dikirim',
        code: 'edit_window',
      );
    }
    if (CommentRules.validateBody(body) != null) {
      throw const CommentException(
        'Isi komentar tidak valid',
        code: 'invalid_body',
      );
    }
    list[i] = old.copyWith(body: body.trim(), editedAt: DateTime.now());
    return list[i];
  }

  @override
  Future<Comment?> deleteComment(String commentId) async {
    await Future<void>.delayed(latency);
    final list = _listOf(commentId);
    if (list == null) {
      throw const CommentException(
        'Komentar sudah tidak tersedia',
        code: 'not_found',
      );
    }
    final i = list.indexWhere((c) => c.id == commentId);
    final old = list[i];
    if (!old.isMine) {
      throw const CommentException(
        'Hanya pemilik yang bisa menghapus komentar',
        code: 'forbidden',
      );
    }
    if (list.any((c) => c.parentId == commentId)) {
      list[i] = old.copyWith(status: CommentStatus.deleted, clearBody: true);
      return list[i];
    }
    list.removeAt(i);
    onCountChanged?.call(old.postId, -1);
    return null;
  }

  List<Comment> _generate(Post post) {
    final now = DateTime.now();
    final out = <Comment>[];
    String? lastRoot;
    String? lastReply;

    for (var i = 0; i < post.commentCount; i++) {
      final id = '${post.id}_c$i';
      String? parent;
      var depth = 0;
      switch (i % 5) {
        case 1:
        case 4:
          parent = lastRoot;
          depth = parent == null ? 0 : 1;
        case 2:
          parent = lastReply ?? lastRoot;
          depth = lastReply != null ? 2 : (lastRoot != null ? 1 : 0);
        default:
          parent = null;
          depth = 0;
      }
      if (depth == 0) {
        lastRoot = id;
        lastReply = null;
      } else if (depth == 1) {
        lastReply = id;
      }

      final isOp = i % 4 == 2;
      final deleted = i % 11 == 6;
      var created = post.createdAt.add(Duration(minutes: 7 * (i + 1)));
      if (created.isAfter(now)) {
        created = now.subtract(Duration(minutes: post.commentCount - i));
      }

      out.add(
        Comment(
          id: id,
          postId: post.id,
          parentId: parent,
          depth: depth,
          body: deleted
              ? null
              : _texts[(i * 5 + post.id.length) % _texts.length],
          status: deleted ? CommentStatus.deleted : CommentStatus.active,
          authorUsername: isOp
              ? (post.isAnonymous ? null : post.authorUsername)
              : _authors[i % _authors.length],
          isOp: isOp,
          isAnonymousOp: isOp && post.isAnonymous,
          upvotes: (i * 7) % 15,
          downvotes: (i * 3) % 4,
          createdAt: created,
          editedAt: i % 9 == 4 ? created.add(const Duration(minutes: 2)) : null,
        ),
      );
    }
    return out;
  }
}
