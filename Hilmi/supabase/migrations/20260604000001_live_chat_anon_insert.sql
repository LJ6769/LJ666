-- 允许匿名用户发送直播间弹幕（无登录时 sender_id 为空）
create policy "live_chat_insert_anon" on public."LiveChat"
  for insert
  to anon
  with check (true);
