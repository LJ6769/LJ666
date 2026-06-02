#!/usr/bin/env python3
"""Delete all objects under media/hilmi/ in Supabase Storage."""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from media_upload_common import load_env

_env = load_env()
PROJECT_URL = _env.get("SUPABASE_URL", "").rstrip("/")
BUCKET = "media"
PREFIX = "hilmi"
SERVICE_KEY = _env.get("SUPABASE_SERVICE_ROLE_KEY", "")


def api(method: str, path: str, body: dict | None = None) -> dict:
    url = f"{PROJECT_URL}{path}"
    data = None
    headers = {"Authorization": f"Bearer {SERVICE_KEY}"}
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    with urllib.request.urlopen(req, timeout=120) as resp:
        raw = resp.read().decode("utf-8")
        return json.loads(raw) if raw else {}


def list_objects(prefix: str) -> list[str]:
    paths: list[str] = []
    offset = 0
    limit = 1000
    while True:
        batch = api(
            "POST",
            f"/storage/v1/object/list/{BUCKET}",
            {"prefix": prefix, "limit": limit, "offset": offset},
        )
        if not batch:
            break
        for item in batch:
            name = item.get("name") or ""
            if not name:
                continue
            full = f"{prefix}/{name}" if prefix else name
            if item.get("id") is None and not name.endswith(
                (".jpg", ".mp4", ".mp3", ".png", ".jpeg", ".webp")
            ):
                paths.extend(list_objects(full))
            else:
                paths.append(full)
        if len(batch) < limit:
            break
        offset += limit
    return paths


def delete_paths(paths: list[str]) -> None:
    for i in range(0, len(paths), 100):
        chunk = paths[i : i + 100]
        encoded = [urllib.parse.quote(p, safe="/") for p in chunk]
        api("DELETE", f"/storage/v1/object/{BUCKET}", {"prefixes": encoded})


def main() -> int:
    if not SERVICE_KEY:
        print("Set SUPABASE_SERVICE_ROLE_KEY", file=sys.stderr)
        return 1
    print(f"Listing {BUCKET}/{PREFIX}/ ...")
    paths = list_objects(PREFIX)
    if not paths:
        print("No objects found.")
        return 0
    print(f"Deleting {len(paths)} objects...")
    delete_paths(paths)
    print("Storage cleanup done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
