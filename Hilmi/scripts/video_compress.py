"""朋友圈 / 直播视频压缩（ffmpeg）。供 upload_*.py 调用。"""

from __future__ import annotations

import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Optional, Tuple

# 目标：720p H.264，单条通常 < 15MB（大源文件会明显缩小）
DEFAULT_MAX_HEIGHT = 720
DEFAULT_CRF = 28
DEFAULT_PRESET = "medium"
DEFAULT_AUDIO_BITRATE = "128k"
DEFAULT_WARN_SIZE_MB = 20.0
DEFAULT_SKIP_IF_HEIGHT_LE = 720
DEFAULT_SKIP_IF_SIZE_MB = 12.0


@dataclass(frozen=True)
class CompressResult:
    source: Path
    output: Path
    skipped: bool
    source_bytes: int
    output_bytes: int

    @property
    def ratio(self) -> float:
        if self.source_bytes <= 0:
            return 1.0
        return self.output_bytes / self.source_bytes


def require_ffmpeg() -> str:
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise RuntimeError("未找到 ffmpeg，请先安装：brew install ffmpeg")
    return ffmpeg


def format_bytes(n: int) -> str:
    if n < 1024:
        return f"{n} B"
    if n < 1024 * 1024:
        return f"{n / 1024:.1f} KB"
    return f"{n / (1024 * 1024):.1f} MB"


def probe_video_height(*, ffprobe: str, path: Path) -> Optional[int]:
    cmd = [
        ffprobe,
        "-v",
        "error",
        "-select_streams",
        "v:0",
        "-show_entries",
        "stream=height",
        "-of",
        "csv=p=0",
        str(path),
    ]
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True).strip()
        return int(out) if out.isdigit() else None
    except (subprocess.CalledProcessError, ValueError):
        return None


def extract_poster_frame(
    *,
    ffmpeg: str,
    video_path: Path,
    output_path: Path,
    seek: str = "00:00:01",
    max_height: int = 720,
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        ffmpeg,
        "-y",
        "-ss",
        seek,
        "-i",
        str(video_path),
        "-frames:v",
        "1",
        "-vf",
        f"scale=-2:{max_height}",
        "-q:v",
        "4",
        str(output_path),
    ]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def should_skip_compress(
    path: Path,
    *,
    max_height: int = DEFAULT_MAX_HEIGHT,
    max_size_mb: float = DEFAULT_SKIP_IF_SIZE_MB,
) -> bool:
    size_mb = path.stat().st_size / (1024 * 1024)
    if size_mb > max_size_mb:
        return False
    ffprobe = shutil.which("ffprobe")
    if ffprobe is None:
        return False
    height = probe_video_height(ffprobe=ffprobe, path=path)
    return height is not None and height <= max_height


def compress_mp4(
    *,
    ffmpeg: str,
    source: Path,
    dest: Optional[Path] = None,
    max_height: int = DEFAULT_MAX_HEIGHT,
    crf: int = DEFAULT_CRF,
    preset: str = DEFAULT_PRESET,
    audio_bitrate: str = DEFAULT_AUDIO_BITRATE,
    allow_skip: bool = True,
) -> CompressResult:
    if not source.is_file():
        raise FileNotFoundError(source)

    source_bytes = source.stat().st_size
    if allow_skip and should_skip_compress(source, max_height=max_height):
        return CompressResult(
            source=source,
            output=source,
            skipped=True,
            source_bytes=source_bytes,
            output_bytes=source_bytes,
        )

    if dest is None:
        tmp = tempfile.NamedTemporaryFile(suffix=".mp4", delete=False)
        tmp.close()
        dest = Path(tmp.name)
    else:
        dest.parent.mkdir(parents=True, exist_ok=True)

    cmd = [
        ffmpeg,
        "-y",
        "-i",
        str(source),
        "-vf",
        f"scale=-2:{max_height}",
        "-c:v",
        "libx264",
        "-preset",
        preset,
        "-crf",
        str(crf),
        "-c:a",
        "aac",
        "-b:a",
        audio_bitrate,
        "-movflags",
        "+faststart",
        str(dest),
    ]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    output_bytes = dest.stat().st_size
    return CompressResult(
        source=source,
        output=dest,
        skipped=False,
        source_bytes=source_bytes,
        output_bytes=output_bytes,
    )


def prepare_upload_mp4(
    *,
    ffmpeg: str,
    source: Path,
    compress: bool = True,
) -> Tuple[Path, Optional[CompressResult], bool]:
    """返回 (上传用路径, 压缩结果, 是否为临时文件需删除)。"""
    if not compress:
        return source, None, False

    result = compress_mp4(ffmpeg=ffmpeg, source=source)
    if result.skipped:
        return source, result, False
    return result.output, result, True
