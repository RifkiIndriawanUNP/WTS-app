// Preview Linimasa tanpa Supabase/Docker. Jalankan dari folder app/:
//   flutter run -d edge -t lib/features/timeline/preview/timeline_preview.dart
//
// Pengguna "masuk" otomatis sebagai @preview_user (postingan p11 = milikmu).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/data/fake_auth_repository.dart';
import '../../auth/domain/user_profile.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../presentation/screens/home_tab.dart';

class _SignedInAuth extends FakeAuthRepository {
  @override
  Future<UserProfile?> restoreSession() async => UserProfile(
    id: 'preview',
    email: 'preview@nusaputra.ac.id',
    username: 'preview_user',
    prodiName: 'Teknik Informatika',
    createdAt: DateTime.now(),
  );
}

void main() => runApp(
  ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(_SignedInAuth())],
    child: const _App(),
  ),
);

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WTS (preview linimasa)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) =>
          LiquidBackground(child: child ?? const SizedBox.shrink()),
      home: const _Boot(),
    );
  }
}

class _Boot extends ConsumerStatefulWidget {
  const _Boot();

  @override
  ConsumerState<_Boot> createState() => _BootState();
}

class _BootState extends ConsumerState<_Boot> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    ref.read(authControllerProvider.notifier).restore().then((_) {
      if (mounted) {
        setState(() => _ready = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: SafeArea(
        bottom: false,
        child: _ready
            ? const HomeTab()
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
