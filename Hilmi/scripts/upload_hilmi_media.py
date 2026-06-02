#!/usr/bin/env python3
"""已弃用：请使用 scripts/upload_media.py（路径与六表种子一致，且支持 JPG/MP4 压缩）。"""
"""Upload Hilmi素材 to Supabase Storage bucket `media`."""

from __future__ import annotations

import mimetypes
import os
import sys
from pathlib import Path

import urllib.error
import urllib.parse
import urllib.request

def load_env_file() -> None:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from media_upload_common import load_env as load_lib_env

    for key, value in load_lib_env().items():
        os.environ.setdefault(key, value)


load_env_file()
ASSETS = Path(os.environ.get("HILMI_ASSETS", "/Users/mac/Downloads/Hilmi切图/Hilmi素材"))
PROJECT_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
BUCKET = "media"
SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")


def sanitize_storage_path(storage_path: str) -> str:
    """Storage keys must be ASCII; keep DB paths in sync via _fuben suffix."""
    return storage_path.replace("副本", "fuben")


def upload(local: Path, storage_path: str) -> None:
    storage_path = sanitize_storage_path(storage_path)
    mime, _ = mimetypes.guess_type(local.name)
    mime = mime or "application/octet-stream"
    encoded = urllib.parse.quote(storage_path, safe="/")
    url = f"{PROJECT_URL}/storage/v1/object/{BUCKET}/{encoded}"
    data = local.read_bytes()
    req = urllib.request.Request(
        url,
        data=data,
        method="POST",
        headers={
            "Authorization": f"Bearer {SERVICE_KEY}",
            "Content-Type": mime,
            "x-upsert": "true",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            if resp.status not in (200, 201):
                raise RuntimeError(f"HTTP {resp.status} for {storage_path}")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"{storage_path}: HTTP {e.code} {body}") from e


def iter_uploads():
    users = ASSETS / "用户信息"
    for gender, folder in (("female", "女"), ("male", "男")):
        d = users / folder
        if not d.is_dir():
            continue
        for f in sorted(d.glob("*")):
            if f.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}:
                yield f, f"hilmi/users/{gender}/{f.name}"

    moments = ASSETS / "朋友圈"
    for n in range(1, 16):
        f = moments / f"{n}.mp4"
        if f.is_file():
            yield f, f"hilmi/moments/{n}.mp4"
    for n in range(16, 21):
        sub = moments / str(n)
        if not sub.is_dir():
            continue
        for f in sorted(sub.glob("*.jpg")):
            yield f, f"hilmi/moments/{n}/{f.name}"

    live = ASSETS / "直播间"
    for category in ("Tutorials", "Other"):
        cat_dir = live / category
        if not cat_dir.is_dir():
            continue
        for room_dir in sorted(cat_dir.iterdir()):
            if not room_dir.is_dir():
                continue
            idx = room_dir.name
            for f in sorted(room_dir.iterdir()):
                if f.suffix.lower() in {".jpg", ".jpeg", ".mp4"}:
                    yield f, f"hilmi/live-streams/{category}/{idx}/{f.name}"

    chat = ASSETS / "聊天室"
    covers = chat / "聊天室封面+信息"
    if covers.is_dir():
        for f in sorted(covers.glob("*.jpg")):
            stem = f.stem
            if stem.isdigit():
                yield f, f"hilmi/tipsy-bar/{stem}.jpg"

    audio = chat / "用户音频"
    if audio.is_dir():
        for f in sorted(audio.glob("*.mp3")):
            stem = f.stem
            if stem.isdigit():
                yield f, f"hilmi/chat-audio/{stem}.mp3"


def main() -> int:
    if not SERVICE_KEY:
        print("Set SUPABASE_SERVICE_ROLE_KEY", file=sys.stderr)
        return 1
    if not ASSETS.is_dir():
        print(f"Assets not found: {ASSETS}", file=sys.stderr)
        return 1

    items = list(iter_uploads())
    print(f"Uploading {len(items)} files to {BUCKET}...")
    ok = 0
    for local, remote in items:
        upload(local, remote)
        ok += 1
        print(f"  [{ok}/{len(items)}] {remote}")
    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
