-- =============================================================================
-- WTS | 0003_rls.sql : GRANT, Row Level Security, Storage, Realtime
-- Prinsip: deny-by-default. Klien hanya punya hak minimum; sisanya lewat RPC/view.
-- =============================================================================

-- ---------- 1. CABUT HAK BAWAAN ----------
revoke all on all tables    in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon;
grant usage on schema public to anon, authenticated;

-- ---------- 2. GRANT TABEL (sengaja sempit; kolom untuk UPDATE dibatasi) ----------
grant select on public.prodi, public.tags, public.meeting_points, public.app_config to authenticated;
grant insert, update, delete on public.prodi, public.tags, public.meeting_points, public.app_config to authenticated; -- dibatasi policy is_admin()

grant select, insert on public.profiles to authenticated;
grant update (username, prodi_id, bio, avatar_path, dm_privacy, notif_prefs, username_changed_at)
  on public.profiles to authenticated;

grant select, delete on public.posts to authenticated;
grant update (caption, status, expires_at) on public.posts to authenticated;
grant select on public.post_tags, public.post_images to authenticated;

grant select, insert on public.comments to authenticated;
grant update (body) on public.comments to authenticated;

grant select, insert, update, delete on public.post_votes, public.comment_votes to authenticated;
grant select, insert, delete on public.saved_posts, public.saved_products to authenticated;

grant select on public.products to authenticated;
grant update (title, description, price, rent_unit, deposit, condition, defect_note,
              negotiable, meeting_point_id, prodi_id) on public.products to authenticated;
grant select on public.product_tags to authenticated;
grant select, insert, delete on public.product_images to authenticated;

grant select on public.conversations, public.market_chats, public.offers, public.ratings to authenticated;
grant select, insert, delete on public.messages to authenticated;
grant select, insert, delete on public.blocks to authenticated;
grant select, insert on public.reports to authenticated;
grant select on public.user_strikes to authenticated;
grant select, insert on public.appeals to authenticated;
grant update (status, handled_by) on public.appeals to authenticated;
grant select, delete on public.notifications to authenticated;
grant update (is_read) on public.notifications to authenticated;
grant select, insert, update, delete on public.device_tokens to authenticated;
grant select on public.audit_logs to authenticated;
-- banned_emails, file_delete_queue, rate_limits: TANPA grant (hanya service_role/security definer)

grant select on public.posts_public, public.comments_public, public.profiles_public to authenticated;

-- ---------- 3. GRANT FUNGSI ----------
-- helper yang dipakai policy
grant execute on function
  public.is_staff(), public.is_admin(), public.is_active_user(), public.is_internal(),
  public.is_blocked_between(uuid, uuid), public.is_dm_member(uuid), public.is_market_member(uuid),
  public.is_chat_member(text, uuid), public.is_post_visible(uuid), public.can_comment(uuid),
  public.is_comment_visible(uuid), public.is_product_visible(uuid), public.can_send_dm(uuid),
  public.can_send_market(uuid), public.fmt_rp(bigint)
  to authenticated;
-- RPC
grant execute on function
  public.touch_last_login(), public.delete_my_account(),
  public.create_post(text, smallint[], jsonb, boolean, int, jsonb),
  public.delete_comment(uuid),
  public.create_product(text, text, listing_type, bigint, item_condition, smallint[], jsonb, rent_unit, bigint, text, boolean, smallint, smallint),
  public.extend_product(uuid), public.delete_product(uuid),
  public.start_dm(uuid), public.accept_dm(uuid), public.mark_read(text, uuid),
  public.open_market_chat(uuid), public.send_offer(uuid, bigint),
  public.respond_offer(uuid, text, bigint), public.set_chat_progress(uuid, text),
  public.mark_sold(uuid, uuid), public.cancel_market_chat(uuid, text),
  public.rate_deal(uuid, smallint, text),
  public.moderate_action(uuid, text, text), public.admin_reveal_author(uuid)
  to authenticated;
grant execute on function public.ping() to anon, authenticated;

