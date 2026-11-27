import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/post.dart';

const List<List<Color>> _palette = [
  [Color(0xFF38BDF8), Color(0xFF6366F1)],
  [Color(0xFF34D399), Color(0xFF0EA5E9)],
  [Color(0xFFFBBF24), Color(0xFFF43F5E)],
  [Color(0xFFA78BFA), Color(0xFF38BDF8)],
  [Color(0xFF2DD4BF), Color(0xFF3B82F6)],
  [Color(0xFFFB7185), Color(0xFFF59E0B)],
];

/// Satu gambar postingan. Tanpa path = gambar contoh (gradien). Path http =
/// jaringan; path lain = file lokal (Android) / blob (web).
/// Saat integrasi, path Storage diubah menjadi URL publik di repository.
class PostImageView extends StatelessWidget {
  const PostImageView({
    super.key,
    required this.image,
    this.fit = BoxFit.cover,
  });

  final PostImage image;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final colors = _palette[image.seed.abs() % _palette.length];
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 44,
          color: Colors.white.withValues(alpha: 0.75),
        ),
      ),
    );

    Widget error(BuildContext context, Object error, StackTrace? stackTrace) =>
        placeholder;
    final path = image.path;
    if (path == null) {
      return placeholder;
    }
    if (kIsWeb || path.startsWith('http')) {
      return Image.network(path, fit: fit, errorBuilder: error);
    }
    return Image.file(File(path), fit: fit, errorBuilder: error);
  }
}

/// Galeri di kartu: satu gambar tampil penuh; beberapa gambar bisa digeser
/// dengan penanda "1/5" dan titik.
class PostImageGallery extends StatefulWidget {
  const PostImageGallery({super.key, required this.images, this.onTap});

  final List<PostImage> images;
  final ValueChanged<int>? onTap;

  @override
  State<PostImageGallery> createState() => _PostImageGalleryState();
}

class _PostImageGalleryState extends State<PostImageGallery> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.images.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: count,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => GestureDetector(
                onTap: widget.onTap == null ? null : () => widget.onTap!(i),
                child: PostImageView(image: widget.images[i]),
              ),
            ),
            if (count > 1) ...[
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '${_index + 1}/$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < count; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _index ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(
                              alpha: i == _index ? 0.95 : 0.55,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
