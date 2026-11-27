import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wts/core/constants/app_constants.dart';
import 'package:wts/features/auth/data/auth_repository.dart';
import 'package:wts/features/auth/data/fake_auth_repository.dart';
import 'package:wts/features/auth/domain/user_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = FakeAuthRepository(latency: Duration.zero);
  });

  const email = 'fajar.kurniawan@nusaputra.ac.id';

  Future<UserProfile> register(String e, String username) =>
      repo.completeProfile(
        email: e,
        username: username,
        acceptedTerms: true,
        prodiId: 1,
        bio: 'Halo',
      );

  test('menolak email non-kampus saat kirim OTP', () async {
    await expectLater(
      repo.sendOtp('rina@gmail.com'),
      throwsA(isA<AuthException>()),
    );
  });

  test('OTP salah mengurangi sisa percobaan, lalu terkunci', () async {
    await repo.sendOtp(email);
    var result = await repo.verifyOtp(email: email, code: '000000');
    expect(result.outcome, VerifyOutcome.invalidCode);
    expect(result.attemptsLeft, AppConstants.otpMaxAttempts - 1);

    for (var i = 0; i < AppConstants.otpMaxAttempts - 1; i++) {
      result = await repo.verifyOtp(email: email, code: '000000');
    }
    expect(result.outcome, VerifyOutcome.tooManyAttempts);
  });

  test(
    'alur pengguna baru: OTP -> newUser -> profil -> sesi tersimpan',
    () async {
      await repo.sendOtp(email);
      final verify = await repo.verifyOtp(
        email: email,
        code: AppConstants.simulatedOtp,
      );
      expect(verify.outcome, VerifyOutcome.newUser);
      expect(await repo.restoreSession(), isNull);

      final user = await register(email, 'fajar_k');
      expect(user.initials, 'FA');
      expect(user.prodiName, 'Teknik Informatika');
      expect(user.role, UserRole.user);
      expect((await repo.restoreSession())?.username, 'fajar_k');

      // Kode hanya bisa dipakai sekali.
      final reuse = await repo.verifyOtp(
        email: email,
        code: AppConstants.simulatedOtp,
      );
      expect(reuse.outcome, VerifyOutcome.expired);

      await repo.signOut();
      expect(await repo.restoreSession(), isNull);
      await repo.sendOtp(email);
      final again = await repo.verifyOtp(
        email: email,
        code: AppConstants.simulatedOtp,
      );
      expect(again.outcome, VerifyOutcome.existingUser);
    },
  );

  test('wajib setuju Syarat & Ketentuan', () async {
    await expectLater(
      repo.completeProfile(
        email: email,
        username: 'fajar_k',
        acceptedTerms: false,
      ),
      throwsA(isA<AuthException>()),
    );
  });

  test('username terpakai atau dicadangkan ditolak', () async {
    await register(email, 'fajar_k');
    expect(await repo.isUsernameAvailable('fajar_k'), isFalse);
    expect(await repo.isUsernameAvailable('admin'), isFalse);
    expect(await repo.isUsernameAvailable('rina_p'), isTrue);

    await expectLater(
      register('rina@nusaputra.ac.id', 'fajar_k'),
      throwsA(isA<AuthException>()),
    );
  });

  test('ganti username hanya sekali per 30 hari', () async {
    await register(email, 'fajar_k');
    final changed = await repo.updateProfile(
      email: email,
      username: 'fajar_baru',
    );
    expect(changed.username, 'fajar_baru');

    await expectLater(
      repo.updateProfile(email: email, username: 'fajar_lagi'),
      throwsA(
        isA<AuthException>().having((e) => e.code, 'code', 'username_cooldown'),
      ),
    );
    // Ubah bio saja (username sama) tetap boleh.
    final bioOnly = await repo.updateProfile(
      email: email,
      username: 'fajar_baru',
      bio: 'Baru',
    );
    expect(bioOnly.bio, 'Baru');
  });

  test('akun banned dan suspended dibatasi setelah OTP benar', () async {
    for (final (mail, outcome) in [
      ('banned@nusaputra.ac.id', VerifyOutcome.banned),
      ('suspended@nusaputra.ac.id', VerifyOutcome.suspended),
    ]) {
      await repo.sendOtp(mail);
      final result = await repo.verifyOtp(
        email: mail,
        code: AppConstants.simulatedOtp,
      );
      expect(result.outcome, outcome);
      expect(result.restriction, isNotNull);
    }
  });

  test('hapus akun lalu daftar ulang = akun baru', () async {
    final first = await register(email, 'fajar_k');
    await repo.deleteAccount(email);
    expect(await repo.restoreSession(), isNull);
    final second = await register(email, 'fajar_k');
    expect(second.id, isNot(first.id));
  });

  test('Google non-kampus ditolak', () async {
    final result = await repo.signInWithGoogle(email: 'rina@gmail.com');
    expect(result.outcome, VerifyOutcome.invalidDomain);
  });
}
