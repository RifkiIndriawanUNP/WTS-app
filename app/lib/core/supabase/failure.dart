import 'package:supabase_flutter/supabase_flutter.dart';

/// Error yang sudah ramah pengguna. Tangkap error Supabase lalu ubah dengan mapError().
class Failure implements Exception {
  const Failure(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Kode error berasal dari backend (lihat docs/Desain_Backend_WTS.txt bab 5).
const _messages = <String, String>{
  'rate_limit_exceeded': 'Terlalu sering. Coba lagi sebentar lagi.',
  'account_inactive': 'Akunmu sedang ditangguhkan atau tidak aktif.',
  'email_domain_not_allowed': 'Gunakan email kampus @nusaputra.ac.id.',
  'email_banned': 'Email ini tidak dapat digunakan.',
  'product_booked': 'Produk sudah dipesan pembeli lain.',
  'product_unavailable': 'Produk tidak tersedia.',
  'blocked': 'Tidak dapat melakukan aksi ini.',
  'dm_disabled': 'Pengguna ini menonaktifkan pesan.',
  'forbidden': 'Kamu tidak punya akses.',
  'invalid_state': 'Aksi tidak valid pada status saat ini.',
};

Failure mapError(Object error) {
  if (error is PostgrestException) {
    final code = error.message;
    return Failure(code, _messages[code] ?? 'Terjadi kesalahan. Coba lagi.');
  }
  if (error is AuthException) {
    return Failure('auth', error.message);
  }
  return const Failure(
    'unknown',
    'Terjadi kesalahan. Periksa koneksi internet.',
  );
}
