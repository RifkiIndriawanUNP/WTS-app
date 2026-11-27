import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'glass_container.dart';

/// Avatar bulat: foto bila ada, kalau tidak inisial nama.
/// [glass] = bingkai kaca (profil besar). Di daftar/kartu pakai `glass: false`
/// agar tidak menambah lapisan blur.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.initials,
    this.imagePath,
    this.size = 96,
    this.glass = true,
  });

  final String initials;
  final String? imagePath;
  final double size;
  final bool glass;

  /// Web (preview di browser) memakai URL blob; Android memakai file lokal.
  /// Saat integrasi, URL avatar dari Storage memakai `Image.network`.
  Widget _photo(String path, Widget fallback) {
    Widget error(BuildContext context, Object error, StackTrace? stackTrace) =>
        fallback;
    if (kIsWeb || path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: error,
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      width: size,
      height: size,
      errorBuilder: error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = Center(
      child: Text(
        initials,
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: size * 0.34,
        ),
      ),
    );

    final content = SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: imagePath != null ? _photo(imagePath!, fallback) : fallback,
      ),
    );

    if (!glass) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
        child: content,
      );
    }
    return GlassContainer(radius: size, child: content);
  }
}
