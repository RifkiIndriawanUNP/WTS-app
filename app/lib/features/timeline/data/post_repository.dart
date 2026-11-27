import '../domain/post.dart';
import '../domain/post_filter.dart';

class FeedPage {
  const FeedPage({required this.items, required this.hasMore});

  final List<Post> items;
  final bool hasMore;
}

/// Kesalahan data linimasa. [code] mengikuti kode di Kontrak_Data_Frontend
/// (mis. `own_content`, `not_found`, `network`).
class PostException implements Exception {
  const PostException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'PostException($code): $message';
}

/// Kontrak data linimasa. Sekarang diisi FakePostRepository; nanti
/// implementasi Supabase (view posts_public, tabel post_votes & saved_posts).
abstract class PostRepository {
  /// Halaman feed. Pengumuman resmi (`isOfficial`) selalu di atas.
  /// Backend memakai kursor; di sini cukup [offset].
  ///
  /// [query] mencari di isi postingan dan nama tag: setiap kata harus cocok
  /// (tanpa membedakan huruf besar/kecil). Kosong/spasi saja = tanpa pencarian.
  /// [filter] mempersempit hasil (rentang waktu, hanya bergambar, sembunyikan selesai).
  Future<FeedPage> fetchFeed({
    required PostSort sort,
    int? tagId,
    String? query,
    PostFilter filter = const PostFilter(),
    int offset = 0,
    int limit = 10,
  });

  /// Tag linimasa aktif, urut sort_order.
  Future<List<PostTag>> fetchTags();

  /// [vote]: -1, 0, atau 1. Melempar [PostException] `own_content` bila
  /// postingan milik sendiri. Mengembalikan postingan terbaru.
  Future<Post> setVote(String postId, int vote);

  /// Mengembalikan status simpan yang baru.
  Future<bool> toggleSave(String postId);

  /// Satu postingan. Kode error: `not_found` (dihapus/kedaluwarsa/disembunyikan).
  Future<Post> getPost(String postId);

  /// Menjaga jumlah komentar sinkron setelah menambah/menghapus komentar.
  /// Implementasi backend cukup no-op: jumlah dihitung trigger database.
  void applyCommentDelta(String postId, int delta);

  /// Membuat postingan baru. Kode error: `invalid_caption`, `tags_required`,
  /// `invalid_tag`, `too_many_images`, `invalid_duration`, `invalid_link`,
  /// `rate_limit_exceeded`, `forbidden`.
  Future<Post> createPost(PostDraft draft);

  /// Ubah caption saja (gambar & tag tidak bisa diubah). Hanya pemilik dan
  /// hanya dalam 24 jam. Kode error: `forbidden`, `edit_window`,
  /// `invalid_caption`, `not_found`.
  Future<Post> updateCaption(String postId, String caption);

  /// Hanya pemilik (`forbidden` bila bukan). Postingan hilang dari feed.
  Future<void> deletePost(String postId);

  /// Tandai "Selesai" (status closed): komentar ditutup. Hanya pemilik.
  Future<Post> closePost(String postId);

  /// Postingan seorang pengguna, terbaru dulu. Untuk profil orang lain hanya
  /// yang tidak anonim; untuk profil sendiri semuanya (anonim ikut, hanya
  /// terlihat oleh pemiliknya).
  Future<FeedPage> fetchByAuthor({
    required String username,
    int offset = 0,
    int limit = 10,
  });

  /// Postingan yang disimpan pengguna saat ini, simpanan terbaru dulu.
  /// Yang sudah kedaluwarsa/dihapus tidak ditampilkan.
  Future<FeedPage> fetchSaved({int offset = 0, int limit = 10});
}
