abstract final class AppConstants {
  static const String campusEmailDomain = 'nusaputra.ac.id';

  // OTP (sama dengan aturan backend: 6 digit, 10 menit, 5 percobaan, kirim ulang 60 dtk)
  static const int otpLength = 6;
  static const int otpResendSeconds = 60;
  static const int otpValidMinutes = 10;
  static const int otpMaxAttempts = 5;

  /// Kode OTP simulasi (hanya untuk mode lokal tanpa backend).
  static const String simulatedOtp = '123456';

  // Profil (mengikuti tabel profiles)
  static const int usernameMin = 3;
  static const int usernameMax = 20;
  static const int bioMax = 160;

  /// Username hanya boleh diganti sekali per 30 hari (profiles.username_changed_at).
  static const int usernameChangeCooldownDays = 30;

  /// Batas pilih foto di perangkat. Server membatasi avatar 256 KB, jadi
  /// foto harus dikompres sebelum diunggah (flutter_image_compress, saat integrasi).
  static const int maxAvatarBytes = 5 * 1024 * 1024;
  static const List<String> allowedImageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];
}
