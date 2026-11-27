import '../domain/comment.dart';

/// Kode (Kontrak_Data_Frontend): `not_found`, `forbidden`, `comments_closed`,
/// `invalid_body`, `max_depth`, `edit_window`, `own_content`,
/// `rate_limit_exceeded`, `network`.
class CommentException implements Exception {
  const CommentException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'CommentException($code): $message';
}

/// Kontrak data komentar. Backend: view comments_public (baca), tabel comments
/// (tulis, dibatasi RLS/trigger), tabel comment_votes, RPC delete_comment.
/// Laporan komentar memakai ReportRepository (modul moderasi).
abstract class CommentRepository {
  /// Semua komentar sebuah postingan (daftar datar; susun dengan buildCommentTree).
  Future<List<Comment>> fetchComments(String postId);

  /// [vote]: -1, 0, atau 1. Melempar [CommentException] `own_content` bila
  /// komentar milik sendiri. Mengembalikan komentar terbaru.
  Future<Comment> setVote(String commentId, int vote);

  /// Komentar baru ([parentId] null = komentar utama). Kode error: `invalid_body`,
  /// `max_depth`, `comments_closed`, `not_found`, `forbidden`, `rate_limit_exceeded`.
  Future<Comment> createComment({
    required String postId,
    required String body,
    String? parentId,
  });

  /// Ubah isi; hanya pemilik dan hanya 5 menit pertama (`edit_window`).
  Future<Comment> editComment(String commentId, String body);

  /// Hapus komentar milik sendiri. Bila punya balasan, komentar tetap ada
  /// sebagai "[komentar dihapus]" (dikembalikan); bila tidak, hilang (null).
  Future<Comment?> deleteComment(String commentId);
}
