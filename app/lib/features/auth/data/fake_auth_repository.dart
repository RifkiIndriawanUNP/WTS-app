import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../profile/domain/prodi.dart';
import '../domain/account_restriction.dart';
import '../domain/user_profile.dart';
import 'auth_repository.dart';

/// Implementasi lokal tanpa backend. Pengguna dan sesi disimpan di
/// SharedPreferences; OTP disimulasikan di memori (kode: 123456).
///
/// Akun uji:
///  - banned@nusaputra.ac.id     -> layar "akun diblokir"
///  - suspended@nusaputra.ac.id  -> layar "akun ditangguhkan" (7 hari lagi)
///  - admin@nusaputra.ac.id      -> role admin
///  - mod@nusaputra.ac.id        -> role moderator
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.latency = const Duration(milliseconds: 600)});

  /// Jeda buatan agar indikator loading terlihat. Gunakan Duration.zero di tes.
  final Duration latency;

  static const String _usersKey = 'wts.fake.users';
  static const String _sessionKey = 'wts.fake.session';

  static const Set<String> _reservedUsernames = {
    'admin',
    'administrator',
    'moderator',
    'wts',
    'support',
    'anonim',
    'anonymous',
    'system',
  };
  static const String _bannedEmail = 'banned@nusaputra.ac.id';
  static const String _suspendedEmail = 'suspended@nusaputra.ac.id';
  static const String _adminEmail = 'admin@nusaputra.ac.id';
  static const String _modEmail = 'mod@nusaputra.ac.id';

  final Map<String, _OtpEntry> _otps = {};

  Future<void> _delay([Duration? d]) => Future<void>.delayed(d ?? latency);

  Future<Map<String, dynamic>> _loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_usersKey);
    if (raw == null || raw.isEmpty) {
      return <String, dynamic>{};
    }
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> _saveUsers(Map<String, dynamic> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usersKey, jsonEncode(users));
  }

  AccountRestriction? _restrictionFor(String email) {
    if (email == _bannedEmail) {
      return const AccountRestriction.banned();
    }
    if (email == _suspendedEmail) {
      return AccountRestriction.suspended(
        DateTime.now().add(const Duration(days: 7)),
      );
    }
    return null;
  }

  @override
  Future<UserProfile?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_sessionKey);
    if (email == null) {
      return null;
    }
    if (_restrictionFor(email) != null) {
      return null;
    }
    final users = await _loadUsers();
    final json = users[email];
    if (json == null) {
      return null;
    }
    return UserProfile.fromJson(Map<String, dynamic>.from(json as Map));
  }

  @override
  Future<void> sendOtp(String email) async {
    await _delay();
    final e = Validators.normalizeEmail(email);
    if (!Validators.isCampusEmail(e)) {
      throw const AuthException(
        'Hanya email @${AppConstants.campusEmailDomain} yang bisa masuk',
        code: 'invalid_domain',
      );
    }
    _otps[e] = _OtpEntry(
      code: AppConstants.simulatedOtp,
      expiresAt: DateTime.now().add(
        const Duration(minutes: AppConstants.otpValidMinutes),
      ),
      attemptsLeft: AppConstants.otpMaxAttempts,
    );
  }

  @override
  Future<VerifyResult> verifyOtp({
    required String email,
    required String code,
  }) async {
    await _delay();
    final e = Validators.normalizeEmail(email);
    final entry = _otps[e];

    if (entry == null || DateTime.now().isAfter(entry.expiresAt)) {
      _otps.remove(e);
      return const VerifyResult(VerifyOutcome.expired);
    }
    if (entry.attemptsLeft <= 0) {
      return const VerifyResult(VerifyOutcome.tooManyAttempts);
    }
    if (code != entry.code) {
      entry.attemptsLeft--;
      if (entry.attemptsLeft <= 0) {
        return const VerifyResult(VerifyOutcome.tooManyAttempts);
      }
      return VerifyResult(
        VerifyOutcome.invalidCode,
        attemptsLeft: entry.attemptsLeft,
      );
    }

    _otps.remove(e); // kode hanya bisa dipakai sekali
    return _afterAuth(e);
  }

  @override
  Future<VerifyResult> signInWithGoogle({required String email}) async {
    await _delay();
    final e = Validators.normalizeEmail(email);
    if (!Validators.isCampusEmail(e)) {
      return const VerifyResult(VerifyOutcome.invalidDomain);
    }
    return _afterAuth(e);
  }

  Future<VerifyResult> _afterAuth(String email) async {
    final restriction = _restrictionFor(email);
    if (restriction != null) {
      return VerifyResult(
        restriction.banned ? VerifyOutcome.banned : VerifyOutcome.suspended,
        restriction: restriction,
      );
    }
    final users = await _loadUsers();
    final json = users[email];
    if (json == null) {
      return const VerifyResult(VerifyOutcome.newUser);
    }

    final user = UserProfile.fromJson(Map<String, dynamic>.from(json as Map));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, email);
    return VerifyResult(VerifyOutcome.existingUser, user: user);
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    await _delay(const Duration(milliseconds: 350));
    final u = Validators.normalizeUsername(username);
    if (_reservedUsernames.contains(u)) {
      return false;
    }
    final users = await _loadUsers();
    return !users.values.any((v) => (v as Map)['username'] == u);
  }

  @override
  Future<UserProfile> completeProfile({
    required String email,
    required String username,
    required bool acceptedTerms,
    int? prodiId,
    String? bio,
    String? avatarPath,
  }) async {
    await _delay();
    final e = Validators.normalizeEmail(email);
    final u = Validators.normalizeUsername(username);

    if (!acceptedTerms) {
      throw const AuthException(
        'Setujui Syarat & Ketentuan dulu',
        code: 'terms_required',
      );
    }
    if (Validators.username(u) != null) {
      throw const AuthException(
        'Username tidak valid',
        code: 'username_invalid',
      );
    }
    if (Validators.bio(bio) != null) {
      throw const AuthException('Bio terlalu panjang', code: 'bio_invalid');
    }

    final users = await _loadUsers();
    final taken =
        _reservedUsernames.contains(u) ||
        users.values.any((v) => (v as Map)['username'] == u);
    if (taken) {
      throw const AuthException(
        'Username sudah dipakai',
        code: 'username_taken',
      );
    }

    final now = DateTime.now();
    final cleanBio = (bio ?? '').trim();
    final user = UserProfile(
      id: 'u_${now.microsecondsSinceEpoch}',
      email: e,
      username: u,
      prodiId: prodiId,
      prodiName: findFakeProdi(prodiId)?.name,
      avatarPath: avatarPath,
      bio: cleanBio.isEmpty ? null : cleanBio,
      role: e == _adminEmail
          ? UserRole.admin
          : (e == _modEmail ? UserRole.moderator : UserRole.user),
      createdAt: now,
    );

    users[e] = user.toJson();
    await _saveUsers(users);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, e);
    return user;
  }

  @override
  Future<UserProfile> updateProfile({
    required String email,
    required String username,
    int? prodiId,
    String? bio,
    String? avatarPath,
  }) async {
    await _delay();
    final e = Validators.normalizeEmail(email);
    final u = Validators.normalizeUsername(username);

    final users = await _loadUsers();
    final raw = users[e];
    if (raw == null) {
      throw const AuthException('Akun tidak ditemukan', code: 'not_found');
    }
    final current = UserProfile.fromJson(Map<String, dynamic>.from(raw as Map));

    if (Validators.bio(bio) != null) {
      throw const AuthException('Bio terlalu panjang', code: 'bio_invalid');
    }

    DateTime? usernameChangedAt = current.usernameChangedAt;
    if (u != current.username) {
      if (Validators.username(u) != null) {
        throw const AuthException(
          'Username tidak valid',
          code: 'username_invalid',
        );
      }
      if (current.usernameUnlockAt(DateTime.now()) != null) {
        throw const AuthException(
          'Username baru bisa diganti lagi nanti',
          code: 'username_cooldown',
        );
      }
      final taken =
          _reservedUsernames.contains(u) ||
          users.entries.any(
            (en) => en.key != e && (en.value as Map)['username'] == u,
          );
      if (taken) {
        throw const AuthException(
          'Username sudah dipakai',
          code: 'username_taken',
        );
      }
      usernameChangedAt = DateTime.now();
    }

    final cleanBio = (bio ?? '').trim();
    final updated = UserProfile(
      id: current.id,
      email: current.email,
      createdAt: current.createdAt,
      role: current.role,
      status: current.status,
      suspendedUntil: current.suspendedUntil,
      username: u,
      prodiId: prodiId,
      prodiName: findFakeProdi(prodiId)?.name,
      avatarPath: avatarPath,
      bio: cleanBio.isEmpty ? null : cleanBio,
      usernameChangedAt: usernameChangedAt,
    );
    users[e] = updated.toJson();
    await _saveUsers(users);
    return updated;
  }

  @override
  Future<void> deleteAccount(String email) async {
    await _delay();
    final e = Validators.normalizeEmail(email);
    final users = await _loadUsers();
    users.remove(e);
    await _saveUsers(users);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  @override
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}

class _OtpEntry {
  _OtpEntry({
    required this.code,
    required this.expiresAt,
    required this.attemptsLeft,
  });

  final String code;
  final DateTime expiresAt;
  int attemptsLeft;
}
