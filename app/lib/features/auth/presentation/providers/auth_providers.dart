import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/validators.dart';
import '../../data/auth_repository.dart';
import '../../data/fake_auth_repository.dart';
import '../../domain/account_restriction.dart';
import '../../domain/user_profile.dart';

/// Ganti isi provider ini dengan implementasi Supabase saat backend siap.
/// Preview/tes memakai `authRepositoryProvider.overrideWithValue(...)`.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FakeAuthRepository(),
);

enum AuthStatus { unknown, signedOut, signedIn }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.pendingEmail,
    this.restriction,
  });

  final AuthStatus status;
  final UserProfile? user;

  /// Email yang sedang diverifikasi / didaftarkan (belum punya profil).
  final String? pendingEmail;

  /// Terisi bila akun ditangguhkan/diblokir (untuk layar pembatasan).
  final AccountRestriction? restriction;
}

class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthState build() => const AuthState();

  Future<UserProfile?> restore() async {
    final user = await _repo.restoreSession();
    state = user == null
        ? const AuthState(status: AuthStatus.signedOut)
        : AuthState(status: AuthStatus.signedIn, user: user);
    return user;
  }

  Future<void> requestOtp(String email) async {
    final e = Validators.normalizeEmail(email);
    await _repo.sendOtp(e);
    state = AuthState(status: AuthStatus.signedOut, pendingEmail: e);
  }

  Future<void> resendOtp() async {
    final e = state.pendingEmail;
    if (e == null) {
      return;
    }
    await _repo.sendOtp(e);
  }

  Future<VerifyResult> verifyOtp(String code) async {
    final e = state.pendingEmail;
    if (e == null) {
      return const VerifyResult(VerifyOutcome.expired);
    }
    final result = await _repo.verifyOtp(email: e, code: code);
    _apply(result, e);
    return result;
  }

  Future<VerifyResult> signInWithGoogle({required String email}) async {
    final e = Validators.normalizeEmail(email);
    final result = await _repo.signInWithGoogle(email: e);
    _apply(result, e);
    return result;
  }

  void _apply(VerifyResult result, String email) {
    switch (result.outcome) {
      case VerifyOutcome.existingUser:
        state = AuthState(status: AuthStatus.signedIn, user: result.user);
      case VerifyOutcome.newUser:
        state = AuthState(status: AuthStatus.signedOut, pendingEmail: email);
      case VerifyOutcome.banned:
      case VerifyOutcome.suspended:
        state = AuthState(
          status: AuthStatus.signedOut,
          restriction: result.restriction,
        );
      default:
        break;
    }
  }

  Future<bool> isUsernameAvailable(String username) =>
      _repo.isUsernameAvailable(username);

  Future<void> completeProfile({
    required String username,
    required bool acceptedTerms,
    int? prodiId,
    String? bio,
    String? avatarPath,
  }) async {
    final email = state.pendingEmail;
    if (email == null) {
      throw const AuthException(
        'Sesi pendaftaran berakhir. Silakan masuk ulang.',
        code: 'no_pending',
      );
    }
    final user = await _repo.completeProfile(
      email: email,
      username: username,
      acceptedTerms: acceptedTerms,
      prodiId: prodiId,
      bio: bio,
      avatarPath: avatarPath,
    );
    state = AuthState(status: AuthStatus.signedIn, user: user);
  }

  /// Mengembalikan profil baru. Melempar [AuthException] bila ditolak.
  Future<UserProfile> updateProfile({
    required String username,
    int? prodiId,
    String? bio,
    String? avatarPath,
  }) async {
    final current = state.user;
    if (current == null) {
      throw const AuthException('Silakan masuk dulu', code: 'not_found');
    }
    final user = await _repo.updateProfile(
      email: current.email,
      username: username,
      prodiId: prodiId,
      bio: bio,
      avatarPath: avatarPath,
    );
    state = AuthState(status: AuthStatus.signedIn, user: user);
    return user;
  }

  Future<void> deleteAccount() async {
    final current = state.user;
    if (current == null) {
      return;
    }
    await _repo.deleteAccount(current.email);
    state = const AuthState(status: AuthStatus.signedOut);
  }

  /// Batalkan pendaftaran yang belum selesai (kembali ke login).
  void cancelPending() => state = const AuthState(status: AuthStatus.signedOut);

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AuthState(status: AuthStatus.signedOut);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
