-- 修复首页 Stories=0 / 头像不显示：User 表 RLS 无策略会导致 anon 读不到数据
-- 在 Dashboard SQL Editor 执行一次即可

alter table public."User" disable row level security;

-- 头像路径与上传脚本一致（Storage 不支持中文文件名「副本」→ copy）
update public."User"
set avatar_path = replace(avatar_path, '_副本.', '_copy.')
where avatar_path like '%_副本.%';
