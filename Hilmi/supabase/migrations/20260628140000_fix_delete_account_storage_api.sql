-- Supabase 禁止直接 DELETE storage.objects，Storage 清理由客户端 Storage API 完成。

drop function if exists public._delete_user_media_storage(uuid, uuid, text, text);

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  delete from public."User" where auth_user_id = v_uid;
  delete from auth.users where id = v_uid;
end;
$$;

grant execute on function public.delete_my_account() to authenticated;
