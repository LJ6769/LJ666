-- 全员默认 0；仅 Niko、donk666 为 100000（App 内展示为 100k）

update public."User"
set coins = 0;

update public."User"
set coins = 100000
where display_name ilike 'Niko'
   or display_name ilike 'donk'
   or email ilike 'donk666%';
