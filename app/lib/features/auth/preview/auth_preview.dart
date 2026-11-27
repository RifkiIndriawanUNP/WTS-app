// Preview fitur Login tanpa Supabase/Docker.
// Jalankan dari folder app/:
//   flutter run -d edge -t lib/features/auth/preview/auth_preview.dart
//
// Kode OTP simulasi: 123456. Akun uji: banned@, suspended@, admin@, mod@
// (@nusaputra.ac.id). Data lokal disimpan di browser (SharedPreferences).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/widgets.dart';
import '../auth_routes.dart';
import '../data/fake_auth_repository.dart';
import '../presentation/providers/auth_providers.dart';

void main() => runApp(
  ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository())],
    child: const _AuthPreviewApp(),
  ),
);

final GoRouter _router = GoRouter(
  initialLocation: AuthRoutes.splash,
  routes: [
    ...authRoutes,
    GoRoute(path: AuthRoutes.home, builder: (c, s) => const _HomeStub()),
  ],
);

class _AuthPreviewApp extends StatelessWidget {
  const _AuthPreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'WTS (preview login)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      routerConfig: _router,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) =>
          LiquidBackground(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Pengganti Home sampai tab Home milik C tersedia.
class _HomeStub extends ConsumerWidget {
  const _HomeStub();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider.select((s) => s.user));
    return GlassScaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UserAvatar(
                initials: user?.initials ?? '?',
                imagePath: user?.avatarPath,
                size: 80,
              ),
              const SizedBox(height: 12),
              Text('Masuk sebagai @${user?.username ?? '-'}'),
              const SizedBox(height: 16),
              SizedBox(
                width: 200,
                child: GlassButton(
                  label: 'Keluar',
                  onPressed: () async {
                    await ref.read(authControllerProvider.notifier).signOut();
                    if (context.mounted) context.go(AuthRoutes.login);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
