/// Tindakan moderator/admin pada satu kasus (RPC `moderate_action`).
enum ModerationAction {
  dismiss(
    'Abaikan laporan',
    'Konten tidak melanggar. Bila sempat disembunyikan otomatis, konten tampil lagi.',
  ),
  hide(
    'Sembunyikan konten',
    'Konten tidak tampil untuk pengguna lain, tetapi masih tersimpan sebagai bukti.',
  ),
  delete(
    'Hapus konten',
    'Konten dihapus dari aplikasi (salinan bukti tetap ada). Dihitung sebagai pelanggaran.',
  ),
  warn(
    'Beri peringatan',
    'Pemilik konten menerima peringatan. Dihitung sebagai pelanggaran.',
  ),
  suspend3(
    'Suspend 3 hari',
    'Akun tidak bisa masuk selama 3 hari. Konten disembunyikan.',
    suspendDays: 3,
  ),
  suspend7(
    'Suspend 7 hari',
    'Akun tidak bisa masuk selama 7 hari. Konten disembunyikan.',
    suspendDays: 7,
  ),
  suspend30(
    'Suspend 30 hari',
    'Akun tidak bisa masuk selama 30 hari. Konten disembunyikan.',
    suspendDays: 30,
  ),
  ban(
    'Blokir permanen',
    'Akun diblokir selamanya dan email tidak bisa mendaftar lagi. Konten disembunyikan.',
  );

  const ModerationAction(this.label, this.description, {this.suspendDays});

  final String label;
  final String description;
  final int? suspendDays;

  /// Suspend dan blokir hanya untuk admin.
  bool get adminOnly => suspendDays != null || this == ModerationAction.ban;

  /// Semua tindakan selain abaikan wajib disertai alasan.
  bool get needsReason => this != ModerationAction.dismiss;

  bool get isSanction => adminOnly;

  /// Tindakan yang dicatat sebagai pelanggaran pemilik konten.
  bool get countsAsViolation =>
      this == ModerationAction.delete ||
      this == ModerationAction.warn ||
      isSanction;

  /// Konten jadi tidak tampil setelah tindakan ini?
  bool get hidesContent =>
      this != ModerationAction.dismiss && this != ModerationAction.warn;

  bool get destructive =>
      this == ModerationAction.delete ||
      this == ModerationAction.ban ||
      suspendDays != null;
}

abstract final class ModerationRules {
  static const int reasonMin = 5;
  static const int reasonMax = 300;
  static const int appealMin = 10;
  static const int appealMax = 500;
}

enum AppealStatus {
  pending('Menunggu'),
  accepted('Diterima'),
  rejected('Ditolak');

  const AppealStatus(this.label);
  final String label;
}

/// Banding dari pengguna yang ditangguhkan/diblokir (satu kali).
class Appeal {
  const Appeal({
    required this.id,
    required this.message,
    required this.createdAt,
    this.accountLabel,
    this.status = AppealStatus.pending,
    this.decidedBy,
    this.decidedAt,
    this.note,
  });

  final String id;
  final String message;
  final DateTime createdAt;

  /// Mis. "@username" bila diketahui.
  final String? accountLabel;
  final AppealStatus status;
  final String? decidedBy;
  final DateTime? decidedAt;

  /// Jawaban admin.
  final String? note;

  Appeal decided({
    required AppealStatus status,
    required String by,
    required DateTime at,
    String? note,
  }) => Appeal(
    id: id,
    message: message,
    createdAt: createdAt,
    accountLabel: accountLabel,
    status: status,
    decidedBy: by,
    decidedAt: at,
    note: note,
  );
}

/// Catatan audit untuk setiap tindakan moderasi / akses identitas anonim.
class AuditEntry {
  const AuditEntry({
    required this.actor,
    required this.action,
    required this.target,
    required this.createdAt,
    this.detail,
  });

  final String actor;
  final String action;
  final String target;
  final String? detail;
  final DateTime createdAt;
}
