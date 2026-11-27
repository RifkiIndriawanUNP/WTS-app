import 'package:shared_preferences/shared_preferences.dart';

/// Penyimpanan lokal sederhana untuk mode tanpa backend.
abstract final class AppPrefs {
  static const String _introKey = 'wts.intro_seen';

  static Future<bool> hasSeenIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_introKey) ?? false;
  }

  static Future<void> markIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_introKey, true);
  }

  /// Hapus semua data uji lokal (pengguna, sesi, intro). Hanya untuk debug.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.startsWith('wts.'))) {
      await prefs.remove(key);
    }
  }
}
