/// Program studi (tabel `prodi`). Daftar asli diambil dari backend; daftar
/// palsu di bawah mengikuti seed.sql dan HANYA contoh.
class Prodi {
  const Prodi(this.id, this.name);

  final int id;
  final String name;
}

const List<Prodi> kFakeProdi = [
  Prodi(1, 'Teknik Informatika'),
  Prodi(2, 'Sistem Informasi'),
  Prodi(3, 'Teknik Komputer'),
  Prodi(4, 'Manajemen'),
  Prodi(5, 'Akuntansi'),
];

Prodi? findFakeProdi(int? id) {
  if (id == null) {
    return null;
  }
  for (final p in kFakeProdi) {
    if (p.id == id) {
      return p;
    }
  }
  return null;
}
