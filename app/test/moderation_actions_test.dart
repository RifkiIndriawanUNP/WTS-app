import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wts/features/auth/domain/user_profile.dart';
import 'package:wts/features/auth/presentation/providers/auth_providers.dart';
import 'package:wts/features/auth/presentation/screens/account_restricted_screen.dart';
import 'package:wts/features/moderation/data/fake_report_repository.dart';
import 'package:wts/features/moderation/data/report_repository.dart';
import 'package:wts/features/moderation/domain/moderation_action.dart';
import 'package:wts/features/moderation/domain/report.dart';
import 'package:wts/features/moderation/domain/report_case.dart';
import 'package:wts/features/moderation/presentation/providers/report_providers.dart';
import 'package:wts/features/moderation/presentation/screens/report_detail_screen.dart';
import 'package:wts/features/moderation/presentation/screens/report_queue_screen.dart';
import 'package:wts/features/timeline/data/fake_post_repository.dart';
import 'package:wts/features/timeline/domain/post.dart';
import 'package:wts/shared/widgets/widgets.dart';

UserProfile _user(UserRole role) => UserProfile(
  id: 'u-${role.name}',
  email: '${role.name}@nusaputra.ac.id',
  username: role == UserRole.admin ? 'admin_np' : 'mod_np',
  role: role,
  createdAt: DateTime(2026, 9, 1),
);

class _SignedIn extends AuthController {
  _SignedIn(this._u);

  final UserProfile _u;

  @override
  AuthState build() => AuthState(status: AuthStatus.signedIn, user: _u);
}

typedef _Visibility = ({ReportTarget target, String id, bool visible});

FakeReportRepository _repo(UserRole role, [List<_Visibility>? log]) =>
    FakeReportRepository(
      latency: Duration.zero,
      currentUser: () => _user(role),
      onVisibilityChanged: log == null
          ? null
          : (target, id, visible) =>
                log.add((target: target, id: id, visible: visible)),
    );

Matcher _code(String code) =>
    throwsA(isA<ReportException>().having((e) => e.code, 'code', code));

