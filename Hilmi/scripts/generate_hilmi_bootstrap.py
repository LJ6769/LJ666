#!/usr/bin/env python3
"""从 Hilmi素材 生成独立 Supabase 项目的建表 + 种子 SQL。"""

from __future__ import annotations

import re
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = Path(
    "/Users/mac/Downloads/Hilmi切图/Hilmi素材"
)
OUT = ROOT / "supabase" / "hilmi_full_bootstrap.sql"
SCHEMA = ROOT / "supabase" / "migrations" / "20260525100000_hilmi_init.sql"

FEMALE_NAMES = [
    "Elowen", "Liora", "Marnie", "Ione", "Seraphina", "Briar", "Paloma", "Soraya",
    "Wren", "Odette", "Kaelin", "Zora", "Lilibeth", "Nova", "Thalassa",
]
MALE_NAMES = [
    "Caspian", "Orion", "Soren", "Atticus", "Kael", "Thorne", "Evander", "Jasper",
    "Marlow", "Rohan", "Silas", "Torin", "Uriah", "Viggo", "Zane",
]


def read_docx(path: Path) -> str:
    with zipfile.ZipFile(path) as z:
        xml = z.read("word/document.xml")
    root = ET.fromstring(xml)
    texts: list[str] = []
    for t in root.iter(
        "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}t"
    ):
        if t.text:
            texts.append(t.text)
        if t.tail:
            texts.append(t.tail)
    return "".join(texts)


def esc(s: str) -> str:
    return s.replace("'", "''")


def storage_name(filename: str) -> str:
    return filename.replace("副本", "fuben")


def parse_user_bios(text: str) -> dict[str, str]:
    bios: dict[str, str] = {}
    for section, names in (("Woman", FEMALE_NAMES), ("Man", MALE_NAMES)):
        idx = text.find(section)
        if idx < 0:
            continue
        chunk = text[idx + len(section) :]
        other = "Man" if section == "Woman" else ""
        if other:
            j = chunk.find(other)
            if j >= 0:
                chunk = chunk[:j]
        pos = 0
        for name in names:
            j = chunk.find(name, pos)
            if j < 0:
                continue
            start = j + len(name)
            next_pos = len(chunk)
            for other_name in names:
                if other_name == name:
                    continue
                k = chunk.find(other_name, start)
                if k >= 0:
                    next_pos = min(next_pos, k)
            bios[name] = chunk[start:next_pos].strip()
            pos = start
    return bios


def split_captions(text: str, count: int) -> list[str]:
    """朋友圈等按「1. 」编号分段。"""
    parts = re.split(r"(?=\d+\.)", text)
    items = []
    for p in parts:
        p = re.sub(r"^\d+\.\s*", "", p).strip()
        if p:
            items.append(p)
    if len(items) >= count:
        return items[:count]
    return items + [""] * (count - len(items))


# 直播间文案.docx：Tutorials1/2、…、Bartending3、…、Other1、Session2、Cocktails3、
_LIVE_SECTION_MARKERS = (
    "Tutorials1、",
    "Tutorials2、",
    "Bartending3、",
    "Other1、",
    "Session2、",
    "Cocktails3、",
)


def split_live_captions(text: str, count: int = 6) -> list[str]:
    """直播间文案：去掉文档标题前缀，按 6 段小节拆分正文。"""
    body = re.sub(r"^直播间文案\s*", "", text.strip())
    positions: list[tuple[int, int]] = []
    for marker in _LIVE_SECTION_MARKERS:
        idx = body.find(marker)
        if idx < 0:
            raise ValueError(f"直播间文案缺少分段标记: {marker!r}")
        positions.append((idx, idx + len(marker)))

    positions.sort(key=lambda x: x[0])
    items: list[str] = []
    for i, (_, start) in enumerate(positions):
        end = positions[i + 1][0] if i + 1 < len(positions) else len(body)
        items.append(body[start:end].strip())

    if len(items) != count:
        raise ValueError(f"直播间文案应拆成 {count} 段，实际 {len(items)} 段")
    return items


def avatar_path(gender: str, filename: str) -> str:
    folder = "female" if gender == "female" else "male"
    return f"hilmi/users/{folder}/{storage_name(filename)}"


