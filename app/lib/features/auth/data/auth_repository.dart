import '../domain/account_restriction.dart';
import '../domain/user_profile.dart';

class AuthException implements Exception {
  const AuthException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'AuthException($code): $message';
}

enum VerifyOutcome {
  newUser,
  existingUser,
  invalidCode,
  expired,
  tooManyAttempts,
  banned,
  suspended,
  invalidDomain,
}

class VerifyResult {
  const VerifyResult(
    this.outcome, {
    this.attemptsLeft,
    this.user,
    this.restriction,
  });

  final VerifyOutcome outcome;
  final int? attemptsLeft;
  final UserProfile? user;

  /// Terisi untuk [VerifyOutcome.banned] dan [VerifyOutcome.suspended].
  final AccountRestriction? restriction;
}

/// Kontrak akses data autentikasi + profil sendiri. Saat ini diisi
/// FakeAuthRepository; implementasi Supabase (auth.signInWithOtp, tabel
/// profiles, RPC delete_my_account, touch_last_login) dibuat kemudian.
///
/// Untuk Supabase: login Google TIDAK dipakai (kontrak hanya email OTP).
/// Tombol Google di UI hanyalah simulasi lokal dan dihapus saat integrasi.
abstract class AuthRepository {
  Future<UserProfile?> restoreSession();

  Future<void> sendOtp(String email);

  Future<VerifyResult> verifyOtp({required String email, required String code});

  Future<VerifyResult> signInWithGoogle({required String email});

  Future<bool> isUsernameAvailable(String username);

  /// Membuat profil pertama setelah OTP. [acceptedTerms] harus true.
  /// Kode error: `username_invalid`, `username_taken`, `bio_invalid`, `terms_required`.
  Future<UserProfile> completeProfile({
    required String email,
    required String username,
    required bool acceptedTerms,
    int? prodiId,
    String? bio,
    String? avatarPath,
  });

  /// Mengganti isi profil (null = dikosongkan untuk kolom opsional).
  /// Kode error: `username_invalid`, `username_taken`, `username_cooldown`,
  /// `bio_invalid`, `not_found`.
  Future<UserProfile> updateProfile({
    required String email,
    required String username,
    int? prodiId,
    String? bio,
    String? avatarPath,
  });

  /// Menghapus akun (RPC delete_my_account). Mendaftar ulang dengan email
  /// yang sama menghasilkan akun baru.
  Future<void> deleteAccount(String email);

  Future<void> signOut();
}
