-- 房主语音：进入房间后播放，路径与素材 room_index 对应。

alter table public."ChatRoom"
  add column if not exists host_audio_path text;

update public."ChatRoom"
set host_audio_path = 'chat-audio/' || room_index::text || '.mp3'
where host_audio_path is null or host_audio_path = '';
