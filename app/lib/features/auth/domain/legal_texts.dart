/// Ringkasan Syarat & Ketentuan serta Aturan Komunitas yang ditampilkan di app.
/// DRAF: samakan dengan dokumen resmi tim/kampus sebelum rilis (UU PDP).
typedef LegalSection = (String title, String body);

const List<LegalSection> kTermsSections = [
  (
    'Pengguna',
    'WTS khusus mahasiswa Universitas Nusa Putra. Kamu masuk memakai email kampus dan bertanggung jawab atas semua aktivitas akunmu.',
  ),
  (
    'Konten',
    'Kamu bertanggung jawab atas isi postingan, komentar, dan chat. WTS dapat menyembunyikan atau menghapus konten yang melanggar aturan.',
  ),
  (
    'Anonim',
    'Postingan anonim menyembunyikan namamu dari pengguna lain. Identitas penulis tetap tersimpan di sistem dan hanya dapat dibuka admin untuk penegakan aturan; setiap pembukaan dicatat.',
  ),
  (
    'Transaksi',
    'WTS tidak memproses pembayaran. Transaksi dilakukan langsung (COD) dan menjadi tanggung jawab penjual dan pembeli.',
  ),
  (
    'Data & akun',
    'Akun yang tidak masuk selama 6 bulan akan dihapus. Kamu dapat menghapus akunmu kapan saja dari Pengaturan.',
  ),
];

const List<LegalSection> kCommunitySections = [
  (
    'Saling menghormati',
    'Dilarang perundungan, pelecehan, ujaran kebencian, atau konten SARA.',
  ),
  (
    'Konten pantas',
    'Dilarang konten dewasa, kekerasan, atau yang melanggar hukum.',
  ),
  ('Tidak menipu', 'Dilarang penipuan, informasi palsu, dan barang palsu.'),
  (
    'Jaga data pribadi',
    'Jangan membagikan data pribadi orang lain tanpa izin.',
  ),
  (
    'Tanpa spam',
    'Dilarang postingan berulang, iklan di tempat yang salah, atau tautan berbahaya.',
  ),
  (
    'Barang terlarang',
    'Dilarang menjual narkoba, miras, rokok/vape, senjata, obat resep, soal ujian atau jasa joki, barang curian/bajakan, dan konten dewasa.',
  ),
  (
    'Transaksi aman',
    'Bertemu di area kampus yang ramai, cek barang sebelum membayar, dan jangan transfer uang muka ke orang yang belum dikenal.',
  ),
];
