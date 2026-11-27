import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wts/features/auth/domain/user_profile.dart';
import 'package:wts/features/auth/presentation/providers/auth_providers.dart';
import 'package:wts/features/profile/data/fake_profile_repository.dart';
import 'package:wts/features/profile/data/profile_repository.dart';
import 'package:wts/features/profile/presentation/providers/profile_providers.dart';
import 'package:wts/features/profile/presentation/screens/profile_screen.dart';
import 'package:wts/features/timeline/data/fake_post_repository.dart';
import 'package:wts/features/timeline/presentation/providers/feed_providers.dart';

final _me = UserProfile(
  id: 'u1',
  email: 'saya@nusaputra.ac.id',
  username: 'saya_mhs',
  prodiName: 'Teknik Informatika',
  bio: 'Suka ngoding',
  createdAt: DateTime(2026, 9, 1),
);

class _SignedIn extends AuthController {
  @override
  AuthState build() => AuthState(status: AuthStatus.signedIn, user: _me);
}

void main() {
  group('Postingan per penulis (repo palsu)', () {
    late FakePostRepository repo;
    setUp(
      () => repo = FakePostRepository(
        currentUser: () => _me,
        latency: Duration.zero,
      ),
    );

    test(
      'profil orang lain hanya berisi postingannya yang tidak anonim',
      () async {
        final page = await repo.fetchByAuthor(username: 'dina_kamila');
        expect(page.items, isNotEmpty);
        expect(
          page.items.every((p) => p.authorUsername == 'dina_kamila'),
          isTrue,
        );
        expect(page.items.every((p) => !p.isAnonymous), isTrue);
      },
    );

    test(
      'profil sendiri berisi postingan milik sendiri, terbaru dulu',
      () async {
        final page = await repo.fetchByAuthor(username: 'saya_mhs');
        expect(page.items.map((p) => p.id), ['p15', 'p11']);
        expect(page.items.every((p) => p.isMine), isTrue);
      },
    );

    test('pengguna tanpa postingan -> kosong', () async {
      final page = await repo.fetchByAuthor(username: 'tidak_ada');
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('paginasi memakai offset dan limit', () async {
      final first = await repo.fetchByAuthor(username: 'saya_mhs', limit: 1);
      expect(first.items.length, 1);
      expect(first.hasMore, isTrue);
      final second = await repo.fetchByAuthor(
        username: 'saya_mhs',
        offset: 1,
        limit: 1,
      );
      expect(second.items.single.id, isNot(first.items.single.id));
      expect(second.hasMore, isFalse);
    });
  });

  group('Postingan tersimpan (repo palsu)', () {
    test('urut simpanan terbaru dulu, batal simpan menghapus', () async {
      final repo = FakePostRepository(
        currentUser: () => _me,
        latency: Duration.zero,
      );
      expect((await repo.fetchSaved()).items, isEmpty);
      await repo.toggleSave('p4');
      await repo.toggleSave('p2');
      expect((await repo.fetchSaved()).items.map((p) => p.id), ['p2', 'p4']);
      await repo.toggleSave('p2');
      expect((await repo.fetchSaved()).items.map((p) => p.id), ['p4']);
      expect((await repo.fetchSaved()).items.single.isSaved, isTrue);
    });

    test('postingan yang dihapus tidak muncul lagi', () async {
      final repo = FakePostRepository(
        currentUser: () => _me,
        latency: Duration.zero,
      );
      await repo.toggleSave('p11');
      await repo.deletePost('p11');
      expect((await repo.fetchSaved()).items, isEmpty);
    });
  });

  group('FakeProfileRepository', () {
    final repo = FakeProfileRepository(
      currentUser: () => _me,
      latency: Duration.zero,
    );

    test('profil orang lain', () async {
      final p = await repo.fetchProfile('nadia_putri');
      expect(p.prodiName, 'Sistem Informasi');
      expect(p.initials, 'NA');
    });

    test('profil sendiri memakai data akun', () async {
      final p = await repo.fetchProfile('saya_mhs');
      expect(p.bio, 'Suka ngoding');
    });

    test('tidak dikenal -> not_found', () async {
      await expectLater(
        repo.fetchProfile('hantu'),
        throwsA(
          isA<ProfileException>().having((e) => e.code, 'code', 'not_found'),
        ),
      );
    });
  });

  group('Tampilan', () {
    late FakePostRepository posts;

    Widget app(Widget home) => ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_SignedIn.new),
        postRepositoryProvider.overrideWithValue(posts),
        profileRepositoryProvider.overrideWithValue(
          FakeProfileRepository(currentUser: () => _me, latency: Duration.zero),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: home)),
    );

    void bigScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    setUp(
      () => posts = FakePostRepository(
        currentUser: () => _me,
        latency: Duration.zero,
      ),
    );

    testWidgets('profil sendiri: info, aksi, dan postingan milik sendiri', (
      tester,
    ) async {
      bigScreen(tester);
      await tester.pumpWidget(app(const ProfileScreen()));
      await tester.pumpAndSettle();

      expect(find.text('@saya_mhs'), findsWidgets);
      expect(find.text('Teknik Informatika'), findsOneWidget);
      expect(find.text('Jurusan'), findsOneWidget);
      expect(find.text('Suka ngoding'), findsOneWidget);
      expect(find.text('Set Photo'), findsOneWidget);
      expect(find.text('Edit Info'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Postingan'), findsOneWidget);
      expect(find.text('Market'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);

      expect(
        find.text('Ada yang mau bentuk tim lomba debat antar kampus?'),
        findsOneWidget,
      );
      expect(find.textContaining('Tips lulus praktikum'), findsOneWidget);
    });

    testWidgets('tab Saved kosong lalu terisi setelah menyimpan', (
      tester,
    ) async {
      bigScreen(tester);
      await tester.pumpWidget(app(const ProfileScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Saved'));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada yang disimpan'), findsOneWidget);

      await tester.tap(find.text('Postingan'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Simpan').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Saved'));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada yang disimpan'), findsNothing);
      expect(find.byTooltip('Hapus dari simpanan'), findsOneWidget);
    });

    testWidgets('tab Market menampilkan keterangan sementara', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(app(const ProfileScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Market'));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada produk'), findsOneWidget);
    });

    testWidgets('Edit Info membuka layar Ubah Profil', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(app(const ProfileScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Info'));
      await tester.pumpAndSettle();
      expect(find.text('Ubah Profil'), findsOneWidget);
    });

    testWidgets('Settings membuka layar Pengaturan', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(app(const ProfileScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Pengaturan'), findsOneWidget);
      expect(find.text('saya@nusaputra.ac.id'), findsOneWidget);
    });

    testWidgets('profil orang lain: tanpa aksi ubah dan tanpa tab Saved', (
      tester,
    ) async {
      bigScreen(tester);
      await tester.pumpWidget(
        app(const ProfileScreen(username: 'dina_kamila', showBack: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('@dina_kamila'), findsWidgets);
      expect(find.text('Desain Komunikasi Visual'), findsOneWidget);
      expect(find.text('Set Photo'), findsNothing);
      expect(find.text('Saved'), findsNothing);
      expect(find.text('Lomba desain poster tingkat nasional'), findsOneWidget);
      expect(find.byTooltip('Laporkan pengguna'), findsOneWidget);
    });

    testWidgets('pengguna tidak dikenal menampilkan pesan', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(
        app(const ProfileScreen(username: 'hantu', showBack: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pengguna tidak ditemukan'), findsWidgets);
    });
  });
}
