import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wts/features/market/domain/product.dart';
import 'package:wts/features/market/presentation/market_providers.dart';
import 'package:wts/features/market/presentation/market_style.dart';
import 'package:wts/shared/models/app_user.dart';
import 'package:wts/shared/widgets/common_widgets.dart';

const _kTabs = <String>['Semua', 'Dijual', 'Disewakan', 'Gratis'];
const _kTabTypes = <ListingType?>[
  null,
  ListingType.sell,
  ListingType.rent,
  ListingType.free,
];

/// Halaman "Favorit": daftar produk yang disimpan, geser untuk menghapus.
class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(favoriteProductsProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: MC.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            MarketTitleBar(title: 'Favorit', onBack: () => context.pop()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: PillSegmented(
                labels: _kTabs,
                index: _tab,
                height: 44,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    ErrorState(onRetry: () => ref.invalidate(productsProvider)),
                data: (all) {
                  final type = _kTabTypes[_tab];
                  final list = type == null
                      ? all
                      : all.where((p) => p.listingType == type).toList();
                  if (list.isEmpty) {
                    return const EmptyState(
                      icon: Icons.favorite_border_rounded,
                      title: 'Belum ada favorit',
                      message: 'Ketuk ikon hati pada barang untuk menyimpannya.',
                    );
                  }
                  return ListView(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + bottom),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                        child: Text(
                          '${list.length} Barang',
                          style: mt(
                            size: 13,
                            weight: FontWeight.w700,
                            color: MC.slate,
                          ),
                        ),
                      ),
                      for (final p in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Dismissible(
                            key: ValueKey('fav_${p.id}'),
                            direction: DismissDirection.endToStart,
                            dismissThresholds: const {
                              DismissDirection.endToStart: .55,
                            },
                            onDismissed: (_) => ref
                                .read(savedProductIdsProvider.notifier)
                                .remove(p.id),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 22),
                              decoration: BoxDecoration(
                                color: MC.red,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            child: _FavoriteTile(
                              product: p,
                              onTap: () =>
                                  context.push('/market/product/${p.id}'),
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      const _SwipeHint(),
                    ],
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

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final sold = p.isSold;
    final free = p.isFree;
    final seller = userById(p.sellerId);

    final Color thumb;
    final Color thumbCircle;
    final Color thumbIcon;
    final Color price;
    if (sold) {
      thumb = const Color(0xFFD9DEE6);
      thumbCircle = const Color(0xFFE9EDF2);
      thumbIcon = const Color(0xFF334155);
      price = MC.slateLight;
    } else if (free) {
      thumb = const Color(0xFFD7F2E8);
      thumbCircle = const Color(0xFFEAF8F2);
      thumbIcon = const Color(0xFF218E74);
      price = MC.green;
    } else {
      thumb = MC.peach;
      thumbCircle = MC.peachCircle;
      thumbIcon = MC.orangeDeep;
      price = MC.orange;
    }

    final Color tagBg;
    final Color tagFg;
    final String tag;
    if (sold) {
      tagBg = const Color(0xFFE5E9EF);
      tagFg = const Color(0xFF475569);
      tag = p.isRent ? 'DISEWA' : 'TERJUAL';
    } else if (free) {
      tagBg = MC.greenBg;
      tagFg = MC.green;
      tag = 'GRATIS';
    } else {
      tagBg = const Color(0xFFFEF3DC);
      tagFg = const Color(0xFFB45309);
      tag = p.isRent ? 'SEWA' : 'DIJUAL';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0F2F6)),
        boxShadow: softShadow(.05, 12),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 78,
                    height: 78,
                    child: sold || free
                        ? PeachPlaceholder(
                            circle: 34,
                            iconSize: 22,
                            color: thumb,
                            circleColor: thumbCircle,
                            iconColor: thumbIcon,
                          )
                        : (p.photoBytesList.isNotEmpty ||
                                p.imageUrls.isNotEmpty)
                            ? ProductMedia(product: p, circle: 34, iconSize: 22)
                            : PeachPlaceholder(
                                circle: 34,
                                iconSize: 22,
                                color: thumb,
                                circleColor: thumbCircle,
                                iconColor: thumbIcon,
                              ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              p.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: mt(
                                size: 15,
                                weight: FontWeight.w800,
                                color: MC.ink,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: tagBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              tag,
                              style: mt(
                                size: 11,
                                weight: FontWeight.w700,
                                color: tagFg,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sold ? p.priceLabel : (free ? 'Rp 0' : p.priceLabel),
                        style: mt(size: 17, weight: FontWeight.w800, color: price),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sold ? 'Sudah tidak tersedia' : seller.name,
                        style: mt(
                          size: 12.5,
                          weight: FontWeight.w500,
                          color: MC.slateLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE5EDFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.chevron_left_rounded, size: 18, color: MC.blue),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Geser ke kiri untuk menghapus dari Favorit. Geser sampai habis untuk langsung menghapus.',
              style: mt(
                size: 13,
                weight: FontWeight.w600,
                color: MC.blue,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}