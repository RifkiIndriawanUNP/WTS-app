import 'package:go_router/go_router.dart';
import 'package:wts/features/notifications/presentation/notifications_page.dart';

/// Rute fitur Notifikasi (tab ke-4).
final List<RouteBase> notificationRoutes = [
  GoRoute(
    path: '/notifications',
    builder: (context, state) => const NotificationsPage(),
  ),
];
