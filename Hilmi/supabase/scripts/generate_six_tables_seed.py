#!/usr/bin/env python3
"""从 Hilmi素材 生成六表种子 SQL。"""

from __future__ import annotations

import json
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

import generate_seed as gs  # noqa: E402

ASSETS_BASE = Path("/Users/mac/Downloads/Hilmi切图/Hilmi素材")
OUT = SCRIPT_DIR.parent / "migrations" / "20260603000002_six_tables_seed.sql"


def sql_json(obj: object) -> str:
    return f"'{gs.esc(json.dumps(obj, ensure_ascii=False))}'::jsonb"


def main() -> None:
    gs.reset_dollar_tags()
    gs.BASE = ASSETS_BASE
    users = gs.parse_users()
    moments = gs.parse_moments()
    live_copy = gs.parse_live_copy()
    live_assets = gs.scan_live_assets()
    live_copy.sort(key=lambda s: (s["game_slug"], s["room_index"]))

    cat_by_slug = {slug: (name, order, show) for slug, name, order, show in gs.CATEGORIES}
    females = [u for u in users if u["gender"] == "female"]
    star_sort = {females[i]["display_name"]: i + 1 for i in range(min(10, len(females)))}

    lines: list[str] = [
        f"-- 由 generate_six_tables_seed.py 生成",
        f"-- 素材: {ASSETS_BASE}",
        "",
        'truncate table public."Message" cascade;',
        'truncate table public."LiveChat" cascade;',
        'truncate table public."PostChat" cascade;',
        'truncate table public."Post" cascade;',
        'truncate table public."Live" cascade;',
        'truncate table public."User" cascade;',
        "",
        "-- User",
        'insert into public."User" (display_name, gender, bio, avatar_path, is_popular_star, popular_star_sort, coins) values',
    ]

    user_rows: list[str] = []
    for user in users:
        sort = star_sort.get(user["display_name"])
        is_star = sort is not None
        user_rows.append(
            "  ("
            f"{gs.sql_str(user['display_name'])}, "
            f"'{user['gender']}'::public.gender_type, "
            f"{gs.sql_dollar(user['bio'])}, "
            f"{gs.sql_str(user.get('avatar_path'))}, "
            f"{str(is_star).lower()}, "
            f"{str(sort) if sort else 'null'}, "
            "0)"
        )
    lines.append(",\n".join(user_rows) + ";\n")

    lines.append(
        "create temp table _user_rn on commit drop as\n"
        'select id, row_number() over (order by created_at, id) as rn from public."User";\n\n'
    )

    lines.append("-- Live")
    viewer_counts = [12, 19, 23, 28, 35, 8, 42, 15, 51, 63, 33, 77]
    streamer_idx = 0
    for copy in live_copy:
        slug = copy["game_slug"]
        cat_name, cat_order, show_home = cat_by_slug.get(slug, (slug, 99, False))
        asset = live_assets.get((slug, copy["room_index"]), {})
        streamer_idx += 1
        user_rn = (streamer_idx - 1) % len(users) + 1 if users else 1
        viewer = viewer_counts[streamer_idx % len(viewer_counts)]
        lines.append(
            'insert into public."Live" (\n'
            "  category_slug, category_name, category_sort_order, show_on_home,\n"
            "  streamer_id, room_index, description, tags,\n"
            "  cover_path, video_path, viewer_count, is_live, sort_order\n"
            ") values (\n"
            f"  {gs.sql_str(slug)}, {gs.sql_str(cat_name)}, {cat_order}, {str(show_home).lower()},\n"
            f"  (select id from _user_rn where rn = {user_rn}),\n"
            f"  {copy['room_index']}, {gs.sql_dollar(copy['description'])}, {gs.sql_array(copy['tags'])},\n"
            f"  {gs.sql_str(asset.get('cover_path'))}, {gs.sql_str(asset.get('video_path'))},\n"
            f"  {viewer}, true, {copy['room_index']}\n"
            ");\n"
        )

    lines.append("\n-- Post")
    for seq, post in enumerate(moments, start=1):
        if seq in gs.EXCLUDED_MOMENT_POST_INDICES:
            continue
        user_rn = (seq - 1) % len(users) + 1 if users else 1
        media_items = []
        for order, (media_type, path, poster_path) in enumerate(gs.moment_media_paths(seq)):
            item: dict = {"type": media_type, "storage_path": path, "sort_order": order}
            if poster_path:
                item["poster_path"] = poster_path
            media_items.append(item)
        lines.append(
            'insert into public."Post" (author_id, post_index, content, media) values (\n'
            f"  (select id from _user_rn where rn = {user_rn}),\n"
            f"  {seq}, {gs.sql_dollar(post['content'])}, {sql_json(media_items)}\n"
            ");\n"
        )

    lines.append(
        "\n-- Popular Star 展示名\n"
        "with stars as (\n"
        '  select id, row_number() over (order by popular_star_sort) as rn from public."User"\n'
        "  where is_popular_star = true\n"
        ")\n"
        'update public."User" u set display_name = v.name\n'
        "from stars s\n"
        "join (values\n"
        "  (1, 'Emerson'), (2, 'Gideon'), (3, 'Casper'), (4, 'Elias'),\n"
        "  (5, 'Fiona'), (6, 'Hazel'), (7, 'Iris'), (8, 'Juno'), (9, 'Kira'), (10, 'Luna')\n"
        ") as v(rn, name) on v.rn = s.rn\n"
        "where u.id = s.id;\n"
    )

    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT}")
    print(f"  users: {len(users)}, live: {len(live_copy)}, posts: {len(moments)}")


if __name__ == "__main__":
    main()
