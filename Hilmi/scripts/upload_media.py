#!/usr/bin/env python3
"""上传 Hilmi素材 → Supabase Storage bucket: media"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from typing import Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))

from media_upload_common import (
    DEFAULT_ASSETS_BASE,
    is_excluded_moment_post,
    load_env,
    storage_safe_filename,
    upload_storage_file,
)
from image_compress import prepare_upload_jpeg
from video_compress import (
    compress_params_for_storage_path,
    prepare_upload_mp4,
    require_ffmpeg,
)

FOLDER_MAP = {
    "Other": "other",
    "Tutorials": "tutorials",
}


def iter_uploads(
    *,
    base: Path,
    include_videos: bool,
    only: frozenset[str] | None = None,
) -> list[tuple[Path, str]]:
    items: list[tuple[Path, str]] = []
    upload_users = only is None or "users" in only
    upload_live = only is None or "live" in only
    upload_moments = only is None or "moments" in only
    upload_chat = only is None or "chat" in only

    for gender, folder in (("male", "男"), ("female", "女")):
        if not upload_users:
            continue
        src = base / "用户信息" / folder
        if not src.is_dir():
            continue
        for file in sorted(src.glob("*.jpg")):
            items.append(
                (file, f"users/{gender}/{storage_safe_filename(file.name)}"),
            )

    live_base = base / "直播间"
    if upload_live and live_base.is_dir():
        for game_dir in live_base.iterdir():
            if not game_dir.is_dir() or game_dir.name.startswith("."):
                continue
            slug = FOLDER_MAP.get(game_dir.name, game_dir.name.lower().replace(" ", "-"))
            for room in game_dir.iterdir():
                if not room.is_dir() or not room.name.isdigit():
                    continue
                for file in room.iterdir():
                    if not file.is_file() or file.name.startswith("."):
                        continue
                    if file.suffix.lower() == ".mp4" and not include_videos:
                        continue
                    if file.suffix.lower() == ".jpg":
                        items.append((file, f"live-streams/{slug}/{room.name}/cover.jpg"))
                    elif file.suffix.lower() == ".mp4":
                        items.append((file, f"live-streams/{slug}/{room.name}/video.mp4"))

    moments = base / "朋友圈"
    if upload_moments and moments.is_dir():
        for file in sorted(moments.glob("*.mp4")):
            if is_excluded_moment_post(file.stem):
                continue
            if include_videos:
                items.append((file, f"moments/{file.name}"))
        for folder in sorted(moments.iterdir()):
            if folder.is_dir() and folder.name.isdigit():
                if is_excluded_moment_post(folder.name):
                    continue
                for img in sorted(folder.glob("*.jpg")):
                    items.append(
                        (
                            img,
                            f"moments/{folder.name}/{storage_safe_filename(img.name)}",
                        ),
                    )

    chat_covers = base / "聊天室" / "聊天室封面+信息"
    if upload_chat and chat_covers.is_dir():
        for img in sorted(chat_covers.glob("*.jpg")):
            items.append((img, f"chat-rooms/{img.stem}.jpg"))

    chat_audio = base / "聊天室" / "用户音频"
    if upload_chat and chat_audio.is_dir():
        for audio in sorted(chat_audio.glob("*.mp3")):
            if audio.stem.isdigit():
                items.append((audio, f"chat-audio/{audio.stem}.mp3"))

    return items


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--with-videos", action="store_true")
    parser.add_argument("--no-compress", action="store_true")
    parser.add_argument(
        "--no-compress-images",
        action="store_true",
        help="跳过 JPG 压缩（默认上传前压缩以减小 egress）",
    )
    parser.add_argument(
        "--assets-base",
        type=Path,
        default=Path(os.environ.get("HILMI_ASSETS", DEFAULT_ASSETS_BASE)),
        help="Hilmi素材 根目录（也可用环境变量 HILMI_ASSETS）",
    )
    parser.add_argument(
        "--only",
        type=str,
        default="",
        help="仅上传指定分类，逗号分隔：moments,live,users,chat",
    )
    args = parser.parse_args()

    base = args.assets_base.expanduser().resolve()
    only = (
        frozenset(part.strip() for part in args.only.split(",") if part.strip())
        if args.only.strip()
        else None
    )

    if not base.is_dir():
        print(f"素材目录不存在: {base}")
        sys.exit(1)

    env = load_env()
    url = env.get("SUPABASE_URL", "")
    key = env.get("SUPABASE_SERVICE_ROLE_KEY", "")
    if not url or not key:
        print("请在 lib/config/supabase_config.dart 与 supabase_admin_config.dart 配置 Supabase")
        sys.exit(1)

    ffmpeg = None
    compress_videos = args.with_videos and not args.no_compress
    compress_images = not args.no_compress_images
    if compress_videos:
        try:
            ffmpeg = require_ffmpeg()
        except RuntimeError as error:
            print(error)
            sys.exit(1)

    items = iter_uploads(
        base=base,
        include_videos=args.with_videos,
        only=only,
    )
    print(f"准备上传 {len(items)} 个文件…\n")

    ok = 0
    for local, storage_path in items:
        upload_path = local
        temp_path: Optional[Path] = None
        try:
            if compress_videos and ffmpeg and local.suffix.lower() == ".mp4":
                max_height, crf = compress_params_for_storage_path(storage_path)
                upload_path, _, is_temp = prepare_upload_mp4(
                    ffmpeg=ffmpeg,
                    source=local,
                    compress=True,
                    max_height=max_height,
                    crf=crf,
                )
                if is_temp:
                    temp_path = upload_path
            elif compress_images and local.suffix.lower() in {".jpg", ".jpeg"}:
                upload_path, is_temp = prepare_upload_jpeg(local)
                if is_temp:
                    temp_path = upload_path
            upload_storage_file(
                supabase_url=url,
                api_key=key,
                storage_path=storage_path,
                local_path=upload_path,
            )
            ok += 1
            print(f"  [{ok}/{len(items)}] {storage_path}")
        finally:
            if temp_path and temp_path.exists():
                temp_path.unlink(missing_ok=True)

    print(f"\n完成 {ok} 个文件。")


if __name__ == "__main__":
    main()
