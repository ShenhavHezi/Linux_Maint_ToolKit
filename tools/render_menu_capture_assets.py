#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests" / "fixtures"
ASSETS = ROOT / "docs" / "assets"


def load_text(path: Path) -> str:
    return path.read_text(encoding="utf-8").strip("\n")


def extract_section(text: str, title: str) -> str:
    marker = f"=== {title} ==="
    start = text.find(marker)
    if start == -1:
        raise SystemExit(f"missing section marker: {marker}")
    start += len(marker)
    remainder = text[start:].lstrip("\n")
    next_idx = remainder.find("\n===")
    if next_idx != -1:
        remainder = remainder[:next_idx]
    return remainder.strip("\n")


def font_path() -> str:
    try:
        out = subprocess.check_output(
            ["fc-match", "-f", "%{file}\n", "DejaVu Sans Mono"],
            text=True,
        ).strip()
        if out:
            return out
    except Exception:
        pass
    return "/usr/share/fonts/dejavu-sans-mono-fonts/DejaVuSansMono.ttf"


def render_terminal_block(text: str, output: Path, title: str) -> None:
    font = ImageFont.truetype(font_path(), 18)
    probe = Image.new("RGB", (10, 10))
    draw = ImageDraw.Draw(probe)
    sample_bbox = draw.textbbox((0, 0), "M", font=font)
    char_w = sample_bbox[2] - sample_bbox[0]
    char_h = sample_bbox[3] - sample_bbox[1]
    line_gap = 8
    pad_x = 34
    pad_y = 28

    lines = text.splitlines()
    max_cols = max(len(line) for line in lines)
    width = pad_x * 2 + max_cols * char_w
    height = pad_y * 2 + len(lines) * (char_h + line_gap) + 44

    image = Image.new("RGB", (width, height), "#09111f")
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle(
        (0, 0, width - 1, height - 1),
        radius=28,
        outline="#1e293b",
        width=2,
        fill="#09111f",
    )
    draw.text((pad_x, 16), title, font=font, fill="#94a3b8")

    y = pad_y + 30
    for line in lines:
        draw.text((pad_x, y), line, font=font, fill="#e2e8f0")
        y += char_h + line_gap

    image.save(output)


def main() -> int:
    ASSETS.mkdir(parents=True, exist_ok=True)
    overview = load_text(FIXTURES / "menu_section_frame.txt")
    triage = extract_section(load_text(FIXTURES / "menu_all_sections.txt"), "Triage")
    render_terminal_block(
        overview,
        ASSETS / "menu_dashboard_capture.png",
        "Current menu capture: Overview",
    )
    render_terminal_block(
        triage,
        ASSETS / "menu_triage_capture.png",
        "Current menu capture: Triage",
    )
    print("rendered menu capture assets")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
