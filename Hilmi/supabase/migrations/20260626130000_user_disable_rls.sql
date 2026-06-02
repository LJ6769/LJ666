-- User 表需对客户端可读（Popular Star / 主播头像）；与 deploy_schema_only.sql 一致
alter table public."User" disable row level security;
