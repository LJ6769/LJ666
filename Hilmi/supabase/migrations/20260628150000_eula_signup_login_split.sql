-- 注册与登录分别记录 EULA：首次注册弹一次、首次登录再弹一次。

alter table public."User"
  add column if not exists eula_login_accepted_at timestamptz;

comment on column public."User".eula_accepted_at is
  '注册流程同意 EULA 的时间。';
comment on column public."User".eula_login_accepted_at is
  '登录流程同意 EULA 的时间。';

-- 注册同意（写入 eula_accepted_at，不写入登录字段）
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

-- 登录同意（仅写入 eula_login_accepted_at）
create or replace function public.accept_eula_login()
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
  set eula_login_accepted_at = coalesce(eula_login_accepted_at, v_at),
      updated_at = now()
  where auth_user_id = auth.uid();

  if not found then
    raise exception 'profile not found' using errcode = '28000';
  end if;

  return v_at;
end;
$$;

grant execute on function public.accept_eula() to authenticated;
grant execute on function public.accept_eula_login() to authenticated;