void main() {
  group('Tindakan moderasi (repo palsu)', () {
    test('abaikan tanpa alasan: kasus jadi Diabaikan', () async {
      final repo = _repo(UserRole.moderator);
      final c = await repo.moderate(
        caseId: 'comment:c12',
        action: ModerationAction.dismiss,
      );
      expect(c.status, ReportStatus.dismissed);
      expect(c.action, ModerationAction.dismiss);
      expect(c.handledBy, 'mod_np');
      expect(c.priorViolations, 2); // tidak bertambah
      expect(
        (await repo.fetchQueue()).any((x) => x.id == 'comment:c12'),
        isFalse,
      );
      expect(
        (await repo.fetchQueue(handled: true))
            .any((x) => x.id == 'comment:c12'),
        isTrue,
      );
    });

    test('tindakan selain abaikan wajib beralasan', () async {
      final repo = _repo(UserRole.moderator);
      await expectLater(
        repo.moderate(caseId: 'comment:c12', action: ModerationAction.hide),
        _code('invalid'),
      );
      await expectLater(
        repo.moderate(
          caseId: 'comment:c12',
          action: ModerationAction.hide,
          reason: 'ab',
        ),
        _code('invalid'),
      );
    });

    test(
      'sembunyikan: konten jadi tidak tersedia dan callback dipanggil',
      () async {
        final log = <_Visibility>[];
        final repo = _repo(UserRole.moderator, log);
        final c = await repo.moderate(
          caseId: 'post:p3',
          action: ModerationAction.hide,
          reason: 'Spam berulang',
        );
        expect(c.status, ReportStatus.resolved);
        expect(c.content.available, isFalse);
        expect(c.actionNote, 'Spam berulang');
        expect(log.single.id, 'p3');
        expect(log.single.visible, isFalse);
      },
    );

    test(
      'peringatan menambah pelanggaran tanpa menyembunyikan konten',
      () async {
        final log = <_Visibility>[];
        final repo = _repo(UserRole.moderator, log);
        final c = await repo.moderate(
          caseId: 'comment:c12',
          action: ModerationAction.warn,
          reason: 'Bahasa kasar',
        );
        expect(c.priorViolations, 3);
        expect(c.content.available, isTrue);
        expect(log, isEmpty);
      },
    );

    test('abaikan kasus yang auto-sembunyi memulihkan konten', () async {
      final log = <_Visibility>[];
      final repo = _repo(UserRole.moderator, log);
      await repo.moderate(caseId: 'post:p3', action: ModerationAction.dismiss);
      expect(log.single.visible, isTrue);
    });

    test('moderator tidak boleh suspend/ban, admin boleh', () async {
      final mod = _repo(UserRole.moderator);
      await expectLater(
        mod.moderate(
          caseId: 'post:p3',
          action: ModerationAction.suspend7,
          reason: 'Spam',
        ),
        _code('forbidden'),
      );
      await expectLater(
        mod.moderate(
          caseId: 'post:p3',
          action: ModerationAction.ban,
          reason: 'Spam',
        ),
        _code('forbidden'),
      );
      final admin = _repo(UserRole.admin);
      final c = await admin.moderate(
        caseId: 'post:p3',
        action: ModerationAction.suspend7,
        reason: 'Spam berulang',
      );
      expect(c.status, ReportStatus.resolved);
      expect(c.priorViolations, 2);
      expect(c.content.available, isFalse);
    });

    test('pengguna biasa ditolak', () async {
      final repo = _repo(UserRole.user);
      await expectLater(
        repo.moderate(caseId: 'post:p3', action: ModerationAction.dismiss),
        _code('forbidden'),
      );
    });

    test('kasus yang sudah ditangani tidak bisa ditindak lagi', () async {
      final repo = _repo(UserRole.moderator);
      await repo.moderate(
        caseId: 'comment:c12',
        action: ModerationAction.dismiss,
      );
      await expectLater(
        repo.moderate(caseId: 'comment:c12', action: ModerationAction.dismiss),
        _code('already_handled'),
      );
    });

    test('kasus tak dikenal -> not_found', () async {
      await expectLater(
        _repo(UserRole.moderator)
            .moderate(caseId: 'post:zzz', action: ModerationAction.dismiss),
        _code('not_found'),
      );
    });

    test('setiap tindakan masuk audit log (khusus admin)', () async {
      final repo = _repo(UserRole.admin);
      await repo.moderate(
        caseId: 'comment:c12',
        action: ModerationAction.dismiss,
      );
      await repo.moderate(
        caseId: 'post:p3',
        action: ModerationAction.ban,
        reason: 'Penipuan berulang',
      );
      final log = await repo.fetchAuditLog();
      expect(log.map((e) => e.action), ['ban', 'dismiss']);
      expect(log.first.actor, 'admin_np');
      expect(log.first.detail, 'Penipuan berulang');
      await expectLater(
        _repo(UserRole.moderator).fetchAuditLog(),
        _code('forbidden'),
      );
    });

    test('buka identitas anonim: hanya admin dan tercatat', () async {
      await expectLater(
        _repo(UserRole.moderator).revealAuthor('post:p9'),
        _code('forbidden'),
      );
      final admin = _repo(UserRole.admin);
      expect(await admin.revealAuthor('post:p9'), 'budi_santoso');
      expect((await admin.fetchAuditLog()).first.action, 'reveal_author');
      expect(
        await admin.revealAuthor('post:p3'),
        'promo_kilat',
      ); // bukan anonim
    });
  });

  group('Banding (repo palsu)', () {
    test('pesan terlalu pendek ditolak, satu kali per akun', () async {
      final repo = _repo(UserRole.moderator);
      await expectLater(repo.submitAppeal(message: 'tolong'), _code('invalid'));
      await repo.submitAppeal(message: 'Saya tidak melanggar aturan apa pun.');
      await expectLater(
        repo.submitAppeal(message: 'Saya ajukan lagi ya, tolong ditinjau.'),
        _code('already_appealed'),
      );
    });

    test('banding bisa diajukan tanpa sesi', () async {
      final repo = FakeReportRepository(latency: Duration.zero);
      await repo.submitAppeal(message: 'Saya tidak melanggar aturan apa pun.');
    });

    test('moderator melihat, admin memutuskan', () async {
      final repo = _repo(UserRole.moderator);
      await repo.submitAppeal(message: 'Saya tidak melanggar aturan apa pun.');
      final pending = await repo.fetchAppeals();
      expect(pending.length, 2); // 1 contoh + 1 baru
      await expectLater(
        repo.decideAppeal(appealId: pending.first.id, accept: true),
        _code('forbidden'),
      );

      final admin = FakeReportRepository(
        latency: Duration.zero,
        currentUser: () => _user(UserRole.admin),
      );
      final seeded = (await admin.fetchAppeals()).single;
      final done = await admin.decideAppeal(
        appealId: seeded.id,
        accept: true,
        note: 'Dipulihkan',
      );
      expect(done.status, AppealStatus.accepted);
      expect(done.note, 'Dipulihkan');
      expect(await admin.fetchAppeals(), isEmpty);
      expect((await admin.fetchAppeals(decided: true)).single.id, seeded.id);
      await expectLater(
        admin.decideAppeal(appealId: seeded.id, accept: false),
        _code('already_handled'),
      );
    });
  });

  test('repo postingan palsu: sembunyikan lalu pulihkan', () async {
    final posts = FakePostRepository(
      currentUser: () => null,
      latency: Duration.zero,
    );
    Future<bool> inFeed() async {
      final page = await posts.fetchFeed(sort: PostSort.newest, limit: 50);
      return page.items.any((p) => p.id == 'p3');
    }

    expect(await inFeed(), isTrue);
    posts.setModerationHidden('p3', hidden: true);
    expect(await inFeed(), isFalse);
    posts.setModerationHidden('p3', hidden: false);
    expect(await inFeed(), isTrue);
  });

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('Layar detail: tindakan', () {
    Future<void> pumpDetail(
      WidgetTester tester,
      UserRole role,
      String caseId,
    ) async {
      tall(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _SignedIn(_user(role))),
            reportRepositoryProvider.overrideWithValue(_repo(role)),
          ],
          child: MaterialApp(home: ReportDetailScreen(caseId: caseId)),
        ),
      );
      await settle(tester);
    }

    testWidgets('moderator: suspend dan blokir terkunci', (tester) async {
      await pumpDetail(tester, UserRole.moderator, 'post:p3');
      expect(find.text('Khusus admin'), findsNWidgets(4));
      expect(find.text('Abaikan laporan'), findsOneWidget);
    });

    testWidgets('admin: tidak ada yang terkunci', (tester) async {
      await pumpDetail(tester, UserRole.admin, 'post:p3');
      expect(find.text('Khusus admin'), findsNothing);
    });

    testWidgets('abaikan -> kasus berstatus ditangani', (tester) async {
      await pumpDetail(tester, UserRole.moderator, 'post:p3');
      await tester.tap(find.text('Abaikan laporan'));
      await settle(tester);
      await tester.tap(find.widgetWithText(GlassButton, 'Abaikan laporan'));
      await settle(tester);
      expect(find.text('Penanganan'), findsOneWidget);
      expect(find.text('Tindakan'), findsNothing);
    });

    testWidgets('sembunyikan: tombol aktif setelah alasan diisi', (
      tester,
    ) async {
      await pumpDetail(tester, UserRole.moderator, 'comment:c12');
      await tester.tap(find.text('Sembunyikan konten'));
      await settle(tester);
      final button = find.widgetWithText(GlassButton, 'Sembunyikan konten');
      expect(tester.widget<GlassButton>(button).onPressed, isNull);
      await tester.enterText(
        find.byType(TextField),
        'Bahasa merendahkan orang lain',
      );
      await tester.pump();
      expect(tester.widget<GlassButton>(button).onPressed, isNotNull);
      await tester.tap(button);
      await settle(tester);
      expect(find.text('Penanganan'), findsOneWidget);
      expect(find.textContaining('Bahasa merendahkan'), findsOneWidget);
    });

    testWidgets('tombol buka identitas hanya untuk admin', (tester) async {
      await pumpDetail(tester, UserRole.moderator, 'post:p9');
      expect(find.text('Buka identitas'), findsNothing);
    });

    testWidgets('admin membuka identitas penulis anonim', (tester) async {
      await pumpDetail(tester, UserRole.admin, 'post:p9');
      await tester.tap(find.text('Buka identitas'));
      await settle(tester);
      await tester.tap(find.widgetWithText(GlassButton, 'Buka identitas'));
      await settle(tester);
      expect(find.text('@budi_santoso'), findsOneWidget);
    });
  });

  group('Banding di layar antrean', () {
    Future<void> pumpQueue(WidgetTester tester, UserRole role) async {
      tall(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _SignedIn(_user(role))),
            reportRepositoryProvider.overrideWithValue(_repo(role)),
          ],
          child: const MaterialApp(home: ReportQueueScreen()),
        ),
      );
      await settle(tester);
    }

    testWidgets('tab Banding menampilkan banding menunggu', (tester) async {
      await pumpQueue(tester, UserRole.moderator);
      await tester.tap(find.textContaining('Banding ('));
      await settle(tester);
      expect(find.text('@promo_kilat'), findsOneWidget);
      expect(find.text('Sudah diputuskan'), findsOneWidget);
    });

    testWidgets('admin menerima banding', (tester) async {
      await pumpQueue(tester, UserRole.admin);
      await tester.tap(find.textContaining('Banding ('));
      await settle(tester);
      await tester.tap(find.text('@promo_kilat'));
      await settle(tester);
      await tester.tap(find.widgetWithText(GlassButton, 'Terima banding'));
      await settle(tester);
      expect(find.text('Banding diterima'), findsOneWidget);
    });
  });

  group('Layar akun dibatasi: ajukan banding', () {
    testWidgets('kirim banding lalu tombol berubah', (tester) async {
      tall(tester);
      final repo = FakeReportRepository(latency: Duration.zero);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [reportRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: AccountRestrictedScreen()),
        ),
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(GlassButton, 'Ajukan banding'));
      await settle(tester);
      final send = find.widgetWithText(GlassButton, 'Kirim banding');
      expect(tester.widget<GlassButton>(send).onPressed, isNull);
      await tester.enterText(
        find.byType(TextField),
        'Saya tidak melanggar aturan apa pun.',
      );
      await tester.pump();
      await tester.tap(send);
      await settle(tester);
      expect(
        find.widgetWithText(GlassButton, 'Banding sudah diajukan'),
        findsOneWidget,
      );
      expect(find.textContaining('Banding terkirim'), findsOneWidget);
    });
  });
}
