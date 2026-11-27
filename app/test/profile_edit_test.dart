import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wts/features/auth/auth_routes.dart';
import 'package:wts/features/auth/data/fake_auth_repository.dart';
import 'package:wts/features/auth/domain/user_profile.dart';
import 'package:wts/features/auth/presentation/providers/auth_providers.dart';
import 'package:wts/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:wts/features/profile/presentation/screens/settings_screen.dart';
import 'package:wts/shared/widgets/widgets.dart';

class _SignedIn extends AuthController {
  _SignedIn(this.user);

  final UserProfile user;

  @override
  AuthState build() => AuthState(status: AuthStatus.signedIn, user: user);
}

void main() {
  late FakeAuthRepository repo;
  late UserProfile user;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> seed(WidgetTester tester, {bool recentlyRenamed = false}) async {
    repo = FakeAuthRepository(latency: Duration.zero);
    final created = await tester.runAsync(
      () => repo.completeProfile(
        email: 'saya@nusaputra.ac.id',
        username: recentlyRenamed ? 'nama_lama' : 'saya_mhs',
        acceptedTerms: true,
        prodiId: 1,
        bio: 'Halo',
      ),
    );
    user = created!;
    if (recentlyRenamed) {
      user = (await tester.runAsync(
        () => repo.updateProfile(
          email: 'saya@nusaputra.ac.id',
          username: 'saya_mhs',
          prodiId: 1,
          bio: 'Halo',
        ),
      ))!;
    }
  }

  overrides() => [
    authRepositoryProvider.overrideWithValue(repo),
    authControllerProvider.overrideWith(() => _SignedIn(user)),
  ];

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget host() => ProviderScope(
    overrides: overrides(),
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ),
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> openEdit(WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
  }

  GlassButton saveButton(WidgetTester tester) =>
      tester.widget<GlassButton>(find.widgetWithText(GlassButton, 'Simpan'));

  group('Ubah Profil', () {
    testWidgets('terisi data akun dan Simpan nonaktif sebelum ada perubahan', (
      tester,
    ) async {
      bigScreen(tester);
      await seed(tester);
      await openEdit(tester);

      expect(find.text('Ubah Profil'), findsOneWidget);
      expect(find.text('saya_mhs'), findsOneWidget);
      expect(find.text('Halo'), findsOneWidget);
      expect(find.text('Teknik Informatika'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('ubah bio -> Simpan aktif -> tersimpan dan layar menutup', (
      tester,
    ) async {
      bigScreen(tester);
      await seed(tester);
      await openEdit(tester);

      await tester.enterText(find.byType(TextField).at(1), 'Bio baru saya');
      await tester.pump();
      expect(saveButton(tester).onPressed, isNotNull);

      await tester.tap(find.widgetWithText(GlassButton, 'Simpan'));
      await tester.pumpAndSettle();

      expect(find.text('buka'), findsOneWidget); // kembali ke layar awal
      final container = ProviderScope.containerOf(
        tester.element(find.text('buka')),
      );
      expect(container.read(authControllerProvider).user?.bio, 'Bio baru saya');
    });

    testWidgets('mengosongkan bio menyimpan null', (tester) async {
      bigScreen(tester);
      await seed(tester);
      await openEdit(tester);

      await tester.enterText(find.byType(TextField).at(1), '');
      await tester.pump();
      await tester.tap(find.widgetWithText(GlassButton, 'Simpan'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.text('buka')),
      );
      expect(container.read(authControllerProvider).user?.bio, isNull);
    });

    testWidgets('username baru yang dicadangkan ditolak', (tester) async {
      bigScreen(tester);
      await seed(tester);
      await openEdit(tester);

      await tester.enterText(find.byType(TextField).first, 'admin');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Username sudah dipakai'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('username terlalu pendek menampilkan pesan', (tester) async {
      bigScreen(tester);
      await seed(tester);
      await openEdit(tester);

      await tester.enterText(find.byType(TextField).first, 'ab');
      await tester.pump();
      expect(find.text('Minimal 3 karakter'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('username terkunci 30 hari setelah diganti', (tester) async {
      bigScreen(tester);
      await seed(tester, recentlyRenamed: true);
      await openEdit(tester);

      expect(
        find.textContaining('Username baru bisa diganti lagi pada'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isFalse,
      );
    });

    testWidgets('ganti program studi mengaktifkan Simpan', (tester) async {
      bigScreen(tester);
      await seed(tester);
      await openEdit(tester);

      await tester.tap(find.text('Teknik Informatika'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Akuntansi'));
      await tester.pumpAndSettle();

      expect(find.text('Akuntansi'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNotNull);
    });
  });

  group('Pengaturan', () {
    Widget settingsApp() => ProviderScope(
      overrides: overrides(),
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const SettingsScreen(),
            ),
            GoRoute(
              path: AuthRoutes.login,
              builder: (context, state) =>
                  const Scaffold(body: Text('LAYAR LOGIN')),
            ),
          ],
        ),
      ),
    );

    testWidgets('menampilkan email, tentang, dan aksi sesi', (tester) async {
      bigScreen(tester);
      await seed(tester);
      await tester.pumpWidget(settingsApp());
      await tester.pumpAndSettle();

      expect(find.text('saya@nusaputra.ac.id'), findsOneWidget);
      expect(find.text('Syarat & Ketentuan'), findsOneWidget);
      expect(find.text('Aturan Komunitas'), findsOneWidget);
      expect(find.text(kAppVersionLabel), findsOneWidget);
      expect(find.text('Keluar'), findsOneWidget);
      expect(find.text('Hapus akun'), findsOneWidget);
    });

    testWidgets('Keluar meminta konfirmasi lalu ke layar login', (
      tester,
    ) async {
      bigScreen(tester);
      await seed(tester);
      await tester.pumpWidget(settingsApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();
      expect(find.text('Keluar dari WTS?'), findsOneWidget);

      await tester.tap(find.widgetWithText(GlassButton, 'Keluar'));
      await tester.pumpAndSettle();
      expect(find.text('LAYAR LOGIN'), findsOneWidget);
    });

    testWidgets('Hapus akun butuh mengetik username lalu menghapus akun', (
      tester,
    ) async {
      bigScreen(tester);
      await seed(tester);
      await tester.pumpWidget(settingsApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hapus akun'));
      await tester.pumpAndSettle();

      GlassButton confirm() => tester.widget<GlassButton>(
        find.widgetWithText(GlassButton, 'Hapus akun permanen'),
      );
      expect(confirm().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'salah');
      await tester.pump();
      expect(confirm().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'saya_mhs');
      await tester.pump();
      expect(confirm().onPressed, isNotNull);

      await tester.tap(find.widgetWithText(GlassButton, 'Hapus akun permanen'));
      await tester.pumpAndSettle();

      expect(find.text('LAYAR LOGIN'), findsOneWidget);
      expect(await tester.runAsync(repo.restoreSession), isNull);
    });

    testWidgets('Batal pada hapus akun tidak menghapus apa pun', (
      tester,
    ) async {
      bigScreen(tester);
      await seed(tester);
      await tester.pumpWidget(settingsApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hapus akun'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(find.text('Pengaturan'), findsOneWidget);
      expect(find.text('LAYAR LOGIN'), findsNothing);
    });
  });
}
