class LinkMatch {
  const LinkMatch(this.start, this.end, this.url);

  final int start;
  final int end;

  /// URL yang sudah dinormalkan (selalu http/https).
  final String url;
}

/// Deteksi tautan di teks. Hanya http/https (dan "www.") yang dikenali,
/// sehingga skema berbahaya (javascript:, intent:, file:) tidak pernah
/// menjadi tautan yang bisa diketuk.
abstract final class Links {
  static final RegExp _regex = RegExp(
    r'(?:https?:\/\/|www\.)[^\s<>"]+',
    caseSensitive: false,
  );

  static const String _trailing = '.,;:!?)]}\'"';

  static List<LinkMatch> find(String text) {
    final out = <LinkMatch>[];
    for (final m in _regex.allMatches(text)) {
      var end = m.end;
      while (end > m.start && _trailing.contains(text[end - 1])) {
        end--;
      }
      final url = normalize(text.substring(m.start, end));
      if (url != null) out.add(LinkMatch(m.start, end, url));
    }
    return out;
  }

  static String? normalize(String raw) {
    var url = raw.trim();
    if (url.toLowerCase().startsWith('www.')) url = 'https://$url';
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return null;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }
    if (uri.host.isEmpty || !uri.host.contains('.')) {
      return null;
    }
    return url;
  }

  static String host(String url) => Uri.tryParse(url)?.host ?? url;
}
