/// Status komentar yang sampai ke klien (comment_status di database).
/// Komentar `deleted` tetap tampil sebagai "[komentar dihapus]" bila punya balasan.
enum CommentStatus { active, deleted }

enum CommentSort {
  best('Terbaik'),
  newest('Terbaru'),
  oldest('Terlama');

  const CommentSort(this.label);
  final String label;
}

abstract final class CommentRules {
  static const int bodyMin = 1;
  static const int bodyMax = 1000;

  /// Kedalaman balasan: 0 = komentar utama, maksimal 2 (tiga tingkat).
  static const int maxDepth = 2;
  static const Duration editWindow = Duration(minutes: 5);

  static String? validateBody(String body) {
    final b = body.trim();
    if (b.length < bodyMin) {
      return 'Tulis komentar dulu';
    }
    if (b.length > bodyMax) {
      return 'Komentar maksimal $bodyMax karakter';
    }
    return null;
  }
}

class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.createdAt,
    this.parentId,
    this.depth = 0,
    this.body,
    this.status = CommentStatus.active,
    this.authorUsername,
    this.authorAvatar,
    this.isOp = false,
    this.isAnonymousOp = false,
    this.upvotes = 0,
    this.downvotes = 0,
    this.editedAt,
    this.isMine = false,
    this.myVote = 0,
  });

  final String id;
  final String postId;
  final String? parentId;
  final int depth;

  /// Null bila komentar sudah dihapus.
  final String? body;
  final CommentStatus status;

  /// Null bila penulis adalah pemilik postingan anonim (view menyembunyikannya).
  final String? authorUsername;
  final String? authorAvatar;

  /// Penulis komentar = pemilik postingan.
  final bool isOp;
  final bool isAnonymousOp;
  final int upvotes;
  final int downvotes;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool isMine;

  /// 1 = upvote, -1 = downvote, 0 = belum memilih.
  final int myVote;

  int get score => upvotes - downvotes;
  bool get isDeleted => status == CommentStatus.deleted;
  bool get isEdited => editedAt != null;
  bool get canReply => depth < CommentRules.maxDepth && !isDeleted;

  String get authorLabel =>
      isAnonymousOp || authorUsername == null ? 'Anonim' : '@$authorUsername';

  String get authorInitials {
    final name = authorUsername;
    if (isAnonymousOp || name == null) {
      return '?';
    }
    final letters = name.replaceAll('_', '');
    if (letters.isEmpty) {
      return '?';
    }
    return letters.substring(0, letters.length >= 2 ? 2 : 1).toUpperCase();
  }

  /// Edit hanya oleh pemilik dalam 5 menit.
  bool canEdit(DateTime now) =>
      isMine &&
      !isDeleted &&
      now.difference(createdAt) < CommentRules.editWindow;

  Comment withVote(int vote) {
    var up = upvotes;
    var down = downvotes;
    if (myVote == 1) {
      up--;
    }
    if (myVote == -1) {
      down--;
    }
    if (vote == 1) {
      up++;
    }
    if (vote == -1) {
      down++;
    }
    return copyWith(upvotes: up, downvotes: down, myVote: vote);
  }

  Comment copyWith({
    String? body,
    bool clearBody = false,
    CommentStatus? status,
    int? upvotes,
    int? downvotes,
    int? myVote,
    DateTime? editedAt,
  }) {
    return Comment(
      id: id,
      postId: postId,
      parentId: parentId,
      depth: depth,
      body: clearBody ? null : (body ?? this.body),
      status: status ?? this.status,
      authorUsername: authorUsername,
      authorAvatar: authorAvatar,
      isOp: isOp,
      isAnonymousOp: isAnonymousOp,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      createdAt: createdAt,
      editedAt: editedAt ?? this.editedAt,
      isMine: isMine,
      myVote: myVote ?? this.myVote,
    );
  }
}

/// Satu komentar beserta balasannya (pohon).
class CommentNode {
  CommentNode(this.comment);

  final Comment comment;
  final List<CommentNode> children = [];

  /// Jumlah seluruh keturunan.
  int get descendantCount =>
      children.fold(0, (sum, c) => sum + 1 + c.descendantCount);
}

/// Menyusun daftar datar menjadi pohon. Komentar utama mengikuti [sort];
/// balasan selalu urut waktu (lama ke baru) agar percakapan terbaca.
/// Balasan yang induknya tidak ada (mis. tersaring) dibuang.
List<CommentNode> buildCommentTree(List<Comment> flat, CommentSort sort) {
  final nodes = {for (final c in flat) c.id: CommentNode(c)};
  final roots = <CommentNode>[];
  for (final c in flat) {
    final node = nodes[c.id]!;
    final parent = c.parentId == null ? null : nodes[c.parentId];
    if (c.parentId == null) {
      roots.add(node);
    } else if (parent != null) {
      parent.children.add(node);
    }
  }

  int byTime(CommentNode a, CommentNode b) =>
      a.comment.createdAt.compareTo(b.comment.createdAt);
  void sortChildren(CommentNode n) {
    n.children.sort(byTime);
    n.children.forEach(sortChildren);
  }

  roots.forEach(sortChildren);
  switch (sort) {
    case CommentSort.best:
      roots.sort((a, b) {
        final c = b.comment.score.compareTo(a.comment.score);
        return c != 0 ? c : byTime(a, b);
      });
    case CommentSort.newest:
      roots.sort((a, b) => byTime(b, a));
    case CommentSort.oldest:
      roots.sort(byTime);
  }
  return roots;
}
