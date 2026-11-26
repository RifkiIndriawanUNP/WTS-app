import 'package:go_router/go_router.dart';
import 'package:wts/core/router/navigator_keys.dart';
import 'package:wts/features/notifications/presentation/notification_settings_page.dart';
import 'package:wts/features/notifications/presentation/notifications_page.dart';

/// Rute fitur Notifikasi (tab ke-4).
final List<RouteBase> notificationRoutes = [
  GoRoute(
    path: '/notifications',
    builder: (context, state) => const NotificationsPage(),
    routes: [
      GoRoute(
        path: 'settings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationSettingsPage(),
      ),
    ],
  ),
];