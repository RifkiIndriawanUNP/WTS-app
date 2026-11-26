import 'package:wts/core/preview/preview_runner.dart';
import 'package:wts/features/chat/chat_routes.dart';
import 'package:wts/features/market/market_routes.dart';
import 'package:wts/features/notifications/notifications_routes.dart';

/// flutter run -d edge -t lib/features/notifications/preview/notifications_preview.dart
void main() {
  runFeaturePreview(
    initialLocation: '/notifications',
    // Notifikasi membuka chat dan produk, jadi rute itu ikut dipasang.
    routes: [...notificationRoutes, ...chatRoutes, ...marketRoutes],
  );
}
