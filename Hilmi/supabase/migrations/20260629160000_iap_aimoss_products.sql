-- 金币商城：App Store Connect 真实商品 ID（与 lib/config/iap_config.dart 一致）
create or replace function public.iap_coins_for_product(p_product_id text)
returns integer
language sql
immutable
set search_path = public
as $$
  select case trim(p_product_id)
    when 'mgwtghzkyzayvhbw' then 400
    when 'ijwhpdnfcbtmhcsm' then 800
    when 'rsdzurddehlcrqzu' then 2450
    when 'unyqcpbgddjxgwwu' then 5150
    when 'sikxnzlzflsjwubp' then 10800
    when 'dncewabylvgxxify' then 29400
    when 'szhwifwbucazxgkf' then 63700
    else null
  end::integer;
$$;
