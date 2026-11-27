// Pintu masuk PREVIEW pribadi (tanpa Supabase/Docker). Jalankan dari app/:
//   flutter run -d edge -t lib/main_preview.dart
//
// File ini milikmu sendiri untuk mencoba fitur B. Jangan di-commit jika
// main_preview.dart milik tim (A) sudah ada; simpan sebagai salinan lokal.
//
// Cara menambah fitur baru: ganti placeholder di daftar `children`
// pada `_PreviewShellState.build` dengan layar asli, dan tambahkan route fitur ke `_router`.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_routes.dart';
import 'features/auth/data/fake_auth_repository.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/timeline/presentation/screens/home_tab.dart';
import 'shared/widgets/widgets.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ],
      child: const _PreviewApp(),
    ),
  );
}

final GoRouter _router = GoRouter(
  initialLocation: AuthRoutes.splash,
  routes: [
    ...authRoutes,
    GoRoute(
      path: AuthRoutes.home,
      builder: (context, state) => const _PreviewShell(),
    ),
  ],
);

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'WTS (preview)',
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

const List<GlassNavItem> _navItems = [
  GlassNavItem(icon: Icons.home_rounded, label: 'Home'),
  GlassNavItem(icon: Icons.storefront_rounded, label: 'Market'),
  GlassNavItem(icon: Icons.chat_bubble_rounded, label: 'Chat'),
  GlassNavItem(icon: Icons.notifications_rounded, label: 'Notifikasi'),
  GlassNavItem(icon: Icons.person_rounded, label: 'Profil'),
];

class _PreviewShell extends StatefulWidget {
  const _PreviewShell();

  @override
  State<_PreviewShell> createState() => _PreviewShellState();
}

class _PreviewShellState extends State<_PreviewShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      extendBody: true,
      bottomNavigationBar: GlassBottomNav(
        items: _navItems,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: [
            // Isi tiap tab: ganti placeholder dengan layar asli seiring tahap selesai.
            HomeTab(onOpenProfile: () => setState(() => _index = 4)),
            const _Placeholder('Market (milik D)'),
            const _Placeholder('Chat (milik B-DM / D)'),
            const _Placeholder('Notifikasi'),
            const ProfileScreen(),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