-- ---------- 4. RLS ----------
alter table public.prodi             enable row level security;
alter table public.tags              enable row level security;
alter table public.meeting_points    enable row level security;
alter table public.app_config        enable row level security;
alter table public.profiles          enable row level security;
alter table public.posts             enable row level security;
alter table public.post_tags         enable row level security;
alter table public.post_images       enable row level security;
alter table public.comments          enable row level security;
alter table public.post_votes        enable row level security;
alter table public.comment_votes     enable row level security;
alter table public.saved_posts       enable row level security;
alter table public.saved_products    enable row level security;
alter table public.products          enable row level security;
alter table public.product_tags      enable row level security;
alter table public.product_images    enable row level security;
alter table public.conversations     enable row level security;
alter table public.market_chats      enable row level security;
alter table public.messages          enable row level security;
alter table public.offers            enable row level security;
alter table public.ratings           enable row level security;
alter table public.blocks            enable row level security;
alter table public.reports           enable row level security;
alter table public.user_strikes      enable row level security;
alter table public.appeals           enable row level security;
alter table public.notifications     enable row level security;
alter table public.device_tokens     enable row level security;
alter table public.banned_emails     enable row level security;   -- tanpa policy = tertutup
alter table public.file_delete_queue enable row level security;   -- tanpa policy = tertutup
alter table public.rate_limits       enable row level security;   -- tanpa policy = tertutup
alter table public.audit_logs        enable row level security;

-- Referensi: baca semua user login, tulis admin
create policy ref_read_prodi on public.prodi          for select to authenticated using (true);
create policy ref_read_tags  on public.tags           for select to authenticated using (true);
create policy ref_read_mp    on public.meeting_points for select to authenticated using (true);
create policy ref_read_cfg   on public.app_config     for select to authenticated using (key <> 'rate_limits' or public.is_admin());
create policy ref_write_prodi on public.prodi          for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy ref_write_tags  on public.tags           for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy ref_write_mp    on public.meeting_points for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy ref_write_cfg   on public.app_config     for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- profiles
create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()) or public.is_staff());
create policy profiles_insert on public.profiles for insert to authenticated
  with check (id = (select auth.uid()) and role = 'user' and status = 'active'
              and strike_count = 0 and sold_total = 0);
create policy profiles_update on public.profiles for update to authenticated
  using (id = (select auth.uid()) and public.is_active_user())
  with check (id = (select auth.uid()));

-- posts (baca publik via posts_public)
create policy posts_select on public.posts for select to authenticated
  using (author_id = (select auth.uid()) or public.is_staff());
create policy posts_update on public.posts for update to authenticated
  using (author_id = (select auth.uid()) and public.is_active_user())
  with check (author_id = (select auth.uid()));
create policy posts_delete on public.posts for delete to authenticated
  using (author_id = (select auth.uid()) and public.is_active_user());
create policy post_tags_select on public.post_tags for select to authenticated
  using (exists (select 1 from public.posts p where p.id = post_id));       -- ikut RLS posts (milik sendiri/staf)
create policy post_images_select on public.post_images for select to authenticated
  using (exists (select 1 from public.posts p where p.id = post_id));

-- comments (baca publik via comments_public)
create policy comments_select on public.comments for select to authenticated
  using (author_id = (select auth.uid()) or public.is_staff());
create policy comments_insert on public.comments for insert to authenticated
  with check (author_id = (select auth.uid()) and public.can_comment(post_id));
create policy comments_update on public.comments for update to authenticated
  using (author_id = (select auth.uid()) and public.is_active_user())
  with check (author_id = (select auth.uid()));

-- votes & saved (privat milik sendiri)
create policy post_votes_all on public.post_votes for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()) and public.is_post_visible(post_id));
create policy comment_votes_all on public.comment_votes for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()) and public.is_comment_visible(comment_id));
create policy saved_posts_all on public.saved_posts for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()) and public.is_post_visible(post_id));
create policy saved_products_all on public.saved_products for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()) and public.is_product_visible(product_id));

-- products (penjual tidak anonim -> tabel boleh dibaca langsung)
create policy products_select on public.products for select to authenticated
  using (seller_id = (select auth.uid()) or public.is_staff() or public.is_product_visible(id));
create policy products_update on public.products for update to authenticated
  using (seller_id = (select auth.uid()) and public.is_active_user())
  with check (seller_id = (select auth.uid()));
create policy product_tags_select on public.product_tags for select to authenticated
  using (exists (select 1 from public.products p where p.id = product_id));
create policy product_images_select on public.product_images for select to authenticated
  using (exists (select 1 from public.products p where p.id = product_id));
create policy product_images_insert on public.product_images for insert to authenticated
  with check (public.is_active_user()
              and exists (select 1 from public.products p where p.id = product_id and p.seller_id = (select auth.uid())));
create policy product_images_delete on public.product_images for delete to authenticated
  using (exists (select 1 from public.products p where p.id = product_id and p.seller_id = (select auth.uid())));

