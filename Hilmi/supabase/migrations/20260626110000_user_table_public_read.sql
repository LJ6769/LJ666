-- User 表需对客户端公开读（朋友圈/直播作者头像昵称、Popular Star 等）
-- 远程曾启用 RLS 且无 policy，导致 PostgREST 关联 User 恒为 null。

alter table public."User" disable row level security;
