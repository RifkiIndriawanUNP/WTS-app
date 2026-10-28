-- =============================================================================
-- WTS | 0001_schema.sql : tipe enum, tabel, indeks
-- Postgres (Supabase). Semua waktu = timestamptz. PK = uuid.
-- =============================================================================
create extension if not exists pg_trgm with schema extensions;

-- ---------- ENUM ----------
create type user_role          as enum ('user','moderator','admin');
create type account_status     as enum ('active','suspended','banned');
create type post_status        as enum ('active','closed','expired','hidden');
create type comment_status     as enum ('active','hidden','deleted');
create type product_status     as enum ('available','booked','sold','expired','hidden','deleted');
create type listing_type       as enum ('sell','rent');
create type rent_unit          as enum ('day','week','month','semester');
create type item_condition     as enum ('new','used');
create type tag_scope          as enum ('timeline','product');
create type dm_status          as enum ('request','accepted');
create type market_chat_status as enum ('negotiating','agreed','on_the_way','arrived','sold','cancelled','closed');
create type message_type       as enum ('text','image','location','contact','link','offer','system');
create type offer_status       as enum ('pending','accepted','rejected','countered','expired');
create type report_target      as enum ('post','comment','product','user','message');
create type report_reason      as enum ('spam','hate','harassment','adult','scam','prohibited_item','misinformation','privacy','other');
create type report_status      as enum ('pending','resolved','rejected');

-- ---------- REFERENSI ----------
create table public.prodi (
  id      smallint generated always as identity primary key,
  name    text not null unique,
  faculty text
);

create table public.tags (
  id         smallint generated always as identity primary key,
  scope      tag_scope not null,
  name       text not null,
  slug       text not null,
  sort_order smallint not null default 0,
  is_active  boolean not null default true,
  unique (scope, slug)
);

create table public.meeting_points (
  id          smallint generated always as identity primary key,
  name        text not null,
  description text,
  is_active   boolean not null default true
);

create table public.app_config (
  key   text primary key,
  value jsonb not null
);

-- ---------- PROFIL ----------
-- id = auth.users.id. Email TIDAK disimpan di sini (ada di auth.users).
create table public.profiles (
  id                 uuid primary key references auth.users(id) on delete cascade,
  username           text not null unique check (username ~ '^[a-z0-9_]{3,20}$'),
  prodi_id           smallint references public.prodi(id) on delete set null,
  bio                text check (char_length(bio) <= 160),
  avatar_path        text,
  role               user_role not null default 'user',
  status             account_status not null default 'active',
  suspended_until    timestamptz,
  strike_count       smallint not null default 0,
  dm_privacy         text not null default 'all' check (dm_privacy in ('all','none')),
  notif_prefs        jsonb not null default '{}'::jsonb,
  sold_total         int not null default 0,
  last_login_at      timestamptz not null default now(),
  username_changed_at timestamptz,
  inactive_warned_at timestamptz,
  created_at         timestamptz not null default now()
);
create index profiles_last_login_idx on public.profiles (last_login_at);

-- ---------- LINIMASA ----------
create table public.posts (
  id             uuid primary key default gen_random_uuid(),
  author_id      uuid not null references public.profiles(id) on delete cascade,
  is_anonymous   boolean not null default false,
  is_official    boolean not null default false,
  caption        text not null check (char_length(caption) between 1 and 2000),
  status         post_status not null default 'active',
  extra          jsonb not null default '{}'::jsonb,   -- {link, deadline, duration_min} untuk kuesioner
  upvotes        int not null default 0,
  downvotes      int not null default 0,
  score          int generated always as (upvotes - downvotes) stored,
  hot_score      double precision not null default 0,
  comment_count  int not null default 0,
  edited_at      timestamptz,
  expires_at     timestamptz not null default (now() + interval '30 days'),
  hard_delete_at timestamptz not null default (now() + interval '45 days'),
  reminded_at    timestamptz,
  created_at     timestamptz not null default now(),
  search         tsvector generated always as (to_tsvector('simple', caption)) stored
);
create index posts_feed_idx    on public.posts (status, created_at desc);
create index posts_hot_idx     on public.posts (status, hot_score desc);
create index posts_author_idx  on public.posts (author_id, created_at desc);
create index posts_expires_idx on public.posts (expires_at) where status in ('active','closed');
create index posts_hard_idx    on public.posts (hard_delete_at);
create index posts_search_idx  on public.posts using gin (search);
create index posts_trgm_idx    on public.posts using gin (caption extensions.gin_trgm_ops);

create table public.post_tags (
  post_id uuid not null references public.posts(id) on delete cascade,
  tag_id  smallint not null references public.tags(id),
  primary key (post_id, tag_id)
);
create index post_tags_tag_idx on public.post_tags (tag_id);

create table public.post_images (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.posts(id) on delete cascade,
  path       text not null,         -- nama file acak, TANPA user id (anti-deanonimisasi)
  width      int,
  height     int,
  sort_order smallint not null default 0
);
create index post_images_post_idx on public.post_images (post_id, sort_order);

