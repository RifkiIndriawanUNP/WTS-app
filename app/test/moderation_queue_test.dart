import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wts/features/auth/domain/user_profile.dart';
import 'package:wts/features/auth/presentation/providers/auth_providers.dart';
import 'package:wts/features/moderation/data/fake_report_repository.dart';
import 'package:wts/features/moderation/data/report_repository.dart';
import 'package:wts/features/moderation/domain/report.dart';
import 'package:wts/features/moderation/domain/report_case.dart';
import 'package:wts/features/moderation/presentation/providers/report_providers.dart';
import 'package:wts/features/moderation/presentation/screens/report_queue_screen.dart';
import 'package:wts/features/profile/presentation/screens/settings_screen.dart';
import 'package:wts/shared/widgets/widgets.dart';

UserProfile _user(UserRole role) => UserProfile(
  id: 'u-${role.name}',
  email: '${role.name}@nusaputra.ac.id',
  username: role.name == 'user' ? 'mahasiswa' : 'mod_np',
  role: role,
  createdAt: DateTime(2026, 9, 1),
);

class _SignedIn extends AuthController {
  _SignedIn(this._u);

  final UserProfile _u;

  @override
  AuthState build() => AuthState(status: AuthStatus.signedIn, user: _u);
}

FakeReportRepository _repo(UserRole role) => FakeReportRepository(
  latency: Duration.zero,
  currentUser: () => _user(role),
);

