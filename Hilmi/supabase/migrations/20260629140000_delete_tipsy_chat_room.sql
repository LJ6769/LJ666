-- 房主删除自己创建的 Tipsy Bar 聊天室。

create or replace function public.delete_tipsy_chat_room(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid;
  v_room_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  v_room_id := p_room_id;
  if v_room_id is null then
    raise exception 'room id required' using errcode = '22023';
  end if;

  select id into v_me
  from public."User"
  where auth_user_id = auth.uid();

  if v_me is null then
    raise exception 'profile not found' using errcode = '28000';
  end if;

  if not exists (
    select 1
    from public."ChatRoomMember" m
    where m.chat_room_id = v_room_id
      and m.user_id = v_me
      and m.sort_order = 0
  ) then
    raise exception 'only room host can delete' using errcode = '42501';
  end if;

  delete from public."ChatRoom"
  where id = v_room_id;
end;
$$;

grant execute on function public.delete_tipsy_chat_room(uuid) to authenticated;
