import '../../../core/constants/app_constants.dart';

/// Peran akun (enum user_role di database).
enum UserRole { user, moderator, admin }

/// Status akun (enum account_status di database).
enum AccountStatus { active, suspended, banned }

/// Profil pengguna yang sedang masuk (tabel `profiles`). Tidak ada nama
/// tampilan: pengguna dikenal lewat @username saja.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.username,
    required this.createdAt,
    this.prodiId,
    this.prodiName,
    this.avatarPath,
    this.bio,
    this.role = UserRole.user,
    this.status = AccountStatus.active,
    this.suspendedUntil,
    this.usernameChangedAt,
  });

  final String id;

  /// Hanya untuk diri sendiri; email tidak pernah tampil ke pengguna lain.
  final String email;
  final String username;
  final DateTime createdAt;
  final int? prodiId;
  final String? prodiName;
  final String? avatarPath;
  final String? bio;
  final UserRole role;
  final AccountStatus status;
  final DateTime? suspendedUntil;
  final DateTime? usernameChangedAt;

  /// Kapan username boleh diganti lagi; null bila sudah boleh sekarang.
  DateTime? usernameUnlockAt(DateTime now) {
    final changed = usernameChangedAt;
    if (changed == null) {
      return null;
    }
    final unlock = changed.add(
      const Duration(days: AppConstants.usernameChangeCooldownDays),
    );
    return unlock.isAfter(now) ? unlock : null;
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isModerator => role == UserRole.moderator || role == UserRole.admin;

  /// Dua huruf pertama username (tanpa garis bawah), huruf besar.
  String get initials => initialsOf(username);

  static String initialsOf(String username) {
    final letters = username.replaceAll('_', '');
    if (letters.isEmpty) {
      return '?';
    }
    return letters.substring(0, letters.length >= 2 ? 2 : 1).toUpperCase();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'username': username,
    'prodiId': prodiId,
    'prodiName': prodiName,
    'avatarPath': avatarPath,
    'bio': bio,
    'role': role.name,
    'status': status.name,
    'suspendedUntil': suspendedUntil?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'usernameChangedAt': usernameChangedAt?.toIso8601String(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) =>
        json[key] == null ? null : DateTime.parse(json[key] as String);
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      prodiId: json['prodiId'] as int?,
      prodiName: json['prodiName'] as String?,
      avatarPath: json['avatarPath'] as String?,
      bio: json['bio'] as String?,
      role: UserRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => UserRole.user,
      ),
      status: AccountStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => AccountStatus.active,
      ),
      suspendedUntil: date('suspendedUntil'),
      createdAt: DateTime.parse(json['createdAt'] as String),
      usernameChangedAt: date('usernameChangedAt'),
    );
  }
}
