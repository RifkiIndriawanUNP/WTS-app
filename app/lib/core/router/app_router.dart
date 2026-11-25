import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wts/core/router/main_shell.dart';
import 'package:wts/core/router/navigator_keys.dart';
import 'package:wts/core/router/placeholder_page.dart';
import 'package:wts/features/chat/chat_routes.dart';
import 'package:wts/features/market/market_routes.dart';
import 'package:wts/features/notifications/notifications_routes.dart';

/// Router 5 tab: Home, Market, Chat, Notifikasi, Profil.
/// Home dan Profil masih placeholder (dikerjakan anggota tim lain).
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/market',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const PlaceholderPage(
                  title: 'Home',
                  icon: Icons.home_rounded,
                  note: 'Linimasa dikerjakan anggota tim lain.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(routes: marketRoutes),
          StatefulShellBranch(routes: chatRoutes),
          StatefulShellBranch(routes: notificationRoutes),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const PlaceholderPage(
                  title: 'Profil',
                  icon: Icons.person_rounded,
                  note: 'Profil dikerjakan anggota tim lain.',
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
