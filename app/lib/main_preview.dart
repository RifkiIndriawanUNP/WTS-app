import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wts/core/router/app_router.dart';
import 'package:wts/core/theme/app_theme.dart';

/// Pintu masuk preview tanpa Supabase/Docker (semua data palsu).
///   flutter run -d edge -t lib/main_preview.dart
void main() {
  runApp(const ProviderScope(child: PreviewApp()));
}

class PreviewApp extends ConsumerWidget {
  const PreviewApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'WTS Preview',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
