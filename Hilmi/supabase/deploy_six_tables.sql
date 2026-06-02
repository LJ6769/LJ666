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

-- >>> 20260603000002_six_tables_seed.sql
-- 由 generate_six_tables_seed.py 生成
-- 素材: /Users/mac/Downloads/Hilmi切图/Hilmi素材

truncate table public."Message" cascade;
truncate table public."LiveChat" cascade;
truncate table public."PostChat" cascade;
truncate table public."Post" cascade;
truncate table public."Live" cascade;
truncate table public."User" cascade;

-- User
insert into public."User" (display_name, gender, bio, avatar_path, is_popular_star, popular_star_sort, coins) values
  ('Caspian', 'male'::public.gender_type, $txt1$A whiskey beginner; enjoys sipping slowly and chatting.$txt1$, 'users/male/07f60db48311389623c311d669e0d216.jpg', false, null, 0),
  ('Orion', 'male'::public.gender_type, $txt2$Loves watching flair bartending; occasionally shakes up a few simple drinks himself.$txt2$, 'users/male/124f3dabc51b00b83fb23397614b5bc7_副本.jpg', false, null, 0),
  ('Soren', 'male'::public.gender_type, $txt3$Prefers hard spirits and classic cocktails; not a fan of anything too flashy or gimmicky.$txt3$, 'users/male/2fa39d58e44804f66932129b5eb3fb72.jpg', false, null, 0),
  ('Atticus', 'male'::public.gender_type, $txt4$Loves learning the stories behind the spirits—savoring the drink rather than downing it fast.$txt4$, 'users/male/5ea033948e9cbafbcb4ea221efd6b121.jpg', false, null, 0),
  ('Kael', 'male'::public.gender_type, $txt5$An at-home cocktail enthusiast; doesn't have many tools, but has enough to get the job done.$txt5$, 'users/male/66b7ef7a002cbf00727f86d3b49e7e02.jpg', false, null, 0),
  ('Thorne', 'male'::public.gender_type, $txt6$A craft beer aficionado; loves exploring a wide variety of flavors.$txt6$, 'users/male/6b475a7771285bad4fc004d7b322c741.jpg', false, null, 0),
  ('Evander', 'male'::public.gender_type, $txt7$Occasionally meets up with friends for a casual drink—relaxing conversation, strictly no work talk.$txt7$, 'users/male/6f6fa79bea0e6ac662a5a5ce9efdae1d.jpg', false, null, 0),
  ('Jasper', 'male'::public.gender_type, $txt8$Enjoys making simple cocktails at home using fresh fruit.$txt8$, 'users/male/8a0d4b91252652b65af9deb24ba37aeb.jpg', false, null, 0),
  ('Marlow', 'male'::public.gender_type, $txt9$A regular in late-night voice chat rooms—sipping a drink while chatting about daily life.$txt9$, 'users/male/96c90bfae9c8fbdf230fee6fafea2319.jpg', false, null, 0),
  ('Rohan', 'male'::public.gender_type, $txt10$Loves Asian-inspired cocktails; finds the aromatic spices truly captivating.$txt10$, 'users/male/a07b840e2e32c924b3169ec4571c0e16.jpg', false, null, 0),
  ('Silas', 'male'::public.gender_type, $txt11$Collects various types of small drinking glasses—believes that drinking should always be a ritual.$txt11$, 'users/male/a0aeb81442942abbb9a588d2eb65d880.jpg', false, null, 0),
  ('Torin', 'male'::public.gender_type, $txt12$Drinks responsibly—enjoys the pleasant buzz of being tipsy without aiming to get drunk.$txt12$, 'users/male/c6140e4b00f258dafac4b846a4342c43.jpg', false, null, 0),
  ('Uriah', 'male'::public.gender_type, $txt13$I also love non-alcoholic mocktails—delicious and guilt-free.$txt13$, 'users/male/ec66007c6f056c6ae339e3e60186e63c_副本.jpg', false, null, 0),
  ('Viggo', 'male'::public.gender_type, $txt14$My style is minimalist mixology; clean and refreshing is what matters most.$txt14$, 'users/male/eda68f142bd9cf77aab21cb892736c28.jpg', false, null, 0),
  ('Zane', 'male'::public.gender_type, $txt15$I learn mixology by following live streams—it’s a fun way to entertain myself at home every day.$txt15$, 'users/male/efdf90cde9925c0fe24a0bad17e66ac9.jpg', false, null, 0),
  ('Elowen', 'female'::public.gender_type, $txt16$Enjoys a light drink; occasionally mixes simple cocktails at home.$txt16$, 'users/female/592852497ab6e4fb1b80fbf427b30d18.jpg', true, 1, 0),
  ('Liora', 'female'::public.gender_type, $txt17$A connoisseur of the "tipsy glow"; loves a good atmosphere and beautiful glassware.$txt17$, 'users/female/60955dacc25e0ee6abbb57897bb29c8a.jpg', true, 2, 0),
  ('Marnie', 'female'::public.gender_type, $txt18$Enjoys a post-get off work drink to unwind and shake off the day's fatigue.$txt18$, 'users/female/692f79eeb66d16255f8faefa292baa5d.jpg', true, 3, 0),
  ('Ione', 'female'::public.gender_type, $txt19$Prefers crisp, fruity cocktails; has a low tolerance but loves trying new flavors.$txt19$, 'users/female/72564814ba8a88dd10504045df770ceb.jpg', true, 4, 0),
  ('Seraphina', 'female'::public.gender_type, $txt20$Occasionally explores new bars, documenting the recipes for delicious signature drinks.$txt20$, 'users/female/748d2481d5adf63d40a5dbc1254c73e1.jpg', true, 5, 0),
  ('Briar', 'female'::public.gender_type, $txt21$Loves small gatherings with friends—drinking and chatting makes for a perfectly cozy time.$txt21$, 'users/female/8e0d25662a646f0e8d4c438f8fa17c02.jpg', true, 6, 0),
  ('Paloma', 'female'::public.gender_type, $txt22$A devoted tequila fan; prefers signature cocktails with a sweet-and-sour profile.$txt22$, 'users/female/b612e5d024003574d534212acae68154.jpg', true, 7, 0),
  ('Soraya', 'female'::public.gender_type, $txt23$Prefers gentle, low-alcohol drinks; a mild buzz is just right.$txt23$, 'users/female/c078fc8dd99746ad50da8dd9ecc72c18.jpg', true, 8, 0),
  ('Wren', 'female'::public.gender_type, $txt24$A cocktail-mixing novice, slowly learning the ropes with simple recipes.$txt24$, 'users/female/d54ba3d44201befb31414b7c1d4d1200.jpg', true, 9, 0),
  ('Odette', 'female'::public.gender_type, $txt25$Prefers classic cocktails; not a fan of overly flashy or complicated combinations.$txt25$, 'users/female/dedb1d91321d4ec91864e8ee955d2063.jpg', true, 10, 0),
  ('Kaelin', 'female'::public.gender_type, $txt26$Loves watching live cocktail-mixing streams and tries to recreate the drinks herself.$txt26$, 'users/female/e3b808af0548772f85191b5a3c41dd21.jpg', false, null, 0),
  ('Zora', 'female'::public.gender_type, $txt27$Enjoys seeking out drinks that are visually stunning and "Instagrammable."$txt27$, 'users/female/e6d2ebea91fd3fc65d54f96e9e977e6f.jpg', false, null, 0),
  ('Lilibeth', 'female'::public.gender_type, $txt28$A lover of sweet drinks; steers clear of anything too bitter or too strong.$txt28$, 'users/female/f0c06ad77f3c9113c37786ef36c8337a.jpg', false, null, 0),
  ('Nova', 'female'::public.gender_type, $txt29$Loves experimenting with new recipes—often stumbles upon delightful surprises through trial and error.$txt29$, 'users/female/f3d679452276a14062960dac46f7dca2.jpg', false, null, 0),
  ('Thalassa', 'female'::public.gender_type, $txt30$The beach + a mild buzz = my ideal weekend combination.$txt30$, 'users/female/f9f491005a328da0b84059e31ffbf4e1.jpg', false, null, 0);

create temp table _user_rn on commit drop as
select id, row_number() over (order by created_at, id) as rn from public."User";


-- Live
insert into public."Live" (
  category_slug, category_name, category_sort_order, show_on_home,
  streamer_id, room_index, description, tags,
  cover_path, video_path, viewer_count, is_live, sort_order
) values (
  'other', 'Other', 2, true,
  (select id from _user_rn where rn = 1),
  1, $txt31$Time to crack open a craft beer! An in-depth tasting session focused on Red Ales—sample brews and discuss flavor profiles online, chatting about great beer with fellow enthusiasts.$txt31$, array['#CraftBeer', '#BeerTasting', '#RedAle', '#BeerBuddies', '#CraftBeerSession'],
  'live-streams/other/1/cover.jpg', 'live-streams/other/1/video.mp4',
  19, true, 1
);

insert into public."Live" (
  category_slug, category_name, category_sort_order, show_on_home,
  streamer_id, room_index, description, tags,
  cover_path, video_path, viewer_count, is_live, sort_order
) values (
  'other', 'Other', 2, true,
  (select id from _user_rn where rn = 2),
  2, $txt32$A late-night, tipsy bartending soirée! Create the perfect vibe with home-mixed cocktails—let a good drink be the cure for a long, tiring day.$txt32$, array['#LateNightDrinks', '#HomeTipsy', '#RelaxedBartending', '#SocialDrinking', '#AtmosphericCocktails'],
  'live-streams/other/2/cover.jpg', 'live-streams/other/2/video.mp4',
  23, true, 2
);

insert into public."Live" (
  category_slug, category_name, category_sort_order, show_on_home,
  streamer_id, room_index, description, tags,
  cover_path, video_path, viewer_count, is_live, sort_order
) values (
  'other', 'Other', 2, true,
  (select id from _user_rn where rn = 3),
  3, $txt33$A special session dedicated to Japanese Whisky cocktails! Featuring premium base spirits like Yamazaki and Hakushu, we unlock the authentic charm of Japanese-style mixology.$txt33$, array['#JapaneseBartending', '#Whisky', '#YamazakiHakushu', '#PremiumCocktails', '#JapaneseMixology'],
  'live-streams/other/3/cover.jpg', 'live-streams/other/3/video.mp4',
  28, true, 3
);

insert into public."Live" (
  category_slug, category_name, category_sort_order, show_on_home,
  streamer_id, room_index, description, tags,
  cover_path, video_path, viewer_count, is_live, sort_order
) values (
  'tutorials', 'Tutorials', 1, true,
  (select id from _user_rn where rn = 4),
  1, $txt34$A wall-to-wall cabinet stocked with a thousand base spirits! Professional bartenders mix live online, offering step-by-step tutorials ranging from classic cocktails to creative signature blends.$txt34$, array['#ProfessionalBartending', '#WallOfSpirits', '#CreativeCocktails', '#BartendingLivestream', '#CocktailTutorials'],
  'live-streams/tutorials/1/cover.jpg', 'live-streams/tutorials/1/video.mp4',
  35, true, 1
);

insert into public."Live" (
  category_slug, category_name, category_sort_order, show_on_home,
  streamer_id, room_index, description, tags,
  cover_path, video_path, viewer_count, is_live, sort_order
) values (
  'tutorials', 'Tutorials', 1, true,
  (select id from _user_rn where rn = 5),
  2, $txt35$Make it right in your kitchen! A beginner-friendly, zero-barrier home bartending mini-class—even total novices can easily whip up delicious signature drinks.$txt35$, array['#HomeBartending', '#BeginnerFriendly', '#HomeCocktails', '#BartendingTutorials', '#EasyBartending'],
  'live-streams/tutorials/2/cover.jpg', 'live-streams/tutorials/2/video.mp4',
  8, true, 2
);

insert into public."Live" (
  category_slug, category_name, category_sort_order, show_on_home,
  streamer_id, room_index, description, tags,
  cover_path, video_path, viewer_count, is_live, sort_order
) values (
  'tutorials', 'Tutorials', 1, true,
  (select id from _user_rn where rn = 6),
  3, $txt36$Live from a real bar counter! Veteran bartenders break down classic cocktail recipes, inviting you to experience the true allure of professional mixology.$txt36$, array['#BarBartending', '#ClassicCocktails', '#ProfessionalTechniques', '#BartenderLife', '#LiveAtTheBar'],
  'live-streams/tutorials/3/cover.jpg', 'live-streams/tutorials/3/video.mp4',
  42, true, 3
);


-- Post
insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 1),
  1, $txt37$A classic in hand, a gentle buzz—drinking in the rituals that enrich everyday life.$txt37$, '[{"type": "video", "storage_path": "moments/1.mp4", "sort_order": 0, "poster_path": "moments/1/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 2),
  2, $txt38$Joy without the alcohol: a collision of coffee and absinthe—keeping you lucid yet delightfully tipsy.$txt38$, '[{"type": "video", "storage_path": "moments/2.mp4", "sort_order": 0, "poster_path": "moments/2/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 3),
  3, $txt39$A creative signature blend that excels in both aesthetics and flavor; every sip is the pure sweetness of fresh fruit.$txt39$, '[{"type": "video", "storage_path": "moments/3.mp4", "sort_order": 0, "poster_path": "moments/3/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 4),
  4, $txt40$The bar counter is a stage, and every bottle toss is a dazzling display of passion and professionalism.$txt40$, '[{"type": "video", "storage_path": "moments/4.mp4", "sort_order": 0, "poster_path": "moments/4/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 5),
  5, $txt41$Shaking a cocktail isn't just about the drink; it’s about the ritual of living. One good drink is enough to soothe away all your weariness.$txt41$, '[{"type": "video", "storage_path": "moments/5.mp4", "sort_order": 0, "poster_path": "moments/5/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 6),
  6, $txt42$Gentle moments at a vintage bar: a glass of freshly mixed magic, raised in a toast to everyone who lives life with earnest dedication.$txt42$, '[{"type": "video", "storage_path": "moments/6.mp4", "sort_order": 0, "poster_path": "moments/6/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 7),
  7, $txt43$The sweet-and-sour tang of passion fruit blossoms within the glass—who else understands the sheer joy of falling in love with a drink at first sip?$txt43$, '[{"type": "video", "storage_path": "moments/7.mp4", "sort_order": 0, "poster_path": "moments/7/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 8),
  8, $txt44$Cocktails & Dreams: at this neon-lit bar, unlock a glass of romance that belongs exclusively to the night.$txt44$, '[{"type": "video", "storage_path": "moments/8.mp4", "sort_order": 0, "poster_path": "moments/8/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 9),
  9, $txt45$The bar is set, the drinks are ready—tonight, your happiness is entirely in the hands of the bartender.$txt45$, '[{"type": "video", "storage_path": "moments/9.mp4", "sort_order": 0, "poster_path": "moments/9/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 10),
  10, $txt46$A drink crafted with meticulous attention to detail; from the shaking to the garnish, every step is a testament to a deep love for the craft.$txt46$, '[{"type": "video", "storage_path": "moments/10.mp4", "sort_order": 0, "poster_path": "moments/10/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 11),
  11, $txt47$Served with precision, locking the full flavor into every single drop—bartending is the romance found in the details.$txt47$, '[{"type": "video", "storage_path": "moments/11.mp4", "sort_order": 0, "poster_path": "moments/11/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 12),
  12, $txt48$The gentle warmth of the wooden bar, the crisp clinking of ice—this chilled drink holds the refreshing coolness of summer within.$txt48$, '[{"type": "video", "storage_path": "moments/12.mp4", "sort_order": 0, "poster_path": "moments/12/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 13),
  13, $txt49$The aromatic zest of orange peel, enveloping the rich body of the spirit—a classic Martini, served with a full sense of ritual.$txt49$, '[{"type": "video", "storage_path": "moments/13.mp4", "sort_order": 0, "poster_path": "moments/13/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 14),
  14, $txt50$Passion is the antidote to the passage of time; shake up a cocktail and smile as you face the little trivialities of daily life.$txt50$, '[{"type": "video", "storage_path": "moments/14.mp4", "sort_order": 0, "poster_path": "moments/14/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 15),
  15, $txt51$Bathed in shifting red and blue light, this signature cocktail is utterly intoxicating—both in its stunning looks and its exquisite flavor.$txt51$, '[{"type": "video", "storage_path": "moments/15.mp4", "sort_order": 0, "poster_path": "moments/15/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 16),
  16, $txt52$The pure joy of an Aperol Spritz: a summer romance born from the dance between oranges and sparkling water. If you’ve tasted it, you understand.$txt52$, '[{"type": "image", "storage_path": "moments/16/13d988e9a47e9c0cc686b3a909376bad.jpg", "sort_order": 0}, {"type": "image", "storage_path": "moments/16/6bd79b5583e9ae03b0308194766b81c6.jpg", "sort_order": 1}, {"type": "image", "storage_path": "moments/16/ab9ec23f687d23b550e32729348355f0.jpg", "sort_order": 2}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 17),
  17, $txt53$The tartness of fresh lime provides the perfect, soothing foundation for a homemade cocktail—sharing a gentle buzz with friends is pure bliss.$txt53$, '[{"type": "image", "storage_path": "moments/17/045fbf1e0738343f7ad7d1ee35c50033.jpg", "sort_order": 0}, {"type": "image", "storage_path": "moments/17/41ce1d502eee121398b4df0dbe95e885.jpg", "sort_order": 1}, {"type": "image", "storage_path": "moments/17/6d978919ac202732717306a8f1069c03.jpg", "sort_order": 2}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 18),
  18, $txt54$It’s not just the drink that’s pink—it’s the relaxed, carefree mood of the weekend. Shake up a glass and craft a moment of gentle serenity, just for yourself.$txt54$, '[{"type": "image", "storage_path": "moments/18/acd5afb7d087962e920ebb26bb9390b4.jpg", "sort_order": 0}, {"type": "image", "storage_path": "moments/18/fc9a510bc4ec6260261a807ac92434d8.jpg", "sort_order": 1}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 19),
  19, $txt55$The silky liquid flows through the filter; the aroma of coffee, entwined with the scent of spirits, makes this cup a gentle antidote for the late-night hours.$txt55$, '[{"type": "image", "storage_path": "moments/19/b5c63ea80d9d2867daa46ad4eef5d558.jpg", "sort_order": 0}, {"type": "image", "storage_path": "moments/19/b605f58807bfa65dc732cfeaabab3198.jpg", "sort_order": 1}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 20),
  20, $txt56$With its dense, creamy foam and exquisite garnishes, every cup of coffee liqueur serves as a testament to a sincere dedication—and a deep love—for life.$txt56$, '[{"type": "image", "storage_path": "moments/20/d7ff5ac78a7f50ecf77e5b7eec230e8f.jpg", "sort_order": 0}, {"type": "image", "storage_path": "moments/20/fe3f3d325347e09e9f0bbe11c456fe7f.jpg", "sort_order": 1}]'::jsonb
);


-- Popular Star 展示名
with stars as (
  select id, row_number() over (order by popular_star_sort) as rn from public."User"
  where is_popular_star = true
)
update public."User" u set display_name = v.name
from stars s
join (values
  (1, 'Emerson'), (2, 'Gideon'), (3, 'Casper'), (4, 'Elias'),
  (5, 'Fiona'), (6, 'Hazel'), (7, 'Iris'), (8, 'Juno'), (9, 'Kira'), (10, 'Luna')
) as v(rn, name) on v.rn = s.rn
where u.id = s.id;

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