create table public.comments (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.posts(id) on delete cascade,
  author_id  uuid not null references public.profiles(id) on delete cascade,
  parent_id  uuid references public.comments(id) on delete cascade,
  depth      smallint not null default 0 check (depth between 0 and 2),
  body       text not null check (char_length(body) between 1 and 1000),
  status     comment_status not null default 'active',
  upvotes    int not null default 0,
  downvotes  int not null default 0,
  score      int generated always as (upvotes - downvotes) stored,
  edited_at  timestamptz,
  created_at timestamptz not null default now()
);
create index comments_post_idx   on public.comments (post_id, created_at);
create index comments_parent_idx on public.comments (parent_id);
create index comments_author_idx on public.comments (author_id);

create table public.post_votes (
  post_id    uuid not null references public.posts(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  value      smallint not null check (value in (1,-1)),
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index post_votes_user_idx on public.post_votes (user_id);

create table public.comment_votes (
  comment_id uuid not null references public.comments(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  value      smallint not null check (value in (1,-1)),
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);
create index comment_votes_user_idx on public.comment_votes (user_id);

-- ---------- MARKETPLACE ----------
create table public.products (
  id               uuid primary key default gen_random_uuid(),
  seller_id        uuid not null references public.profiles(id) on delete cascade,
  title            text not null check (char_length(title) between 3 and 100),
  description      text not null check (char_length(description) between 1 and 2000),
  listing_type     listing_type not null,
  price            bigint not null check (price > 0 and price <= 100000000),
  rent_unit        rent_unit,
  deposit          bigint check (deposit is null or (deposit >= 0 and deposit <= 100000000)),
  condition        item_condition not null,
  defect_note      text check (char_length(defect_note) <= 1000),
  negotiable       boolean not null default true,
  meeting_point_id smallint references public.meeting_points(id) on delete set null,
  prodi_id         smallint references public.prodi(id) on delete set null,
  status           product_status not null default 'available',
  sold_at          timestamptz,
  expires_at       timestamptz not null default (now() + interval '30 days'),
  hard_delete_at   timestamptz not null default (now() + interval '45 days'),
  extension_count  smallint not null default 0 check (extension_count between 0 and 3),
  view_count       int not null default 0,
  save_count       int not null default 0,
  reminded_at      timestamptz,
  created_at       timestamptz not null default now(),
  search           tsvector generated always as (to_tsvector('simple', title || ' ' || description)) stored,
  constraint rent_unit_chk  check ((listing_type = 'rent') = (rent_unit is not null)),
  constraint defect_chk     check (condition = 'new' or char_length(coalesce(defect_note,'')) >= 3)
);
create index products_feed_idx   on public.products (status, created_at desc);
create index products_price_idx  on public.products (status, price);
create index products_seller_idx on public.products (seller_id, status);
create index products_hard_idx   on public.products (hard_delete_at);
create index products_search_idx on public.products using gin (search);

create table public.product_tags (
  product_id uuid not null references public.products(id) on delete cascade,
  tag_id     smallint not null references public.tags(id),
  primary key (product_id, tag_id)
);

create table public.product_images (
  id         uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  path       text not null,
  width      int,
  height     int,
  sort_order smallint not null default 0
);
create index product_images_idx on public.product_images (product_id, sort_order);

create table public.saved_posts (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  post_id    uuid not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);
create table public.saved_products (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);

-- ---------- CHAT ----------
-- DM: pasangan user unik, user_a < user_b
create table public.conversations (
  id              uuid primary key default gen_random_uuid(),
  user_a          uuid not null references public.profiles(id) on delete cascade,
  user_b          uuid not null references public.profiles(id) on delete cascade,
  requester_id    uuid not null references public.profiles(id) on delete cascade,
  status          dm_status not null default 'request',
  last_message_at timestamptz not null default now(),
  created_at      timestamptz not null default now(),
  check (user_a < user_b),
  unique (user_a, user_b)
);
create index conversations_b_idx on public.conversations (user_b);

-- Chat market: terikat 1 produk + 1 pembeli
create table public.market_chats (
  id               uuid primary key default gen_random_uuid(),
  product_id       uuid not null references public.products(id) on delete cascade,
  buyer_id         uuid not null references public.profiles(id) on delete cascade,
  seller_id        uuid not null references public.profiles(id) on delete cascade,
  status           market_chat_status not null default 'negotiating',
  agreed_price     bigint,
  sold_at          timestamptz,
  cancelled_at     timestamptz,
  last_activity_at timestamptz not null default now(),
  delete_at        timestamptz default (now() + interval '3 days'),
  created_at       timestamptz not null default now(),
  check (buyer_id <> seller_id),
  unique (product_id, buyer_id)
);
-- Maksimal SATU kesepakatan aktif per produk (cegah dua pembeli sepakat bersamaan)
create unique index market_chats_one_deal on public.market_chats (product_id)
  where status in ('agreed','on_the_way','arrived');
create index market_chats_buyer_idx  on public.market_chats (buyer_id);
create index market_chats_seller_idx on public.market_chats (seller_id);
create index market_chats_delete_idx on public.market_chats (delete_at) where delete_at is not null;

create table public.messages (
  id                 uuid primary key default gen_random_uuid(),
  dm_conversation_id uuid references public.conversations(id) on delete cascade,
  market_chat_id     uuid references public.market_chats(id) on delete cascade,
  sender_id          uuid references public.profiles(id) on delete set null,  -- null = pesan sistem
  type               message_type not null default 'text',
  body               text check (char_length(body) <= 2000),
  meta               jsonb not null default '{}'::jsonb,
  reply_to           uuid references public.messages(id) on delete set null,
  read_at            timestamptz,
  delete_at          timestamptz,
  created_at         timestamptz not null default now(),
  check ((dm_conversation_id is not null)::int + (market_chat_id is not null)::int = 1)
);
create index messages_dm_idx     on public.messages (dm_conversation_id, created_at);
create index messages_market_idx on public.messages (market_chat_id, created_at);
create index messages_delete_idx on public.messages (delete_at) where delete_at is not null;

create table public.offers (
  id             uuid primary key default gen_random_uuid(),
  market_chat_id uuid not null references public.market_chats(id) on delete cascade,
  from_user      uuid not null references public.profiles(id) on delete cascade,
  price          bigint not null check (price > 0 and price <= 100000000),
  status         offer_status not null default 'pending',
  expires_at     timestamptz not null default (now() + interval '24 hours'),
  created_at     timestamptz not null default now(),
  responded_at   timestamptz
);
create index offers_chat_idx on public.offers (market_chat_id, created_at);
create unique index offers_one_pending on public.offers (market_chat_id) where status = 'pending';

create table public.ratings (
  id             uuid primary key default gen_random_uuid(),
  market_chat_id uuid references public.market_chats(id) on delete set null,
  rater_id       uuid not null references public.profiles(id) on delete cascade,
  ratee_id       uuid not null references public.profiles(id) on delete cascade,
  stars          smallint not null check (stars between 1 and 5),
  comment        text check (char_length(comment) <= 300),
  created_at     timestamptz not null default now(),
  check (rater_id <> ratee_id)
);
create unique index ratings_once on public.ratings (market_chat_id, rater_id) where market_chat_id is not null;
create index ratings_ratee_idx on public.ratings (ratee_id);

-- ---------- SOSIAL & MODERASI ----------
create table public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index blocks_blocked_idx on public.blocks (blocked_id);

create table public.reports (
  id             uuid primary key default gen_random_uuid(),
  reporter_id    uuid references public.profiles(id) on delete set null,
  target_type    report_target not null,
  target_id      uuid not null,
  target_user_id uuid references public.profiles(id) on delete set null,
  reason         report_reason not null,
  note           text check (char_length(note) <= 500),
  snapshot       jsonb,
  status         report_status not null default 'pending',
  action         text,
  handled_by     uuid references public.profiles(id) on delete set null,
  handled_at     timestamptz,
  created_at     timestamptz not null default now(),
  unique (reporter_id, target_type, target_id)
);
create index reports_queue_idx  on public.reports (status, created_at);
create index reports_target_idx on public.reports (target_type, target_id);

create table public.user_strikes (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  report_id  uuid references public.reports(id) on delete set null,
  action     text not null,
  note       text,
  created_by uuid references public.profiles(id) on delete set null,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);
create index user_strikes_user_idx on public.user_strikes (user_id);

create table public.appeals (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  report_id  uuid references public.reports(id) on delete set null,
  message    text not null check (char_length(message) between 5 and 1000),
  status     text not null default 'pending' check (status in ('pending','accepted','rejected')),
  handled_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (user_id, report_id)
);

-- ---------- NOTIFIKASI & INFRASTRUKTUR ----------
create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  type       text not null,
  payload    jsonb not null default '{}'::jsonb,
  is_read    boolean not null default false,
  pushed_at  timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_user_idx on public.notifications (user_id, is_read, created_at desc);

create table public.device_tokens (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  fcm_token  text not null unique,
  platform   text not null default 'android',
  updated_at timestamptz not null default now()
);
create index device_tokens_user_idx on public.device_tokens (user_id);

create table public.banned_emails (
  email_hash text primary key,        -- sha256(lower(email)), bukan email asli
  reason     text,
  created_at timestamptz not null default now()
);

create table public.file_delete_queue (
  id         bigint generated always as identity primary key,
  bucket     text not null,
  path       text not null,
  attempts   smallint not null default 0,
  created_at timestamptz not null default now()
);

create table public.audit_logs (
  id          bigint generated always as identity primary key,
  actor_id    uuid,
  action      text not null,
  target_type text,
  target_id   text,
  detail      jsonb,
  created_at  timestamptz not null default now()
);
create index audit_logs_created_idx on public.audit_logs (created_at desc);

create table public.rate_limits (
  user_id uuid not null,
  action  text not null,
  bucket  timestamptz not null,
  hits    int not null default 0,
  primary key (user_id, action, bucket)
);
