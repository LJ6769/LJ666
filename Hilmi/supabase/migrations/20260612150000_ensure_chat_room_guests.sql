-- 进入聊天室时嘉宾不足 2 人则自动补全（依赖 pick_chat_room_guest_stars）。

create or replace function public.ensure_chat_room_guests(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room_index integer;
  v_host_id uuid;
  v_guest_count integer;
begin
  if p_room_id is null then
    return;
  end if;

  select cr.room_index into v_room_index
  from public."ChatRoom" cr
  where cr.id = p_room_id;

  if v_room_index is null then
    return;
  end if;

  select m.user_id into v_host_id
  from public."ChatRoomMember" m
  where m.chat_room_id = p_room_id
    and m.sort_order = 0
  limit 1;

  select count(*)::int into v_guest_count
  from public."ChatRoomMember" m
  where m.chat_room_id = p_room_id
    and m.sort_order > 0;

  if v_guest_count >= 2 then
    return;
  end if;

  delete from public."ChatRoomMember" m
  where m.chat_room_id = p_room_id
    and m.sort_order > 0;

  insert into public."ChatRoomMember" (chat_room_id, user_id, sort_order)
  select p_room_id, picked.user_id, picked.sort_order
  from public.pick_chat_room_guest_stars(v_room_index, v_host_id) picked
  on conflict (chat_room_id, user_id) do update
  set sort_order = excluded.sort_order;
end;
$$;

grant execute on function public.ensure_chat_room_guests(uuid) to authenticated;
grant execute on function public.ensure_chat_room_guests(uuid) to anon;