def main() -> None:
    bios = parse_user_bios(read_docx(ASSETS / "用户信息" / "用户信息.docx"))
    moment_caps = split_captions(
        read_docx(ASSETS / "朋友圈" / "朋友圈文案.docx"), 20
    )
    live_caps = split_live_captions(
        read_docx(ASSETS / "直播间" / "直播间文案.docx"), 6
    )
    # Tipsy Bar 文案（与素材 1–8 对应）
    tipsy_rooms = [
        (
            1,
            "Neon Tavern: A Night of Gentle Tipsiness",
            "Our online tavern is now open! Come enjoy a signature custom cocktail—the perfect way to unwind and feel pleasantly mellow.",
            False,
        ),
        (
            2,
            "The Signature Cocktail Inspiration Exchange",
            "Share your recipes for visually stunning cocktails and chat about how to recreate authentic bar-quality flavors right at home.",
            True,
        ),
        (
            3,
            "Retro Bar Mixology Session",
            "Experience the allure of a vintage bar counter and unlock the secrets to crafting classic cocktails with a gentle, refined touch.",
            False,
        ),
        (
            4,
            "The Healing Mixology Workshop",
            "Let a beautifully layered, signature cocktail soothe away the fatigue and frustrations of a busy day.",
            True,
        ),
        (
            5,
            "Professional Cocktail Shaking Masterclass",
            "Master standard shaking techniques and unlock the true essence of classic cocktails—such as the Martini—with expert precision.",
            False,
        ),
        (
            6,
            "The Gentleman Bartender's Salon",
            "Discuss professional bartending etiquette and share recipes for elegant, signature cocktails—including the timeless Martini.",
            True,
        ),
        (
            7,
            "Exquisite Cocktail Tasting & Appreciation",
            "Savor the nuanced flavors of sophisticated cocktails while exchanging tips on mixing techniques and perfect pairings.",
            False,
        ),
        (
            8,
            'The "Good Vibes" Cocktail Share-a-thon',
            "Double your happiness with a cocktail in hand! Share your favorite recipes for visually stunning drinks that capture the perfect summer vibe.",
            True,
        ),
    ]

    lines: list[str] = [
        "-- Hilmi 独立项目：建表 + 种子（自动生成）",
        "",
        SCHEMA.read_text(encoding="utf-8"),
        "",
        "-- ========== 种子数据 ==========",
        "",
    ]

    # profiles
    sort_star = 1
    for gender, names, folder in (
        ("female", FEMALE_NAMES, "女"),
        ("male", MALE_NAMES, "男"),
    ):
        d = ASSETS / "用户信息" / folder
        files = sorted(
            f.name for f in d.iterdir() if f.suffix.lower() in {".jpg", ".jpeg", ".png"}
        )
        for i, name in enumerate(names):
            bio = esc(bios.get(name, ""))
            handle = "@" + name.lower()
            fname = files[i] if i < len(files) else files[0]
            path = avatar_path(gender, fname)
            is_star = gender == "female" and sort_star <= 8
            star_sort = sort_star if is_star else "NULL"
            if is_star:
                sort_star += 1
            coins = 200
            lines.append(
                "INSERT INTO public.profiles "
                "(display_name, handle, gender, bio, avatar_path, is_popular_star, "
                f"popular_star_sort, coins) VALUES ('{name}', '{handle}', '{gender}', "
                f"'{bio}', '{path}', {str(is_star).lower()}, {star_sort}, {coins});"
            )

    lines.append(
        "UPDATE public.profiles SET display_name = 'Crystal', handle = '@87654efr' "
        "WHERE display_name = 'Elowen';"
    )
    lines.append("")

    # moment posts
    for n in range(1, 21):
        cap = esc(moment_caps[n - 1] if n - 1 < len(moment_caps) else "")
        likes = 3 * n if n <= 15 else max(1, 48 - (n - 16) * 3)
        comments = min(8, n if n <= 10 else max(0, n - 7))
        offset = (n - 1) if n <= 15 else (n - 16)
        lines.append(
            f"INSERT INTO public.moment_posts (post_index, content, author_id, "
            f"like_count, comment_count)\n"
            f"SELECT {n}, '{cap}', p.id, {likes}, {comments}\n"
            f"FROM public.profiles p WHERE p.gender = 'female'\n"
            f"ORDER BY p.popular_star_sort NULLS LAST, p.display_name "
            f"LIMIT 1 OFFSET {offset}\n"
            f"ON CONFLICT (post_index) DO UPDATE SET content = EXCLUDED.content, "
            f"author_id = EXCLUDED.author_id;"
        )
    lines.append("")

    # moment media
    for n in range(1, 16):
        lines.append(
            "INSERT INTO public.moment_media (post_id, media_type, storage_path, sort_order) "
            f"SELECT mp.id, 'video', 'hilmi/moments/{n}.mp4', 0 "
            f"FROM public.moment_posts mp WHERE mp.post_index = {n};"
        )
    for n in range(16, 21):
        sub = ASSETS / "朋友圈" / str(n)
        if sub.is_dir():
            for i, f in enumerate(sorted(sub.glob("*.jpg"))):
                sp = f"hilmi/moments/{n}/{storage_name(f.name)}"
                lines.append(
                    "INSERT INTO public.moment_media (post_id, media_type, storage_path, sort_order) "
                    f"SELECT mp.id, 'image', '{sp}', {i} "
                    f"FROM public.moment_posts mp WHERE mp.post_index = {n};"
                )
    lines.append("")

    # live streams
    live_meta = [
        ("bartending-tutorials", 1, "Crystal", live_caps[0] if live_caps else ""),
        ("bartending-tutorials", 2, "Kaelin", live_caps[1] if len(live_caps) > 1 else ""),
        ("bartending-tutorials", 3, "Seraphina", live_caps[2] if len(live_caps) > 2 else ""),
        ("bartending-other", 1, "Orion", live_caps[3] if len(live_caps) > 3 else ""),
        ("bartending-other", 2, "Marlow", live_caps[4] if len(live_caps) > 4 else ""),
        ("bartending-other", 3, "Viggo", live_caps[5] if len(live_caps) > 5 else ""),
    ]
    viewers = [87, 124, 161, 109, 138, 167]
    tag_sets = [
        ["ProfessionalBartending", "WallOfSpirits", "CreativeCocktails"],
        ["HomeBartending", "BeginnerFriendly", "HomeCocktails"],
        ["BarBartending", "ClassicCocktails", "ProfessionalTechniques"],
        ["CraftBeer", "BeerTasting", "RedAle"],
        ["LateNightDrinks", "HomeTipsy", "RelaxedBartending"],
        ["JapaneseBartending", "Whisky", "PremiumCocktails"],
    ]
    for i, (slug, room, streamer, desc) in enumerate(live_meta):
        cat = "Tutorials" if "tutorials" in slug else "Other"
        desc_e = esc(desc)
        tags = "ARRAY[" + ",".join(f"'{t}'" for t in tag_sets[i]) + "]"
        lines.append(
            "INSERT INTO public.live_streams "
            "(category_id, streamer_id, room_index, description, tags, cover_path, "
            "video_path, streamer_avatar_path, viewer_count, is_live, sort_order)\n"
            f"SELECT gc.id, p.id, {room}, '{desc_e}', {tags},\n"
            f"  'hilmi/live-streams/{cat}/{room}/{room}.jpg',\n"
            f"  'hilmi/live-streams/{cat}/{room}/{room}.mp4',\n"
            f"  p.avatar_path, {viewers[i]}, true, {room}\n"
            f"FROM public.game_categories gc, public.profiles p\n"
            f"WHERE gc.slug = '{slug}' AND p.display_name = '{streamer}';"
        )
    lines.append("")

    # tipsy bar rooms
    for n, title, intro, right in tipsy_rooms:
        title_e = esc(title)
        intro_e = esc(intro)
        lines.append(
            "INSERT INTO public.tipsy_bar_rooms "
            "(room_index, title, intro, cover_path, audio_path, image_on_right, sort_order) "
            f"VALUES ({n}, '{title_e}', '{intro_e}', 'hilmi/tipsy-bar/{n}.jpg', "
            f"'hilmi/chat-audio/{n}.mp3', {str(right).lower()}, {n});"
        )
    lines.append("")

    # participants: 8 rooms x 4
    for room_idx in range(1, 9):
        for slot in range(4):
            offset = ((room_idx - 1) * 4 + slot) % 30
            lines.append(
                "INSERT INTO public.tipsy_bar_room_participants (room_id, profile_id, sort_order)\n"
                f"SELECT r.id, p.id, {slot}\n"
                f"FROM public.tipsy_bar_rooms r,\n"
                "LATERAL (\n"
                f"  SELECT id FROM public.profiles ORDER BY display_name LIMIT 1 OFFSET {offset}\n"
                ") p\n"
                f"WHERE r.room_index = {room_idx};"
            )

    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUT} ({len(lines)} statements)")


if __name__ == "__main__":
    main()
