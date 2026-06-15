-- 删除本人评论/弹幕，并维护帖子 comment_count。

create or replace function public.decrement_post_comment_count()
returns trigger
language plpgsql
as $$
begin
  update public."Post"
  set comment_count = greatest(comment_count - 1, 0)
  where id = old.post_id;
  return old;
end;
$$;

drop trigger if exists post_chat_count_delete on public."PostChat";
create trigger post_chat_count_delete
  after delete on public."PostChat"
  for each row execute function public.decrement_post_comment_count();

create or replace function public.delete_own_post_comment(p_comment_id uuid)
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

  if p_comment_id is null then
    raise exception 'comment id required' using errcode = '22023';
  end if;

  delete from public."PostChat"
  where id = p_comment_id
    and author_id = v_me;

  if not found then
    raise exception 'comment not found' using errcode = '42501';
  end if;
end;
$$;

create or replace function public.delete_own_live_chat(p_message_id uuid)
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

  if p_message_id is null then
    raise exception 'message id required' using errcode = '22023';
  end if;

  delete from public."LiveChat"
  where id = p_message_id
    and sender_id = v_me;

  if not found then
    raise exception 'message not found' using errcode = '42501';
  end if;
end;
$$;

create or replace function public.delete_own_chat_room_chat(p_message_id uuid)
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

  if p_message_id is null then
    raise exception 'message id required' using errcode = '22023';
  end if;

  delete from public."ChatRoomChat"
  where id = p_message_id
    and sender_id = v_me;

  if not found then
    raise exception 'message not found' using errcode = '42501';
  end if;
end;
$$;

grant execute on function public.delete_own_post_comment(uuid) to authenticated;
grant execute on function public.delete_own_live_chat(uuid) to authenticated;
grant execute on function public.delete_own_chat_room_chat(uuid) to authenticated;
