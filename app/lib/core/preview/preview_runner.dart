import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wts/core/router/navigator_keys.dart';
import 'package:wts/core/theme/app_theme.dart';

/// Menjalankan satu fitur saja (tanpa 5 tab) untuk preview:
///   flutter run -d edge -t lib/features/market/preview/market_preview.dart
void runFeaturePreview({
  required String initialLocation,
  required List<RouteBase> routes,
}) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    routes: routes,
  );
  runApp(
    ProviderScope(
      child: MaterialApp.router(
        title: 'WTS Preview',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        routerConfig: router,
      ),
    ),
  );
}
