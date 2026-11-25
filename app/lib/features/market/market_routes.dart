import 'package:go_router/go_router.dart';
import 'package:wts/core/router/navigator_keys.dart';
import 'package:wts/features/market/presentation/create_product_page.dart';
import 'package:wts/features/market/presentation/market_page.dart';
import 'package:wts/features/market/presentation/product_detail_page.dart';

/// Rute fitur Market (dipasang ke router utama oleh app_router.dart).
final List<RouteBase> marketRoutes = [
  GoRoute(
    path: '/market',
    builder: (context, state) => const MarketPage(),
    routes: [
      GoRoute(
        path: 'new',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CreateProductPage(),
      ),
      GoRoute(
        path: 'product/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            ProductDetailPage(productId: state.pathParameters['id']!),
      ),
    ],
  ),
];
