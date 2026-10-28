# WTS (Want to Sell, Want to Share)

Aplikasi mobile micro-sosial media + marketplace COD untuk mahasiswa Universitas Nusa Putra.
Stack: **Flutter** (app) + **Supabase** (database, login, penyimpanan, backend).

## Struktur repo

```
wts/
├─ app/          Aplikasi Flutter (dikerjakan semua anggota)
├─ supabase/     Backend: migrations (skema DB), functions, seed, tests (dikelola Lead/A)
├─ docs/         Dokumen analisis & desain (BACA dulu!)
├─ .github/      Pengecekan otomatis (CI)
└─ README.md
```

## Dokumen penting
- `docs/Analisis_Sistem_WTS.txt`  : fitur & alur seluruh aplikasi
- `docs/Desain_Backend_WTS.txt`   : nama tabel, RPC, aturan akses, kode error (kontrak data)

## Persiapan (sekali saja)
Pasang: Git, Flutter (versi: **ISI_VERSI_TIM**), Android Studio, Docker Desktop, Supabase CLI.

## Menjalankan di laptop sendiri

```bash
# 1. Ambil kode terbaru
git pull

# 2. Hidupkan backend lokal (Docker harus sudah berjalan)
supabase start
supabase db reset          # membangun database + data awal + akun uji
supabase status            # salin "anon key" / "Publishable key"

# 3. Siapkan konfigurasi app
cd app
flutter pub get
cp env/dev.example.json env/dev.json      # Windows PowerShell: Copy-Item env\dev.example.json env\dev.json
# edit env/dev.json -> isi SUPABASE_ANON_KEY dari langkah 2

# 4. Jalankan
flutter run --dart-define-from-file=env/dev.json
```

Akun uji lokal: `dev1@nusaputra.ac.id` ... `dev4@nusaputra.ac.id`, password `Dev12345!` (dev1 = admin).

Setiap kali ada perubahan di folder `supabase/` (setelah `git pull`): jalankan lagi `supabase db reset`.

## Aturan kerja tim
- **Jangan** push langsung ke `main`. Buat branch: `feat/nama-fitur`, lalu buka Pull Request.
- Commit: `feat: ...`, `fix: ...`, `chore: ...`, `docs: ...`
- Perubahan database **hanya lewat file baru** di `supabase/migrations/` (diatur Lead/A). Jangan edit migrasi lama.
- **Jangan commit rahasia**: `env/dev.json`, keystore, `google-services.json`.
- PR kecil, minta review minimal 1 orang, merge setelah CI hijau.
