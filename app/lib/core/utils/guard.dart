import 'package:flutter/material.dart';
import 'package:wts/core/supabase/failure.dart';

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}

/// Jalankan aksi; jika gagal tampilkan pesan ramah (Failure.message).
Future<T?> guarded<T>(BuildContext context, Future<T> Function() action) async {
  try {
    return await action();
  } on Failure catch (e) {
    if (context.mounted) showSnack(context, e.message);
  } catch (_) {
    if (context.mounted) {
      showSnack(context, 'Terjadi kesalahan. Coba lagi.');
    }
  }
  return null;
}
