#!/usr/bin/env python3
"""根据 直播间文案.docx 生成修正 live_streams.description 的 SQL。"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from generate_hilmi_bootstrap import (  # noqa: E402
    ASSETS,
    esc,
    read_docx,
    split_live_captions,
)

OUT = ROOT / "supabase" / "fix_live_stream_descriptions.sql"

LIVE_META = [
    ("bartending-tutorials", 1, "Crystal"),
    ("bartending-tutorials", 2, "Kaelin"),
    ("bartending-tutorials", 3, "Seraphina"),
    ("bartending-other", 1, "Orion"),
    ("bartending-other", 2, "Marlow"),
    ("bartending-other", 3, "Viggo"),
]


def main() -> None:
    docx = ASSETS / "直播间" / "直播间文案.docx"
    if not docx.exists():
        raise SystemExit(f"素材不存在: {docx}")

    caps = split_live_captions(read_docx(docx), 6)
    lines = [
        "-- 修正 live_streams.description：按直播间文案.docx 拆成 6 条",
        "-- 在 Hilmi Supabase SQL Editor 执行，或由 deploy 脚本应用",
        "",
    ]

    for (slug, room_index, _streamer), desc in zip(LIVE_META, caps):
        desc_e = esc(desc)
        lines.append(
            f"UPDATE public.live_streams AS ls\n"
            f"SET description = '{desc_e}', updated_at = now()\n"
            f"FROM public.game_categories AS gc\n"
            f"WHERE ls.category_id = gc.id\n"
            f"  AND gc.slug = '{slug}'\n"
            f"  AND ls.room_index = {room_index};"
        )
        lines.append("")

    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT} ({len(caps)} updates)")
    for i, d in enumerate(caps, 1):
        print(f"  [{i}] {d[:72]}...")


if __name__ == "__main__":
    main()
