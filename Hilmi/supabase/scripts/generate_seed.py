#!/usr/bin/env python3
"""从 Hilmi素材 解析用户 / 朋友圈 / 直播文案与路径。"""

from __future__ import annotations

import re
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

BASE = Path("/Users/mac/Downloads/Hilmi切图/Hilmi素材")

EXCLUDED_MOMENT_POST_INDICES: frozenset[int] = frozenset()

FOLDER_MAP = {
    "Other": "other",
    "Tutorials": "tutorials",
}

CATEGORIES = [
    ("popular", "Popular", 0, True),
    ("tutorials", "Tutorials", 1, True),
    ("other", "Other", 2, True),
]


def storage_safe_filename(filename: str) -> str:
    return filename.replace("副本", "copy")


def read_docx(path: Path) -> str:
    with zipfile.ZipFile(path) as z:
        root = ET.fromstring(z.read("word/document.xml"))
    return "".join(
        t.text or ""
        for t in root.iter(
            "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}t"
        )
    )


def esc(value: str) -> str:
    # Supabase SQL Editor 可能把弯引号 ’ 转成 ASCII '，须先统一再加倍转义
    normalized = (
        value.replace("\u2019", "'")
        .replace("\u2018", "'")
        .replace("\u2032", "'")
    )
    return normalized.replace("'", "''")


def reset_dollar_tags() -> None:
    sql_dollar._counter = 0  # type: ignore[attr-defined]


def sql_dollar(value: str | None) -> str:
    """Dollar-quoted literal：文案含 it's / every 等时不会被 SQL Editor 截断。"""
    if value is None:
        return "null"
    counter = getattr(sql_dollar, "_counter", 0) + 1
    sql_dollar._counter = counter  # type: ignore[attr-defined]
    tag = f"txt{counter}"
    while f"${tag}$" in value:
        counter += 1
        sql_dollar._counter = counter  # type: ignore[attr-defined]
        tag = f"txt{counter}"
    return f"${tag}${value}${tag}$"


def sql_str(value: str | None) -> str:
    if value is None:
        return "null"
    return f"'{esc(value)}'"


def sql_array(items: list[str]) -> str:
    if not items:
        return "array[]::text[]"
    inner = ", ".join(sql_str(i) for i in items)
    return f"array[{inner}]"


def parse_users() -> list[dict]:
    text = read_docx(BASE / "用户信息/用户信息.docx")
    text = re.sub(r"^用户信息", "", text).strip()

    def parse_block(section: str, gender: str) -> list[dict]:
        users: list[dict] = []
        # docx 无空格：ElowenEnjoys a light drink...LioraA connoisseur...
        pattern = re.compile(
            r"([A-Z][a-z]{2,14})([A-Z].*?)(?=[A-Z][a-z]{2,14}[A-Z]|$)",
            re.S,
        )
        for match in pattern.finditer(section):
            name = match.group(1).strip()
            bio = match.group(2).strip()
            if name in ("Woman", "Man", "Male", "Female"):
                continue
            users.append({"display_name": name, "bio": bio, "gender": gender})
        return users

    if "Man" in text:
        woman_part, man_part = text.split("Man", 1)
        woman_text = woman_part.replace("Woman", "", 1)
        females = parse_block(woman_text, "female")
        males = parse_block(man_part, "male")
    elif "Male" in text:
        woman_part, man_part = text.split("Male", 1)
        woman_text = woman_part.replace("Female", "", 1).replace("Woman", "", 1)
        females = parse_block(woman_text, "female")
        males = parse_block(man_part, "male")
    else:
        females = parse_block(text.replace("Woman", "", 1), "female")
        males = []

    male_avatars = sorted((BASE / "用户信息/男").glob("*.jpg"))
    female_avatars = sorted((BASE / "用户信息/女").glob("*.jpg"))
    for user, path in zip(males, male_avatars):
        user["avatar_path"] = f"users/male/{storage_safe_filename(path.name)}"
    for user, path in zip(females, female_avatars):
        user["avatar_path"] = f"users/female/{storage_safe_filename(path.name)}"
    return males + females


def parse_moments() -> list[dict]:
    text = read_docx(BASE / "朋友圈/朋友圈文案.docx")
    text = re.sub(r"^朋友圈文案", "", text).strip()
    posts: list[dict] = []
    for item in re.split(r"(?=\d+\.)", text):
        item = item.strip()
        if not item:
            continue
        match = re.match(r"(\d+)\.\s*(.*)", item, re.S)
        if not match:
            continue
        posts.append({"content": match.group(2).strip()})
    return posts


def parse_live_copy() -> list[dict]:
    text = read_docx(BASE / "直播间/直播间文案.docx")
    text = re.sub(r"^直播间文案", "", text).strip()
    games = [
        ("Tutorials", "tutorials"),
        ("Other", "other"),
    ]
    streams: list[dict] = []
    for i, (key, slug) in enumerate(games):
        start = text.find(key)
        if start < 0:
            continue
        end = text.find(games[i + 1][0]) if i + 1 < len(games) else len(text)
        section = text[start:end]
        for ent in re.split(r"(?=\d+、)", section):
            ent = ent.strip()
            match = re.match(
                r"(\d+)、\s*(.*?)(?:Tags:\s*(.*))?$",
                ent,
                re.S,
            )
            if not match:
                continue
            tags = re.findall(r"#[\w]+", match.group(3) or "")
            streams.append(
                {
                    "game_slug": slug,
                    "room_index": int(match.group(1)),
                    "description": match.group(2).strip(),
                    "tags": tags,
                }
            )
    return streams


def scan_live_assets() -> dict[tuple[str, int], dict]:
    assets: dict[tuple[str, int], dict] = {}
    live_base = BASE / "直播间"
    for folder in live_base.iterdir():
        if not folder.is_dir() or folder.name.startswith("."):
            continue
        slug = FOLDER_MAP.get(folder.name, folder.name.lower().replace(" ", "-"))
        for room in folder.iterdir():
            if not room.is_dir() or not room.name.isdigit():
                continue
            idx = int(room.name)
            cover = video = None
            for file in room.iterdir():
                if not file.is_file() or file.name.startswith("."):
                    continue
                if file.suffix.lower() == ".jpg":
                    cover = "cover.jpg"
                elif file.suffix.lower() == ".mp4":
                    video = "video.mp4"
            assets[(slug, idx)] = {
                "cover_path": f"live-streams/{slug}/{idx}/cover.jpg" if cover else None,
                "video_path": f"live-streams/{slug}/{idx}/video.mp4" if video else None,
            }
    return assets


def moment_media_paths(post_index: int) -> list[tuple[str, str, str | None]]:
    if post_index in EXCLUDED_MOMENT_POST_INDICES:
        return []
    video = BASE / "朋友圈" / f"{post_index}.mp4"
    if video.exists():
        return [
            (
                "video",
                f"moments/{post_index}.mp4",
                f"moments/{post_index}/poster.jpg",
            )
        ]
    folder = BASE / "朋友圈" / str(post_index)
    if folder.is_dir():
        return [
            ("image", f"moments/{post_index}/{path.name}", None)
            for path in sorted(folder.glob("*.jpg"))
        ]
    return []
