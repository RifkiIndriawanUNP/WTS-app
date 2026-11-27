import '../../auth/domain/user_profile.dart';
import '../domain/public_profile.dart';
import 'profile_repository.dart';

/// Profil contoh untuk pengguna yang menulis di data linimasa palsu.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({
    required this.currentUser,
    this.latency = const Duration(milliseconds: 400),
  });

  final UserProfile? Function() currentUser;
  final Duration latency;

  /// Isi `true` untuk menguji tampilan error.
  bool failNext = false;

  static final Map<String, PublicProfile> _seed = {
    for (final p in [
      PublicProfile(
        username: 'wts_resmi',
        joinedAt: DateTime(2026, 8, 1),
        bio: 'Akun resmi WTS. Pengumuman dan pembaruan aplikasi.',
        isOfficial: true,
      ),
      PublicProfile(
        username: 'nadia_putri',
        joinedAt: DateTime(2026, 9, 3),
        prodiName: 'Sistem Informasi',
        bio: 'Lagi skripsi, mohon bantuannya 🙏',
      ),
      PublicProfile(
        username: 'rian_pratama',
        joinedAt: DateTime(2026, 9, 10),
        prodiName: 'Teknik Informatika',
      ),
      PublicProfile(
        username: 'siti_aisyah',
        joinedAt: DateTime(2026, 9, 12),
        prodiName: 'Manajemen',
        bio: 'Suka bikin event kampus.',
      ),
      PublicProfile(
        username: 'bem_nusaputra',
        joinedAt: DateTime(2026, 8, 20),
        prodiName: 'Teknik Informatika',
        bio: 'Badan Eksekutif Mahasiswa Universitas Nusa Putra.',
      ),
      PublicProfile(
        username: 'dina_kamila',
        joinedAt: DateTime(2026, 9, 18),
        prodiName: 'Desain Komunikasi Visual',
      ),
      PublicProfile(
        username: 'fajar_k',
        joinedAt: DateTime(2026, 10, 1),
        prodiName: 'Teknik Informatika',
      ),
      PublicProfile(
        username: 'budi_santoso',
        joinedAt: DateTime(2026, 10, 5),
        prodiName: 'Teknik Informatika',
        bio: 'Jual beli alat praktikum, COD di kampus.',
      ),
      PublicProfile(
        username: 'maya_lestari',
        joinedAt: DateTime(2026, 10, 9),
        prodiName: 'Sistem Informasi',
      ),
      PublicProfile(
        username: 'ilham_r',
        joinedAt: DateTime(2026, 10, 15),
        prodiName: 'Teknik Komputer',
      ),
      PublicProfile(
        username: 'himpunan_ti',
        joinedAt: DateTime(2026, 8, 25),
        prodiName: 'Teknik Informatika',
        bio: 'Himpunan Mahasiswa Teknik Informatika.',
      ),
    ])
      p.username: p,
  };

  @override
  Future<PublicProfile> fetchProfile(String username) async {
    await Future<void>.delayed(latency);
    if (failNext) {
      failNext = false;
      throw const ProfileException(
        'Gagal memuat profil. Periksa koneksimu.',
        code: 'network',
      );
    }
    final me = currentUser();
    if (me != null && me.username == username) {
      return PublicProfile(
        username: me.username,
        joinedAt: me.createdAt,
        prodiName: me.prodiName,
        bio: me.bio,
        avatarPath: me.avatarPath,
      );
    }
    final found = _seed[username];
    if (found == null) {
      throw const ProfileException(
        'Pengguna tidak ditemukan',
        code: 'not_found',
      );
    }
    return found;
  }
}
