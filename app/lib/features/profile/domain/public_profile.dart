/// Profil yang boleh dilihat pengguna lain (view `profiles_public`).
/// Email dan status akun tidak termasuk.
class PublicProfile {
  const PublicProfile({
    required this.username,
    required this.joinedAt,
    this.prodiName,
    this.bio,
    this.avatarPath,
    this.isOfficial = false,
  });

  final String username;
  final DateTime joinedAt;
  final String? prodiName;
  final String? bio;
  final String? avatarPath;
  final bool isOfficial;

  String get initials {
    final cleaned = username.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (cleaned.isEmpty) {
      return '?';
    }
    return cleaned.substring(0, cleaned.length >= 2 ? 2 : 1).toUpperCase();
  }
}
