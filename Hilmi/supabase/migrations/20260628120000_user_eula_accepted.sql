-- EULA 同意时间（服务端持久化：卸载重装不丢失；删号后新账号需重新同意）

alter table public."User"
  add column if not exists eula_accepted_at timestamptz;

comment on column public."User".eula_accepted_at is
  '用户同意 EULA 的时间；NULL 表示尚未同意。';

create or replace function public.accept_eula()
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  v_at timestamptz := now();
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  update public."User"
  set eula_accepted_at = coalesce(eula_accepted_at, v_at),
      updated_at = now()
  where auth_user_id = auth.uid();

  if not found then
    raise exception 'profile not found' using errcode = '28000';
  end if;

  return v_at;
end;
$$;

grant execute on function public.accept_eula() to authenticated;

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
