FITUR YANG SUDAH DIGARAP: MARKETPLACE, CHAT MARKET (COD), CHAT DM, DAN NOTIFIKASI

FONDASI
- Tema liquid glass: latar gradien, kartu kaca buram, dan navigasi bawah kapsul melayang.
- Router 5 tab (Home, Market, Chat, Notifikasi, Profil).
- Logo WTS di header Market.
- main_preview.dart dan preview per fitur, supaya bisa dijalankan tanpa Supabase atau Docker.
- Pola repository (UI, provider, repository, lalu repository palsu), sehingga nanti mudah diganti ke Supabase.

MARKETPLACE
- Feed produk grid 2 kolom, bisa tarik untuk memuat ulang.
- Pencarian, chip kategori, filter (jual/sewa, baru/second, rentang harga, hanya tersedia, bisa nego), dan urutan (terbaru, harga terendah, harga tertinggi, segera berakhir).
- Foto produk contoh diambil dari internet, dengan placeholder jika gagal dimuat.
- Detail produk: galeri foto yang bisa digeser, status, kondisi, kategori, titik COD, deskripsi, kekurangan barang second, dan info penjual.
- Tombol Tawar dan Chat Penjual.
- Simpan produk, bagikan tautan, dan laporkan produk.
- Aksi pemilik: perpanjang masa tayang (+30 hari, maksimal 3 kali), tandai terjual atau disewa, dan hapus produk.
- Form Tambah Barang: jual atau sewa, harga berformat otomatis, deposit dan satuan sewa, kondisi (kekurangan wajib untuk barang second), kategori, titik temu COD, harga bisa nego, pernyataan barang terlarang, dan validasi isian.
- Unggah foto dari galeri (hingga 10 foto, bisa dihapus satu per satu).
- Maksimal 20 produk aktif per pengguna.

CHAT MARKET (COD)
- Kartu produk di atas ruang chat.
- Tawar-menawar: kartu tawaran dengan tombol Setuju, Tawar lagi, dan Tolak. Hanya satu tawaran aktif dan kedaluwarsa dalam 24 jam.
- Status transaksi: Negosiasi, Sepakat, Berangkat, Sampai, Terjual, serta Dibatalkan dan Ditutup.
- Tombol "Saya berangkat", "Saya sudah sampai", "Tandai terjual" (khusus penjual), dan batalkan transaksi dengan alasan.
- Hanya satu chat berstatus Sepakat per produk. Produk yang terjual menutup chat pembeli lain dengan pesan sistem.
- Rating 1 sampai 5 bintang setelah transaksi selesai.
- Kirim teks, foto dari galeri, lokasi, kontak WhatsApp (dengan konfirmasi), dan tautan (dengan peringatan sebelum dibuka).
- Banner hitung mundur penghapusan otomatis: negosiasi atau batal 3 hari, sepakat dan terjual 7 hari, chat lain pada produk terjual 3 hari.
- Tips keamanan COD, laporkan penipuan, dan hapus pesan sendiri (maksimal 15 menit).
- Batas 30 pesan per menit.
- Balasan otomatis dari lawan bicara untuk simulasi, ditambah menu simulasi (mode debug) untuk mencoba semua alur sendirian.

CHAT DM
- Daftar percakapan bersama chat market, dengan filter Semua, Pribadi, dan Jual-Beli, pencarian, serta penanda pesan belum dibaca.
- Mulai pesan baru lewat tombol pensil.
- Permintaan Pesan untuk pesan pertama (Terima, Abaikan, Blokir).
- Pengaturan privasi DM dan blokir.
- Kirim teks, foto dari galeri, lokasi, kontak WhatsApp, dan tautan.
- Banner "Pesan dihapus otomatis setelah 3 hari". Pesan yang lebih lama dari 3 hari tidak ditampilkan.
- Batas 30 pesan per menit dan 20 percakapan baru per hari.
- Balasan otomatis dari lawan bicara untuk simulasi.

NOTIFIKASI
- Daftar notifikasi dengan filter Semua, Mention, dan Market, dikelompokkan menjadi Hari ini, Minggu ini, dan Lebih lama.
- Tandai satu atau semua sudah dibaca, dengan badge jumlah belum dibaca di tab.
- Ketuk notifikasi untuk membuka chat atau produk terkait.
- Notifikasi baru muncul saat lawan bicara menawar, menyetujui, berangkat, sampai, atau menandai terjual.

CARA MENJALANKAN
Dari folder app, jalankan: flutter pub get, lalu flutter run -d edge -t lib/main_preview.dart. Preview per fitur ada di lib/features/market/preview, lib/features/chat/preview, dan lib/features/notifications/preview.
