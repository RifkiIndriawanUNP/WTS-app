import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wts/features/market/domain/product.dart';
import 'package:wts/features/market/presentation/market_providers.dart';
import 'package:wts/features/market/presentation/market_style.dart';
import 'package:wts/shared/widgets/app_icons.dart';

/// Tinggi tetap sel grid agar baris rapi (foto 142 + teks).
const double kCardExtentPlain = 228;
const double kCardExtentWithPill = 262;

class ProductCard extends ConsumerWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.showTypePill = false,
    this.highlight = '',
  });

  final Product product;
  final VoidCallback onTap;

  /// Tampilkan pil "Dijual/Sewa/Gratis" di atas judul (hasil pencarian).
  final bool showTypePill;

  /// Kata kunci yang dicetak biru pada judul.
  final String highlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(
      savedProductIdsProvider.select((s) => s.contains(product.id)),
    );
    final style = listingStyleOf(product.listingType);
    final titleStyle = mt(
      size: 14,
      weight: FontWeight.w700,
      color: MC.text,
      height: 1.3,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(.07, 14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 142,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ProductMedia(product: product, circle: 64, iconSize: 28),
                      if (product.status != ProductStatus.available)
                        Container(
                          color: Colors.white.withValues(alpha: .55),
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: MC.ink.withValues(alpha: .78),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              product.statusLabel,
                              style: mt(
                                size: 12,
                                weight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: _ConditionTag(
                          label: product.isUsed ? 'Second' : 'Baru',
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: _HeartButton(
                          saved: saved,
                          onTap: () => ref
                              .read(savedProductIdsProvider.notifier)
                              .toggle(product.id),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showTypePill) ...[
                          ListingPill(type: product.listingType),
                          const SizedBox(height: 12),
                        ],
                        Text.rich(
                          highlightSpan(
                            product.title,
                            highlight,
                            base: titleStyle,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Text(
                          product.priceLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: mt(
                            size: 16,
                            weight: FontWeight.w800,
                            color: style.price,
                          ),
                        ),
                      ],
                    ),
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

class _ConditionTag extends StatelessWidget {
  const _ConditionTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: mt(size: 12, weight: FontWeight.w600, color: MC.text),
      ),
    );
  }
}

class _HeartButton extends StatelessWidget {
  const _HeartButton({required this.saved, required this.onTap});

  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: AppIcon(
          saved ? WtsIcons.heartFilled : WtsIcons.heart,
          size: 17,
          color: saved ? MC.red : MC.ink,
        ),
      ),
    );
  }
}