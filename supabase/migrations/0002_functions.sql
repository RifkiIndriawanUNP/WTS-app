-- =============================================================================
-- WTS | 0002_functions.sql : helper, trigger, RPC, view
-- Konvensi:
--  * Tabel dasar bersifat privat; konten publik dibaca lewat VIEW (anonimitas).
--  * Operasi bernilai bisnis lewat RPC (security definer) -> RLS menolak DML langsung.
--  * is_internal() = konteks sistem/RPC sehingga guard trigger dilewati.
-- =============================================================================

-- ---------- HELPER ----------
create or replace function public.is_internal() returns boolean
language sql stable as $$
  select auth.uid() is null
      or coalesce(current_setting('wts.internal', true), '') = '1'
      or pg_trigger_depth() > 1
$$;

create or replace function public.is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles
                 where id = auth.uid() and role in ('moderator','admin') and status = 'active')
$$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles
                 where id = auth.uid() and role = 'admin' and status = 'active')
$$;

create or replace function public.is_active_user() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles
                 where id = auth.uid()
                   and (status = 'active' or (status = 'suspended' and suspended_until <= now())))
$$;

create or replace function public.require_active_user() returns void
language plpgsql stable as $$
begin
  if not public.is_active_user() then
    raise exception 'account_inactive' using errcode = '42501';
  end if;
end $$;

create or replace function public.is_blocked_between(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from blocks
                 where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a))
$$;

create or replace function public.fmt_rp(n bigint) returns text
language sql immutable as $$
  select 'Rp' || replace(to_char(n, 'FM999,999,999,999'), ',', '.')
$$;

create or replace function public.calc_hot(p_score int, p_created timestamptz) returns double precision
language sql stable as $$
  select p_score::double precision
         / power(extract(epoch from (now() - p_created)) / 3600.0 + 2, 1.5)
$$;

create or replace function public.is_dm_member(conv uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from conversations c
                 where c.id = conv and auth.uid() in (c.user_a, c.user_b))
$$;

create or replace function public.is_market_member(chat uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from market_chats c
                 where c.id = chat and auth.uid() in (c.buyer_id, c.seller_id))
$$;

create or replace function public.is_chat_member(kind text, chat uuid) returns boolean
language sql stable as $$
  select case kind when 'dm' then public.is_dm_member(chat)
                   when 'market' then public.is_market_member(chat)
                   else false end
$$;

