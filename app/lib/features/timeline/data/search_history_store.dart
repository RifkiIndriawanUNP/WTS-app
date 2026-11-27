import 'package:shared_preferences/shared_preferences.dart';

/// Riwayat pencarian di perangkat (tidak dikirim ke server). Terbaru dulu,
/// tanpa duplikat (huruf besar/kecil diabaikan), maksimal [maxItems].
class SearchHistoryStore {
  const SearchHistoryStore();

  static const String _key = 'wts.search_history';
  static const int maxItems = 8;

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  Future<List<String>> add(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      return load();
    }
    final prefs = await SharedPreferences.getInstance();
    final list = [
      q,
      for (final s in prefs.getStringList(_key) ?? const <String>[])
        if (s.toLowerCase() != q.toLowerCase()) s,
    ].take(maxItems).toList();
    await prefs.setStringList(_key, list);
    return list;
  }

  Future<List<String>> remove(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final list = [
      for (final s in prefs.getStringList(_key) ?? const <String>[])
        if (s != query) s,
    ];
    await prefs.setStringList(_key, list);
    return list;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
