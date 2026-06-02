-- >>> 20260603000001_six_tables_schema.sql
-- 六表结构：User / Live / Post / PostChat / LiveChat / Message（与 Dashboard 一致）

create extension if not exists "pgcrypto";

-- 清空 public
do $$
declare
  r record;
begin
  for r in
    select viewname as name
    from pg_views
    where schemaname = 'public'
  loop
    execute format('drop view if exists public.%I cascade', r.name);
  end loop;

  for r in
    select c.relname as name
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r', 'm')
  loop
    execute format('drop table if exists public.%I cascade', r.name);
  end loop;

  for r in
    select p.proname as name, oidvectortypes(p.proargtypes) as args
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
  loop
    execute format('drop function if exists public.%I(%s) cascade', r.name, r.args);
  end loop;

  for r in
    select t.typname as name
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typtype = 'e'
  loop
    execute format('drop type if exists public.%I cascade', r.name);
  end loop;
end $$;

create type public.gender_type as enum ('male', 'female', 'other');

-- ---------------------------------------------------------------------------
-- User（用户/主播资料）
-- ---------------------------------------------------------------------------
create table public."User" (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users (id) on delete set null,
  display_name text not null,
  gender public.gender_type,
  bio text,
  avatar_path text,
  email text,
  apple_user_id text unique,
  coins integer not null default 0 check (coins >= 0),
  avatar_frame_index integer not null default 0,
  is_popular_star boolean not null default false,
  popular_star_sort integer,
  following_ids uuid[] not null default '{}'::uuid[],
  follower_ids uuid[] not null default '{}'::uuid[],
  blocked_ids uuid[] not null default '{}'::uuid[],
  liked_post_ids uuid[] not null default '{}'::uuid[],
  iap_processed_tx_ids text[] not null default '{}'::text[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index user_auth_user_id_idx on public."User" (auth_user_id);
create index user_popular_star_idx on public."User" (is_popular_star, popular_star_sort)
  where is_popular_star = true;
create index user_following_ids_gin on public."User" using gin (following_ids);
create index user_follower_ids_gin on public."User" using gin (follower_ids);

-- ---------------------------------------------------------------------------
-- Live
-- ---------------------------------------------------------------------------
create table public."Live" (
  id uuid primary key default gen_random_uuid(),
  category_slug text not null,
  category_name text not null,
  category_sort_order integer not null default 0,
  show_on_home boolean not null default false,
  streamer_id uuid not null references public."User" (id) on delete cascade,
  room_index integer not null,
  description text not null,
  tags text[] not null default '{}',
  cover_path text,
  video_path text,
  viewer_count integer not null default 0 check (viewer_count >= 0),
  is_live boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (category_slug, room_index)
);

create index live_category_home_idx on public."Live" (show_on_home, category_sort_order);
create index live_streamer_idx on public."Live" (streamer_id);

-- ---------------------------------------------------------------------------
-- Post
-- ---------------------------------------------------------------------------
create table public."Post" (
  id uuid primary key default gen_random_uuid(),
  post_index integer not null unique,
  author_id uuid not null references public."User" (id) on delete cascade,
  content text not null,
  like_count integer not null default 0 check (like_count >= 0),
  comment_count integer not null default 0 check (comment_count >= 0),
  media jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index post_author_idx on public."Post" (author_id);
create index post_created_idx on public."Post" (created_at desc);

-- ---------------------------------------------------------------------------
-- PostChat
-- ---------------------------------------------------------------------------
create table public."PostChat" (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public."Post" (id) on delete cascade,
  author_id uuid not null references public."User" (id) on delete cascade,
  content text not null check (char_length(trim(content)) > 0),
  created_at timestamptz not null default now()
);

create index post_chat_post_idx on public."PostChat" (post_id, created_at);

-- ---------------------------------------------------------------------------
-- LiveChat
-- ---------------------------------------------------------------------------
create table public."LiveChat" (
  id uuid primary key default gen_random_uuid(),
  live_id uuid not null references public."Live" (id) on delete cascade,
  sender_id uuid references public."User" (id) on delete set null,
  content text not null check (char_length(trim(content)) > 0),
  created_at timestamptz not null default now()
);

create index live_chat_live_idx on public."LiveChat" (live_id, created_at);

-- ---------------------------------------------------------------------------
-- Message（私信：header + chat）
-- ---------------------------------------------------------------------------
create table public."Message" (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null,
  message_kind text not null check (message_kind in ('header', 'chat')),
  user_low_id uuid not null references public."User" (id) on delete cascade,
  user_high_id uuid not null references public."User" (id) on delete cascade,
  sender_id uuid references public."User" (id) on delete set null,
  body text,
  last_message_at timestamptz,
  last_message_preview text,
  last_sender_id uuid references public."User" (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint message_users_ordered check (user_low_id < user_high_id),
  constraint message_header_shape check (
    message_kind <> 'header' or (body is null and sender_id is null)
  ),
  constraint message_chat_shape check (
    message_kind <> 'chat'
    or (
      body is not null
      and char_length(trim(body)) > 0
      and sender_id is not null
    )
  )
);

create unique index message_conversation_header_uidx
  on public."Message" (conversation_id)
  where message_kind = 'header';

create index message_conversation_created_idx
  on public."Message" (conversation_id, created_at);

-- ---------------------------------------------------------------------------
-- 触发器
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger user_updated_at
  before update on public."User"
  for each row execute function public.set_updated_at();

create trigger live_updated_at
  before update on public."Live"
  for each row execute function public.set_updated_at();

create trigger post_updated_at
  before update on public."Post"
  for each row execute function public.set_updated_at();

create or replace function public.increment_post_comment_count()
returns trigger language plpgsql as $$
begin
  update public."Post" set comment_count = comment_count + 1 where id = new.post_id;
  return new;
end;
$$;

create trigger post_chat_count
  after insert on public."PostChat"
  for each row execute function public.increment_post_comment_count();

create or replace function public.sync_message_header_on_chat()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public."Message" (
    conversation_id, message_kind, user_low_id, user_high_id,
    last_message_at, last_message_preview, last_sender_id
  )
  values (
    new.conversation_id, 'header', new.user_low_id, new.user_high_id,
    new.created_at, left(trim(new.body), 200), new.sender_id
  )
  on conflict (conversation_id) where (message_kind = 'header')
  do update set
    last_message_at = excluded.last_message_at,
    last_message_preview = excluded.last_message_preview,
    last_sender_id = excluded.last_sender_id;
  return new;
end;
$$;

create trigger message_chat_header
  after insert on public."Message"
  for each row when (new.message_kind = 'chat')
  execute function public.sync_message_header_on_chat();

-- ---------------------------------------------------------------------------
-- RLS（User 表保持 UNRESTRICTED：不启用 RLS；其余表公开读）
-- ---------------------------------------------------------------------------
alter table public."User" disable row level security;

alter table public."Live" enable row level security;
alter table public."Post" enable row level security;
alter table public."PostChat" enable row level security;
alter table public."LiveChat" enable row level security;
alter table public."Message" enable row level security;

create policy "live_select" on public."Live" for select using (true);
create policy "post_select" on public."Post" for select using (true);
create policy "post_chat_select" on public."PostChat" for select using (true);
create policy "live_chat_select" on public."LiveChat" for select using (true);
create policy "message_select" on public."Message" for select using (true);

create policy "post_insert" on public."Post" for insert to authenticated with check (true);
create policy "post_update" on public."Post" for update to authenticated using (true);
create policy "post_delete" on public."Post" for delete to authenticated using (true);
create policy "post_chat_insert" on public."PostChat" for insert to authenticated with check (true);
create policy "live_chat_insert" on public."LiveChat" for insert to authenticated with check (true);
create policy "message_insert" on public."Message" for insert to authenticated with check (true);
-- 发送 chat 后触发器会 upsert header，需要 update 策略
create policy "message_update" on public."Message" for update to authenticated using (true) with check (true);

alter publication supabase_realtime add table public."LiveChat";

-- ---------------------------------------------------------------------------
-- RPC：关注 / 点赞（数据存在 User、Post 字段，不新增表）
-- ---------------------------------------------------------------------------
create or replace function public.toggle_follow(p_target_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid;
  v_following uuid[];
  v_blocked uuid[];
  v_now boolean;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select id, following_ids, blocked_ids
  into v_me, v_following, v_blocked
  from public."User"
  where auth_user_id = auth.uid();

  if v_me is null then
    raise exception 'profile not found' using errcode = '28000';
  end if;
  if p_target_id is null or p_target_id = v_me then
    return jsonb_build_object('following', false, 'following_ids', to_jsonb(v_following));
  end if;
  if p_target_id = any (v_blocked) then
    raise exception 'user is blocked' using errcode = '22023';
  end if;

  if p_target_id = any (v_following) then
    v_following := array_remove(v_following, p_target_id);
    v_now := false;
    update public."User"
    set
      follower_ids = array_remove(follower_ids, v_me),
      updated_at = now()
    where id = p_target_id;
  else
    v_following := v_following || p_target_id;
    v_now := true;
    update public."User"
    set
      follower_ids = case
        when v_me = any (follower_ids) then follower_ids
        else follower_ids || v_me
      end,
      updated_at = now()
    where id = p_target_id;
  end if;

  update public."User"
  set following_ids = v_following, updated_at = now()
  where id = v_me;

  return jsonb_build_object('following', v_now, 'following_ids', to_jsonb(v_following));
end;
$$;

create or replace function public.toggle_block(p_target_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid;
  v_blocked uuid[];
  v_following uuid[];
  v_followers uuid[];
  v_now boolean;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select id, blocked_ids, following_ids, follower_ids
  into v_me, v_blocked, v_following, v_followers
  from public."User"
  where auth_user_id = auth.uid();

  if v_me is null then
    raise exception 'profile not found' using errcode = '28000';
  end if;
  if p_target_id is null or p_target_id = v_me then
    return jsonb_build_object('blocked', false, 'blocked_ids', to_jsonb(v_blocked));
  end if;

  if p_target_id = any (v_blocked) then
    v_blocked := array_remove(v_blocked, p_target_id);
    v_now := false;
  else
    v_blocked := v_blocked || p_target_id;
    v_now := true;

    if p_target_id = any (v_following) then
      v_following := array_remove(v_following, p_target_id);
      update public."User"
      set
        follower_ids = array_remove(follower_ids, v_me),
        updated_at = now()
      where id = p_target_id;
    end if;

    if p_target_id = any (v_followers) then
      v_followers := array_remove(v_followers, p_target_id);
      update public."User"
      set
        following_ids = array_remove(following_ids, v_me),
        updated_at = now()
      where id = p_target_id;
    end if;
  end if;

  update public."User"
  set
    blocked_ids = v_blocked,
    following_ids = v_following,
    follower_ids = v_followers,
    updated_at = now()
  where id = v_me;

  return jsonb_build_object('blocked', v_now, 'blocked_ids', to_jsonb(v_blocked));
end;
$$;

create or replace function public.toggle_post_like(p_post_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid;
  v_liked_ids uuid[];
  v_now boolean;
  v_count integer;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select id, liked_post_ids
  into v_me, v_liked_ids
  from public."User"
  where auth_user_id = auth.uid();

  if v_me is null then
    raise exception 'profile not found' using errcode = '28000';
  end if;
  if p_post_id is null then
    raise exception 'invalid post' using errcode = '22023';
  end if;

  if p_post_id = any (v_liked_ids) then
    v_liked_ids := array_remove(v_liked_ids, p_post_id);
    v_now := false;
    update public."Post"
    set like_count = greatest(like_count - 1, 0), updated_at = now()
    where id = p_post_id;
  else
    v_liked_ids := array_prepend(p_post_id, v_liked_ids);
    v_now := true;
    update public."Post"
    set like_count = like_count + 1, updated_at = now()
    where id = p_post_id;
  end if;

  update public."User"
  set liked_post_ids = v_liked_ids, updated_at = now()
  where id = v_me;

  select like_count into v_count from public."Post" where id = p_post_id;

  return jsonb_build_object(
    'liked', v_now,
    'like_count', coalesce(v_count, 0),
    'liked_post_ids', to_jsonb(v_liked_ids)
  );
end;
$$;

grant execute on function public.toggle_follow(uuid) to authenticated;
grant execute on function public.toggle_block(uuid) to authenticated;
grant execute on function public.toggle_post_like(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- RPC：内购充值（校验商品 + 交易号幂等；扣币由客户端直接更新 User.coins）
-- ---------------------------------------------------------------------------
create or replace function public.iap_coins_for_product(p_product_id text)
returns integer
language sql
immutable
set search_path = public
as $$
  select case trim(p_product_id)
    when 'mgwtghzkyzayvhbw' then 400
    when 'ijwhpdnfcbtmhcsm' then 800
    when 'rsdzurddehlcrqzu' then 2450
    when 'unyqcpbgddjxgwwu' then 5150
    when 'sikxnzlzflsjwubp' then 10800
    when 'dncewabylvgxxify' then 29400
    when 'szhwifwbucazxgkf' then 63700
    else null
  end::integer;
$$;

create or replace function public.grant_coins_from_purchase(
  p_product_id text,
  p_transaction_id text
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_coins integer;
  v_grant integer;
  v_tx text;
  v_processed text[];
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  v_tx := trim(p_transaction_id);
  if v_tx = '' then
    raise exception 'invalid transaction' using errcode = '22023';
  end if;

  v_grant := public.iap_coins_for_product(p_product_id);
  if v_grant is null or v_grant <= 0 then
    raise exception 'unknown product' using errcode = '22023';
  end if;

  select id, coins, iap_processed_tx_ids
  into v_user_id, v_coins, v_processed
  from public."User"
  where auth_user_id = auth.uid();

  if v_user_id is null then
    raise exception 'profile not found' using errcode = '28000';
  end if;

  if v_tx = any (v_processed) then
    return v_coins;
  end if;

  update public."User"
  set
    coins = coins + v_grant,
    iap_processed_tx_ids = v_processed || v_tx,
    updated_at = now()
  where id = v_user_id
  returning coins into v_coins;

  return v_coins;
end;
$$;

grant execute on function public.grant_coins_from_purchase(text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- RPC：直播间人数
-- ---------------------------------------------------------------------------
create or replace function public.join_live_stream(p_stream_id uuid)
returns integer language plpgsql security definer set search_path = public as $$
declare c integer;
begin
  update public."Live" set viewer_count = viewer_count + 1 where id = p_stream_id returning viewer_count into c;
  return coalesce(c, 0);
end;
$$;

create or replace function public.leave_live_stream(p_stream_id uuid)
returns integer language plpgsql security definer set search_path = public as $$
declare c integer;
begin
  update public."Live" set viewer_count = greatest(viewer_count - 1, 0) where id = p_stream_id returning viewer_count into c;
  return coalesce(c, 0);
end;
$$;

grant execute on function public.join_live_stream(uuid) to anon, authenticated;
grant execute on function public.leave_live_stream(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Storage：私有 media
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit)
values ('media', 'media', false, 52428800)
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit;

drop policy if exists "media_anon_select" on storage.objects;
create policy "media_anon_select" on storage.objects for select to anon using (bucket_id = 'media');
drop policy if exists "media_authenticated_select" on storage.objects;
create policy "media_authenticated_select" on storage.objects for select to authenticated using (bucket_id = 'media');
drop policy if exists "media_authenticated_insert" on storage.objects;
create policy "media_authenticated_insert" on storage.objects for insert to authenticated with check (bucket_id = 'media');
drop policy if exists "media_authenticated_update" on storage.objects;
create policy "media_authenticated_update" on storage.objects for update to authenticated using (bucket_id = 'media');
drop policy if exists "media_authenticated_delete" on storage.objects;
create policy "media_authenticated_delete" on storage.objects for delete to authenticated using (bucket_id = 'media');

-- >>> 20260626110000_user_table_public_read.sql
-- User 表需对客户端公开读（朋友圈/直播作者头像昵称、Popular Star 等）
-- 远程曾启用 RLS 且无 policy，导致 PostgREST 关联 User 恒为 null。

alter table public."User" disable row level security;

-- >>> 20260626120000_auth_user_profile_trigger.sql
-- 新用户注册时自动写入 public."User"（避免仅创建 auth.users 而无业务资料行）

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
  v_name text;
  v_bio text;
begin
  v_email := lower(trim(coalesce(new.email, '')));
  v_name := trim(coalesce(new.raw_user_meta_data ->> 'display_name', ''));
  v_bio := trim(coalesce(new.raw_user_meta_data ->> 'bio', ''));
  if v_name = '' and v_email <> '' then
    v_name := split_part(v_email, '@', 1);
  end if;
  if v_name = '' then
    v_name := 'Player';
  end if;

  insert into public."User" (auth_user_id, email, display_name, bio)
  values (
    new.id,
    nullif(v_email, ''),
    v_name,
    nullif(v_bio, '')
  )
  on conflict (auth_user_id) do update
    set email = coalesce(nullif(excluded.email, ''), public."User".email),
        display_name = case
          when public."User".display_name is null
            or public."User".display_name = ''
            or public."User".display_name = 'Player'
          then excluded.display_name
          else public."User".display_name
        end,
        bio = coalesce(nullif(excluded.bio, ''), public."User".bio);

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_auth_user();

-- 保持 User 表对客户端可读（见 20260626110000_user_table_public_read.sql）
alter table public."User" disable row level security;
