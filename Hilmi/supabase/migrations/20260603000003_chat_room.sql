-- Tipsy Bar 语音聊天室：ChatRoom + ChatRoomMember
-- 由 generate_chat_room_seed.py 生成（素材: /Users/mac/Downloads/Hilmi切图/Hilmi素材/聊天室）

create table if not exists public."ChatRoom" (
  id uuid primary key default gen_random_uuid(),
  room_index integer not null unique,
  title text not null,
  description text not null,
  cover_path text not null,
  image_on_right boolean not null default false,
  show_on_home boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists chat_room_home_idx
  on public."ChatRoom" (show_on_home, sort_order);

create table if not exists public."ChatRoomMember" (
  chat_room_id uuid not null references public."ChatRoom" (id) on delete cascade,
  user_id uuid not null references public."User" (id) on delete cascade,
  sort_order integer not null default 0,
  primary key (chat_room_id, user_id)
);

create index if not exists chat_room_member_room_idx
  on public."ChatRoomMember" (chat_room_id, sort_order);

alter table public."ChatRoom" enable row level security;
alter table public."ChatRoomMember" enable row level security;

drop policy if exists "chat_room_select" on public."ChatRoom";
create policy "chat_room_select" on public."ChatRoom" for select using (true);

drop policy if exists "chat_room_member_select" on public."ChatRoomMember";
create policy "chat_room_member_select" on public."ChatRoomMember" for select using (true);

insert into public."ChatRoom" (
  room_index, title, description, cover_path, image_on_right, show_on_home, sort_order
) values
  (
    1,
    'Neon Tavern: A Night of Gentle Tipsiness',
    'Our online tavern is now open! Come enjoy a signature custom cocktail—the perfect way to unwind and feel pleasantly mellow.',
    'chat-rooms/1.jpg',
    false,
    true,
    1
  ),
  (
    2,
    'The Signature Cocktail Inspiration Exchange',
    'Share your recipes for visually stunning cocktails and chat about how to recreate authentic bar-quality flavors right at home.',
    'chat-rooms/2.jpg',
    true,
    true,
    2
  ),
  (
    3,
    'Retro Bar Mixology Session',
    'Experience the allure of a vintage bar counter and unlock the secrets to crafting classic cocktails with a gentle, refined touch.',
    'chat-rooms/3.jpg',
    false,
    true,
    3
  ),
  (
    4,
    'The Healing Mixology Workshop',
    'Let a beautifully layered, signature cocktail soothe away the fatigue and frustrations of a busy day.',
    'chat-rooms/4.jpg',
    true,
    false,
    4
  ),
  (
    5,
    'Professional Cocktail Shaking Masterclass',
    'Master standard shaking techniques and unlock the true essence of classic cocktails—such as the Martini—with expert precision.',
    'chat-rooms/5.jpg',
    false,
    false,
    5
  ),
  (
    6,
    'The Gentleman Bartender''s Salon',
    'Discuss professional bartending etiquette and share recipes for elegant, signature cocktails—including the timeless Martini.',
    'chat-rooms/6.jpg',
    true,
    false,
    6
  ),
  (
    7,
    'Exquisite Cocktail Tasting & Appreciation',
    'Savor the nuanced flavors of sophisticated cocktails while exchanging tips on mixing techniques and perfect pairings.',
    'chat-rooms/7.jpg',
    false,
    false,
    7
  ),
  (
    8,
    'The "Good Vibes" Cocktail Share-a-thon',
    'Double your happiness with a cocktail in hand! Share your favorite recipes for visually stunning drinks that capture the perfect summer vibe.',
    'chat-rooms/8.jpg',
    true,
    false,
    8
  )
on conflict (room_index) do update set
  title = excluded.title,
  description = excluded.description,
  cover_path = excluded.cover_path,
  image_on_right = excluded.image_on_right,
  show_on_home = excluded.show_on_home,
  sort_order = excluded.sort_order;

-- 每个房间按 room_index 轮换 5 位明星；sort_order=0 为房主（各房间不同）。
delete from public."ChatRoomMember";

insert into public."ChatRoomMember" (chat_room_id, user_id, sort_order)
select cr.id, picked.user_id, picked.sort_order
from public."ChatRoom" cr
cross join lateral (
  with stars as (
    select
      id as user_id,
      row_number() over (order by popular_star_sort) - 1 as star_idx
    from public."User"
    where is_popular_star = true and popular_star_sort is not null
  ),
  star_count as (
    select count(*)::int as n from stars
  )
  select s.user_id, gs.seat::int as sort_order
  from generate_series(0, 2) as gs(seat)
  cross join star_count sc
  join stars s on s.star_idx = ((cr.room_index - 1 + gs.seat) % sc.n)
) picked
on conflict (chat_room_id, user_id) do update set sort_order = excluded.sort_order;
