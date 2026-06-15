-- 删除 title 为 donk 的聊天室（成员与公屏消息随 FK CASCADE 一并清理）。

delete from public."ChatRoom"
where title = 'donk';
