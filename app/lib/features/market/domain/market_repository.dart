import 'package:wts/features/market/domain/product.dart';

/// Kontrak data Market. Implementasi palsu: data/fake_market_repository.dart.
/// Implementasi Supabase nanti: data/supabase_market_repository.dart
/// (RPC create_product / extend_product / delete_product).
abstract class MarketRepository {
  Stream<List<Product>> watchProducts();

  Product? findById(String id);

  Future<Product> createProduct(NewProductInput input);

  Future<void> extendProduct(String id);

  Future<void> deleteProduct(String id);

  /// Dipakai chat market (dipesan / terjual / tersedia lagi) dan
  /// "terjual di luar WTS".
  Future<void> setStatus(String id, ProductStatus status);
}
