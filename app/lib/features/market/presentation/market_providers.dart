import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wts/core/session/session.dart';
import 'package:wts/features/market/data/fake_market_repository.dart';
import 'package:wts/features/market/domain/market_repository.dart';
import 'package:wts/features/market/domain/market_transaction.dart';
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

extension MarketSortLabel on MarketSort {
  String get label {
    switch (this) {
      case MarketSort.newest:
        return 'Terbaru';
      case MarketSort.priceAsc:
        return 'Harga terendah';
      case MarketSort.priceDesc:
        return 'Harga tertinggi';
      case MarketSort.endingSoon:
        return 'Segera berakhir';
    }
  }
}

const _unset = Object();

class MarketFilter {
  const MarketFilter({
    this.query = '',
    this.category,
    this.type,
    this.condition,
    this.minPrice,
    this.maxPrice,
    this.negotiable,
    this.handover,
    this.sort = MarketSort.newest,
  });

  final String query;
  final String? category;
  final ListingType? type;
  final ItemCondition? condition;
  final int? minPrice;
  final int? maxPrice;

  /// null = semua, true = "Bisa nego", false = "Harga pas".
  final bool? negotiable;
  final Handover? handover;
  final MarketSort sort;

  /// Jumlah filter aktif (untuk titik penanda tombol filter).
  int get activeCount =>
      (type != null ? 1 : 0) +
      (category != null ? 1 : 0) +
      (condition != null ? 1 : 0) +
      (minPrice != null ? 1 : 0) +
      (maxPrice != null ? 1 : 0) +
      (negotiable != null ? 1 : 0) +
      (handover != null ? 1 : 0);

  MarketFilter copyWith({
    String? query,
    Object? category = _unset,
    Object? type = _unset,
    Object? condition = _unset,
    Object? minPrice = _unset,
    Object? maxPrice = _unset,
    Object? negotiable = _unset,
    Object? handover = _unset,
    MarketSort? sort,
  }) {
    return MarketFilter(
      query: query ?? this.query,
      category:
          identical(category, _unset) ? this.category : category as String?,
      type: identical(type, _unset) ? this.type : type as ListingType?,
      condition: identical(condition, _unset)
          ? this.condition
          : condition as ItemCondition?,
      minPrice: identical(minPrice, _unset) ? this.minPrice : minPrice as int?,
      maxPrice: identical(maxPrice, _unset) ? this.maxPrice : maxPrice as int?,
      negotiable:
          identical(negotiable, _unset) ? this.negotiable : negotiable as bool?,
      handover:
          identical(handover, _unset) ? this.handover : handover as Handover?,
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

  void setType(ListingType? type) => state = state.copyWith(type: type);

  void setSort(MarketSort sort) => state = state.copyWith(sort: sort);

  void replace(MarketFilter next) => state = next;
}

/// Filter beranda Market (chip kategori, urutan, sheet filter).
final marketFilterProvider =
    NotifierProvider<MarketFilterNotifier, MarketFilter>(
  MarketFilterNotifier.new,
);

/// Filter halaman pencarian (terpisah dari beranda).
final searchFilterProvider =
    NotifierProvider<MarketFilterNotifier, MarketFilter>(
  MarketFilterNotifier.new,
);

/// Produk yang difavoritkan (lokal). Nanti terhubung ke tabel saved_products
/// lewat fitur `saved` milik anggota tim lain.
class SavedProductIds extends Notifier<Set<String>> {
  @override
  Set<String> build() => {'p3', 'p5', 'p6', 'p7'};

  void toggle(String id) {
    final next = {...state};
    if (!next.remove(id)) next.add(id);
    state = next;
  }

  void remove(String id) {
    if (!state.contains(id)) return;
    state = {...state}..remove(id);
  }
}

final savedProductIdsProvider =
    NotifierProvider<SavedProductIds, Set<String>>(SavedProductIds.new);

List<Product> applyMarketFilter(MarketFilter f, List<Product> input) {
  final q = f.query.toLowerCase();
  final out = input.where((p) {
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
    if (f.negotiable != null && p.negotiable != f.negotiable) return false;
    if (f.handover != null && p.handover != f.handover) return false;
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
  return ref
      .watch(productsProvider)
      .whenData((list) => applyMarketFilter(filter, list));
});

final searchResultsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final filter = ref.watch(searchFilterProvider);
  return ref
      .watch(productsProvider)
      .whenData((list) => applyMarketFilter(filter, list));
});

/// Produk yang difavoritkan (termasuk yang sudah terjual), urut sesuai daftar.
final favoriteProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final saved = ref.watch(savedProductIdsProvider);
  return ref.watch(productsProvider).whenData(
        (list) => list.where((p) => saved.contains(p.id)).toList(),
      );
});

/// Produk milik pengguna (dipakai bila nanti dibutuhkan filter "produk saya").
final myProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final meId = ref.watch(currentUserProvider).id;
  return ref.watch(productsProvider).whenData(
        (list) => list.where((p) => p.sellerId == meId).toList(),
      );
});

// ---------------------------------------------------------------- Pencarian

const kPopularSearches = <String>[
  'IoT',
  'Buku',
  'Elektronik',
  'Kos',
  'Perabot',
  'Keyboard',
];

