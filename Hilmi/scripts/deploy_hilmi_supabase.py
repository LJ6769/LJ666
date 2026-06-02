#!/usr/bin/env python3
"""
在 Hilmi 独立 Supabase 项目执行 hilmi_full_bootstrap.sql 并上传素材。

配置见 lib/config/supabase_config.dart 与 supabase_admin_config.dart；
数据库密码也可 export SUPABASE_DB_PASSWORD。
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_env() -> None:
    sys.path.insert(0, str(ROOT / "scripts"))
    from media_upload_common import load_env as load_lib_env

    for key, value in load_lib_env().items():
        os.environ.setdefault(key, value)


def run_sql_file(password: str, sql_path: Path) -> None:
    url = os.environ.get("SUPABASE_URL", "").rstrip("/")
    if not url or "supabase.co" not in url:
        raise SystemExit("Set SUPABASE_URL in lib/config/supabase_config.dart")
    ref = url.replace("https://", "").split(".")[0]
    pooler = os.environ.get(
        "SUPABASE_POOLER_HOST", "aws-1-us-west-2.pooler.supabase.com:6543"
    )
    conn = f"postgresql://postgres.{ref}:{password}@{pooler}/postgres"
    sql = sql_path.read_text(encoding="utf-8")
    try:
        import psycopg2  # type: ignore
    except ImportError:
        subprocess.check_call(
            [sys.executable, "-m", "pip", "install", "psycopg2-binary", "-q"]
        )
        import psycopg2  # type: ignore

    print(f"Connecting to {host} ...")
    with psycopg2.connect(conn) as conn:
        conn.autocommit = True
        with conn.cursor() as cur:
            cur.execute(sql)
    print("SQL applied.")


def main() -> int:
    load_env()
    password = os.environ.get("SUPABASE_DB_PASSWORD", "")
    bootstrap = ROOT / "supabase" / "hilmi_full_bootstrap.sql"

    gen = ROOT / "scripts" / "generate_hilmi_bootstrap.py"
    subprocess.check_call([sys.executable, str(gen)])

    if not password:
        print(
            "缺少 SUPABASE_DB_PASSWORD，无法自动执行 SQL。\n"
            "请在 Hilmi 项目 Dashboard → SQL Editor 中执行：\n"
            f"  {bootstrap}\n"
            "或在 lib/config/supabase_admin_config.dart 配置 dbPassword / serviceRoleKey 后重试。"
        )
        return 1

    run_sql_file(password, bootstrap)

    upload = ROOT / "scripts" / "upload_hilmi_media.py"
    if os.environ.get("SUPABASE_SERVICE_ROLE_KEY"):
        subprocess.check_call([sys.executable, str(upload)])
    else:
        print("跳过 Storage 上传：未设置 SUPABASE_SERVICE_ROLE_KEY")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
