import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wts/core/theme/app_theme.dart';
import 'package:wts/features/market/domain/product.dart';
import 'package:wts/features/market/presentation/market_providers.dart';
import 'package:wts/shared/widgets/common_widgets.dart';
import 'package:wts/shared/widgets/glass.dart';

Color productStatusColor(ProductStatus s) {
  switch (s) {
    case ProductStatus.available:
      return AppColors.success;
    case ProductStatus.booked:
      return AppColors.warning;
    case ProductStatus.sold:
      return AppColors.danger;
  }
}

Widget buildProductMedia({
  required Product product,
  int index = 0,
  double iconSize = 36,
}) {
  if (index < product.photoBytesList.length) {
    return Image.memory(
      product.photoBytesList[index],
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => ImagePlaceholder(
        seed: product.seed + index,
        iconSize: iconSize,
      ),
    );
  }
  if (index < product.imageUrls.length && product.imageUrls[index].isNotEmpty) {
    return Image.network(
      product.imageUrls[index],
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const SkeletonBox(radius: 0);
      },
      errorBuilder: (_, _, _) => ImagePlaceholder(
        seed: product.seed + index,
        iconSize: iconSize,
      ),
    );
  }
  return ImagePlaceholder(
    seed: product.seed + index,
    iconSize: iconSize,
  );
}

class ProductCard extends ConsumerWidget {
  const ProductCard({super.key, required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(
      savedProductIdsProvider.select((s) => s.contains(product.id)),
    );
    return GlassCard(
      blur: 0,
      padding: EdgeInsets.zero,
      radius: 20,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.08,
            child: Stack(
              fit: StackFit.expand,
              children: [
                buildProductMedia(product: product, index: 0),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Row(
                    children: [
                      _Tag(
                        label: product.isRent
                            ? 'Sewa'
                            : (product.isUsed ? 'Second' : 'Baru'),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: GestureDetector(
                    onTap: () => ref
                        .read(savedProductIdsProvider.notifier)
                        .toggle(product.id),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .85),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        saved
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 18,
                        color: saved ? AppColors.danger : AppColors.ink,
                      ),
                    ),
                  ),
                ),
                if (product.status != ProductStatus.available)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: .35),
                      alignment: Alignment.center,
                      child: Text(
                        product.statusLabel.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.priceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}