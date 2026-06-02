"""上传前压缩 JPG，降低 Storage 体积与客户端 egress。"""

from __future__ import annotations

import tempfile
from pathlib import Path

from PIL import Image

DEFAULT_MAX_SIDE = 1080
DEFAULT_JPEG_QUALITY = 82
# 小于该体积且尺寸已够小则跳过压缩
SKIP_BELOW_BYTES = 120_000


def prepare_upload_jpeg(
    source: Path,
    *,
    max_side: int = DEFAULT_MAX_SIDE,
    quality: int = DEFAULT_JPEG_QUALITY,
) -> tuple[Path, bool]:
    """返回 (上传路径, 是否为临时文件)。"""
    if source.suffix.lower() not in {".jpg", ".jpeg"}:
        return source, False

    if source.stat().st_size < SKIP_BELOW_BYTES:
        try:
            with Image.open(source) as img:
                w, h = img.size
                if max(w, h) <= max_side:
                    return source, False
        except OSError:
            return source, False

    with Image.open(source) as img:
        img = img.convert("RGB")
        w, h = img.size
        longest = max(w, h)
        if longest > max_side:
            scale = max_side / longest
            img = img.resize(
                (int(w * scale), int(h * scale)),
                Image.Resampling.LANCZOS,
            )

        tmp = tempfile.NamedTemporaryFile(suffix=".jpg", delete=False)
        tmp_path = Path(tmp.name)
        tmp.close()
        img.save(
            tmp_path,
            format="JPEG",
            quality=quality,
            optimize=True,
            progressive=True,
        )
        return tmp_path, True
