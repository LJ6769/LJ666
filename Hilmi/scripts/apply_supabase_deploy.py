#!/usr/bin/env python3
"""将 supabase/deploy_six_tables.sql 应用到远程 Postgres（需 SUPABASE_DB_PASSWORD）。"""

from __future__ import annotations

import os
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEPLOY_SQL = PROJECT_ROOT / "supabase" / "deploy_six_tables.sql"


def load_env() -> dict[str, str]:
    import sys

    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from media_upload_common import load_env as load_lib_env

    return load_lib_env()


def main() -> None:
    try:
        import psycopg2
    except ImportError:
        print("请先安装: pip3 install psycopg2-binary")
        sys.exit(1)

    env = load_env()
    ref = env.get("SUPABASE_PROJECT_REF", "wcuvzeyusbmfwsgrmgou")
    password = env.get("SUPABASE_DB_PASSWORD") or os.environ.get("SUPABASE_DB_PASSWORD")
    host = env.get("SUPABASE_POOLER_HOST", f"aws-0-us-west-1.pooler.supabase.com:6543")

    if not password:
        print("请在 lib/config/supabase_admin_config.dart 设置 dbPassword，或 export SUPABASE_DB_PASSWORD")
        sys.exit(1)

    if ":" in host:
        host_part, port = host.rsplit(":", 1)
    else:
        host_part, port = host, "6543"

    dsn = (
        f"host={host_part} port={port} dbname=postgres "
        f"user=postgres.{ref} password={password} sslmode=require"
    )

    if not DEPLOY_SQL.is_file():
        print(f"缺少 {DEPLOY_SQL}，请先运行: python3 supabase/scripts/build_deploy.py")
        sys.exit(1)

    sql = DEPLOY_SQL.read_text(encoding="utf-8")
    print(f"连接 {ref} … 执行 {DEPLOY_SQL.name} ({len(sql)} 字符)")
    conn = psycopg2.connect(dsn)
    conn.autocommit = True
    try:
        with conn.cursor() as cur:
            cur.execute(sql)
        print("完成。")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
