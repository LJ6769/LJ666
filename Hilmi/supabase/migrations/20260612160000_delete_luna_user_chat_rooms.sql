-- 删除真实登录用户 Luna 创建的 Tipsy Bar 聊天室（不含种子房明星房主）。

delete from public."ChatRoom"
where id in (
  select cr.id
  from public."ChatRoom" cr
  join public."ChatRoomMember" m
    on m.chat_room_id = cr.id
   and m.sort_order = 0
  join public."User" u on u.id = m.user_id
  where u.display_name = 'Luna'
    and u.auth_user_id is not null
);
