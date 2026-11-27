import 'moderation_action.dart';
import 'report.dart';

/// Status penanganan satu kasus laporan (enum report_status di database;
/// `dismissed` = `rejected` di database).
enum ReportStatus {
  pending('Menunggu'),
  resolved('Ditindak'),
  dismissed('Diabaikan');

  const ReportStatus(this.label);
  final String label;

  bool get isHandled => this != ReportStatus.pending;

  String get dbValue => switch (this) {
    ReportStatus.dismissed => 'rejected',
    _ => name,
  };
}

/// Salinan (snapshot) konten saat dilaporkan. Tetap ada walau pemilik
/// menghapus kontennya, supaya bukti tidak hilang.
class ReportedContent {
  const ReportedContent({
    this.title,
    this.body = '',
    this.authorUsername,
    this.isAnonymous = false,
    this.imageCount = 0,
    this.meta,
    this.lines = const [],
    this.createdAt,
    this.available = true,
  });

  /// Judul (barang) bila ada.
  final String? title;
  final String body;

  /// Null bila anonim. Identitas anonim hanya bisa dibuka admin (Tahap 6B).
  final String? authorUsername;
  final bool isAnonymous;
  final int imageCount;

  /// Info tambahan satu baris, mis. "Rp45.000 - Second".
  final String? meta;

  /// Untuk laporan pesan: 20 pesan terakhir sebelum pesan yang dilaporkan.
  final List<String> lines;
  final DateTime? createdAt;

  /// False bila konten sudah dihapus/disembunyikan sehingga hanya salinan.
  final bool available;

  ReportedContent withAvailable(bool value) => ReportedContent(
    title: title,
    body: body,
    authorUsername: authorUsername,
    isAnonymous: isAnonymous,
    imageCount: imageCount,
    meta: meta,
    lines: lines,
    createdAt: createdAt,
    available: value,
  );
}

/// Satu kasus = semua laporan untuk satu konten (dikelompokkan per target).
class ReportCase {
  const ReportCase({
    required this.target,
    required this.targetId,
    required this.status,
    required this.reportCount,
    required this.reasons,
    required this.firstReportedAt,
    required this.lastReportedAt,
    required this.content,
    this.notes = const [],
    this.autoHidden = false,
    this.priorViolations = 0,
    this.handledAt,
    this.handledBy,
    this.action,
    this.actionNote,
  });

  final ReportTarget target;
  final String targetId;
  final ReportStatus status;

  /// Jumlah pelapor unik.
  final int reportCount;
  final Map<ReportReason, int> reasons;

  /// Catatan pelapor (tanpa identitas pelapor).
  final List<String> notes;
  final DateTime firstReportedAt;
  final DateTime lastReportedAt;
  final ReportedContent content;

  /// Disembunyikan otomatis karena ambang laporan tercapai.
  final bool autoHidden;

  /// Berapa kali pemilik konten pernah ditindak sebelumnya.
  final int priorViolations;
  final DateTime? handledAt;
  final String? handledBy;

  /// Tindakan yang diambil (null = belum ditangani).
  final ModerationAction? action;
  final String? actionNote;

  /// Hasil setelah ditangani.
  ReportCase handled({
    required ModerationAction action,
    required String by,
    required DateTime at,
    String? note,
  }) => ReportCase(
    target: target,
    targetId: targetId,
    status: action == ModerationAction.dismiss
        ? ReportStatus.dismissed
        : ReportStatus.resolved,
    reportCount: reportCount,
    reasons: reasons,
    notes: notes,
    firstReportedAt: firstReportedAt,
    lastReportedAt: lastReportedAt,
    content: action.hidesContent
        ? content.withAvailable(false)
        : (action == ModerationAction.dismiss
              ? content.withAvailable(true)
              : content),
    autoHidden: action == ModerationAction.dismiss ? false : autoHidden,
    priorViolations: priorViolations + (action.countsAsViolation ? 1 : 0),
    handledAt: at,
    handledBy: by,
    action: action,
    actionNote: note,
  );

  String get id => '${target.name}:$targetId';

  /// Alasan yang paling banyak dilaporkan.
  ReportReason get topReason {
    var best = reasons.entries.first;
    for (final e in reasons.entries) {
      if (e.value > best.value) {
        best = e;
      }
    }
    return best.key;
  }

  static const Set<ReportReason> _severe = {
    ReportReason.scam,
    ReportReason.hate,
    ReportReason.harassment,
    ReportReason.adult,
    ReportReason.privacy,
  };

  /// Alasan berat -> tinjau lebih dulu.
  bool get isSevere => reasons.keys.any(_severe.contains);

  /// Skor urutan antrean: makin tinggi makin dulu.
  int get priority => reportCount + (isSevere ? 2 : 0) + (autoHidden ? 2 : 0);
}
