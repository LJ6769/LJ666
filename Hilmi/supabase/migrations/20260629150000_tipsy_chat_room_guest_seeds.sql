-- 自建 Tipsy Bar 与种子房一致：房主 + 2 位明星嘉宾麦位；并回填仅房主的旧房间。

create or replace function public.create_tipsy_chat_room(
  p_title text,
  p_description text,
  p_cover_path text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid;
  v_coins integer;
  v_cost constant integer := 20;
  v_room_index integer;
  v_sort_order integer;
  v_room_id uuid;
  v_title text;
  v_desc text;
  v_cover text;
  v_image_on_right boolean;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  v_title := trim(coalesce(p_title, ''));
  v_desc := trim(coalesce(p_description, ''));
  v_cover := trim(coalesce(p_cover_path, ''));

  if v_title = '' then
    raise exception 'title is required' using errcode = '22023';
  end if;
  if v_desc = '' then
    raise exception 'description is required' using errcode = '22023';
  end if;
  if v_cover = '' then
    raise exception 'cover is required' using errcode = '22023';
  end if;

  select id, coins into v_me, v_coins
  from public."User"
  where auth_user_id = auth.uid();

  if v_me is null then
    raise exception 'profile not found' using errcode = '28000';
  end if;

  if v_coins < v_cost then
    raise exception 'insufficient coins' using errcode = '22023';
  end if;

  select coalesce(max(room_index), 0) + 1 into v_room_index
  from public."ChatRoom";

  select coalesce(max(sort_order), 0) + 1 into v_sort_order
  from public."ChatRoom";

  v_image_on_right := (v_room_index % 2) = 0;

  update public."User"
  set coins = coins - v_cost, updated_at = now()
  where id = v_me;

  insert into public."ChatRoom" (
    room_index,
    title,
    description,
    cover_path,
    image_on_right,
    show_on_home,
    sort_order,
    host_audio_path
  ) values (
    v_room_index,
    v_title,
    v_desc,
    v_cover,
    v_image_on_right,
    true,
    v_sort_order,
    null
  )
  returning id into v_room_id;

  insert into public."ChatRoomMember" (chat_room_id, user_id, sort_order)
  values (v_room_id, v_me, 0)
  on conflict (chat_room_id, user_id) do update
  set sort_order = excluded.sort_order;

  insert into public."ChatRoomMember" (chat_room_id, user_id, sort_order)
  select v_room_id, picked.user_id, picked.sort_order
  from (
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
    from generate_series(1, 2) as gs(seat)
    cross join star_count sc
    join stars s on sc.n > 0
      and s.star_idx = ((v_room_index - 1 + gs.seat) % sc.n)
  ) picked
  on conflict (chat_room_id, user_id) do update
  set sort_order = excluded.sort_order;

  select coins into v_coins from public."User" where id = v_me;

  return jsonb_build_object(
    'room_id', v_room_id,
    'room_index', v_room_index,
    'coins', v_coins
  );
end;
$$;

grant execute on function public.create_tipsy_chat_room(text, text, text) to authenticated;

-- 回填：仅有房主、缺少嘉宾麦位的房间。
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
  from generate_series(1, 2) as gs(seat)
  cross join star_count sc
  join stars s on sc.n > 0
    and s.star_idx = ((cr.room_index - 1 + gs.seat) % sc.n)
) picked
where not exists (
  select 1
  from public."ChatRoomMember" m
  where m.chat_room_id = cr.id
    and m.sort_order = picked.sort_order
)
on conflict (chat_room_id, user_id) do update
set sort_order = excluded.sort_order;
