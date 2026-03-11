#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import subprocess
import tempfile
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


def build_demo_gif(frames: list[Path], output: Path) -> None:
    images = [Image.open(path).convert("P", palette=Image.Palette.ADAPTIVE, colors=128) for path in frames]
    durations = [1200, 900, 900, 900, 1100][: len(images)]
    images[0].save(
        output,
        save_all=True,
        append_images=images[1:],
        duration=durations,
        loop=0,
        optimize=False,
        disposal=2,
    )


def capture_main_menu_text() -> str:
    summary_json = (
        '{"rows":[{"monitor":"network_monitor","host":"web-2","status":"CRIT","reason":"http_failed"},'
        '{"monitor":"service_monitor","host":"web-1","status":"WARN","reason":"service_inactive"}],'
        '"problems":[{"monitor":"network_monitor","host":"web-2","status":"CRIT","reason":"http_failed"}],'
        '"reason_rollup":[{"reason":"http_failed","count":1},{"reason":"service_inactive","count":1}],'
        '"totals":{"OK":0,"WARN":1,"CRIT":1,"UNKNOWN":0,"SKIP":0},"meta":{"overall":"CRIT"}}'
    )
    with tempfile.TemporaryDirectory(prefix="linux_maint_menu_capture_") as tmp:
        fixture_root = Path(tmp)
        logs_dir = fixture_root / "logs"
        logs_dir.mkdir(parents=True, exist_ok=True)
        (logs_dir / "full_health_monitor_summary_latest.json").write_text(summary_json, encoding="utf-8")
        bash_script = f"""
set -euo pipefail
ROOT_DIR={str(ROOT)!r}
LM="$ROOT_DIR/bin/linux-maint"
source "$LM" >/dev/null 2>&1
MODE=repo
LOG_DIR={str(logs_dir)!r}
LM_CFG_DIR=/tmp/linux_maint_cfg_fixture
LM_STATE_DIR=/tmp/linux_maint_state_fixture
TUI_BACKEND=gum
TUI_MENU_STYLE=full
NO_COLOR=1
catalog=$'quickstart|Start here: first setup, guided rescue, and escalation [q]\\n'\
$'overview|See fleet health, latest problems, and the fast answer [o]\\n'\
$'run|Run checks, preview scope, and launch safely [r]\\n'\
$'triage|Investigate failures and repair safely [t]\\n'\
$'share|Share reports, bundles, and reference docs [s]\\n'\
$'exit|Exit [x]\\n'
tui_gum_render_menu_frame "Choose your next step" "main" "$catalog" 10 2>&1 >/dev/null
"""
        out = subprocess.check_output(["bash", "-lc", bash_script], text=True)
    lines = [line.rstrip() for line in out.splitlines()]
    while lines and not lines[0]:
        lines.pop(0)
    while lines and not lines[-1]:
        lines.pop()
    return "\n".join(lines)


def main() -> int:
    ASSETS.mkdir(parents=True, exist_ok=True)
    main_text = capture_main_menu_text()
    overview = load_text(FIXTURES / "menu_section_frame.txt")
    quickstart = extract_section(load_text(FIXTURES / "menu_all_sections.txt"), "Quickstart")
    triage = extract_section(load_text(FIXTURES / "menu_all_sections.txt"), "Triage")
    share = extract_section(load_text(FIXTURES / "menu_all_sections.txt"), "Share")
    render_terminal_block(
        main_text,
        ASSETS / "menu_welcome_capture.png",
        "Current menu capture: Welcome",
    )
    render_terminal_block(
        quickstart,
        ASSETS / "menu_quickstart_capture.png",
        "Current menu capture: Quickstart",
    )
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
    render_terminal_block(
        share,
        ASSETS / "menu_share_capture.png",
        "Current menu capture: Share",
    )
    build_demo_gif(
        [
            ASSETS / "menu_welcome_capture.png",
            ASSETS / "menu_quickstart_capture.png",
            ASSETS / "menu_dashboard_capture.png",
            ASSETS / "menu_triage_capture.png",
            ASSETS / "menu_share_capture.png",
        ],
        ASSETS / "menu_demo.gif",
    )
    print("rendered menu capture assets")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
