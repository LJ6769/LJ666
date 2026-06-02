"""Supabase Storage 上传与 lib/config 配置读取（脚本共用）。"""

from __future__ import annotations

import mimetypes
import os
import re
import time
from pathlib import Path
from typing import Optional
from urllib.parse import quote

import urllib.error
import urllib.request

PROJECT_ROOT = Path(__file__).resolve().parents[1]
CONFIG_DIR = PROJECT_ROOT / "lib" / "config"
DEFAULT_ASSETS_BASE = Path("/Users/mac/Downloads/Hilmi切图/Hilmi素材")

# 已下架朋友圈（体积过大等），上传脚本跳过；留空表示种子里的帖子都应上传。
EXCLUDED_MOMENT_POST_INDICES: frozenset[int] = frozenset()


def is_excluded_moment_post(name: str) -> bool:
    return name.isdigit() and int(name) in EXCLUDED_MOMENT_POST_INDICES


def storage_safe_filename(filename: str) -> str:
    """Supabase Storage 对象名不支持中文等字符（如 副本）。"""
    name = filename.replace("副本", "copy")
    try:
        name.encode("ascii")
        return name
    except UnicodeEncodeError:
        stem = Path(filename).stem
        suffix = Path(filename).suffix.lower()
        safe_stem = "".join(
            c if ord(c) < 128 and (c.isalnum() or c in "._-") else "_"
            for c in stem.replace("副本", "copy")
        ).strip("_")
        return (safe_stem or "file") + suffix


def _dart_const(path: Path, name: str) -> str:
    if not path.is_file():
        return ""
    text = path.read_text(encoding="utf-8")
    match = re.search(
        rf"static const {re.escape(name)}\s*=\s*(?:\n\s*)?'([^']*)'",
        text,
    )
    return match.group(1) if match else ""


def load_env() -> dict[str, str]:
    client = CONFIG_DIR / "supabase_config.dart"
    admin = CONFIG_DIR / "supabase_admin_config.dart"
    env: dict[str, str] = {
        "SUPABASE_URL": _dart_const(client, "url"),
        "SUPABASE_PROJECT_REF": _dart_const(client, "projectRef"),
        "SUPABASE_ANON_KEY": _dart_const(client, "anonKey"),
        "SUPABASE_SERVICE_ROLE_KEY": _dart_const(admin, "serviceRoleKey"),
    }
    db_password = _dart_const(admin, "dbPassword")
    if db_password:
        env["SUPABASE_DB_PASSWORD"] = db_password
    pooler = _dart_const(admin, "poolerHost")
    if pooler:
        env["SUPABASE_POOLER_HOST"] = pooler
    for key in ("SUPABASE_DB_PASSWORD", "SUPABASE_POOLER_HOST"):
        if os.environ.get(key):
            env[key] = os.environ[key]
    return {k: v for k, v in env.items() if v}


# 客户端/CDN 缓存 7 天，减少重复下载带来的 egress
STORAGE_CACHE_CONTROL = "public, max-age=604800, immutable"


def upload_storage_file(
    *,
    supabase_url: str,
    api_key: str,
    storage_path: str,
    local_path: Path,
    content_type: Optional[str] = None,
    cache_control: str = STORAGE_CACHE_CONTROL,
    retries: int = 3,
) -> None:
    encoded = "/".join(quote(part, safe="") for part in storage_path.split("/"))
    url = f"{supabase_url.rstrip('/')}/storage/v1/object/media/{encoded}"
    mime, _ = mimetypes.guess_type(local_path.name)
    resolved_type = content_type or mime or "application/octet-stream"
    data = local_path.read_bytes()
    timeout = 600 if local_path.suffix.lower() == ".mp4" else 120

    for attempt in range(1, retries + 1):
        req = urllib.request.Request(
            url,
            data=data,
            method="POST",
            headers={
                "apikey": api_key,
                "Authorization": f"Bearer {api_key}",
                "Content-Type": resolved_type,
                "x-upsert": "true",
                "cache-control": cache_control,
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                if resp.status not in (200, 201):
                    raise RuntimeError(f"HTTP {resp.status}")
            return
        except urllib.error.HTTPError as error:
            body = error.read().decode("utf-8", errors="replace")
            if attempt >= retries:
                raise RuntimeError(f"{storage_path}: HTTP {error.code} {body}") from error
        except (urllib.error.URLError, TimeoutError) as error:
            if attempt >= retries:
                raise RuntimeError(f"{storage_path}: {error}") from error
        time.sleep(2)
