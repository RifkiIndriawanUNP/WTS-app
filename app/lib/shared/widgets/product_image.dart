import 'dart:io';

import 'package:flutter/material.dart';
import 'package:wts/shared/widgets/common_widgets.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.productId,
    this.imagePaths = const [],
    this.index = 0,
    this.iconSize = 36,
  });

  final String productId;
  final List<String> imagePaths;
  final int index;
  final double iconSize;

  static const Map<String, List<String>> sampleImages = {
    'p1': ['assets/images/products/esp32.png'],
    'p2': ['assets/images/products/jas_lab.png'],
    'p3': ['assets/images/products/buku.png'],
    'p4': ['assets/images/products/kalkulator.png'],
    'p5': ['assets/images/products/laptop.png'],
    'p6': ['assets/images/products/proyektor.png'],
    'p7': ['assets/images/products/modul.png'],
    'p8': ['assets/images/products/almamater.png'],
    'p9': ['assets/images/products/breadboard.png'],
    'p10': ['assets/images/products/mouse.png'],
  };

  @override
  Widget build(BuildContext context) {
    if (imagePaths.isNotEmpty && index < imagePaths.length) {
      return Image.file(
        File(imagePaths[index]),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _assetOrPlaceholder(),
      );
    }

    return _assetOrPlaceholder();
  }

  Widget _assetOrPlaceholder() {
    final images = sampleImages[productId];

    if (images != null && index < images.length) {
      return Image.asset(
        images[index],
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return ImagePlaceholder(
      seed: productId.codeUnits.fold<int>(0, (a, b) => a + b),
      iconSize: iconSize,
    );
  }
}