/// Model pengguna ringan untuk tampilan. Nanti diisi dari view `profiles_public`.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.username,
    this.major,
    this.dmEnabled = true,
    this.online = false,
  });

  final String id;
  final String name;
  final String username;
  final String? major;
  final bool dmEnabled;
  final bool online;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final p = parts.first;
      return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

const kMeId = 'me';

/// Data pengguna contoh (hanya untuk repository palsu).
const Map<String, AppUser> kFakeUsers = {
  kMeId: AppUser(
    id: kMeId,
    name: 'Rahma Aulia',
    username: 'rahma',
    major: 'Teknik Informatika',
    online: true,
  ),
  'u_dimas': AppUser(
    id: 'u_dimas',
    name: 'Dimas Maulana',
    username: 'dimas_m',
    major: 'Teknik Informatika',
    online: true,
  ),
  'u_rian': AppUser(
    id: 'u_rian',
    name: 'Rian Pratama',
    username: 'rian_p',
    major: 'Sistem Informasi',
  ),
  'u_nadia': AppUser(
    id: 'u_nadia',
    name: 'Nadia Putri',
    username: 'nadia_p',
    major: 'Sistem Informasi',
    online: true,
  ),
  'u_fajar': AppUser(
    id: 'u_fajar',
    name: 'Fajar Ramadhan',
    username: 'fajar_r',
    major: 'Teknik Informatika',
  ),
  'u_anisa': AppUser(
    id: 'u_anisa',
    name: 'Anisa Rahma',
    username: 'anisa_r',
    major: 'Manajemen',
  ),
  'u_budi': AppUser(
    id: 'u_budi',
    name: 'Budi Kurniawan',
    username: 'budi_k',
    major: 'Teknik Sipil',
    dmEnabled: false,
  ),
};

AppUser userById(String id) =>
    kFakeUsers[id] ?? AppUser(id: id, name: 'Pengguna', username: 'pengguna');