create or replace function public.is_post_visible(pid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_active_user() and exists (
    select 1 from posts p
    where p.id = pid and p.status in ('active','closed') and p.expires_at > now()
      and not public.is_blocked_between(auth.uid(), p.author_id))
$$;

create or replace function public.can_comment(pid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_active_user() and exists (
    select 1 from posts p
    where p.id = pid and p.status = 'active' and p.expires_at > now()
      and not public.is_blocked_between(auth.uid(), p.author_id))
$$;

create or replace function public.is_comment_visible(cid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from comments c
                 where c.id = cid and c.status = 'active' and public.is_post_visible(c.post_id))
$$;

create or replace function public.is_product_visible(pid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_active_user() and exists (
    select 1 from products p
    where p.id = pid
      and ((p.status in ('available','booked') and p.expires_at > now())
           or (p.status = 'sold' and p.sold_at > now() - interval '3 days'))
      and not public.is_blocked_between(auth.uid(), p.seller_id))
$$;

create or replace function public.can_send_dm(conv uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_active_user() and exists (
    select 1 from conversations c
    where c.id = conv and auth.uid() in (c.user_a, c.user_b)
      and not public.is_blocked_between(c.user_a, c.user_b)
      and (c.status = 'accepted'
           or (c.requester_id = auth.uid()
               and not exists (select 1 from messages m
                               where m.dm_conversation_id = c.id and m.sender_id = auth.uid()))))
$$;

create or replace function public.can_send_market(chat uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_active_user() and exists (
    select 1 from market_chats c
    where c.id = chat and auth.uid() in (c.buyer_id, c.seller_id)
      and c.status in ('negotiating','agreed','on_the_way','arrived','sold')
      and not public.is_blocked_between(c.buyer_id, c.seller_id))
$$;

-- ---------- RATE LIMIT (konfigurasi di app_config.rate_limits) ----------
create or replace function public.rate_limit(p_action text) returns void
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid(); cfg jsonb; mx int; win interval; secs bigint; b timestamptz; c int;
begin
  if uid is null then return; end if;
  select value -> p_action into cfg from app_config where key = 'rate_limits';
  if cfg is null then return; end if;
  mx := (cfg ->> 'max')::int;
  win := (cfg ->> 'window')::interval;
  secs := extract(epoch from win)::bigint;
  b := to_timestamp((extract(epoch from now())::bigint / secs) * secs);
  insert into rate_limits (user_id, action, bucket, hits) values (uid, p_action, b, 1)
  on conflict (user_id, action, bucket) do update set hits = rate_limits.hits + 1
  returning hits into c;
  if c > mx then
    raise exception 'rate_limit_exceeded' using errcode = 'P0001', detail = p_action;
  end if;
end $$;

create or replace function public.notify(p_user uuid, p_type text, p_payload jsonb default '{}')
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_user is not null then
    insert into notifications (user_id, type, payload) values (p_user, p_type, p_payload);
  end if;
end $$;

create or replace function public.ping() returns text
language sql stable as $$ select 'ok' $$;

-- ---------- AUTH: hanya @nusaputra.ac.id & bukan email ter-ban ----------
create or replace function public.trg_auth_email_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare h text;
begin
  if new.email is null or lower(new.email) !~ '^[a-z0-9._%+-]+@nusaputra\.ac\.id$' then
    raise exception 'email_domain_not_allowed';
  end if;
  h := encode(sha256(convert_to(lower(new.email), 'utf8')), 'hex');
  if exists (select 1 from banned_emails where email_hash = h) then
    raise exception 'email_banned';
  end if;
  return new;
end $$;

create trigger trg_auth_email_guard
  before insert or update of email on auth.users
  for each row execute function public.trg_auth_email_guard();

-- ---------- GUARD KOLOM (lapis kedua setelah GRANT kolom) ----------
create or replace function public.trg_a_profiles_guard() returns trigger
language plpgsql as $$
declare allowed text[] := array['username','prodi_id','bio','avatar_path','dm_privacy','notif_prefs','username_changed_at'];
begin
  if public.is_internal() then return new; end if;
  if (to_jsonb(new) - allowed) is distinct from (to_jsonb(old) - allowed) then
    raise exception 'immutable_columns';
  end if;
  if new.username is distinct from old.username then
    if old.username_changed_at is not null and old.username_changed_at > now() - interval '30 days' then
      raise exception 'username_change_too_soon';
    end if;
    new.username_changed_at := now();
  end if;
  return new;
end $$;
create trigger trg_a_profiles_guard before update on public.profiles
  for each row execute function public.trg_a_profiles_guard();

create or replace function public.trg_a_posts_guard() returns trigger
language plpgsql as $$
declare ign text[] := array['score','search'];
        allowed text[] := array['caption','status','expires_at'];
begin
  if public.is_internal() then return new; end if;
  if (to_jsonb(new) - ign - allowed) is distinct from (to_jsonb(old) - ign - allowed) then
    raise exception 'immutable_columns';
  end if;
  if old.status = 'hidden' then raise exception 'content_hidden'; end if;
  if new.status is distinct from old.status
     and (old.status::text, new.status::text) not in (('active','closed'),('closed','active'),('expired','active')) then
    raise exception 'invalid_status';
  end if;
  if old.status = 'expired' then
    if old.hard_delete_at <= now() then raise exception 'too_late_to_restore'; end if;
    if new.expires_at = old.expires_at then new.expires_at := now() + interval '7 days'; end if;
  end if;
  if new.caption is distinct from old.caption then
    if old.created_at < now() - interval '24 hours' then raise exception 'edit_window_closed'; end if;
    new.edited_at := now();
  end if;
  return new;
end $$;
create trigger trg_a_posts_guard before update on public.posts
  for each row execute function public.trg_a_posts_guard();

create or replace function public.trg_a_products_guard() returns trigger
language plpgsql as $$
declare ign text[] := array['search'];
        allowed text[] := array['title','description','price','rent_unit','deposit','condition',
                                'defect_note','negotiable','meeting_point_id','prodi_id'];
begin
  if public.is_internal() then return new; end if;
  if (to_jsonb(new) - ign - allowed) is distinct from (to_jsonb(old) - ign - allowed) then
    raise exception 'immutable_columns';
  end if;
  if old.status not in ('available','booked') then raise exception 'not_editable'; end if;
  if old.status = 'booked' and new.price is distinct from old.price then
    raise exception 'price_locked_while_booked';
  end if;
  return new;
end $$;
create trigger trg_a_products_guard before update on public.products
  for each row execute function public.trg_a_products_guard();

create or replace function public.trg_a_comments_guard() returns trigger
language plpgsql as $$
declare ign text[] := array['score'];
begin
  if public.is_internal() then return new; end if;
  if (to_jsonb(new) - ign - array['body']) is distinct from (to_jsonb(old) - ign - array['body']) then
    raise exception 'immutable_columns';
  end if;
  if old.status <> 'active' or old.created_at < now() - interval '5 minutes' then
    raise exception 'edit_window_closed';
  end if;
  new.edited_at := now();
  return new;
end $$;
create trigger trg_a_comments_guard before update on public.comments
  for each row execute function public.trg_a_comments_guard();

create or replace function public.trg_a_notifications_guard() returns trigger
language plpgsql as $$
begin
  if public.is_internal() then return new; end if;
  if (to_jsonb(new) - 'is_read') is distinct from (to_jsonb(old) - 'is_read') then
    raise exception 'immutable_columns';
  end if;
  return new;
end $$;
create trigger trg_a_notifications_guard before update on public.notifications
  for each row execute function public.trg_a_notifications_guard();

-- ---------- EXPIRY: hard_delete_at = expires_at + 15 hari ----------
create or replace function public.trg_b_set_expiry() returns trigger
language plpgsql as $$
begin
  if tg_op = 'INSERT' or new.expires_at is distinct from old.expires_at then
    if not public.is_internal()
       and (new.expires_at < now() + interval '1 hour' or new.expires_at > now() + interval '30 days 1 hour') then
      raise exception 'invalid_expiry';
    end if;
    new.hard_delete_at := new.expires_at + interval '15 days';
  end if;
  return new;
end $$;
create trigger trg_b_posts_expiry before insert or update on public.posts
  for each row execute function public.trg_b_set_expiry();
create trigger trg_b_products_expiry before insert or update on public.products
  for each row execute function public.trg_b_set_expiry();

-- ---------- BATAS JUMLAH ANAK (tag/gambar) ----------
create or replace function public.trg_limit_children() returns trigger
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  execute format('select count(*) from %I where %I = $1', tg_argv[0], tg_argv[1])
    into n using (to_jsonb(new) ->> tg_argv[1])::uuid;
  if n >= tg_argv[2]::int then raise exception 'too_many_%', tg_argv[0]; end if;
  return new;
end $$;
create trigger trg_limit_post_tags     before insert on public.post_tags
  for each row execute function public.trg_limit_children('post_tags','post_id','2');
create trigger trg_limit_post_images   before insert on public.post_images
  for each row execute function public.trg_limit_children('post_images','post_id','5');
create trigger trg_limit_product_tags  before insert on public.product_tags
  for each row execute function public.trg_limit_children('product_tags','product_id','2');
create trigger trg_limit_product_images before insert on public.product_images
  for each row execute function public.trg_limit_children('product_images','product_id','10');

-- Path gambar harus UUID acak & file benar-benar milik pengunggah (cek storage.objects)
create or replace function public.trg_check_image_path() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.path !~ '^[0-9a-f-]{36}\.(webp|jpg|png)$' then raise exception 'invalid_image_path'; end if;
  if auth.uid() is not null and not exists (
       select 1 from storage.objects o
       where o.bucket_id = tg_argv[0] and o.name = new.path and o.owner_id = auth.uid()::text) then
    raise exception 'image_not_owned';
  end if;
  return new;
end $$;
create trigger trg_check_post_image before insert on public.post_images
  for each row execute function public.trg_check_image_path('post-images');
create trigger trg_check_product_image before insert on public.product_images
  for each row execute function public.trg_check_image_path('product-images');

-- ---------- ANTRIAN HAPUS FILE ----------
create or replace function public.trg_queue_file() returns trigger
language plpgsql security definer set search_path = public as $$
declare j jsonb := to_jsonb(old); p text;
begin
  p := coalesce(j ->> 'path', j -> 'meta' ->> 'path', j ->> 'avatar_path');
  if p is not null then
    insert into file_delete_queue (bucket, path) values (tg_argv[0], p);
  end if;
  return old;
end $$;
create trigger trg_q_post_images    after delete on public.post_images
  for each row execute function public.trg_queue_file('post-images');
create trigger trg_q_product_images after delete on public.product_images
  for each row execute function public.trg_queue_file('product-images');
create trigger trg_q_avatar_del     after delete on public.profiles
  for each row execute function public.trg_queue_file('avatars');
create trigger trg_q_chat_images    after delete on public.messages
  for each row when (old.type = 'image') execute function public.trg_queue_file('chat-images');

create or replace function public.trg_q_avatar_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if old.avatar_path is not null and new.avatar_path is distinct from old.avatar_path then
    insert into file_delete_queue (bucket, path) values ('avatars', old.avatar_path);
  end if;
  return new;
end $$;
create trigger trg_q_avatar_change after update of avatar_path on public.profiles
  for each row execute function public.trg_q_avatar_change();

-- ---------- VOTE & KOMENTAR ----------
create or replace function public.trg_block_self_vote() returns trigger
language plpgsql security definer set search_path = public as $$
declare owner uuid;
begin
  if tg_table_name = 'post_votes' then
    select author_id into owner from posts where id = new.post_id;
  else
    select author_id into owner from comments where id = new.comment_id;
  end if;
  if owner = new.user_id then raise exception 'cannot_vote_own_content'; end if;
  return new;
end $$;
create trigger trg_self_vote_p before insert on public.post_votes
  for each row execute function public.trg_block_self_vote();
create trigger trg_self_vote_c before insert on public.comment_votes
  for each row execute function public.trg_block_self_vote();

create or replace function public.trg_post_votes_sync() returns trigger
language plpgsql security definer set search_path = public as $$
declare pid uuid := coalesce(new.post_id, old.post_id);
begin
  update posts set
    upvotes   = (select count(*) from post_votes where post_id = pid and value = 1),
    downvotes = (select count(*) from post_votes where post_id = pid and value = -1)
  where id = pid;
  update posts set hot_score = public.calc_hot(score, created_at) where id = pid;
  return null;
end $$;
create trigger trg_post_votes_sync after insert or update or delete on public.post_votes
  for each row execute function public.trg_post_votes_sync();

create or replace function public.trg_comment_votes_sync() returns trigger
language plpgsql security definer set search_path = public as $$
declare cid uuid := coalesce(new.comment_id, old.comment_id);
begin
  update comments set
    upvotes   = (select count(*) from comment_votes where comment_id = cid and value = 1),
    downvotes = (select count(*) from comment_votes where comment_id = cid and value = -1)
  where id = cid;
  return null;
end $$;
create trigger trg_comment_votes_sync after insert or update or delete on public.comment_votes
  for each row execute function public.trg_comment_votes_sync();

create or replace function public.trg_comment_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare par comments%rowtype;
begin
  perform public.rate_limit('comment');
  if new.parent_id is not null then
    select * into par from comments where id = new.parent_id;
    if not found or par.post_id <> new.post_id or par.status <> 'active' then
      raise exception 'invalid_parent';
    end if;
    if par.depth >= 2 then raise exception 'max_depth'; end if;
    new.depth := par.depth + 1;
  else
    new.depth := 0;
  end if;
  return new;
end $$;
create trigger trg_comment_before_insert before insert on public.comments
  for each row execute function public.trg_comment_before_insert();

create or replace function public.trg_comment_after() returns trigger
language plpgsql security definer set search_path = public as $$
declare pid uuid := coalesce(new.post_id, old.post_id); post_owner uuid; par_owner uuid;
begin
  update posts set comment_count = (select count(*) from comments where post_id = pid and status = 'active')
   where id = pid;
  if tg_op = 'INSERT' then
    select author_id into post_owner from posts where id = new.post_id;
    if post_owner <> new.author_id then
      perform public.notify(post_owner, 'comment', jsonb_build_object('post_id', new.post_id, 'comment_id', new.id));
    end if;
    if new.parent_id is not null then
      select author_id into par_owner from comments where id = new.parent_id;
      if par_owner <> new.author_id and par_owner is distinct from post_owner then
        perform public.notify(par_owner, 'reply', jsonb_build_object('post_id', new.post_id, 'comment_id', new.id));
      end if;
    end if;
  end if;
  return null;
end $$;
create trigger trg_comment_after after insert or delete or update of status on public.comments
  for each row execute function public.trg_comment_after();

-- ---------- PESAN ----------
create or replace function public.trg_message_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare prefix text;
begin
  if new.sender_id is not null and not public.is_internal() then
    perform public.rate_limit('message');
  end if;
  prefix := case when new.dm_conversation_id is not null then 'dm/' || new.dm_conversation_id
                 else 'market/' || new.market_chat_id end;
  if new.type = 'text' and coalesce(btrim(new.body), '') = '' then raise exception 'empty_message'; end if;
  if new.type = 'link' and coalesce(new.body, '') !~ '^https?://' then raise exception 'invalid_link'; end if;
  if new.type = 'image' and (new.meta ->> 'path') is null then raise exception 'invalid_image'; end if;
  if new.type = 'image' and new.sender_id is not null
     and (new.meta ->> 'path') not like prefix || '/' || new.sender_id || '/%' then
    raise exception 'invalid_image_path';
  end if;
  if new.type = 'location' and not coalesce((new.meta ->> 'lat')::float between -90 and 90
                                         and (new.meta ->> 'lng')::float between -180 and 180, false) then
    raise exception 'invalid_location';
  end if;
  if new.type = 'contact' and coalesce(new.meta ->> 'phone', '') !~ '^\+?[0-9]{8,15}$' then
    raise exception 'invalid_phone';
  end if;
  if new.dm_conversation_id is not null then
    new.delete_at := new.created_at + interval '3 days';
  end if;
  return new;
end $$;
create trigger trg_message_before_insert before insert on public.messages
  for each row execute function public.trg_message_before_insert();

create or replace function public.trg_message_after_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare other uuid; mc market_chats%rowtype; cid uuid := coalesce(new.dm_conversation_id, new.market_chat_id);
begin
  if new.dm_conversation_id is not null then
    update conversations set last_message_at = new.created_at where id = new.dm_conversation_id;
    if new.sender_id is not null then
      select case when user_a = new.sender_id then user_b else user_a end into other
        from conversations where id = new.dm_conversation_id;
    end if;
  else
    update market_chats set last_activity_at = new.created_at,
           delete_at = case when status = 'negotiating' then new.created_at + interval '3 days' else delete_at end
     where id = new.market_chat_id returning * into mc;
    if new.sender_id is not null then
      other := case when mc.buyer_id = new.sender_id then mc.seller_id else mc.buyer_id end;
    end if;
  end if;
  if other is not null and new.type <> 'system'
     and not exists (select 1 from notifications
                     where user_id = other and type = 'message' and not is_read
                       and created_at > now() - interval '2 minutes'
                       and payload ->> 'chat_id' = cid::text) then
    perform public.notify(other, 'message', jsonb_build_object(
      'chat_type', case when new.dm_conversation_id is not null then 'dm' else 'market' end,
      'chat_id', cid));
  end if;
  return null;
end $$;
create trigger trg_message_after_insert after insert on public.messages
  for each row execute function public.trg_message_after_insert();

-- ---------- LAPORAN: snapshot bukti + auto-hide ----------
create or replace function public.build_snapshot(t report_target, tid uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare j jsonb; m messages%rowtype;
begin
  if t = 'post' then
    select to_jsonb(p) - 'search' || jsonb_build_object('images',
      (select coalesce(jsonb_agg(path), '[]') from post_images where post_id = p.id)) into j from posts p where id = tid;
  elsif t = 'comment' then
    select to_jsonb(c) - 'score' into j from comments c where id = tid;
  elsif t = 'product' then
    select to_jsonb(p) - 'search' || jsonb_build_object('images',
      (select coalesce(jsonb_agg(path), '[]') from product_images where product_id = p.id)) into j from products p where id = tid;
  elsif t = 'user' then
    select jsonb_build_object('id', id, 'username', username, 'bio', bio, 'avatar_path', avatar_path) into j
      from profiles where id = tid;
  elsif t = 'message' then
    select * into m from messages where id = tid;
    select jsonb_build_object('target', m.id, 'messages', coalesce(jsonb_agg(to_jsonb(x) order by x.created_at), '[]')) into j
      from (select id, sender_id, type, body, meta, created_at from messages
             where coalesce(dm_conversation_id, market_chat_id) = coalesce(m.dm_conversation_id, m.market_chat_id)
             order by created_at desc limit 20) x;
  end if;
  return j;
end $$;

create or replace function public.trg_report_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.rate_limit('report');
  new.snapshot := public.build_snapshot(new.target_type, new.target_id);
  if new.snapshot is null then raise exception 'target_not_found'; end if;
  new.target_user_id := case new.target_type
    when 'post'    then (select author_id from posts where id = new.target_id)
    when 'comment' then (select author_id from comments where id = new.target_id)
    when 'product' then (select seller_id from products where id = new.target_id)
    when 'user'    then new.target_id
    when 'message' then (select sender_id from messages where id = new.target_id) end;
  if new.target_user_id = new.reporter_id then raise exception 'cannot_report_self'; end if;
  return new;
end $$;
create trigger trg_report_before_insert before insert on public.reports
  for each row execute function public.trg_report_before_insert();

create or replace function public.trg_report_after_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare n int; thr int;
begin
  select count(distinct reporter_id) into n from reports
   where target_type = new.target_type and target_id = new.target_id and status = 'pending';
  thr := case when new.target_type = 'product' and new.reason = 'scam' then 2 else 3 end;
  if n >= thr then
    if new.target_type = 'post' then
      update posts set status = 'hidden' where id = new.target_id and status in ('active','closed');
    elsif new.target_type = 'comment' then
      update comments set status = 'hidden' where id = new.target_id and status = 'active';
    elsif new.target_type = 'product' then
      update products set status = 'hidden' where id = new.target_id and status in ('available','booked');
    end if;
  end if;
  return null;
end $$;
create trigger trg_report_after_insert after insert on public.reports
  for each row execute function public.trg_report_after_insert();

-- =============================================================================
-- RPC (dipanggil klien lewat supabase.rpc)
-- =============================================================================

create or replace function public.touch_last_login() returns void
language plpgsql security definer set search_path = public as $$
begin
  update profiles set last_login_at = now(), inactive_warned_at = null
   where id = auth.uid() and last_login_at < now() - interval '1 hour';
end $$;

create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and status = 'active') then
    raise exception 'account_not_deletable' using errcode = '42501';
  end if;
  delete from auth.users where id = auth.uid();   -- cascade ke semua data + antrean file
end $$;

-- ----- Linimasa -----
create or replace function public.create_post(
  p_caption text, p_tag_ids smallint[], p_images jsonb default '[]',
  p_anonymous boolean default false, p_days int default 30, p_extra jsonb default '{}')
returns uuid language plpgsql security definer set search_path = public as $$
declare pid uuid;
begin
  perform public.require_active_user();
  perform public.rate_limit('post');
  if p_days not in (1,3,7,14,30) then raise exception 'invalid_duration'; end if;
  if coalesce(array_length(p_tag_ids, 1), 0) not between 1 and 2 then raise exception 'tags_required'; end if;
  if (select count(*) from tags where id = any(p_tag_ids) and scope = 'timeline' and is_active)
       <> array_length(p_tag_ids, 1) then raise exception 'invalid_tag'; end if;
  if jsonb_array_length(p_images) > 5 then raise exception 'too_many_images'; end if;
  if p_extra ? 'link' and (p_extra ->> 'link') !~* '^https?://' then raise exception 'invalid_link'; end if;
  insert into posts (author_id, is_anonymous, caption, extra, expires_at)
  values (auth.uid(), p_anonymous, p_caption,
          jsonb_strip_nulls(jsonb_build_object('link', p_extra -> 'link', 'deadline', p_extra -> 'deadline',
                                               'duration_min', p_extra -> 'duration_min')),
          now() + make_interval(days => p_days))
  returning id into pid;
  insert into post_tags (post_id, tag_id) select pid, unnest(p_tag_ids);
  insert into post_images (post_id, path, width, height, sort_order)
  select pid, e ->> 'path', (e ->> 'w')::int, (e ->> 'h')::int, (ord - 1)::smallint
    from jsonb_array_elements(p_images) with ordinality as t(e, ord);
  return pid;
end $$;

create or replace function public.delete_comment(p_comment uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('wts.internal', '1', true);
  if not exists (select 1 from comments where id = p_comment and author_id = auth.uid()) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if exists (select 1 from comments where parent_id = p_comment) then
    update comments set status = 'deleted', body = '[dihapus]' where id = p_comment;
  else
    delete from comments where id = p_comment;
  end if;
end $$;

-- ----- Marketplace -----
create or replace function public.create_product(
  p_title text, p_description text, p_listing_type listing_type, p_price bigint,
  p_condition item_condition, p_tag_ids smallint[], p_images jsonb,
  p_rent_unit rent_unit default null, p_deposit bigint default null, p_defect_note text default null,
  p_negotiable boolean default true, p_meeting_point smallint default null, p_prodi smallint default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare pid uuid;
begin
  perform public.require_active_user();
  perform public.rate_limit('product');
  if (select count(*) from products where seller_id = auth.uid() and status in ('available','booked')) >= 20 then
    raise exception 'too_many_active_products';
  end if;
  if coalesce(array_length(p_tag_ids, 1), 0) not between 1 and 2 then raise exception 'tags_required'; end if;
  if (select count(*) from tags where id = any(p_tag_ids) and scope = 'product' and is_active)
       <> array_length(p_tag_ids, 1) then raise exception 'invalid_tag'; end if;
  if jsonb_array_length(p_images) not between 1 and 10 then raise exception 'images_required'; end if;
  insert into products (seller_id, title, description, listing_type, price, rent_unit, deposit, condition,
                        defect_note, negotiable, meeting_point_id, prodi_id)
  values (auth.uid(), p_title, p_description, p_listing_type, p_price, p_rent_unit, p_deposit, p_condition,
          p_defect_note, p_negotiable, p_meeting_point, p_prodi)
  returning id into pid;
  insert into product_tags (product_id, tag_id) select pid, unnest(p_tag_ids);
  insert into product_images (product_id, path, width, height, sort_order)
  select pid, e ->> 'path', (e ->> 'w')::int, (e ->> 'h')::int, (ord - 1)::smallint
    from jsonb_array_elements(p_images) with ordinality as t(e, ord);
  return pid;
end $$;

create or replace function public.extend_product(p_product uuid) returns void
language plpgsql security definer set search_path = public as $$
declare p products%rowtype;
begin
  perform public.require_active_user();
  perform set_config('wts.internal', '1', true);
  select * into p from products where id = p_product and seller_id = auth.uid() for update;
  if not found then raise exception 'forbidden' using errcode = '42501'; end if;
  if p.status not in ('available','booked','expired') or p.hard_delete_at <= now() then
    raise exception 'invalid_state';
  end if;
  if p.extension_count >= 3 then raise exception 'max_extensions'; end if;
  -- hard_delete_at dihitung otomatis oleh trigger trg_b_set_expiry (= expires_at + 15 hari)
  update products set expires_at = greatest(expires_at, now()) + interval '30 days',
         status = case when status = 'expired' then 'available' else status end,
         extension_count = extension_count + 1, reminded_at = null
   where id = p_product;
end $$;

create or replace function public.delete_product(p_product uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('wts.internal', '1', true);
  if not exists (select 1 from products where id = p_product and seller_id = auth.uid()
                   and status in ('available','booked','expired','hidden')) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update products set status = 'deleted', hard_delete_at = now() + interval '3 days' where id = p_product;
  update market_chats set status = 'closed', delete_at = now() + interval '3 days'
   where product_id = p_product and status in ('negotiating','agreed','on_the_way','arrived');
end $$;

-- ----- DM -----
create or replace function public.start_dm(p_user uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); cid uuid; priv text; st account_status;
begin
  perform public.require_active_user();
  if p_user = uid then raise exception 'invalid_target'; end if;
  select dm_privacy, status into priv, st from profiles where id = p_user;
  if not found or st = 'banned' then raise exception 'user_not_found'; end if;
  if public.is_blocked_between(uid, p_user) then raise exception 'blocked'; end if;
  select id into cid from conversations where user_a = least(uid, p_user) and user_b = greatest(uid, p_user);
  if cid is not null then return cid; end if;
  if priv = 'none' then raise exception 'dm_disabled'; end if;
  perform public.rate_limit('dm_new');
  insert into conversations (user_a, user_b, requester_id)
  values (least(uid, p_user), greatest(uid, p_user), uid) returning id into cid;
  return cid;
end $$;

create or replace function public.accept_dm(p_conv uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update conversations set status = 'accepted'
   where id = p_conv and requester_id <> auth.uid() and auth.uid() in (user_a, user_b);
  if not found then raise exception 'forbidden' using errcode = '42501'; end if;
end $$;

create or replace function public.mark_read(p_kind text, p_chat uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_chat_member(p_kind, p_chat) then raise exception 'forbidden' using errcode = '42501'; end if;
  update messages set read_at = now()
   where read_at is null and sender_id is distinct from auth.uid()
     and (case p_kind when 'dm' then dm_conversation_id else market_chat_id end) = p_chat;
end $$;

-- ----- Chat market (state machine COD) -----
create or replace function public.open_market_chat(p_product uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare p products%rowtype; cid uuid; uid uuid := auth.uid();
begin
  perform public.require_active_user();
  select * into p from products where id = p_product and status in ('available','booked') and expires_at > now();
  if not found then raise exception 'product_unavailable'; end if;
  if p.seller_id = uid then raise exception 'own_product'; end if;
  if public.is_blocked_between(uid, p.seller_id) then raise exception 'blocked'; end if;
  select id into cid from market_chats where product_id = p_product and buyer_id = uid;
  if cid is null then
    perform public.rate_limit('market_chat_new');
    insert into market_chats (product_id, buyer_id, seller_id) values (p_product, uid, p.seller_id)
    returning id into cid;
    insert into messages (market_chat_id, sender_id, type, body, meta)
    values (cid, null, 'system', 'Chat dimulai. Tips: bertemu di area kampus yang ramai dan cek barang sebelum bayar.',
            '{"event":"started"}');
    perform public.notify(p.seller_id, 'market_new_chat', jsonb_build_object('chat_id', cid, 'product_id', p_product));
  end if;
  return cid;
end $$;

create or replace function public.send_offer(p_chat uuid, p_price bigint) returns uuid
language plpgsql security definer set search_path = public as $$
declare c market_chats%rowtype; uid uuid := auth.uid(); oid uuid; p products%rowtype; other uuid;
begin
  perform public.require_active_user();
  perform public.rate_limit('offer');
  perform set_config('wts.internal', '1', true);
  select * into c from market_chats where id = p_chat for update;
  if not found or uid not in (c.buyer_id, c.seller_id) then raise exception 'forbidden' using errcode = '42501'; end if;
  if c.status <> 'negotiating' then raise exception 'invalid_state'; end if;
  select * into p from products where id = c.product_id;
  if p.status <> 'available' then raise exception 'product_not_available'; end if;
  update offers set status = 'expired' where market_chat_id = p_chat and status = 'pending' and expires_at <= now();
  if exists (select 1 from offers where market_chat_id = p_chat and status = 'pending') then
    raise exception 'pending_offer_exists';
  end if;
  insert into offers (market_chat_id, from_user, price) values (p_chat, uid, p_price) returning id into oid;
  insert into messages (market_chat_id, sender_id, type, body, meta)
  values (p_chat, uid, 'offer', public.fmt_rp(p_price), jsonb_build_object('offer_id', oid, 'price', p_price));
  other := case when uid = c.buyer_id then c.seller_id else c.buyer_id end;
  perform public.notify(other, 'market_offer', jsonb_build_object('chat_id', p_chat, 'price', p_price));
  return oid;
end $$;

create or replace function public.respond_offer(p_offer uuid, p_action text, p_counter bigint default null)
returns void language plpgsql security definer set search_path = public as $$
declare o offers%rowtype; c market_chats%rowtype; p products%rowtype; uid uuid := auth.uid(); new_id uuid; other uuid;
begin
  perform public.require_active_user();
  perform set_config('wts.internal', '1', true);
  select * into o from offers where id = p_offer for update;
  if not found then raise exception 'not_found'; end if;
  select * into c from market_chats where id = o.market_chat_id for update;
  if uid not in (c.buyer_id, c.seller_id) or uid = o.from_user then raise exception 'forbidden' using errcode = '42501'; end if;
  if o.status <> 'pending' or o.expires_at <= now() or c.status <> 'negotiating' then raise exception 'invalid_state'; end if;
  select * into p from products where id = c.product_id for update;   -- serialisasi per produk
  other := o.from_user;

  if p_action = 'accept' then
    if p.status <> 'available' then raise exception 'product_booked'; end if;
    update offers set status = 'accepted', responded_at = now() where id = o.id;
    update market_chats set status = 'agreed', agreed_price = o.price, delete_at = null where id = c.id;
    update products set status = 'booked' where id = p.id;
    insert into messages (market_chat_id, sender_id, type, body, meta)
    values (c.id, null, 'system', 'Harga disepakati ' || public.fmt_rp(o.price) || '. Silakan atur titik temu COD.',
            jsonb_build_object('event', 'agreed', 'price', o.price));
    perform public.notify(other, 'market_agreed', jsonb_build_object('chat_id', c.id, 'price', o.price));
  elsif p_action = 'reject' then
    update offers set status = 'rejected', responded_at = now() where id = o.id;
    insert into messages (market_chat_id, sender_id, type, body, meta)
    values (c.id, null, 'system', 'Tawaran ' || public.fmt_rp(o.price) || ' ditolak.', '{"event":"offer_rejected"}');
    perform public.notify(other, 'market_offer_rejected', jsonb_build_object('chat_id', c.id));
  elsif p_action = 'counter' then
    if p_counter is null or p_counter <= 0 then raise exception 'invalid_price'; end if;
    update offers set status = 'countered', responded_at = now() where id = o.id;
    insert into offers (market_chat_id, from_user, price) values (c.id, uid, p_counter) returning id into new_id;
    insert into messages (market_chat_id, sender_id, type, body, meta)
    values (c.id, uid, 'offer', public.fmt_rp(p_counter), jsonb_build_object('offer_id', new_id, 'price', p_counter));
    perform public.notify(other, 'market_offer', jsonb_build_object('chat_id', c.id, 'price', p_counter));
  else
    raise exception 'invalid_action';
  end if;
exception when unique_violation then
  raise exception 'product_booked';
end $$;

create or replace function public.set_chat_progress(p_chat uuid, p_step text) returns void
language plpgsql security definer set search_path = public as $$
declare c market_chats%rowtype; uid uuid := auth.uid(); who text; other uuid;
begin
  perform public.require_active_user();
  perform set_config('wts.internal', '1', true);
  select * into c from market_chats where id = p_chat for update;
  if not found or uid not in (c.buyer_id, c.seller_id) then raise exception 'forbidden' using errcode = '42501'; end if;
  if c.status not in ('agreed','on_the_way','arrived') then raise exception 'invalid_state'; end if;
  who := case when uid = c.buyer_id then 'Pembeli' else 'Penjual' end;
  other := case when uid = c.buyer_id then c.seller_id else c.buyer_id end;
  if p_step = 'departed' then
    update market_chats set status = case when status = 'agreed' then 'on_the_way' else status end where id = p_chat;
    insert into messages (market_chat_id, sender_id, type, body, meta)
    values (p_chat, null, 'system', who || ' sedang berangkat.', jsonb_build_object('event','departed','by',uid));
  elsif p_step = 'arrived' then
    update market_chats set status = 'arrived' where id = p_chat;
    insert into messages (market_chat_id, sender_id, type, body, meta)
    values (p_chat, null, 'system', who || ' sudah sampai di titik temu.', jsonb_build_object('event','arrived','by',uid));
  else
    raise exception 'invalid_step';
  end if;
  perform public.notify(other, 'market_progress', jsonb_build_object('chat_id', p_chat, 'step', p_step));
end $$;

create or replace function public.mark_sold(p_product uuid, p_chat uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare p products%rowtype; c market_chats%rowtype; r market_chats%rowtype; uid uuid := auth.uid();
begin
  perform public.require_active_user();
  perform set_config('wts.internal', '1', true);
  select * into p from products where id = p_product for update;
  if not found or p.seller_id <> uid then raise exception 'forbidden' using errcode = '42501'; end if;
  if p.status not in ('available','booked') then raise exception 'invalid_state'; end if;
  if p_chat is not null then
    select * into c from market_chats where id = p_chat and product_id = p_product for update;
    if not found or c.status not in ('agreed','on_the_way','arrived') then raise exception 'invalid_chat'; end if;
    update market_chats set status = 'sold', sold_at = now(), delete_at = now() + interval '7 days' where id = p_chat;
    insert into messages (market_chat_id, sender_id, type, body, meta)
    values (p_chat, null, 'system', 'Barang terjual. Terima kasih! Chat ini akan dihapus otomatis 7 hari lagi.',
            '{"event":"sold"}');
    perform public.notify(c.buyer_id, 'market_sold', jsonb_build_object('chat_id', p_chat, 'product_id', p_product));
  end if;
  update products set status = 'sold', sold_at = now() where id = p_product;
  update profiles set sold_total = sold_total + 1 where id = uid;
  for r in select * from market_chats
            where product_id = p_product and id is distinct from p_chat
              and status in ('negotiating','agreed','on_the_way','arrived') loop
    update market_chats set status = 'closed', delete_at = now() + interval '3 days' where id = r.id;
    insert into messages (market_chat_id, sender_id, type, body, meta)
    values (r.id, null, 'system', 'Produk ini sudah terjual.', '{"event":"product_sold"}');
    perform public.notify(r.buyer_id, 'product_sold', jsonb_build_object('chat_id', r.id, 'product_id', p_product));
  end loop;
  update offers set status = 'expired' where status = 'pending'
     and market_chat_id in (select id from market_chats where product_id = p_product);
end $$;

create or replace function public.cancel_market_chat(p_chat uuid, p_reason text default null) returns void
language plpgsql security definer set search_path = public as $$
declare c market_chats%rowtype; uid uuid := auth.uid(); other uuid;
begin
  perform set_config('wts.internal', '1', true);
  select * into c from market_chats where id = p_chat for update;
  if not found or uid not in (c.buyer_id, c.seller_id) then raise exception 'forbidden' using errcode = '42501'; end if;
  if c.status in ('sold','closed','cancelled') then raise exception 'invalid_state'; end if;
  update market_chats set status = 'cancelled', cancelled_at = now(), delete_at = now() + interval '3 days'
   where id = p_chat;
  if c.status in ('agreed','on_the_way','arrived') then
    update products set status = 'available' where id = c.product_id and status = 'booked';
  end if;
  update offers set status = 'expired' where market_chat_id = p_chat and status = 'pending';
  insert into messages (market_chat_id, sender_id, type, body, meta)
  values (p_chat, null, 'system', 'Transaksi dibatalkan.', jsonb_build_object('event','cancelled','by',uid,'reason',p_reason));
  other := case when uid = c.buyer_id then c.seller_id else c.buyer_id end;
  perform public.notify(other, 'market_cancelled', jsonb_build_object('chat_id', p_chat));
end $$;

create or replace function public.rate_deal(p_chat uuid, p_stars smallint, p_comment text default null) returns void
language plpgsql security definer set search_path = public as $$
declare c market_chats%rowtype; uid uuid := auth.uid();
begin
  select * into c from market_chats where id = p_chat;
  if not found or uid not in (c.buyer_id, c.seller_id) or c.status <> 'sold' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  insert into ratings (market_chat_id, rater_id, ratee_id, stars, comment)
  values (p_chat, uid, case when uid = c.buyer_id then c.seller_id else c.buyer_id end, p_stars, p_comment);
end $$;

-- ----- Moderasi (staf) -----
create or replace function public.moderate_action(p_report uuid, p_action text, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare r reports%rowtype; v_email text; v_until timestamptz;
begin
  if not public.is_staff() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_action not in ('dismiss','hide','delete','warn','suspend_3','suspend_7','suspend_30','ban') then
    raise exception 'invalid_action';
  end if;
  if p_action in ('suspend_7','suspend_30','ban') and not public.is_admin() then
    raise exception 'admin_only' using errcode = '42501';
  end if;
  perform set_config('wts.internal', '1', true);
  select * into r from reports where id = p_report for update;
  if not found or r.status <> 'pending' then raise exception 'report_not_pending'; end if;

  if p_action = 'dismiss' then
    if r.target_type = 'post' then
      update posts set status = case when expires_at > now() then 'active' else 'expired' end
       where id = r.target_id and status = 'hidden';
    elsif r.target_type = 'comment' then
      update comments set status = 'active' where id = r.target_id and status = 'hidden';
    elsif r.target_type = 'product' then
      update products set status = case when expires_at > now() then 'available' else 'expired' end
       where id = r.target_id and status = 'hidden';
    end if;
  elsif p_action = 'delete' then
    if r.target_type = 'post' then delete from posts where id = r.target_id;
    elsif r.target_type = 'comment' then update comments set status = 'deleted', body = '[dihapus moderator]' where id = r.target_id;
    elsif r.target_type = 'product' then
      update products set status = 'deleted', hard_delete_at = now() + interval '3 days' where id = r.target_id;
    end if;
  else
    if r.target_type = 'post' then update posts set status = 'hidden' where id = r.target_id and status in ('active','closed','expired');
    elsif r.target_type = 'comment' then update comments set status = 'hidden' where id = r.target_id and status = 'active';
    elsif r.target_type = 'product' then update products set status = 'hidden' where id = r.target_id and status in ('available','booked','expired');
    end if;
  end if;

  if p_action in ('warn','suspend_3','suspend_7','suspend_30','ban') and r.target_user_id is not null then
    insert into user_strikes (user_id, report_id, action, note, created_by, expires_at)
    values (r.target_user_id, r.id, p_action, p_note, auth.uid(), now() + interval '180 days');
    update profiles set strike_count = strike_count + 1 where id = r.target_user_id;
    if p_action like 'suspend_%' then
      v_until := now() + make_interval(days => split_part(p_action, '_', 2)::int);
      update profiles set status = 'suspended', suspended_until = v_until where id = r.target_user_id;
    elsif p_action = 'ban' then
      update profiles set status = 'banned' where id = r.target_user_id;
      select email into v_email from auth.users where id = r.target_user_id;
      insert into banned_emails (email_hash, reason)
      values (encode(sha256(convert_to(lower(v_email), 'utf8')), 'hex'), p_note) on conflict do nothing;
      update posts set status = 'hidden' where author_id = r.target_user_id and status in ('active','closed');
      update products set status = 'hidden' where seller_id = r.target_user_id and status in ('available','booked');
    end if;
  end if;
  if p_action <> 'dismiss' and r.target_user_id is not null then
    perform public.notify(r.target_user_id, 'moderation',
      jsonb_build_object('action', p_action, 'reason', r.reason, 'report_id', r.id));
  end if;

  update reports set status = case when p_action = 'dismiss' then 'rejected' else 'resolved' end,
         action = p_action, handled_by = auth.uid(), handled_at = now() where id = p_report;
  insert into audit_logs (actor_id, action, target_type, target_id, detail)
  values (auth.uid(), 'moderate:' || p_action, r.target_type::text, r.target_id::text,
          jsonb_build_object('report_id', r.id, 'note', p_note));
end $$;

create or replace function public.admin_reveal_author(p_post uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid;
begin
  if not public.is_admin() then raise exception 'admin_only' using errcode = '42501'; end if;
  select author_id into v from posts where id = p_post;
  insert into audit_logs (actor_id, action, target_type, target_id)
  values (auth.uid(), 'reveal_anonymous_author', 'post', p_post::text);
  return v;
end $$;

-- =============================================================================
-- VIEW PUBLIK (berjalan sebagai owner -> menyembunyikan author_id anonim)
-- =============================================================================
create or replace view public.posts_public with (security_invoker = false) as
select p.id,
       case when p.is_anonymous then null else p.author_id end        as author_id,
       case when p.is_anonymous then null else pr.username end        as author_username,
       case when p.is_anonymous then null else pr.avatar_path end     as author_avatar,
       p.is_anonymous, p.is_official, p.caption, p.status, p.extra,
       p.upvotes, p.downvotes, p.score, p.hot_score, p.comment_count,
       p.expires_at, p.edited_at, p.created_at,
       (p.author_id = auth.uid())                                     as is_mine,
       (select v.value from post_votes v where v.post_id = p.id and v.user_id = auth.uid()) as my_vote,
       exists (select 1 from saved_posts s where s.post_id = p.id and s.user_id = auth.uid()) as is_saved,
       coalesce((select jsonb_agg(jsonb_build_object('id', t.id, 'name', t.name, 'slug', t.slug))
                   from post_tags pt join tags t on t.id = pt.tag_id where pt.post_id = p.id), '[]'::jsonb) as tags,
       coalesce((select jsonb_agg(jsonb_build_object('path', i.path, 'w', i.width, 'h', i.height) order by i.sort_order)
                   from post_images i where i.post_id = p.id), '[]'::jsonb) as images,
       p.search
  from posts p
  join profiles pr on pr.id = p.author_id
 where p.status in ('active','closed') and p.expires_at > now()
   and public.is_active_user()
   and not exists (select 1 from blocks b
                    where (b.blocker_id = auth.uid() and b.blocked_id = p.author_id)
                       or (b.blocker_id = p.author_id and b.blocked_id = auth.uid()));

create or replace view public.comments_public with (security_invoker = false) as
select c.id, c.post_id, c.parent_id, c.depth,
       case when po.is_anonymous and c.author_id = po.author_id then null else c.author_id end as author_id,
       case when po.is_anonymous and c.author_id = po.author_id then null else pr.username end as author_username,
       case when po.is_anonymous and c.author_id = po.author_id then null else pr.avatar_path end as author_avatar,
       (c.author_id = po.author_id)                                  as is_op,
       (po.is_anonymous and c.author_id = po.author_id)              as is_anonymous_op,
       case when c.status = 'deleted' then null else c.body end      as body,
       c.status, c.upvotes, c.downvotes, c.score, c.edited_at, c.created_at,
       (c.author_id = auth.uid())                                    as is_mine,
       (select v.value from comment_votes v where v.comment_id = c.id and v.user_id = auth.uid()) as my_vote
  from comments c
  join posts po on po.id = c.post_id
  join profiles pr on pr.id = c.author_id
 where c.status in ('active','deleted')
   and po.status in ('active','closed') and po.expires_at > now()
   and public.is_active_user()
   and not exists (select 1 from blocks b
                    where (b.blocker_id = auth.uid() and b.blocked_id = c.author_id)
                       or (b.blocker_id = c.author_id and b.blocked_id = auth.uid()));

create or replace view public.profiles_public with (security_invoker = false) as
select p.id, p.username, p.avatar_path, p.prodi_id, pd.name as prodi_name, p.bio, p.created_at, p.sold_total,
       (select round(avg(stars)::numeric, 1) from ratings where ratee_id = p.id) as rating_avg,
       (select count(*) from ratings where ratee_id = p.id)                      as rating_count
  from profiles p
  left join prodi pd on pd.id = p.prodi_id
 where p.status <> 'banned' and public.is_active_user();
