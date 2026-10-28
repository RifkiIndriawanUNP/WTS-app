/// Nilai konfigurasi dibaca saat build/run lewat --dart-define-from-file=env/dev.json
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// true hanya untuk pengembangan: boleh login password akun uji dev1..dev4.
  static const devLogin = bool.fromEnvironment('DEV_LOGIN');
}
