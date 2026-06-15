-- 嘉宾麦位：排除房主、同一房间不重复同一明星。

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
    public.chat_room_host_audio_path(v_room_index)
  )
  returning id into v_room_id;

  insert into public."ChatRoomMember" (chat_room_id, user_id, sort_order)
  values (v_room_id, v_me, 0)
  on conflict (chat_room_id, user_id) do update
  set sort_order = excluded.sort_order;

  insert into public."ChatRoomMember" (chat_room_id, user_id, sort_order)
  select v_room_id, picked.user_id, picked.sort_order
  from public.pick_chat_room_guest_stars(v_room_index, v_me) picked
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

-- 修复已有房间：保留房主，嘉宾位重新按规则分配。
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