/// Kata kunci tambahan untuk saran pencarian (selain judul produk).
const _kSuggestionSeeds = <String>[
  'esp32',
  'esp32 starter kit',
  'esp8266',
  'arduino uno',
  'jas lab',
  'buku kalkulus',
  'kalkulator casio',
  'keyboard mekanik',
  'laptop',
  'mouse wireless',
  'modul praktikum',
  'breadboard',
];

List<String> searchSuggestions(String query, List<Product> products) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final pool = <String>{
    ..._kSuggestionSeeds,
    for (final p in products) p.title.toLowerCase(),
  };
  final out = <String>[q];
  final starts = pool.where((s) => s != q && s.startsWith(q)).toList()
    ..sort((a, b) => a.length.compareTo(b.length));
  out.addAll(starts);
  if (out.length < 5) {
    final contains = pool
        .where((s) => s != q && !s.startsWith(q) && s.contains(q))
        .toList()
      ..sort((a, b) => a.length.compareTo(b.length));
    out.addAll(contains);
  }
  return out.take(5).toList();
}

class RecentSearches extends Notifier<List<String>> {
  @override
  List<String> build() => ['Paket esp32', 'Jas lab', 'Buku Bumi Tere Liye'];

  void add(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    state = [
      q,
      ...state.where((e) => e.toLowerCase() != q.toLowerCase()),
    ].take(8).toList();
  }

  void remove(String query) =>
      state = state.where((e) => e != query).toList();

  void clear() => state = const [];
}

final recentSearchesProvider =
    NotifierProvider<RecentSearches, List<String>>(RecentSearches.new);

// ---------------------------------------------------------------- Transaksi

/// Data transaksi contoh. Nanti diganti tabel transaksi/penawaran dari Supabase.
class MarketTransactionsNotifier extends Notifier<List<MarketTransaction>> {
  @override
  List<MarketTransaction> build() => const [
        MarketTransaction(
          id: 't1',
          productId: 'p4',
          title: 'Kalkulator Casio',
          counterpart: 'Nadia Putri',
          isSeller: true,
          price: 160000,
          stage: 1,
          phase: TransactionPhase.ongoing,
          badge: 'Terjadwal',
          infoKind: TransactionInfoKind.schedule,
          infoText: 'Sel, 24 Nov · 10.00 · Perpustakaan',
        ),
        MarketTransaction(
          id: 't2',
          productId: 'p1',
          title: 'Paket ESP32 WiFi + Bluetooth Starter Kit IoT',
          counterpart: 'Alexander Draco',
          isSeller: false,
          price: 160000,
          stage: 0,
          phase: TransactionPhase.ongoing,
          badge: 'Menunggu jawaban',
          infoKind: TransactionInfoKind.deadline,
          infoText: 'Kesepakatanmu berlaku 23 jam',
          awaitingReply: true,
        ),
        MarketTransaction(
          id: 't3',
          productId: 'p5',
          title: 'Lemari Mini 2 Pintu',
          counterpart: 'Anisa Rahma',
          isSeller: false,
          price: 190000,
          stage: 3,
          phase: TransactionPhase.done,
          badge: 'Selesai',
          infoKind: TransactionInfoKind.schedule,
          infoText: 'Sen, 17 Nov · 14.00 · Kantin',
        ),
        MarketTransaction(
          id: 't4',
          productId: 'p7',
          title: 'Modul Praktikum Basis Data',
          counterpart: 'Nadia Putri',
          isSeller: true,
          price: 15000,
          stage: 3,
          phase: TransactionPhase.done,
          badge: 'Selesai',
          infoKind: TransactionInfoKind.schedule,
          infoText: 'Jum, 14 Nov · 09.30 · Perpustakaan',
        ),
        MarketTransaction(
          id: 't5',
          productId: 'p10',
          title: 'Mouse Wireless Logitech M185',
          counterpart: 'Rian Pratama',
          isSeller: false,
          price: 50000,
          stage: 0,
          phase: TransactionPhase.cancelled,
          badge: 'Dibatalkan',
          infoKind: TransactionInfoKind.deadline,
          infoText: 'Dibatalkan sebelum dijawab penjual',
        ),
      ];

  static const _stageBadges = ['Terjadwal', 'Terjadwal', 'Sudah sampai', 'Selesai'];

  /// "Update Status COD": maju satu tahap; sampai "Terjual" -> selesai.
  void advance(String id) {
    state = [
      for (final t in state)
        if (t.id == id && t.phase == TransactionPhase.ongoing)
          _advanced(t)
        else
          t,
    ];
  }

  MarketTransaction _advanced(MarketTransaction t) {
    final next = (t.stage + 1).clamp(0, 3);
    return t.copyWith(
      stage: next,
      badge: _stageBadges[next],
      phase: next == 3 ? TransactionPhase.done : TransactionPhase.ongoing,
    );
  }

  void cancel(String id) {
    state = [
      for (final t in state)
        if (t.id == id)
          t.copyWith(
            phase: TransactionPhase.cancelled,
            badge: 'Dibatalkan',
            awaitingReply: false,
            infoKind: TransactionInfoKind.deadline,
            infoText: 'Kamu membatalkan kesepakatan ini',
          )
        else
          t,
    ];
  }
}

final marketTransactionsProvider =
    NotifierProvider<MarketTransactionsNotifier, List<MarketTransaction>>(
  MarketTransactionsNotifier.new,
);