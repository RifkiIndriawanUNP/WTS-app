-- =============================================================================
-- WTS | tests/rls.test.sql (pgTAP) - tes awal; tambah terus seiring fitur.
-- Jalankan: supabase test db
-- =============================================================================
begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

-- ---- Data awal (dijalankan sebagai postgres, auth.uid() = null -> internal) ----
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'a@nusaputra.ac.id'),
  ('00000000-0000-0000-0000-0000000000a2', 'b@nusaputra.ac.id'),
  ('00000000-0000-0000-0000-0000000000a3', 'c@nusaputra.ac.id');
insert into public.profiles (id, username) values
  ('00000000-0000-0000-0000-0000000000a1', 'user_a'),
  ('00000000-0000-0000-0000-0000000000a2', 'user_b'),
  ('00000000-0000-0000-0000-0000000000a3', 'user_c');

insert into public.posts (id, author_id, is_anonymous, caption) values
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', true, 'post anonim');

insert into public.products (id, seller_id, title, description, listing_type, price, condition) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', 'Jas lab', 'Bagus', 'sell', 50000, 'new');
insert into public.market_chats (id, product_id, buyer_id, seller_id, status) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1',
   '00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000a1', 'agreed');

insert into public.conversations (id, user_a, user_b, requester_id, status) values
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a1',
   '00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000a1', 'accepted');
insert into public.messages (dm_conversation_id, sender_id, type, body) values
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a1', 'text', 'rahasia');

-- 1) Email non-kampus ditolak di level database
select throws_ok(
  $$insert into auth.users (id, email) values (gen_random_uuid(), 'x@gmail.com')$$,
  'email_domain_not_allowed', 'email non @nusaputra.ac.id ditolak');

-- 2) Hanya satu kesepakatan aktif per produk
select throws_ok(
  $$insert into public.market_chats (product_id, buyer_id, seller_id, status) values
    ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a3',
     '00000000-0000-0000-0000-0000000000a1', 'agreed')$$,
  '23505', null, 'dua kesepakatan aktif pada satu produk ditolak');

-- ---- Beralih menjadi user_c (bukan penulis, bukan peserta chat) ----
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000a3","role":"authenticated"}', true);

-- 3) Identitas penulis anonim tidak bocor lewat view publik
select is((select author_id from public.posts_public where id = '00000000-0000-0000-0000-0000000000b1'),
          null, 'author_id postingan anonim disembunyikan');

-- 4) Tabel dasar posts tidak bisa dibaca user lain
select is((select count(*)::int from public.posts), 0, 'user lain tidak dapat select tabel posts');

-- 5) Pesan DM tidak terlihat oleh non-peserta
select is((select count(*)::int from public.messages), 0, 'non-peserta tidak melihat pesan DM');

-- 6) User tidak bisa menaikkan role sendiri
select throws_ok(
  $$update public.profiles set role = 'admin' where id = '00000000-0000-0000-0000-0000000000a3'$$,
  '42501', null, 'user tidak bisa mengubah kolom role');

-- 7) anon tidak punya akses ke view
reset role;
set local role anon;
select throws_ok($$select * from public.posts_public$$, '42501', null, 'anon tidak bisa baca posts_public');

select * from finish();
rollback;
