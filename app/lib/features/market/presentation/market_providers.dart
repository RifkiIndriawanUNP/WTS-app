import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wts/core/session/session.dart';
import 'package:wts/features/market/data/fake_market_repository.dart';
import 'package:wts/features/market/domain/market_repository.dart';
import 'package:wts/features/market/domain/product.dart';

/// Sementara memakai repository palsu. Nanti diganti implementasi Supabase.
final marketRepositoryProvider =
    Provider<MarketRepository>((ref) => FakeMarketRepository());

final productsProvider = StreamProvider<List<Product>>(
  (ref) => ref.watch(marketRepositoryProvider).watchProducts(),
);

final productByIdProvider =
    Provider.family<AsyncValue<Product?>, String>((ref, id) {
  return ref.watch(productsProvider).whenData(
        (list) => list.where((p) => p.id == id).firstOrNull,
      );
});

enum MarketSort { newest, priceAsc, priceDesc, endingSoon }

const _unset = Object();

class MarketFilter {
  const MarketFilter({
    this.query = '',
    this.category,
    this.type,
    this.condition,
    this.minPrice,
    this.maxPrice,
    this.onlyAvailable = false,
    this.onlyNegotiable = false,
    this.onlySaved = false,
    this.onlyMine = false,
    this.sort = MarketSort.newest,
  });

  final String query;
  final String? category;
  final ListingType? type;
  final ItemCondition? condition;
  final int? minPrice;
  final int? maxPrice;
  final bool onlyAvailable;
  final bool onlyNegotiable;
  final bool onlySaved;
  final bool onlyMine;
  final MarketSort sort;

  /// Jumlah filter lanjutan yang aktif (untuk badge tombol filter).
  int get advancedCount =>
      (type != null ? 1 : 0) +
      (condition != null ? 1 : 0) +
      (minPrice != null ? 1 : 0) +
      (maxPrice != null ? 1 : 0) +
      (onlyAvailable ? 1 : 0) +
      (onlyNegotiable ? 1 : 0) +
      (sort != MarketSort.newest ? 1 : 0);

  MarketFilter copyWith({
    String? query,
    Object? category = _unset,
    Object? type = _unset,
    Object? condition = _unset,
    Object? minPrice = _unset,
    Object? maxPrice = _unset,
    bool? onlyAvailable,
    bool? onlyNegotiable,
    bool? onlySaved,
    bool? onlyMine,
    MarketSort? sort,
  }) {
    return MarketFilter(
      query: query ?? this.query,
      category: identical(category, _unset)
          ? this.category
          : category as String?,
      type: identical(type, _unset) ? this.type : type as ListingType?,
      condition: identical(condition, _unset)
          ? this.condition
          : condition as ItemCondition?,
      minPrice:
          identical(minPrice, _unset) ? this.minPrice : minPrice as int?,
      maxPrice:
          identical(maxPrice, _unset) ? this.maxPrice : maxPrice as int?,
      onlyAvailable: onlyAvailable ?? this.onlyAvailable,
      onlyNegotiable: onlyNegotiable ?? this.onlyNegotiable,
      onlySaved: onlySaved ?? this.onlySaved,
      onlyMine: onlyMine ?? this.onlyMine,
      sort: sort ?? this.sort,
    );
  }
}

class MarketFilterNotifier extends Notifier<MarketFilter> {
  @override
  MarketFilter build() => const MarketFilter();

  void setQuery(String query) => state = state.copyWith(query: query);

  void setCategory(String? category) =>
      state = state.copyWith(category: category);

  void toggleSaved() => state = state.copyWith(onlySaved: !state.onlySaved);

  void toggleMine() => state = state.copyWith(onlyMine: !state.onlyMine);

  void replace(MarketFilter next) => state = next;
}

final marketFilterProvider =
    NotifierProvider<MarketFilterNotifier, MarketFilter>(
  MarketFilterNotifier.new,
);

/// Produk yang disimpan (lokal). Nanti terhubung ke tabel saved_products
/// lewat fitur `saved` milik anggota tim lain.
class SavedProductIds extends Notifier<Set<String>> {
  @override
  Set<String> build() => {'p5'};

  void toggle(String id) {
    final next = {...state};
    if (!next.remove(id)) next.add(id);
    state = next;
  }
}

final savedProductIdsProvider =
    NotifierProvider<SavedProductIds, Set<String>>(SavedProductIds.new);

List<Product> applyMarketFilter(
  List<Product> input,
  MarketFilter f, {
  required Set<String> saved,
  required String meId,
}) {
  final q = f.query.toLowerCase();
  final out = input.where((p) {
    if (f.onlyMine && p.sellerId != meId) return false;
    if (f.onlySaved && !saved.contains(p.id)) return false;
    if (q.isNotEmpty &&
        !'${p.title} ${p.description} ${p.category}'
            .toLowerCase()
            .contains(q)) {
      return false;
    }
    if (f.category != null && p.category != f.category) return false;
    if (f.type != null && p.listingType != f.type) return false;
    if (f.condition != null && p.condition != f.condition) return false;
    if (f.minPrice != null && p.price < f.minPrice!) return false;
    if (f.maxPrice != null && p.price > f.maxPrice!) return false;
    if (f.onlyAvailable && p.status != ProductStatus.available) return false;
    if (f.onlyNegotiable && !p.negotiable) return false;
    return true;
  }).toList();

  switch (f.sort) {
    case MarketSort.newest:
      out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case MarketSort.priceAsc:
      out.sort((a, b) => a.price.compareTo(b.price));
    case MarketSort.priceDesc:
      out.sort((a, b) => b.price.compareTo(a.price));
    case MarketSort.endingSoon:
      out.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
  }
  return out;
}

final visibleProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final filter = ref.watch(marketFilterProvider);
  final saved = ref.watch(savedProductIdsProvider);
  final meId = ref.watch(currentUserProvider).id;
  return ref.watch(productsProvider).whenData(
        (list) => applyMarketFilter(list, filter, saved: saved, meId: meId),
      );
});
