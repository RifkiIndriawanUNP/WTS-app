import 'package:wts/core/preview/preview_runner.dart';
import 'package:wts/features/chat/chat_routes.dart';
import 'package:wts/features/market/market_routes.dart';

/// flutter run -d edge -t lib/features/market/preview/market_preview.dart
void main() {
  runFeaturePreview(
    initialLocation: '/market',
    // chatRoutes ikut dipasang karena tombol "Chat Penjual" membuka chat market.
    routes: [...marketRoutes, ...chatRoutes],
  );
}
