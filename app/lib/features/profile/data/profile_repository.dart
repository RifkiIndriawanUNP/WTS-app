import '../domain/public_profile.dart';

/// Kesalahan data profil. Kode: `not_found`, `network`.
class ProfileException implements Exception {
  const ProfileException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'ProfileException($code): $message';
}

/// Kontrak data profil orang lain. Profil sendiri diambil dari AuthController.
/// Tahap 4B menambah: ubah profil, ganti foto, hapus akun.
abstract class ProfileRepository {
  Future<PublicProfile> fetchProfile(String username);
}
