import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth_routes.dart';
import '../../../../core/storage/app_prefs.dart';
import '../../../../shared/widgets/widgets.dart';
import '../providers/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final minDelay = Future<void>.delayed(const Duration(milliseconds: 1700));
    final user = await ref.read(authControllerProvider.notifier).restore();
    final seenIntro = await AppPrefs.hasSeenIntro();
    await minDelay;
    if (!mounted) {
      return;
    }

    if (user != null) {
      context.go(AuthRoutes.home);
    } else if (seenIntro) {
      context.go(AuthRoutes.login);
    } else {
      context.go(AuthRoutes.intro);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return GlassScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutBack,
                  // Hanya skala (tanpa Opacity): Opacity membuat blur kaca
                  // kehilangan latarnya selama animasi.
                  builder: (context, t, child) =>
                      Transform.scale(scale: 0.8 + 0.2 * t, child: child),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GlassContainer(
                        radius: 44,
                        blur: 22,
                        padding: const EdgeInsets.all(22),
                        child: Image.asset(
                          'assets/images/logo_wts.png',
                          width: 76,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'WTS',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Want to Sell, Want to Share',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Text(
                'Khusus mahasiswa Universitas Nusa Putra',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
