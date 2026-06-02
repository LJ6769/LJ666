#!/usr/bin/env python3
"""从 Hilmi素材/聊天室 生成 ChatRoom 种子 SQL。"""

from __future__ import annotations

import re
import sys
import zipfile
from pathlib import Path

ASSETS = Path("/Users/mac/Downloads/Hilmi切图/Hilmi素材/聊天室")
COVERS = ASSETS / "聊天室封面+信息"
DOCX = COVERS / "聊天室文案.docx"
OUT = Path(__file__).resolve().parent.parent / "migrations" / "20260603000003_chat_room.sql"


def sql_str(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def parse_docx(path: Path) -> list[tuple[str, str]]:
    with zipfile.ZipFile(path) as zf:
        xml = zf.read("word/document.xml").decode("utf-8")
    text = re.sub(r"</w:p>", "\n", xml)
    text = re.sub(r"<[^>]+>", "", text)
    text = (
        text.replace("&amp;", "&")
        .replace("&quot;", '"')
        .replace("&apos;", "'")
    )
    lines = [
        ln.strip()
        for ln in text.split("\n")
        if ln.strip() and ln.strip() not in ("聊天室文案", "Intro")
    ]
    rooms: list[tuple[str, str]] = []
    i = 0
    while i < len(lines):
        if re.fullmatch(r"\d+\.", lines[i]):
            i += 1
            continue
        if i + 1 < len(lines) and len(lines[i + 1]) > 35:
            title = lines[i]
            desc = lines[i + 1]
            if desc.lower().startswith("intro"):
                desc = re.sub(r"^intro:?", "", desc, flags=re.I).strip()
            if desc.startswith(":"):
                desc = desc[1:].strip()
            rooms.append((title, desc))
            i += 2
        else:
            i += 1
    return rooms


def main() -> None:
    if not COVERS.is_dir():
        print(f"素材目录不存在: {COVERS}", file=sys.stderr)
        sys.exit(1)

    covers = sorted(COVERS.glob("*.jpg"), key=lambda p: int(p.stem))
    copy = parse_docx(DOCX) if DOCX.is_file() else []

    if len(covers) != len(copy):
        print(
            f"警告: 封面 {len(covers)} 张, 文案 {len(copy)} 条 — 按较少数量对齐",
            file=sys.stderr,
        )

    n = min(len(covers), len(copy)) if copy else len(covers)
    rows: list[str] = []
    for idx in range(n):
        room_index = int(covers[idx].stem)
        title, desc = copy[idx] if copy else (f"Chat Room {room_index}", "")
        image_on_right = room_index % 2 == 0
        show_on_home = room_index <= 3
        rows.append(
            "  (\n"
            f"    {room_index},\n"
            f"    {sql_str(title)},\n"
            f"    {sql_str(desc)},\n"
            f"    {sql_str(f'chat-rooms/{room_index}.jpg')},\n"
            f"    {sql_str(f'chat-audio/{room_index}.mp3')},\n"
            f"    {'true' if image_on_right else 'false'},\n"
            f"    {'true' if show_on_home else 'false'},\n"
            f"    {room_index}\n"
            "  )"
        )

    values_sql = ",\n".join(rows)
    assets_note = str(ASSETS)
    body = """-- Tipsy Bar 语音聊天室：ChatRoom + ChatRoomMember
-- 由 generate_chat_room_seed.py 生成（素材: __ASSETS__）

create table if not exists public."ChatRoom" (
  id uuid primary key default gen_random_uuid(),
  room_index integer not null unique,
  title text not null,
  description text not null,
  cover_path text not null,
  host_audio_path text,
  image_on_right boolean not null default false,
  show_on_home boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists chat_room_home_idx
  on public."ChatRoom" (show_on_home, sort_order);

create table if not exists public."ChatRoomMember" (
  chat_room_id uuid not null references public."ChatRoom" (id) on delete cascade,
  user_id uuid not null references public."User" (id) on delete cascade,
  sort_order integer not null default 0,
  primary key (chat_room_id, user_id)
);

create index if not exists chat_room_member_room_idx
  on public."ChatRoomMember" (chat_room_id, sort_order);

alter table public."ChatRoom" enable row level security;
alter table public."ChatRoomMember" enable row level security;

drop policy if exists "chat_room_select" on public."ChatRoom";
create policy "chat_room_select" on public."ChatRoom" for select using (true);

drop policy if exists "chat_room_member_select" on public."ChatRoomMember";
create policy "chat_room_member_select" on public."ChatRoomMember" for select using (true);

insert into public."ChatRoom" (
  room_index, title, description, cover_path, host_audio_path, image_on_right, show_on_home, sort_order
) values
__VALUES__
on conflict (room_index) do update set
  title = excluded.title,
  description = excluded.description,
  cover_path = excluded.cover_path,
  host_audio_path = excluded.host_audio_path,
  image_on_right = excluded.image_on_right,
  show_on_home = excluded.show_on_home,
  sort_order = excluded.sort_order;

-- 每房 3 人：sort_order=0 房主，1–2 嘉宾（麦位 2、3）；按 room_index 轮换明星。
delete from public."ChatRoomMember";

insert into public."ChatRoomMember" (chat_room_id, user_id, sort_order)
select cr.id, picked.user_id, picked.sort_order
from public."ChatRoom" cr
cross join lateral (
  with stars as (
    select
      id as user_id,
      row_number() over (order by popular_star_sort) - 1 as star_idx
    from public."User"
    where is_popular_star = true and popular_star_sort is not null
  ),
  star_count as (
    select count(*)::int as n from stars
  )
  select s.user_id, gs.seat::int as sort_order
  from generate_series(0, 2) as gs(seat)
  cross join star_count sc
  join stars s on s.star_idx = ((cr.room_index - 1 + gs.seat) % sc.n)
) picked
on conflict (chat_room_id, user_id) do update set sort_order = excluded.sort_order;
"""
    body = body.replace("__ASSETS__", assets_note).replace("__VALUES__", values_sql)

    OUT.write_text(body, encoding="utf-8")
    print(f"已写入 {OUT}（{n} 个聊天室）")


if __name__ == "__main__":
    main()
