-- =============================================================================
-- WTS | seed.sql : data awal. SESUAIKAN daftar prodi & titik temu dengan kondisi kampus.
-- =============================================================================

insert into public.tags (scope, name, slug, sort_order) values
  ('timeline','Kuesioner','kuesioner',1),
  ('timeline','Informasi','informasi',2),
  ('timeline','Organisasi','organisasi',3),
  ('timeline','Tugas','tugas',4),
  ('timeline','WTB','wtb',5),
  ('timeline','Event/Lomba','event-lomba',6),
  ('timeline','Akademik','akademik',7),
  ('timeline','Magang/Loker','magang-loker',8),
  ('timeline','Kehilangan/Penemuan','kehilangan-penemuan',9),
  ('timeline','Diskusi','diskusi',10),
  ('timeline','Lainnya','lainnya',99),
  ('product','Buku/Modul','buku-modul',1),
  ('product','Alat Praktikum','alat-praktikum',2),
  ('product','Jas Lab','jas-lab',3),
  ('product','Laptop & Aksesoris','laptop-aksesoris',4),
  ('product','Elektronik','elektronik',5),
  ('product','Alat Tulis/Gambar','alat-tulis-gambar',6),
  ('product','Perlengkapan Kos','perlengkapan-kos',7),
  ('product','Pakaian/Almamater','pakaian-almamater',8),
  ('product','Lainnya','lainnya',99)
on conflict do nothing;

-- CONTOH: ganti dengan daftar prodi resmi Universitas Nusa Putra
insert into public.prodi (name, faculty) values
  ('Teknik Informatika','Fakultas Teknik, Komputer dan Desain'),
  ('Sistem Informasi','Fakultas Teknik, Komputer dan Desain'),
  ('Teknik Komputer','Fakultas Teknik, Komputer dan Desain'),
  ('Manajemen','Fakultas Bisnis dan Humaniora'),
  ('Akuntansi','Fakultas Bisnis dan Humaniora')
on conflict do nothing;

-- CONTOH titik temu COD
insert into public.meeting_points (name, description) values
  ('Lobby Gedung Utama','Area ramai dekat resepsionis'),
  ('Perpustakaan','Area depan perpustakaan'),
  ('Kantin','Area kantin kampus, siang hari'),
  ('Dekat Pos Satpam','Area gerbang/parkir yang diawasi satpam')
on conflict do nothing;

insert into public.app_config (key, value) values
  ('min_app_version', '"1.0.0"'),
  ('rate_limits', '{
    "post":            {"max": 10,  "window": "1 day"},
    "comment":         {"max": 5,   "window": "1 minute"},
    "product":         {"max": 5,   "window": "1 day"},
    "message":         {"max": 30,  "window": "1 minute"},
    "dm_new":          {"max": 20,  "window": "1 day"},
    "market_chat_new": {"max": 30,  "window": "1 day"},
    "offer":           {"max": 20,  "window": "1 hour"},
    "report":          {"max": 10,  "window": "1 day"}
  }')
on conflict (key) do nothing;
