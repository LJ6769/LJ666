-- 新用户注册时自动写入 public."User"（避免仅创建 auth.users 而无业务资料行）

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
  v_name text;
  v_bio text;
begin
  v_email := lower(trim(coalesce(new.email, '')));
  v_name := trim(coalesce(new.raw_user_meta_data ->> 'display_name', ''));
  v_bio := trim(coalesce(new.raw_user_meta_data ->> 'bio', ''));
  if v_name = '' and v_email <> '' then
    v_name := split_part(v_email, '@', 1);
  end if;
  if v_name = '' then
    v_name := 'Player';
  end if;

  insert into public."User" (auth_user_id, email, display_name, bio)
  values (
    new.id,
    nullif(v_email, ''),
    v_name,
    nullif(v_bio, '')
  )
  on conflict (auth_user_id) do update
    set email = coalesce(nullif(excluded.email, ''), public."User".email),
        display_name = case
          when public."User".display_name is null
            or public."User".display_name = ''
            or public."User".display_name = 'Player'
          then excluded.display_name
          else public."User".display_name
        end,
        bio = coalesce(nullif(excluded.bio, ''), public."User".bio);

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_auth_user();

-- 保持 User 表对客户端可读（见 20260626110000_user_table_public_read.sql）
alter table public."User" disable row level security;
