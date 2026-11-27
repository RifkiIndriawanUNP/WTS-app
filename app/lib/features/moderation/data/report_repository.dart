import '../domain/moderation_action.dart';
import '../domain/report.dart';
import '../domain/report_case.dart';

/// Kode: `already_reported` (sudah pernah melaporkan konten yang sama),
/// `rate_limit_exceeded` (terlalu sering), `network`,
/// `forbidden` (bukan moderator / bukan admin), `not_found`,
/// `already_handled`, `invalid` (alasan kurang/terlalu panjang),
/// `already_appealed`.
class ReportException implements Exception {
  const ReportException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'ReportException($code): $message';
}

/// Kontrak pelaporan. Backend: insert ke tabel `reports` (unik per
/// pelapor + jenis + id target; snapshot dibuat trigger).
///
/// Antrean moderator (Tahap 6A) dibaca lewat RPC/view khusus moderator;
/// RLS wajib menolak pengguna biasa. Aksi (moderate_action) di Tahap 6B.
abstract class ReportRepository {
  Future<void> submit({
    required ReportTarget target,
    required String targetId,
    required ReportReason reason,
    String? note,
  });

  /// Antrean kasus (khusus moderator/admin). [handled] false = menunggu,
  /// true = sudah ditangani. Urutan: prioritas tertinggi dulu (menunggu),
  /// terbaru ditangani dulu (selesai).
  Future<List<ReportCase>> fetchQueue({
    bool handled = false,
    ReportTarget? target,
  });

  /// Satu kasus berdasarkan [ReportCase.id].
  Future<ReportCase> getCase(String id);

  /// Jumlah kasus menunggu (lencana di Pengaturan).
  Future<int> pendingCount();

  /// Ambil tindakan pada kasus menunggu. Backend: RPC `moderate_action`
  /// (security definer) yang mengecek peran, mengubah status laporan dan
  /// konten, menambah strike/suspend/ban, menulis audit_logs, dan mengirim
  /// notifikasi ke pemilik konten. Suspend/ban hanya admin.
  Future<ReportCase> moderate({
    required String caseId,
    required ModerationAction action,
    String? reason,
  });

  /// Buka identitas penulis konten anonim (khusus admin, tercatat di audit).
  Future<String> revealAuthor(String caseId);

  /// Riwayat tindakan, terbaru dulu (khusus admin).
  Future<List<AuditEntry>> fetchAuditLog();

  /// Banding pengguna yang ditangguhkan/diblokir. Boleh dipanggil tanpa
  /// sesi (pengguna sedang dibatasi); satu kali per akun.
  Future<void> submitAppeal({required String message, String? accountLabel});

  /// Daftar banding (moderator/admin). [decided] false = menunggu.
  Future<List<Appeal>> fetchAppeals({bool decided = false});

  /// Putuskan banding (khusus admin). Diterima = pembatasan dicabut.
  Future<Appeal> decideAppeal({
    required String appealId,
    required bool accept,
    String? note,
  });
}
