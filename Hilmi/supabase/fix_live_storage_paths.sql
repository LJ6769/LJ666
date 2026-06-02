-- 将 Live 表媒体路径与 upload_media.py 上传规则对齐（cover.jpg / video.mp4）
-- 在 Storage 上传完成后于 SQL Editor 执行

UPDATE public."Live"
SET
  cover_path = regexp_replace(cover_path, '/[^/]+$', '/cover.jpg'),
  video_path = regexp_replace(video_path, '/[^/]+$', '/video.mp4'),
  updated_at = now()
WHERE cover_path LIKE 'live-streams/%'
   OR video_path LIKE 'live-streams/%';