void main() {
  group('Antrean laporan (repo palsu)', () {
    test('pengguna biasa ditolak (forbidden)', () async {
      final repo = _repo(UserRole.user);
      await expectLater(
        repo.fetchQueue(),
        throwsA(
          isA<ReportException>().having((e) => e.code, 'code', 'forbidden'),
        ),
      );
      await expectLater(repo.pendingCount(), throwsA(isA<ReportException>()));
      await expectLater(
        repo.getCase('post:p3'),
        throwsA(isA<ReportException>()),
      );
    });

    test('tanpa pengguna -> ditolak', () async {
      final repo = FakeReportRepository(latency: Duration.zero);
      await expectLater(repo.fetchQueue(), throwsA(isA<ReportException>()));
    });

    test('moderator dan admin boleh membaca', () async {
      expect(await _repo(UserRole.moderator).fetchQueue(), isNotEmpty);
      expect(await _repo(UserRole.admin).fetchQueue(), isNotEmpty);
    });

    test('menunggu diurutkan dari prioritas tertinggi', () async {
      final list = await _repo(UserRole.moderator).fetchQueue();
      expect(list.every((c) => c.status == ReportStatus.pending), isTrue);
      for (var i = 1; i < list.length; i++) {
        expect(list[i - 1].priority >= list[i].priority, isTrue);
      }
      expect(list.first.id, 'post:p3');
    });

    test('tab selesai hanya berisi kasus yang sudah ditangani', () async {
      final list = await _repo(UserRole.moderator).fetchQueue(handled: true);
      expect(list, isNotEmpty);
      expect(list.every((c) => c.status.isHandled), isTrue);
    });

    test('filter jenis konten', () async {
      final list = await _repo(UserRole.moderator)
          .fetchQueue(target: ReportTarget.comment);
      expect(list, isNotEmpty);
      expect(list.every((c) => c.target == ReportTarget.comment), isTrue);
    });

    test('jumlah menunggu sama dengan panjang antrean', () async {
      final repo = _repo(UserRole.moderator);
      expect(await repo.pendingCount(), (await repo.fetchQueue()).length);
    });

    test('getCase tak dikenal -> not_found', () async {
      await expectLater(
        _repo(UserRole.moderator).getCase('post:tidak-ada'),
        throwsA(
          isA<ReportException>().having((e) => e.code, 'code', 'not_found'),
        ),
      );
    });

    test(
      'laporan baru masuk antrean dan melewati ambang auto-sembunyi',
      () async {
        final repo = _repo(UserRole.moderator);
        final before = await repo.pendingCount();
        await repo.submit(
          target: ReportTarget.post,
          targetId: 'p99',
          reason: ReportReason.spam,
        );
        expect(await repo.pendingCount(), before + 1);
        final c = await repo.getCase('post:p99');
        expect(c.reportCount, 1);
        expect(c.autoHidden, isFalse);
      },
    );

    test(
      'laporan ke konten yang sama menambah jumlah (bukan kasus baru)',
      () async {
        final repo = _repo(UserRole.moderator);
        final before = await repo.pendingCount();
        await repo.submit(
          target: ReportTarget.comment,
          targetId: 'c12',
          reason: ReportReason.spam,
          note: 'tambahan',
        );
        expect(await repo.pendingCount(), before);
        final c = await repo.getCase('comment:c12');
        expect(c.reportCount, 3);
        expect(c.autoHidden, isTrue); // ambang 3 pelapor
        expect(c.notes, contains('tambahan'));
        expect(c.reasons[ReportReason.spam], 1);
      },
    );

    test('pelapor yang sama tidak menghitung dua kali', () async {
      final repo = _repo(UserRole.moderator);
      await repo.submit(
        target: ReportTarget.post,
        targetId: 'p98',
        reason: ReportReason.spam,
      );
      await expectLater(
        repo.submit(
          target: ReportTarget.post,
          targetId: 'p98',
          reason: ReportReason.hate,
        ),
        throwsA(isA<ReportException>()),
      );
      expect((await repo.getCase('post:p98')).reportCount, 1);
    });

    test(
      'penipuan barang: 2 pelapor sudah cukup untuk auto-sembunyi',
      () async {
        final repo = _repo(UserRole.moderator);
        final c = await repo.getCase('product:m7');
        expect(c.reportCount, 2);
        expect(c.autoHidden, isTrue);
      },
    );
  });

  group('Layar antrean', () {
    Future<void> pump(WidgetTester tester, UserRole role) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = _repo(role);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _SignedIn(_user(role))),
            reportRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(home: ReportQueueScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('pengguna biasa melihat pesan khusus moderator', (
      tester,
    ) async {
      await pump(tester, UserRole.user);
      expect(find.text('Halaman ini khusus moderator'), findsOneWidget);
      expect(find.text('Selesai'), findsNothing);
    });

    testWidgets('moderator melihat kasus menunggu dan jumlahnya', (
      tester,
    ) async {
      await pump(tester, UserRole.moderator);
      expect(find.textContaining('Menunggu ('), findsOneWidget);
      expect(find.textContaining('DIJUAL cepat'), findsOneWidget);
      expect(find.text('Disembunyikan otomatis'), findsWidgets);
    });

    testWidgets('pindah ke tab Selesai', (tester) async {
      await pump(tester, UserRole.moderator);
      await tester.tap(find.text('Selesai'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('DIJUAL cepat'), findsNothing);
      expect(find.text('Ditindak'), findsWidgets);
    });

    testWidgets('filter Komentar menyaring daftar', (tester) async {
      await pump(tester, UserRole.moderator);
      await tester.tap(find.widgetWithText(GlassChip, 'Komentar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('tidak pantas kuliah'), findsOneWidget);
      expect(find.textContaining('DIJUAL cepat'), findsNothing);
    });

    testWidgets('ketuk kasus membuka detail', (tester) async {
      await pump(tester, UserRole.moderator);
      await tester.tap(find.textContaining('DIJUAL cepat'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Detail laporan'), findsOneWidget);
      expect(find.text('Ringkasan laporan'), findsOneWidget);
      expect(find.textContaining('4 pelapor'), findsOneWidget);
      expect(find.text('Riwayat terlapor'), findsOneWidget);
    });
  });

  group('Entri di Pengaturan', () {
    Future<void> pumpSettings(WidgetTester tester, UserRole role) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _SignedIn(_user(role))),
            reportRepositoryProvider.overrideWithValue(_repo(role)),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('moderator melihat menu Antrean laporan', (tester) async {
      await pumpSettings(tester, UserRole.moderator);
      expect(find.text('Antrean laporan'), findsOneWidget);
    });

    testWidgets('pengguna biasa tidak melihat menu moderasi', (tester) async {
      await pumpSettings(tester, UserRole.user);
      expect(find.text('Antrean laporan'), findsNothing);
      expect(find.text('Moderasi'), findsNothing);
    });
  });
}
