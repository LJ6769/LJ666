-- 消费金币（送礼物、创建房间等客户端已校验场景）。

create or replace function public.spend_user_coins(p_amount integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid;
  v_coins integer;
  v_amount integer;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  v_amount := coalesce(p_amount, 0);
  if v_amount <= 0 then
    raise exception 'invalid amount' using errcode = '22023';
  end if;

  select id, coins into v_me, v_coins
  from public."User"
  where auth_user_id = auth.uid();

  if v_me is null then
    raise exception 'profile not found' using errcode = '28000';
  end if;

  if v_coins < v_amount then
    raise exception 'insufficient coins' using errcode = '22023';
  end if;

  update public."User"
  set coins = coins - v_amount, updated_at = now()
  where id = v_me
  returning coins into v_coins;

  return jsonb_build_object('coins', v_coins);
end;
$$;

grant execute on function public.spend_user_coins(integer) to authenticated;
