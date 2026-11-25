import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wts/core/theme/app_theme.dart';
import 'package:wts/features/market/domain/product.dart';
import 'package:wts/features/market/presentation/market_providers.dart';
import 'package:wts/features/market/presentation/market_filter_sheet.dart';
import 'package:wts/features/market/presentation/product_card.dart';
import 'package:wts/shared/widgets/common_widgets.dart';
import 'package:wts/shared/widgets/glass.dart';

class MarketPage extends ConsumerStatefulWidget {
  const MarketPage({super.key});

  @override
  ConsumerState<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends ConsumerState<MarketPage> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(marketFilterProvider.notifier).setQuery(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(marketFilterProvider);
    final products = ref.watch(visibleProductsProvider);

    return GlassScaffold(
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: navSpace(context) - 24,
        ),
        child: FloatingActionButton(
          heroTag: 'market_fab',
          onPressed: () => context.push('/market/new'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            GlassHeader(
              title: 'WTS Market',
              subtitle: 'Want to Sell',
              leading: const WtsLogoMark(size: 30),
              actions: [
                GlassIconButton(
                  icon: filter.onlySaved
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  active: filter.onlySaved,
                  tooltip: 'Tersimpan',
                  onTap: () =>
                      ref.read(marketFilterProvider.notifier).toggleSaved(),
                ),
                GlassIconButton(
                  icon: Icons.inventory_2_outlined,
                  active: filter.onlyMine,
                  tooltip: 'Produk saya',
                  onTap: () =>
                      ref.read(marketFilterProvider.notifier).toggleMine(),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassSearchField(
                controller: _search,
                hint: 'Cari buku, gawai, catatan kuliah',
                onChanged: _onSearchChanged,
                onFilterTap: () => showMarketFilterSheet(context),
                filterCount: filter.advancedCount,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  GlassChip(
                    label: 'Semua',
                    selected: filter.category == null,
                    onTap: () => ref
                        .read(marketFilterProvider.notifier)
                        .setCategory(null),
                  ),
                  for (final c in kProductCategories) ...[
                    const SizedBox(width: 8),
                    GlassChip(
                      label: c,
                      selected: filter.category == c,
                      onTap: () => ref
                          .read(marketFilterProvider.notifier)
                          .setCategory(filter.category == c ? null : c),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: products.when(
                loading: () => const _GridSkeleton(),
                error: (e, _) => ErrorState(
                  onRetry: () => ref.invalidate(productsProvider),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Belum ada produk',
                      message:
                          'Coba ubah kata kunci atau filter, atau jadilah yang pertama memposting.',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(productsProvider);
                      await ref.read(productsProvider.future);
                    },
                    child: GridView.builder(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        4,
                        16,
                        navSpace(context) + 56,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: .72,
                      ),
                      itemCount: list.length,
                      itemBuilder: (context, i) => ProductCard(
                        product: list[i],
                        onTap: () =>
                            context.push('/market/product/${list[i].id}'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: .72,
      ),
      itemCount: 6,
      itemBuilder: (context, i) => const SkeletonBox(radius: 20),
    );
  }
}