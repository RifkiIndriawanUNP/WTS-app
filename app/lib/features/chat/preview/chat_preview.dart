import 'package:wts/core/preview/preview_runner.dart';
import 'package:wts/features/chat/chat_routes.dart';
import 'package:wts/features/market/market_routes.dart';

/// flutter run -d edge -t lib/features/chat/preview/chat_preview.dart
void main() {
  runFeaturePreview(
    initialLocation: '/chat',
    // marketRoutes ikut dipasang karena kartu produk di chat membuka detail.
    routes: [...chatRoutes, ...marketRoutes],
  );
}
