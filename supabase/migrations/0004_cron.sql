-- =============================================================================
-- WTS | 0004_cron.sql : job terjadwal (pg_cron) + pemicu push (pg_net)
-- Prasyarat (sekali, lewat SQL editor/dashboard, JANGAN di-commit):
--   select vault.create_secret('https://<project-ref>.supabase.co/functions/v1', 'edge_base_url');
--   select vault.create_secret('<string-acak-panjang>', 'edge_shared_secret');
-- Semua fungsi job dijalankan sebagai owner (auth.uid() null -> is_internal() = true).
-- =============================================================================
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

-- ---------- Pemanggil Edge Function (async, aman bila gagal) ----------
create or replace function public.invoke_edge(fn text, body jsonb default '{}'::jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare base text; sec text;
begin
  select decrypted_secret into base from vault.decrypted_secrets where name = 'edge_base_url';
  select decrypted_secret into sec  from vault.decrypted_secrets where name = 'edge_shared_secret';
  if base is null or sec is null then return; end if;
  perform net.http_post(url := base || '/' || fn,
                        headers := jsonb_build_object('Content-Type','application/json','x-wts-secret', sec),
                        body := body);
exception when others then
  null;   -- jangan pernah menggagalkan transaksi utama karena push/cron
end $$;

create or replace function public.trg_push_notification() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.invoke_edge('send_push', jsonb_build_object('notification_id', new.id));
  return null;
end $$;
create trigger trg_push_notification after insert on public.notifications
  for each row execute function public.trg_push_notification();

-- ---------- JOB ----------
-- 1) Kedaluwarsa konten (tiap 15 menit)
create or replace function public.job_expire_content() returns void
language plpgsql security definer set search_path = public as $$
begin
  update posts    set status = 'expired' where status in ('active','closed') and expires_at <= now();
  update products set status = 'expired' where status = 'available' and expires_at <= now();
  -- chat dari produk yang tidak lagi tersedia: tutup, hapus 3 hari lagi
  update market_chats c set status = 'closed',
         delete_at = least(coalesce(c.delete_at, now() + interval '3 days'), now() + interval '3 days')
   where c.status = 'negotiating'
     and exists (select 1 from products p where p.id = c.product_id
                  and p.status in ('expired','deleted','hidden'));
  update offers set status = 'expired' where status = 'pending' and expires_at <= now();
end $$;

-- 2) Hapus permanen (tiap jam) -> trigger mengantrekan file ke file_delete_queue
create or replace function public.job_hard_delete() returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from posts    where hard_delete_at <= now();
  delete from products where hard_delete_at <= now();
end $$;

-- 3) Retensi chat (tiap jam)
create or replace function public.job_cleanup_chats() returns void
language plpgsql security definer set search_path = public as $$
begin
  -- kesepakatan menggantung > 14 hari tanpa aktivitas -> batal otomatis
  update market_chats set status = 'cancelled', cancelled_at = now(), delete_at = now() + interval '3 days'
   where status in ('agreed','on_the_way','arrived') and last_activity_at < now() - interval '14 days';
  update products p set status = 'available'
   where p.status = 'booked'
     and not exists (select 1 from market_chats c where c.product_id = p.id
                      and c.status in ('agreed','on_the_way','arrived'));
  delete from market_chats where delete_at <= now();     -- pesan ikut terhapus (cascade)
  delete from messages     where delete_at <= now();     -- DM > 3 hari
  delete from conversations c
   where c.last_message_at < now() - interval '30 days'
     and not exists (select 1 from messages m where m.dm_conversation_id = c.id);
end $$;

-- 4) Akun: akhir suspend, peringatan & hapus akun tidak aktif 6 bulan (harian)
create or replace function public.job_accounts() returns void
language plpgsql security definer set search_path = public as $$
begin
  update profiles set status = 'active', suspended_until = null
   where status = 'suspended' and suspended_until <= now();

  insert into notifications (user_id, type, payload)
  select id, 'account_inactive_warning', jsonb_build_object('delete_at', last_login_at + interval '6 months')
    from profiles
   where status <> 'banned' and inactive_warned_at is null
     and last_login_at < now() - interval '6 months' + interval '14 days';
  update profiles set inactive_warned_at = now()
   where status <> 'banned' and inactive_warned_at is null
     and last_login_at < now() - interval '6 months' + interval '14 days';

  delete from auth.users u using profiles p
   where p.id = u.id and p.status <> 'banned' and p.last_login_at < now() - interval '6 months';
end $$;

-- 5) Pengingat durasi (harian)
create or replace function public.job_reminders() returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into notifications (user_id, type, payload)
  select seller_id, 'product_expiring', jsonb_build_object('product_id', id, 'expires_at', expires_at)
    from products where status = 'available' and reminded_at is null
     and expires_at between now() and now() + interval '3 days';
  update products set reminded_at = now()
   where status = 'available' and reminded_at is null and expires_at between now() and now() + interval '3 days';

  insert into notifications (user_id, type, payload)
  select author_id, 'post_expiring', jsonb_build_object('post_id', id, 'expires_at', expires_at)
    from posts where status = 'active' and reminded_at is null
     and expires_at between now() and now() + interval '1 day' and expires_at - created_at >= interval '6 days';
  update posts set reminded_at = now()
   where status = 'active' and reminded_at is null
     and expires_at between now() and now() + interval '1 day' and expires_at - created_at >= interval '6 days';
end $$;

-- 6) Kebersihan umum (harian)
create or replace function public.job_housekeeping() returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from notifications where created_at < now() - interval '30 days';
  delete from rate_limits   where bucket < now() - interval '2 days';
  update reports set snapshot = null
   where snapshot is not null and handled_at is not null and handled_at < now() - interval '30 days';
  delete from audit_logs where created_at < now() - interval '1 year';
end $$;

-- 7) Skor hot (tiap 10 menit, hanya postingan 7 hari terakhir)
create or replace function public.job_recalc_hot() returns void
language sql security definer set search_path = public as $$
  update posts set hot_score = public.calc_hot(score, created_at)
   where status = 'active' and created_at > now() - interval '7 days'
$$;

-- ---------- JADWAL (idempotent) ----------
select cron.unschedule(jobname) from cron.job where jobname like 'wts_%';

select cron.schedule('wts_expire_content', '*/15 * * * *', 'select public.job_expire_content()');
select cron.schedule('wts_hard_delete',    '5 * * * *',    'select public.job_hard_delete()');
select cron.schedule('wts_cleanup_chats',  '10 * * * *',   'select public.job_cleanup_chats()');
select cron.schedule('wts_recalc_hot',     '*/10 * * * *', 'select public.job_recalc_hot()');
select cron.schedule('wts_accounts',       '0 20 * * *',   'select public.job_accounts()');       -- 03:00 WIB
select cron.schedule('wts_reminders',      '0 2 * * *',    'select public.job_reminders()');      -- 09:00 WIB
select cron.schedule('wts_housekeeping',   '30 20 * * *',  'select public.job_housekeeping()');
select cron.schedule('wts_purge_files',    '20 * * * *',   $$select public.invoke_edge('purge_files')$$);
select cron.schedule('wts_sweep_orphans',  '0 21 * * 0',   $$select public.invoke_edge('sweep_orphans')$$);   -- Minggu 04:00 WIB
