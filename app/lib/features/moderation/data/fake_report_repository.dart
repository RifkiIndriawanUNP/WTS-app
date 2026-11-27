import '../../auth/domain/user_profile.dart';
import '../domain/moderation_action.dart';
import '../domain/report.dart';
import '../domain/report_case.dart';
import 'report_repository.dart';

/// Penyimpanan laporan di memori (tanpa backend), berisi contoh kasus.
class FakeReportRepository implements ReportRepository {
  FakeReportRepository({
    this.latency = const Duration(milliseconds: 500),
    this.currentUser,
    this.onVisibilityChanged,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _seed();
  }

  final Duration latency;

  /// Pengguna aktif; antrean hanya untuk moderator/admin.
  final UserProfile? Function()? currentUser;
  final DateTime Function() _clock;

  /// Dipanggil saat tindakan mengubah tampilnya konten (hide/hapus/suspend/
  /// ban = false; abaikan setelah auto-sembunyi = true). Dipakai tampilan
  /// untuk menyembunyikan konten di repo palsu lain.
  final void Function(ReportTarget target, String targetId, bool visible)?
  onVisibilityChanged;

  final Set<String> _sent = {};
  final Map<String, ReportCase> _cases = {};
  final List<AuditEntry> _audit = [];
  final List<Appeal> _appeals = [];
  bool _appealSent = false;

  /// Identitas penulis anonim (hanya bisa dibuka admin lewat [revealAuthor]).
  static const Map<String, String> _anonAuthors = {'post:p9': 'budi_santoso'};

  /// Tindakan yang sudah dicatat (untuk tes).
  List<AuditEntry> get auditEntries => List.unmodifiable(_audit);

  /// Laporan yang terkirim lewat [submit] (untuk tes).
  int get count => _sent.length;

  /// Ambang auto-sembunyi: 3 pelapor unik, atau 2 untuk penipuan barang.
  static bool _shouldAutoHide(
    ReportTarget t,
    Map<ReportReason, int> reasons,
    int n,
  ) {
    if (n >= 3) {
      return true;
    }
    return t == ReportTarget.product && (reasons[ReportReason.scam] ?? 0) >= 2;
  }

  UserProfile _requireModerator() {
    final u = currentUser?.call();
    if (u == null || !u.isModerator) {
      throw const ReportException('Khusus moderator', code: 'forbidden');
    }
    return u;
  }

  UserProfile _requireAdmin() {
    final u = currentUser?.call();
    if (u == null || !u.isAdmin) {
      throw const ReportException('Khusus admin', code: 'forbidden');
    }
    return u;
  }

  @override
  Future<void> submit({
    required ReportTarget target,
    required String targetId,
    required ReportReason reason,
    String? note,
  }) async {
    await Future<void>.delayed(latency);
    final n = (note ?? '').trim();
    if (n.length > ReportRules.noteMax) {
      throw const ReportException('Catatan terlalu panjang', code: 'invalid');
    }
    final key = '${target.name}:$targetId';
    if (!_sent.add(key)) {
      throw const ReportException(
        'Kamu sudah melaporkan ini. Moderator sedang meninjaunya.',
        code: 'already_reported',
      );
    }
    final now = _clock();
    final old = _cases[key];
    if (old == null || old.status.isHandled) {
      // Kasus baru (atau dibuka lagi karena ada laporan baru setelah ditangani).
      final reasons = {reason: 1};
      _cases[key] = ReportCase(
        target: target,
        targetId: targetId,
        status: ReportStatus.pending,
        reportCount: 1,
        reasons: reasons,
        notes: n.isEmpty ? const [] : [n],
        firstReportedAt: now,
        lastReportedAt: now,
        autoHidden: _shouldAutoHide(target, reasons, 1),
        priorViolations: old?.priorViolations ?? 0,
        content:
            old?.content ??
            const ReportedContent(
              body: 'Salinan isi konten belum tersedia di mode pratinjau.',
            ),
      );
      return;
    }
    final reasons = {...old.reasons, reason: (old.reasons[reason] ?? 0) + 1};
    final total = old.reportCount + 1;
    _cases[key] = ReportCase(
      target: old.target,
      targetId: old.targetId,
      status: old.status,
      reportCount: total,
      reasons: reasons,
      notes: n.isEmpty ? old.notes : [...old.notes, n],
      firstReportedAt: old.firstReportedAt,
      lastReportedAt: now,
      content: old.content,
      autoHidden: old.autoHidden || _shouldAutoHide(target, reasons, total),
      priorViolations: old.priorViolations,
    );
  }

  @override
  Future<List<ReportCase>> fetchQueue({
    bool handled = false,
    ReportTarget? target,
  }) async {
    await Future<void>.delayed(latency);
    _requireModerator();
    final list = _cases.values
        .where((c) => c.status.isHandled == handled)
        .where((c) => target == null || c.target == target)
        .toList();
    if (handled) {
      list.sort(
        (a, b) => (b.handledAt ?? b.lastReportedAt).compareTo(
          a.handledAt ?? a.lastReportedAt,
        ),
      );
    } else {
      list.sort((a, b) {
        final p = b.priority.compareTo(a.priority);
        return p != 0 ? p : a.firstReportedAt.compareTo(b.firstReportedAt);
      });
    }
    return list;
  }

  @override
  Future<ReportCase> getCase(String id) async {
    await Future<void>.delayed(latency);
    _requireModerator();
    final c = _cases[id];
    if (c == null) {
      throw const ReportException('Laporan tidak ditemukan', code: 'not_found');
    }
    return c;
  }

  @override
  Future<int> pendingCount() async {
    await Future<void>.delayed(latency);
    _requireModerator();
    return _cases.values.where((c) => !c.status.isHandled).length;
  }

  @override
  Future<ReportCase> moderate({
    required String caseId,
    required ModerationAction action,
    String? reason,
  }) async {
    await Future<void>.delayed(latency);
    final actor = _requireModerator();
    if (action.adminOnly && !actor.isAdmin) {
      throw const ReportException(
        'Tindakan ini khusus admin',
        code: 'forbidden',
      );
    }
    final c = _cases[caseId];
    if (c == null) {
      throw const ReportException('Laporan tidak ditemukan', code: 'not_found');
    }
    if (c.status.isHandled) {
      throw const ReportException(
        'Laporan ini sudah ditangani',
        code: 'already_handled',
      );
    }
    final r = (reason ?? '').trim();
    if (action.needsReason &&
        (r.length < ModerationRules.reasonMin ||
            r.length > ModerationRules.reasonMax)) {
      throw const ReportException(
        'Alasan wajib diisi (5-300 karakter)',
        code: 'invalid',
      );
    }
    final now = _clock();
    final next = c.handled(
      action: action,
      by: actor.username,
      at: now,
      note: r.isEmpty ? null : r,
    );
    _cases[caseId] = next;
    _audit.insert(
      0,
      AuditEntry(
        actor: actor.username,
        action: action.name,
        target: caseId,
        detail: r.isEmpty ? null : r,
        createdAt: now,
      ),
    );
    if (action.hidesContent) {
      onVisibilityChanged?.call(c.target, c.targetId, false);
    } else if (action == ModerationAction.dismiss && c.autoHidden) {
      onVisibilityChanged?.call(c.target, c.targetId, true);
    }
    return next;
  }

  @override
  Future<String> revealAuthor(String caseId) async {
    await Future<void>.delayed(latency);
    final actor = _requireAdmin();
    final c = _cases[caseId];
    if (c == null) {
      throw const ReportException('Laporan tidak ditemukan', code: 'not_found');
    }
    final name = c.content.isAnonymous
        ? _anonAuthors[caseId]
        : c.content.authorUsername;
    if (name == null) {
      throw const ReportException('Penulis tidak diketahui', code: 'not_found');
    }
    _audit.insert(
      0,
      AuditEntry(
        actor: actor.username,
        action: 'reveal_author',
        target: caseId,
        createdAt: _clock(),
      ),
    );
    return name;
  }

  @override
  Future<List<AuditEntry>> fetchAuditLog() async {
    await Future<void>.delayed(latency);
    _requireAdmin();
    return List.of(_audit);
  }

  @override
  Future<void> submitAppeal({
    required String message,
    String? accountLabel,
  }) async {
    await Future<void>.delayed(latency);
    final m = message.trim();
    if (m.length < ModerationRules.appealMin ||
        m.length > ModerationRules.appealMax) {
      throw const ReportException(
        'Pesan banding 10-500 karakter',
        code: 'invalid',
      );
    }
    if (_appealSent) {
      throw const ReportException(
        'Banding hanya bisa diajukan satu kali.',
        code: 'already_appealed',
      );
    }
    _appealSent = true;
    _appeals.add(
      Appeal(
        id: 'ap${_appeals.length + 1}',
        message: m,
        createdAt: _clock(),
        accountLabel: accountLabel,
      ),
    );
  }

  @override
  Future<List<Appeal>> fetchAppeals({bool decided = false}) async {
    await Future<void>.delayed(latency);
    _requireModerator();
    final list = _appeals
        .where((a) => (a.status != AppealStatus.pending) == decided)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<Appeal> decideAppeal({
    required String appealId,
    required bool accept,
    String? note,
  }) async {
    await Future<void>.delayed(latency);
    final actor = _requireAdmin();
    final i = _appeals.indexWhere((a) => a.id == appealId);
    if (i < 0) {
      throw const ReportException('Banding tidak ditemukan', code: 'not_found');
    }
    if (_appeals[i].status != AppealStatus.pending) {
      throw const ReportException(
        'Banding ini sudah diputuskan',
        code: 'already_handled',
      );
    }
    final n = (note ?? '').trim();
    final now = _clock();
    _appeals[i] = _appeals[i].decided(
      status: accept ? AppealStatus.accepted : AppealStatus.rejected,
      by: actor.username,
      at: now,
      note: n.isEmpty ? null : n,
    );
    _audit.insert(
      0,
      AuditEntry(
        actor: actor.username,
        action: accept ? 'appeal_accept' : 'appeal_reject',
        target: appealId,
        detail: n.isEmpty ? null : n,
        createdAt: now,
      ),
    );
    return _appeals[i];
  }

  void _add(ReportCase c) => _cases[c.id] = c;

  void _seed() {
    final now = _clock();
    DateTime ago({int h = 0, int m = 0, int d = 0}) =>
        now.subtract(Duration(days: d, hours: h, minutes: m));

    _appeals.add(
      Appeal(
        id: 'ap0',
        message:
            'Saya tidak sengaja memposting tautan itu. Mohon dipulihkan, '
            'saya sudah membaca aturan komunitas.',
        createdAt: ago(h: 6),
        accountLabel: '@promo_kilat',
      ),
    );
    _add(
      ReportCase(
        target: ReportTarget.post,
        targetId: 'p3',
        status: ReportStatus.pending,
        reportCount: 4,
        reasons: {ReportReason.spam: 3, ReportReason.scam: 1},
        notes: const ['Posting hal yang sama berulang kali di banyak tag.'],
        firstReportedAt: ago(h: 5),
        lastReportedAt: ago(m: 20),
        autoHidden: true,
        priorViolations: 1,
        content: ReportedContent(
          body:
              'DIJUAL cepat!! Paket data murah, chat WA saja, transfer dulu ya. '
              'Kunjungi bit.ly/paket-murah-banget',
          authorUsername: 'promo_kilat',
          imageCount: 2,
          createdAt: ago(h: 7),
        ),
      ),
    );
    _add(
      ReportCase(
        target: ReportTarget.product,
        targetId: 'm7',
        status: ReportStatus.pending,
        reportCount: 2,
        reasons: {ReportReason.scam: 2},
        notes: const ['Minta DP lewat transfer sebelum bertemu.'],
        firstReportedAt: ago(h: 9),
        lastReportedAt: ago(h: 2),
        autoHidden: true,
        content: ReportedContent(
          title: 'Laptop gaming bekas, bonus mouse',
          body:
              'Mulus, jarang dipakai. DP transfer dulu Rp500.000 untuk booking, '
              'barang diantar setelah itu.',
          authorUsername: 'jualcepat88',
          imageCount: 4,
          meta: 'Rp3.500.000 - Second',
          createdAt: ago(d: 1),
        ),
      ),
    );
    _add(
      ReportCase(
        target: ReportTarget.comment,
        targetId: 'c12',
        status: ReportStatus.pending,
        reportCount: 2,
        reasons: {ReportReason.harassment: 1, ReportReason.hate: 1},
        firstReportedAt: ago(h: 3),
        lastReportedAt: ago(h: 1),
        priorViolations: 2,
        content: ReportedContent(
          body:
              'Kamu itu memang tidak pantas kuliah di sini, keluar saja sana.',
          authorUsername: 'komentator_x',
          createdAt: ago(h: 4),
        ),
      ),
    );
    _add(
      ReportCase(
        target: ReportTarget.post,
        targetId: 'p9',
        status: ReportStatus.pending,
        reportCount: 1,
        reasons: {ReportReason.privacy: 1},
        notes: const ['Memuat nomor HP dan alamat kos orang lain.'],
        firstReportedAt: ago(h: 12),
        lastReportedAt: ago(h: 12),
        content: ReportedContent(
          body:
              'Ini orangnya yang kemarin tidak mengembalikan buku. '
              'Kosnya di Jl. Mawar No. 4, HP 0812-xxxx-xxxx.',
          isAnonymous: true,
          createdAt: ago(h: 14),
        ),
      ),
    );
    _add(
      ReportCase(
        target: ReportTarget.message,
        targetId: 'msg-88',
        status: ReportStatus.pending,
        reportCount: 1,
        reasons: {ReportReason.harassment: 1},
        firstReportedAt: ago(d: 1, h: 2),
        lastReportedAt: ago(d: 1, h: 2),
        content: const ReportedContent(
          body: 'Balas dong, jangan sok jual mahal. Aku tahu kamu di mana.',
          authorUsername: 'pengirim_dm',
          lines: [
            'Kamu: Maaf, barangnya sudah terjual.',
            'pengirim_dm: Bohong. Kamu pasti jual ke orang lain.',
            'Kamu: Silakan cek statusnya di aplikasi.',
          ],
        ),
      ),
    );
    _add(
      ReportCase(
        target: ReportTarget.user,
        targetId: 'u-akun-palsu',
        status: ReportStatus.pending,
        reportCount: 1,
        reasons: {ReportReason.other: 1},
        notes: const ['Foto profil dan bio meniru akun BEM.'],
        firstReportedAt: ago(d: 2),
        lastReportedAt: ago(d: 2),
        content: const ReportedContent(
          title: '@bem_resmi_np',
          body: 'Bio: "Akun resmi BEM Nusa Putra. Hubungi untuk titip jual."',
          authorUsername: 'bem_resmi_np',
        ),
      ),
    );
    _add(
      ReportCase(
        target: ReportTarget.post,
        targetId: 'p5',
        status: ReportStatus.resolved,
        reportCount: 3,
        reasons: {ReportReason.adult: 3},
        firstReportedAt: ago(d: 3),
        lastReportedAt: ago(d: 3),
        handledAt: ago(d: 2),
        handledBy: 'mod_np',
        action: ModerationAction.hide,
        actionNote: 'Konten dewasa, melanggar aturan komunitas.',
        content: ReportedContent(
          body: '(Konten disembunyikan moderator)',
          authorUsername: 'akun_lama',
          available: false,
          createdAt: ago(d: 4),
        ),
      ),
    );
    _add(
      ReportCase(
        target: ReportTarget.comment,
        targetId: 'c3',
        status: ReportStatus.dismissed,
        reportCount: 1,
        reasons: {ReportReason.misinformation: 1},
        firstReportedAt: ago(d: 5),
        lastReportedAt: ago(d: 5),
        handledAt: ago(d: 4),
        handledBy: 'mod_np',
        action: ModerationAction.dismiss,
        content: ReportedContent(
          body:
              'Jadwal UAS katanya geser ke minggu depan, cek pengumuman prodi.',
          authorUsername: 'dina_kamila',
          createdAt: ago(d: 6),
        ),
      ),
    );
  }
}
