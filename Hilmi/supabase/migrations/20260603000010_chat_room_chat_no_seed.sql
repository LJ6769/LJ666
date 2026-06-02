-- 移除曾预置的房间种子弹幕（若已执行过带 insert 的旧版 000009）

delete from public."ChatRoomChat"
where content in (
  'Does anyone have any recommendations for a good gin?',
  'Any fellow Mojito lovers out there?'
);
