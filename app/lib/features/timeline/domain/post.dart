/// Status postingan yang tampil di feed (post_status di database).
/// `hidden`/`expired` tidak pernah sampai ke klien (disaring view).
enum PostStatus { active, closed }

/// Urutan feed (lihat Analisis 6.10).
enum PostSort {
  newest('Terbaru'),
  hot('Terpopuler'),
  top('Teratas'),
  mostCommented('Paling banyak komentar'),
  endingSoon('Segera berakhir');

  const PostSort(this.label);
  final String label;
}

/// Aturan isi postingan (sama dengan constraint database/RPC create_post).
abstract final class PostRules {
  static const int captionMin = 1;
  static const int captionMax = 2000;
  static const int minTags = 1;
  static const int maxTags = 2;
  static const int maxImages = 5;
  static const Duration editWindow = Duration(hours: 24);

  /// Pilihan durasi tayang (hari). Bawaan 30.
  static const List<int> lifetimeDays = [1, 3, 7, 14, 30];
  static const int defaultLifetimeDays = 30;

  /// Judul (baris pertama caption) dibatasi agar terbaca sebagai judul.
  static const int titleMax = 120;

  /// Batas posting per hari (rate limit backend: 10/hari, jeda 30 detik).
  static const int dailyLimit = 10;

  /// Id tag "Kuesioner" (seed.sql). Memunculkan isian tautan/batas waktu.
  static const String questionnaireSlug = 'kuesioner';

  /// Judul + isi digabung menjadi satu caption (judul = baris pertama).
  static String compose(String title, String body) {
    final t = title.trim();
    final b = body.trim();
    if (t.isEmpty) {
      return b;
    }
    return b.isEmpty ? t : '$t\n$b';
  }

  /// Pesan kesalahan caption, atau null bila valid.
  static String? validateCaption(String caption) {
    final c = caption.trim();
    if (c.length < captionMin) {
      return 'Tulis sesuatu dulu';
    }
    if (c.length > captionMax) {
      return 'Judul + isi maksimal $captionMax karakter';
    }
    return null;
  }
}

/// Isi formulir "Buat postingan" (sama dengan argumen RPC create_post).
class PostDraft {
  const PostDraft({
    required this.caption,
    required this.tagIds,
    this.images = const [],
    this.isAnonymous = false,
    this.lifetimeDays = PostRules.defaultLifetimeDays,
    this.questionnaire,
  });

  final String caption;
  final List<int> tagIds;
  final List<PostImage> images;
  final bool isAnonymous;
  final int lifetimeDays;
  final QuestionnaireInfo? questionnaire;
}

/// Tag linimasa (tabel `tags`, scope `timeline`; dikelola admin).
class PostTag {
  const PostTag({required this.id, required this.name, required this.slug});

  final int id;
  final String name;
  final String slug;

  @override
  bool operator ==(Object other) => other is PostTag && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Gambar postingan. [path] = path di Storage (atau file lokal yang baru
/// dipilih saat membuat postingan). Tanpa path = gambar contoh bergradien
/// berdasarkan [seed], supaya tampilan bisa diuji tanpa foto.
class PostImage {
  const PostImage({this.path, this.width, this.height, this.seed = 0});

  final String? path;
  final int? width;
  final int? height;
  final int seed;
}

/// Isi `extra` untuk tag Kuesioner: {link, deadline, duration_min}.
class QuestionnaireInfo {
  const QuestionnaireInfo({
    required this.link,
    this.deadline,
    this.durationMin,
  });

  final String link;
  final DateTime? deadline;
  final int? durationMin;
}

class Post {
  const Post({
    required this.id,
    required this.caption,
    required this.tags,
    required this.createdAt,
    required this.expiresAt,
    this.authorUsername,
    this.authorProdi,
    this.authorAvatar,
    this.isAnonymous = false,
    this.isOfficial = false,
    this.status = PostStatus.active,
    this.images = const [],
    this.questionnaire,
    this.upvotes = 0,
    this.downvotes = 0,
    this.commentCount = 0,
    this.editedAt,
    this.isMine = false,
    this.myVote = 0,
    this.isSaved = false,
  });

  final String id;
  final String caption;
  final List<PostTag> tags;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// Null untuk postingan anonim (view menyembunyikannya).
  final String? authorUsername;

  /// Program studi penulis (null bila anonim/belum diisi). Kolom ini belum ada
  /// di view `posts_public`: minta A menambahkannya (issue berlabel `backend`).
  final String? authorProdi;
  final String? authorAvatar;
  final bool isAnonymous;
  final bool isOfficial;
  final PostStatus status;
  final List<PostImage> images;
  final QuestionnaireInfo? questionnaire;
  final int upvotes;
  final int downvotes;
  final int commentCount;
  final DateTime? editedAt;
  final bool isMine;

  /// 1 = upvote, -1 = downvote, 0 = belum memilih.
  final int myVote;
  final bool isSaved;

  int get score => upvotes - downvotes;
  bool get isClosed => status == PostStatus.closed;
  bool get isEdited => editedAt != null;

  String get authorLabel =>
      isAnonymous ? 'Anonim' : '@${authorUsername ?? '-'}';

  String get authorInitials {
    if (isAnonymous || authorUsername == null) {
      return '?';
    }
    final letters = authorUsername!.replaceAll('_', '');
    if (letters.isEmpty) {
      return '?';
    }
    return letters.substring(0, letters.length >= 2 ? 2 : 1).toUpperCase();
  }

  /// Caption dipecah: baris pertama menjadi judul tebal bila masih ada isi
  /// di bawahnya (dan tidak terlalu panjang). Selain itu semuanya isi biasa.
  /// Saat membuat postingan, judul + isi digabung dengan baris baru.
  ({String? title, String body}) get parts {
    final text = caption.trim();
    final i = text.indexOf('\n');
    if (i <= 0 || i > 120) {
      return (title: null, body: text);
    }
    final rest = text.substring(i + 1).trim();
    if (rest.isEmpty) {
      return (title: null, body: text);
    }
    return (title: text.substring(0, i).trim(), body: rest);
  }

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  /// Edit caption hanya oleh pemilik dalam 24 jam (kontrak backend).
  bool canEdit(DateTime now) =>
      isMine && now.difference(createdAt) < PostRules.editWindow;

  /// Hasil setelah suara saya menjadi [vote] (-1, 0, atau 1).
  Post withVote(int vote) {
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

  Post copyWith({
    String? caption,
    int? upvotes,
    int? downvotes,
    int? commentCount,
    int? myVote,
    bool? isSaved,
    PostStatus? status,
    DateTime? editedAt,
    DateTime? expiresAt,
    String? authorUsername,
    String? authorProdi,
    String? authorAvatar,
  }) {
    return Post(
      id: id,
      caption: caption ?? this.caption,
      tags: tags,
      createdAt: createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      authorUsername: authorUsername ?? this.authorUsername,
      authorProdi: authorProdi ?? this.authorProdi,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      isAnonymous: isAnonymous,
      isOfficial: isOfficial,
      status: status ?? this.status,
      images: images,
      questionnaire: questionnaire,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      commentCount: commentCount ?? this.commentCount,
      editedAt: editedAt ?? this.editedAt,
      isMine: isMine,
      myVote: myVote ?? this.myVote,
      isSaved: isSaved ?? this.isSaved,
    );
  }
}