-- chat (staf TIDAK membaca chat; bukti lewat snapshot laporan)
create policy conv_select on public.conversations for select to authenticated
  using ((select auth.uid()) in (user_a, user_b));
create policy mchat_select on public.market_chats for select to authenticated
  using ((select auth.uid()) in (buyer_id, seller_id));
create policy offers_select on public.offers for select to authenticated
  using (public.is_market_member(market_chat_id));
create policy messages_select on public.messages for select to authenticated
  using (case when dm_conversation_id is not null then public.is_dm_member(dm_conversation_id)
              else public.is_market_member(market_chat_id) end);
create policy messages_insert on public.messages for insert to authenticated
  with check (sender_id = (select auth.uid())
              and type in ('text','image','location','contact','link')
              and case when dm_conversation_id is not null then public.can_send_dm(dm_conversation_id)
                       else public.can_send_market(market_chat_id) end);
create policy messages_delete on public.messages for delete to authenticated
  using (sender_id = (select auth.uid()) and created_at > now() - interval '15 minutes'
         and type in ('text','image','location','contact','link'));
create policy ratings_select on public.ratings for select to authenticated
  using ((select auth.uid()) in (rater_id, ratee_id));

-- sosial & moderasi
create policy blocks_all on public.blocks for all to authenticated
  using (blocker_id = (select auth.uid()))
  with check (blocker_id = (select auth.uid()));
create policy reports_select on public.reports for select to authenticated
  using (reporter_id = (select auth.uid()) or public.is_staff());
create policy reports_insert on public.reports for insert to authenticated
  with check (reporter_id = (select auth.uid()) and public.is_active_user());
create policy strikes_select on public.user_strikes for select to authenticated
  using (user_id = (select auth.uid()) or public.is_staff());
create policy appeals_select on public.appeals for select to authenticated
  using (user_id = (select auth.uid()) or public.is_staff());
create policy appeals_insert on public.appeals for insert to authenticated
  with check (user_id = (select auth.uid()));       -- boleh meski suspended
create policy appeals_update on public.appeals for update to authenticated
  using (public.is_staff()) with check (public.is_staff());

-- notifikasi & token
create policy notif_select on public.notifications for select to authenticated using (user_id = (select auth.uid()));
create policy notif_update on public.notifications for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy notif_delete on public.notifications for delete to authenticated using (user_id = (select auth.uid()));
create policy tokens_all   on public.device_tokens for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy audit_select on public.audit_logs for select to authenticated using (public.is_admin());

-- ---------- 5. STORAGE ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('avatars',        'avatars',        true,   262144, array['image/jpeg','image/png','image/webp']),
  ('post-images',    'post-images',    false, 1048576, array['image/jpeg','image/png','image/webp']),
  ('product-images', 'product-images', false, 1048576, array['image/jpeg','image/png','image/webp']),
  ('chat-images',    'chat-images',    false, 1048576, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set file_size_limit = excluded.file_size_limit,
                               allowed_mime_types = excluded.allowed_mime_types;

-- avatars: path {uid}/avatar-*.webp
create policy st_avatars_write on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text and public.is_active_user());
create policy st_avatars_update on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy st_avatars_delete on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- post-images & product-images: nama file = uuid acak (tanpa user id). Kepemilikan = kolom owner_id.
create policy st_media_read on storage.objects for select to authenticated
  using (bucket_id in ('post-images','product-images') and public.is_active_user());
create policy st_media_insert on storage.objects for insert to authenticated
  with check (bucket_id in ('post-images','product-images') and public.is_active_user()
              and name ~ '^[0-9a-f-]{36}\.(webp|jpg|png)$');
create policy st_media_delete on storage.objects for delete to authenticated
  using (bucket_id in ('post-images','product-images') and owner_id = (select auth.uid())::text);

-- chat-images: path {dm|market}/{chat_id}/{uid}/{file}
create policy st_chat_read on storage.objects for select to authenticated
  using (bucket_id = 'chat-images' and public.is_chat_member((storage.foldername(name))[1], ((storage.foldername(name))[2])::uuid));
create policy st_chat_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'chat-images'
              and (storage.foldername(name))[3] = (select auth.uid())::text
              and public.is_chat_member((storage.foldername(name))[1], ((storage.foldername(name))[2])::uuid));

-- ---------- 6. REALTIME (RLS tetap berlaku) ----------
alter publication supabase_realtime add table public.messages, public.market_chats, public.notifications;
