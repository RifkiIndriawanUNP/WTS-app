import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wts/core/utils/guard.dart';
import 'package:wts/shared/widgets/dialogs.dart';

/// Buka tautan eksternal setelah dialog peringatan (hanya http/https).
Future<void> confirmAndOpenLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    showSnack(context, 'Tautan tidak valid.');
    return;
  }
  final ok = await confirmDialog(
    context,
    title: 'Buka tautan eksternal?',
    message: 'Anda akan membuka tautan di luar WTS:\n\n$url',
    confirmLabel: 'Buka',
  );
  if (ok) await _launch(uri);
}

Future<void> openMaps(double lat, double lng) =>
    _launch(Uri.parse('https://www.google.com/maps?q=$lat,$lng'));

/// "0812..." / "+62812..." -> wa.me/62812...
Future<void> openWhatsApp(String phone) {
  var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('0')) digits = '62${digits.substring(1)}';
  return _launch(Uri.parse('https://wa.me/$digits'));
}

Future<void> _launch(Uri uri) async {
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Abaikan: tidak ada aplikasi yang bisa membuka tautan.
  }
}
