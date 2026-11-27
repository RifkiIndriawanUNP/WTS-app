import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Draf postingan yang tersimpan otomatis di perangkat (teks saja; gambar
/// tidak disimpan). Dihapus saat posting berhasil.
class PostFormDraft {
  const PostFormDraft({
    this.title = '',
    this.body = '',
    this.tagIds = const [],
    this.anonymous = false,
    this.days = 30,
    this.link = '',
  });

  final String title;
  final String body;
  final List<int> tagIds;
  final bool anonymous;
  final int days;
  final String link;

  bool get isEmpty =>
      title.trim().isEmpty && body.trim().isEmpty && link.trim().isEmpty;

  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    'tagIds': tagIds,
    'anonymous': anonymous,
    'days': days,
    'link': link,
  };

  factory PostFormDraft.fromJson(Map<String, dynamic> json) => PostFormDraft(
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    tagIds: [
      for (final v in (json['tagIds'] as List? ?? const [])) (v as num).toInt(),
    ],
    anonymous: json['anonymous'] as bool? ?? false,
    days: (json['days'] as num?)?.toInt() ?? 30,
    link: json['link'] as String? ?? '',
  );
}

abstract final class PostDraftStore {
  static const String _key = 'wts.post_draft';

  static Future<PostFormDraft?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) {
        return null;
      }
      final draft = PostFormDraft.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      return draft.isEmpty ? null : draft;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(PostFormDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    if (draft.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, jsonEncode(draft.toJson()));
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
