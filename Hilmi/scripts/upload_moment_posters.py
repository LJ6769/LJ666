#!/usr/bin/env python3
"""从朋友圈 mp4 截取封面并上传到 moments/{n}/poster.jpg（与 Post.media 种子一致）。"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from image_compress import prepare_upload_jpeg
from media_upload_common import DEFAULT_ASSETS_BASE, load_env, upload_storage_file
from video_compress import HIGH_QUALITY_MAX_HEIGHT, extract_poster_frame, require_ffmpeg

MOMENTS = DEFAULT_ASSETS_BASE / "朋友圈"


def main() -> None:
    env = load_env()
    url = env.get("SUPABASE_URL", "")
    key = env.get("SUPABASE_SERVICE_ROLE_KEY", "")
    if not url or not key:
        print("请在 lib/config/supabase_config.dart 与 supabase_admin_config.dart 配置 Supabase")
        sys.exit(1)

    if not MOMENTS.is_dir():
        print(f"素材目录不存在: {MOMENTS}")
        sys.exit(1)

    try:
        ffmpeg = require_ffmpeg()
    except RuntimeError as error:
        print(error)
        sys.exit(1)

    ok = 0
    for mp4 in sorted(MOMENTS.glob("*.mp4"), key=lambda p: int(p.stem)):
        storage_path = f"moments/{mp4.stem}/poster.jpg"
        with tempfile.TemporaryDirectory() as td:
            raw = Path(td) / "poster_raw.jpg"
            out = Path(td) / "poster.jpg"
            extract_poster_frame(
                ffmpeg=ffmpeg,
                video_path=mp4,
                output_path=raw,
                max_height=HIGH_QUALITY_MAX_HEIGHT,
            )
            upload_path, is_temp = prepare_upload_jpeg(raw)
            try:
                upload_storage_file(
                    supabase_url=url,
                    api_key=key,
                    storage_path=storage_path,
                    local_path=upload_path,
                )
            finally:
                if is_temp:
                    upload_path.unlink(missing_ok=True)
        ok += 1
        print(f"  [{ok}] {storage_path}")

    print(f"\n完成 {ok} 个视频封面。")


if __name__ == "__main__":
    main()
