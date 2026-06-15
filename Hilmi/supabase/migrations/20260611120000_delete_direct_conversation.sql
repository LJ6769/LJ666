-- 删除一对一私信会话（header + 全部 chat 消息）。

create or replace function public.delete_direct_conversation(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select id into v_me
  from public."User"
  where auth_user_id = auth.uid();

  if v_me is null then
    raise exception 'profile not found' using errcode = '28000';
  end if;

  if p_conversation_id is null then
    raise exception 'conversation id required' using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public."Message"
    where conversation_id = p_conversation_id
      and message_kind = 'header'
      and (user_low_id = v_me or user_high_id = v_me)
  ) then
    raise exception 'conversation not found' using errcode = '42501';
  end if;

  delete from public."Message"
  where conversation_id = p_conversation_id;
end;
$$;

grant execute on function public.delete_direct_conversation(uuid) to authenticated;
