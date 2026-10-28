-- =============================================================================
-- WTS | seed_dev_users.sql  -  AKUN UJI UNTUK DATABASE LOKAL SAJA
-- Dijalankan otomatis oleh `supabase db reset` (lihat config.toml -> [db.seed]).
-- JANGAN dijalankan di Supabase cloud/production.
-- Hasil: 4 akun   dev1..dev4@nusaputra.ac.id   password: Dev12345!
--        username dev1..dev4 ; dev1 = admin
-- Dibungkus DO + EXCEPTION agar kegagalan di sini tidak menggagalkan db reset.
-- =============================================================================
do $$
declare
  n   int;
  uid uuid;
  em  text;
begin
  for n in 1..4 loop
    em  := 'dev' || n || '@nusaputra.ac.id';
    uid := ('00000000-0000-0000-0000-00000000010' || n)::uuid;

    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change)
    values (
      '00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', em,
      extensions.crypt('Dev12345!', extensions.gen_salt('bf')), now(),
      '{"provider":"email","providers":["email"]}', '{}', now(), now(),
      '', '', '', '')
    on conflict (id) do nothing;

    insert into auth.identities (
      id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    values (
      gen_random_uuid(), uid, uid::text,
      jsonb_build_object('sub', uid::text, 'email', em, 'email_verified', true),
      'email', now(), now(), now())
    on conflict do nothing;

    insert into public.profiles (id, username, role)
    values (uid, 'dev' || n, (case when n = 1 then 'admin' else 'user' end)::user_role)
    on conflict do nothing;
  end loop;
exception when others then
  raise notice 'seed_dev_users dilewati: %', sqlerrm;
end $$;
