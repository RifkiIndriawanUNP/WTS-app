import '../constants/app_constants.dart';

/// Semua fungsi mengembalikan pesan error (String) atau null jika valid.
/// Aturan harus sama dengan constraint database (lihat 0001_schema.sql).
abstract final class Validators {
  static final RegExp _emailRegex = RegExp(
    r'^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$',
  );

  /// profiles.username: ^[a-z0-9_]{3,20}$
  static final RegExp _usernameRegex = RegExp(r'^[a-z0-9_]+$');

  static String normalizeEmail(String value) => value.trim().toLowerCase();

  static bool isCampusEmail(String value) => email(value) == null;

  static String? email(String? value) {
    final e = normalizeEmail(value ?? '');
    if (e.isEmpty) {
      return 'Masukkan email kampusmu';
    }
    if (!_emailRegex.hasMatch(e)) {
      return 'Format email belum benar';
    }
    if (!e.endsWith('@${AppConstants.campusEmailDomain}')) {
      return 'Gunakan email kampus @${AppConstants.campusEmailDomain}';
    }
    return null;
  }

  static String normalizeUsername(String value) => value.trim().toLowerCase();

  static String? username(String? value) {
    final u = normalizeUsername(value ?? '');
    if (u.isEmpty) {
      return 'Username wajib diisi';
    }
    if (u.length < AppConstants.usernameMin) {
      return 'Minimal ${AppConstants.usernameMin} karakter';
    }
    if (u.length > AppConstants.usernameMax) {
      return 'Maksimal ${AppConstants.usernameMax} karakter';
    }
    if (!_usernameRegex.hasMatch(u)) {
      return 'Hanya huruf kecil, angka, dan garis bawah (_)';
    }
    return null;
  }

  static String? bio(String? value) {
    final b = (value ?? '').trim();
    if (b.length > AppConstants.bioMax) {
      return 'Bio maksimal ${AppConstants.bioMax} karakter';
    }
    return null;
  }

  static bool isAllowedImagePath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) {
      return false;
    }
    final ext = path.substring(dot + 1).toLowerCase();
    return AppConstants.allowedImageExtensions.contains(ext);
  }
}
