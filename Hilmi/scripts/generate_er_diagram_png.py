#!/usr/bin/env python3
"""生成 Hilmi 数据库 E-R 图 PNG（表关系 + 全字段中文说明）。"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUTPUT = Path("/Users/mac/Desktop/Hilmi数据库ER图.png")
FONT_PATH = "/System/Library/Fonts/STHeiti Light.ttc"

# 每张表的字段：(英文名, 类型简写, 中文说明)
TABLES: list[tuple[str, str, list[tuple[str, str, str]]]] = [
    (
        "auth.users",
        "Supabase 认证用户表",
        [
            ("id", "uuid PK", "认证主键"),
            ("email", "text", "登录邮箱"),
            ("raw_user_meta_data", "jsonb", "注册时携带的元数据"),
            ("created_at", "timestamptz", "账号创建时间"),
        ],
    ),
    (
        "User",
        "用户 / 主播业务资料",
        [
            ("id", "uuid PK", "业务用户主键"),
            ("auth_user_id", "uuid FK", "关联 auth.users.id"),
            ("display_name", "text", "显示昵称"),
            ("gender", "enum", "性别 male/female/other"),
            ("bio", "text", "个人简介"),
            ("avatar_path", "text", "头像 Storage 路径"),
            ("email", "text", "邮箱"),
            ("apple_user_id", "text", "Apple 登录唯一 ID"),
            ("coins", "int", "金币余额"),
            ("avatar_frame_index", "int", "头像框样式索引"),
            ("is_popular_star", "bool", "是否 Popular Star"),
            ("popular_star_sort", "int", "明星展示排序"),
            ("following_ids", "uuid[]", "我关注的用户 ID"),
            ("follower_ids", "uuid[]", "关注我的用户 ID"),
            ("blocked_ids", "uuid[]", "拉黑用户 ID"),
            ("liked_post_ids", "uuid[]", "已点赞帖子 ID"),
            ("iap_processed_tx_ids", "text[]", "已处理内购交易号"),
            ("eula_accepted_at", "timestamptz", "注册同意 EULA"),
            ("eula_login_accepted_at", "timestamptz", "登录同意 EULA"),
            ("created_at", "timestamptz", "创建时间"),
            ("updated_at", "timestamptz", "更新时间"),
        ],
    ),
    (
        "Live",
        "调酒直播间",
        [
            ("id", "uuid PK", "直播间主键"),
            ("category_slug", "text", "分类标识"),
            ("category_name", "text", "分类显示名"),
            ("category_sort_order", "int", "分类排序"),
            ("show_on_home", "bool", "是否首页展示"),
            ("streamer_id", "uuid FK", "主播 User.id"),
            ("room_index", "int", "分类内房间序号"),
            ("description", "text", "房间描述"),
            ("tags", "text[]", "标签列表"),
            ("cover_path", "text", "封面图路径"),
            ("video_path", "text", "预录视频路径"),
            ("viewer_count", "int", "当前观众数"),
            ("is_live", "bool", "是否直播中"),
            ("sort_order", "int", "列表排序"),
            ("created_at", "timestamptz", "创建时间"),
            ("updated_at", "timestamptz", "更新时间"),
        ],
    ),
    (
        "Post",
        "朋友圈帖子",
        [
            ("id", "uuid PK", "帖子主键"),
            ("post_index", "int UNIQUE", "全局帖子序号"),
            ("author_id", "uuid FK", "作者 User.id"),
            ("content", "text", "文字内容"),
            ("like_count", "int", "点赞数"),
            ("comment_count", "int", "评论数"),
            ("media", "jsonb", "图片/视频媒体数组"),
            ("created_at", "timestamptz", "发布时间"),
            ("updated_at", "timestamptz", "更新时间"),
        ],
    ),
    (
        "PostChat",
        "帖子评论",
        [
            ("id", "uuid PK", "评论主键"),
            ("post_id", "uuid FK", "所属 Post.id"),
            ("author_id", "uuid FK", "评论者 User.id"),
            ("content", "text", "评论内容"),
            ("created_at", "timestamptz", "评论时间"),
        ],
    ),
    (
        "LiveChat",
        "直播弹幕（Realtime）",
        [
            ("id", "uuid PK", "弹幕主键"),
            ("live_id", "uuid FK", "所属 Live.id"),
            ("sender_id", "uuid FK", "发送者 User.id"),
            ("content", "text", "弹幕内容"),
            ("created_at", "timestamptz", "发送时间"),
        ],
    ),
    (
        "Message",
        "一对一私信",
        [
            ("id", "uuid PK", "行主键"),
            ("conversation_id", "uuid", "会话 ID"),
            ("message_kind", "text", "header 摘要 / chat 消息"),
            ("user_low_id", "uuid FK", "双方较小 User.id"),
            ("user_high_id", "uuid FK", "双方较大 User.id"),
            ("sender_id", "uuid FK", "发送者（chat 必填）"),
            ("body", "text", "消息正文"),
            ("last_message_at", "timestamptz", "最后消息时间"),
            ("last_message_preview", "text", "列表预览文案"),
            ("last_sender_id", "uuid FK", "最后发送者"),
            ("created_at", "timestamptz", "创建时间"),
        ],
    ),
    (
        "ChatRoom",
        "Tipsy Bar 聊天室",
        [
            ("id", "uuid PK", "聊天室主键"),
            ("room_index", "int UNIQUE", "房间全局序号"),
            ("title", "text", "房间标题"),
            ("description", "text", "房间描述"),
            ("cover_path", "text", "封面图路径"),
            ("image_on_right", "bool", "首页卡片图靠右"),
            ("show_on_home", "bool", "是否在首页展示"),
            ("sort_order", "int", "列表排序"),
            ("host_audio_path", "text", "房主语音路径"),
            ("created_at", "timestamptz", "创建时间"),
        ],
    ),
    (
        "ChatRoomMember",
        "聊天室成员",
        [
            ("chat_room_id", "uuid PK,FK", "聊天室 ID"),
            ("user_id", "uuid PK,FK", "成员 User.id"),
            ("sort_order", "int", "0=房主 其余=嘉宾"),
        ],
    ),
    (
        "ChatRoomChat",
        "聊天室公屏（Realtime）",
        [
            ("id", "uuid PK", "消息主键"),
            ("chat_room_id", "uuid FK", "所属 ChatRoom.id"),
            ("sender_id", "uuid FK", "发送者 User.id"),
            ("content", "text", "公屏内容"),
            ("created_at", "timestamptz", "发送时间"),
        ],
    ),
]

# ER 简图实体（名称, 中心附近描述行）
ER_ENTITIES = [
    ("auth.users\n认证", 200, 180, (230, 240, 250)),
    ("User\n用户中心", 520, 320, (255, 235, 235)),
    ("Live\n直播", 200, 480, (255, 248, 230)),
    ("LiveChat\n弹幕", 200, 620, (255, 248, 230)),
    ("Post\n朋友圈", 200, 780, (240, 248, 255)),
    ("PostChat\n评论", 200, 920, (240, 248, 255)),
    ("Message\n私信", 840, 480, (245, 240, 255)),
    ("ChatRoom\n酒吧", 840, 720, (235, 250, 240)),
    ("ChatRoomMember\n成员", 1040, 720, (235, 250, 240)),
    ("ChatRoomChat\n公屏", 840, 880, (235, 250, 240)),
]

ER_EDGES = [
    ((200, 180), (520, 320), "1:1"),
    ((520, 320), (200, 480), "主播"),
    ((200, 480), (200, 620), "1:N"),
    ((520, 320), (200, 780), "发布"),
    ((200, 780), (200, 920), "1:N"),
    ((520, 320), (200, 920), "评论"),
    ((520, 320), (840, 480), "会话"),
    ((840, 720), (840, 880), "1:N"),
    ((520, 320), (1040, 720), "N:M"),
    ((840, 720), (1040, 720), "1:N"),
    ((520, 320), (840, 880), "发送"),
]

BG = (252, 250, 245)
TEXT = (30, 30, 30)
SUBTEXT = (70, 70, 70)
LINE = (100, 100, 100)
ACCENT = (200, 77, 77)
HEADER_BG = (200, 77, 77)
HEADER_FG = (255, 255, 255)
GRID_LINE = (220, 220, 220)


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(FONT_PATH, size, index=1 if bold else 0)
    except OSError:
        return ImageFont.load_default()


def measure_field_table(
    fields: list[tuple[str, str, str]],
    title_font: ImageFont.FreeTypeFont,
    field_font: ImageFont.FreeTypeFont,
    col_font: ImageFont.FreeTypeFont,
) -> tuple[int, int]:
    """估算单表字段块宽高。"""
    w = 520
    h = 44 + 28  # 表头 + 列标题
    for _ in fields:
        h += 20
    h += 12
    return w, h


def draw_field_table(
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    table_name: str,
    table_desc: str,
    fields: list[tuple[str, str, str]],
    title_font: ImageFont.FreeTypeFont,
    desc_font: ImageFont.FreeTypeFont,
    col_font: ImageFont.FreeTypeFont,
    field_font: ImageFont.FreeTypeFont,
    width: int = 520,
) -> int:
    """绘制一张表的字段明细，返回占用高度。"""
    row_h = 20
    header_h = 44
    col_h = 26
    total_h = header_h + col_h + len(fields) * row_h + 10

    draw.rounded_rectangle(
        (x, y, x + width, y + total_h),
        radius=8,
        fill=(255, 255, 255),
        outline=(80, 80, 80),
        width=1,
    )
    draw.rectangle((x, y, x + width, y + header_h), fill=HEADER_BG)
    draw.text((x + 10, y + 8), table_name, font=title_font, fill=HEADER_FG)
    draw.text((x + 10, y + 26), table_desc, font=desc_font, fill=(255, 230, 230))

    cy = y + header_h
    draw.rectangle((x, cy, x + width, cy + col_h), fill=(245, 245, 245))
    draw.line((x, cy + col_h, x + width, cy + col_h), fill=GRID_LINE)
    draw.text((x + 8, cy + 5), "字段名", font=col_font, fill=TEXT)
    draw.text((x + 155, cy + 5), "类型", font=col_font, fill=TEXT)
    draw.text((x + 255, cy + 5), "中文说明", font=col_font, fill=TEXT)
    cy += col_h

    c1, c2, c3 = x + 8, x + 155, x + 255
    for name, typ, desc in fields:
        draw.text((c1, cy + 2), name, font=field_font, fill=TEXT)
        draw.text((c2, cy + 2), typ, font=field_font, fill=SUBTEXT)
        draw.text((c3, cy + 2), desc, font=field_font, fill=SUBTEXT)
        cy += row_h
        draw.line((x + 4, cy, x + width - 4, cy), fill=GRID_LINE)

    return total_h


def draw_er_section(
    draw: ImageDraw.ImageDraw,
    ox: int,
    oy: int,
    w: int,
    h: int,
    entity_font: ImageFont.FreeTypeFont,
    edge_font: ImageFont.FreeTypeFont,
    section_font: ImageFont.FreeTypeFont,
) -> None:
    draw.rounded_rectangle((ox, oy, ox + w, oy + h), radius=12, outline=(180, 180, 180), width=2)
    draw.text((ox + w // 2, oy + 22), "表关系简图", font=section_font, fill=TEXT, anchor="mm")

    positions: dict[str, tuple[int, int]] = {}
    for name, ex, ey, color in ER_ENTITIES:
        px, py = ox + ex, oy + ey
        lines = name.split("\n")
        bw, bh = 118, 28 + len(lines) * 18
        x1, y1 = px - bw // 2, py - bh // 2
        x2, y2 = px + bw // 2, py + bh // 2
        draw.rounded_rectangle((x1, y1, x2, y2), radius=8, fill=color, outline=(60, 60, 60), width=1)
        ty = y1 + 8
        for line in lines:
            draw.text((px, ty), line, font=entity_font, fill=TEXT, anchor="mm")
            ty += 18
        positions[name.split("\n")[0]] = (px, py)

    key_map = {
        "auth.users": "auth.users",
        "User": "User",
        "Live": "Live",
        "LiveChat": "LiveChat",
        "Post": "Post",
        "PostChat": "PostChat",
        "Message": "Message",
        "ChatRoom": "ChatRoom",
        "ChatRoomMember": "ChatRoomMember",
        "ChatRoomChat": "ChatRoomChat",
    }

    for (sx, sy), (ex, ey), label in ER_EDGES:
        start = (ox + sx, oy + sy)
        end = (ox + ex, oy + ey)
        draw.line((start, end), fill=LINE, width=2)
        mx, my = (start[0] + end[0]) // 2, (start[1] + end[1]) // 2 - 8
        draw.text((mx, my), label, font=edge_font, fill=ACCENT, anchor="mm")


def main() -> None:
    # 计算字段区高度：2 列布局
    col_w = 540
    gap_x, gap_y = 24, 20
    margin = 40

    title_font = load_font(22, bold=True)
    desc_font = load_font(12)
    col_font = load_font(13, bold=True)
    field_font = load_font(12)
    main_title = load_font(32, bold=True)
    subtitle = load_font(16)
    section_font = load_font(20, bold=True)
    entity_font = load_font(14, bold=True)
    edge_font = load_font(12)
    legend_font = load_font(13)

    er_h = 1020
    field_start_y = margin + 100 + er_h + 30

    # 两列排列表
    col_heights = [0, 0]
    table_blocks: list[tuple[int, int, str, str, list]] = []
    for i, (name, desc, fields) in enumerate(TABLES):
        col = i % 2
        _, th = measure_field_table(fields, title_font, field_font, col_font)
        x = margin + col * (col_w + gap_x)
        y = field_start_y + col_heights[col]
        table_blocks.append((x, y, name, desc, fields))
        col_heights[col] += th + gap_y

    fields_section_h = max(col_heights) + 80
    total_h = field_start_y + fields_section_h + 50
    total_w = margin * 2 + col_w * 2 + gap_x

    img = Image.new("RGB", (total_w, total_h), BG)
    draw = ImageDraw.Draw(img)

    draw.text((total_w // 2, 40), "Hilmi 项目数据库 E-R 图", font=main_title, fill=TEXT, anchor="mm")
    draw.text(
        (total_w // 2, 78),
        "PostgreSQL（Supabase）· 含全部字段中文说明",
        font=subtitle,
        fill=SUBTEXT,
        anchor="mm",
    )

    draw_er_section(
        draw,
        margin,
        margin + 100,
        total_w - margin * 2,
        er_h,
        entity_font,
        edge_font,
        section_font,
    )

    draw.text(
        (margin, field_start_y - 28),
        "字段明细（下表为各表全部字段及中文含义）",
        font=section_font,
        fill=TEXT,
    )

    for x, y, name, desc, fields in table_blocks:
        draw_field_table(
            draw, x, y, name, desc, fields,
            title_font, desc_font, col_font, field_font, col_w - 20,
        )

    # Post.media 补充说明
    note_y = field_start_y + max(col_heights) + 10
    notes = [
        "Post.media（jsonb）元素：type=image 含 storage_path、sort_order；type=video 另含 poster_path。",
        "逻辑关系（无独立表）：关注/粉丝 → following_ids、follower_ids；拉黑 → blocked_ids；点赞 → liked_post_ids。",
        "Storage 桶 media（私有）：avatar_path、cover_path、video_path、media 等仅存路径，客户端签名访问。",
    ]
    for i, note in enumerate(notes):
        draw.text((margin, note_y + i * 22), "※ " + note, font=legend_font, fill=SUBTEXT)

    draw.text(
        (total_w // 2, total_h - 22),
        "依据 supabase/database_schema.txt · Hilmi",
        font=legend_font,
        fill=SUBTEXT,
        anchor="mm",
    )

    img.save(OUTPUT, "PNG", optimize=True)
    print(f"已保存: {OUTPUT} ({total_w}x{total_h})")


if __name__ == "__main__":
    main()
