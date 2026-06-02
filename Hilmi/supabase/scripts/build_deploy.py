#!/usr/bin/env python3
"""合并 schema + seed + 补丁为 deploy_six_tables.sql"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PARTS = [
    ROOT / "migrations" / "20260603000001_six_tables_schema.sql",
    ROOT / "migrations" / "20260603000002_six_tables_seed.sql",
    ROOT / "migrations" / "20260626110000_user_table_public_read.sql",
    ROOT / "migrations" / "20260626120000_auth_user_profile_trigger.sql",
]
OUT = ROOT / "deploy_six_tables.sql"
OUT_SCHEMA = ROOT / "deploy_schema_only.sql"
OUT_SEED = ROOT / "deploy_seed_only.sql"


def main() -> None:
    chunks = []
    for path in PARTS:
        if not path.is_file():
            raise SystemExit(f"缺少: {path}")
        chunks.append(f"-- >>> {path.name}\n{path.read_text(encoding='utf-8').strip()}\n")
    OUT.write_text("\n".join(chunks), encoding="utf-8")

    schema_parts = PARTS[:1] + PARTS[2:]
    schema_chunks = []
    for path in schema_parts:
        schema_chunks.append(
            f"-- >>> {path.name}\n{path.read_text(encoding='utf-8').strip()}\n"
        )
    OUT_SCHEMA.write_text("\n".join(schema_chunks), encoding="utf-8")

    seed_path = PARTS[1]
    OUT_SEED.write_text(
        f"-- >>> {seed_path.name}\n{seed_path.read_text(encoding='utf-8').strip()}\n",
        encoding="utf-8",
    )

    print(f"Wrote {OUT} ({OUT.stat().st_size // 1024} KB)")
    print(f"Wrote {OUT_SCHEMA} ({OUT_SCHEMA.stat().st_size // 1024} KB)")
    print(f"Wrote {OUT_SEED} ({OUT_SEED.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
