-- 嘉宾麦位：在明星池里按 room_index 轮换，尽量凑满 2 个不同嘉宾（排除房主）。

create or replace function public.pick_chat_room_guest_stars(
  p_room_index integer,
  p_host_user_id uuid
)
returns table(user_id uuid, sort_order integer)
language sql
stable
as $$
  with stars as (
    select
      id as user_id,
      row_number() over (order by popular_star_sort) - 1 as star_idx
    from public."User"
    where is_popular_star = true and popular_star_sort is not null
  ),
  star_count as (
    select count(*)::int as n from stars
  ),
  walk as (
    select
      s.user_id,
      row_number() over (order by step.k) as pick_rn
    from star_count sc
    cross join generate_series(0, sc.n - 1) as step(k)
    join stars s on sc.n > 0
      and s.star_idx = ((p_room_index - 1 + 1 + step.k) % sc.n)
    where sc.n > 0
      and (p_host_user_id is null or s.user_id <> p_host_user_id)
  ),
  distinct_walk as (
    select distinct on (walk.user_id)
      walk.user_id,
      walk.pick_rn
    from walk
    order by walk.user_id, walk.pick_rn
  ),
  ranked as (
    select
      distinct_walk.user_id,
      row_number() over (order by distinct_walk.pick_rn) as guest_slot
    from distinct_walk
  )
  select ranked.user_id, ranked.guest_slot::int as sort_order
  from ranked
  where ranked.guest_slot <= 2;
$$;

-- 重新分配嘉宾位，使已有房间尽量显示满 2 位嘉宾。
delete from public."ChatRoomMember" m
using public."ChatRoom" cr
where m.chat_room_id = cr.id
  and m.sort_order > 0;

insert into public."ChatRoomMember" (chat_room_id, user_id, sort_order)
select cr.id, picked.user_id, picked.sort_order
from public."ChatRoom" cr
cross join lateral (
  select p.user_id, p.sort_order
  from public.pick_chat_room_guest_stars(
    cr.room_index,
    (
      select h.user_id
      from public."ChatRoomMember" h
      where h.chat_room_id = cr.id
        and h.sort_order = 0
      limit 1
    )
  ) p
) picked
on conflict (chat_room_id, user_id) do update
  set sort_order = excluded.sort_order;
