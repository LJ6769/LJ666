-- 修复：原先所有 ChatRoom 共用同一组 5 位明星，房主始终相同。
-- 按 room_index 轮换成员，使各房间房主与麦位用户不同。

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
