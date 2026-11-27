import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/post.dart';

/// Tautan bagikan. Tautan dalam aplikasi (deep link) belum ada; sementara
/// memakai skema `wts://`. Ganti saat A menetapkan domain/deep link.
String postShareLink(String postId) => 'wts://post/$postId';

String postShareText(Post post) {
  final text = post.caption.trim().replaceAll(RegExp(r'\s+'), ' ');
  final snippet = text.length > 90 ? '${text.substring(0, 90)}…' : text;
  return '${post.authorLabel} di WTS: $snippet\n${postShareLink(post.id)}';
}

/// Menyalin teks bagikan ke papan klip (tanpa paket tambahan).
/// Saat siap, ganti dengan share sheet sistem (share_plus).
Future<void> sharePost(BuildContext context, Post post) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: postShareText(post)));
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Tautan postingan disalin')));
}
