import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/links.dart';
import 'glass_sheet.dart';

/// Membuka tautan di browser luar SETELAH konfirmasi, dengan domain tujuan
/// ditampilkan. Melindungi dari tautan penipuan/phishing di postingan,
/// komentar, dan chat.
Future<void> openLinkWithConfirm(BuildContext context, String url) async {
  final confirmed = await showGlassConfirm(
    context,
    title: 'Buka tautan?',
    message:
        'Kamu akan membuka ${Links.host(url)}\n\n$url\n\nHati-hati dengan tautan dari orang yang tidak kamu kenal. Jangan memasukkan kata sandi atau data pribadi.',
    confirmLabel: 'Buka',
  );
  if (confirmed != true || !context.mounted) {
    return;
  }

  final messenger = ScaffoldMessenger.of(context);
  try {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Tautan tidak bisa dibuka')),
      );
    }
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Tautan tidak bisa dibuka')),
    );
  }
}
