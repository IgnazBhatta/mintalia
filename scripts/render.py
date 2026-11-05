#!/usr/bin/env python3
"""Render mintalia config templates for the machine being installed on.

The repository stores configs with two placeholders:

    __HOME__     -> the target user's $HOME
    __OUTPUT__   -> the primary niri output name (e.g. eDP-1 / DP-1)

Noctalia desktop-widget coordinates were authored on a 1920x1080 output, so
they are rescaled to the target output here.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

WIDGET_HEADER = re.compile(r"^\s*\[(desktop_widgets|lockscreen_widgets)\.widget\.")
NUM_KEY = re.compile(
    r"^(\s*)(cx|cy|box_width|box_height|placement_width|placement_height)\s*=\s*([0-9.]+)\s*$"
)
COMMUNITY_IDS = re.compile(r"community_ids\s*=\s*\[[^\]]*\]")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=["noctalia", "niri", "plain"])
    parser.add_argument("src")
    parser.add_argument("dst")
    parser.add_argument("--home", required=True)
    parser.add_argument("--output", default="eDP-1")
    parser.add_argument("--width", type=int, default=1920)
    parser.add_argument("--height", type=int, default=1080)
    parser.add_argument("--browser", choices=["floorp", "zen", "none"], default="none")
    parser.add_argument("--discord", action="store_true")
    parser.add_argument("--spotify", action="store_true")
    parser.add_argument("--wayvibes", action="store_true")
    parser.add_argument("--vscode", action="store_true")
    parser.add_argument("--zed", action="store_true")
    return parser.parse_args()


def scale_noctalia(text: str, args: argparse.Namespace) -> str:
    width = args.width if args.width > 0 else 1920
    height = args.height if args.height > 0 else 1080
    sx = width / 1920.0
    sy = height / 1080.0
    s = min(sx, sy)

    out: list[str] = []
    in_widget = False
    for line in text.splitlines():
        if line.lstrip().startswith("["):
            in_widget = bool(WIDGET_HEADER.match(line))
        if in_widget:
            match = NUM_KEY.match(line)
            if match:
                indent, key, raw = match.groups()
                value = float(raw)
                if key == "placement_width":
                    value = float(width)
                elif key == "placement_height":
                    value = float(height)
                elif key in ("cx", "cy"):
                    value *= sx if key == "cx" else sy
                    if key == "cx":
                        value = min(value, max(width - 16, 0))
                    else:
                        value = min(value, max(height - 16, 0))
                else:
                    value *= s
                if value.is_integer():
                    rendered = str(int(value))
                else:
                    rendered = f"{value:.1f}"
                line = f"{indent}{key} = {rendered}"
        out.append(line)
    return "\n".join(out) + "\n"


def noctalia(text: str, args: argparse.Namespace) -> str:
    text = text.replace("__HOME__", args.home).replace("__OUTPUT__", args.output)
    text = scale_noctalia(text, args)

    templates: list[str] = []
    if args.discord:
        templates.append("discord")
    if args.browser == "zen":
        templates.append("zen-browser")
    if args.vscode:
        templates.append("vscode")
    if args.zed:
        templates.append("zed")
    if args.spotify:
        templates.append("spicetify-noctalia")
    rendered = "community_ids = [ " + ", ".join(f'"{t}"' for t in templates) + " ]"
    text = COMMUNITY_IDS.sub(rendered, text)

    if not args.wayvibes:
        text = text.replace('    "wayvibes",\n', "")
        text = text.replace(
            "[widget.wayvibes]\ntype = \"viksit-garg/wayvibes:wayvibes\"\n\n", ""
        )
        text = text.replace('    "viksit-garg/wayvibes",\n', "")
    return text


def niri(text: str, args: argparse.Namespace) -> str:
    text = text.replace("__HOME__", args.home)

    if args.browser == "none":
        text = text.replace(
            '    Mod+B hotkey-overlay-title="Open Browser" { spawn "__BROWSER__"; }\n',
            '    // Mod+B hotkey-overlay-title="Open Browser" { spawn "floorp"; }\n',
        )
    else:
        text = text.replace("__BROWSER__", args.browser)

    optional = {
        'spawn "spotify"': args.spotify,
        'spawn "code"': args.vscode,
        'spawn "zeditor"': args.zed,
    }
    out: list[str] = []
    for line in text.splitlines():
        for needle, enabled in optional.items():
            if needle in line and not enabled and not line.lstrip().startswith("//"):
                stripped = line.lstrip()
                indent = line[: len(line) - len(stripped)]
                line = f"{indent}// {stripped}"
                break
        out.append(line)
    return "\n".join(out) + "\n"


def main() -> int:
    args = parse_args()
    src = Path(args.src)
    dst = Path(args.dst)
    text = src.read_text()

    if args.kind == "noctalia":
        text = noctalia(text, args)
    elif args.kind == "niri":
        text = niri(text, args)
    else:
        text = text.replace("__HOME__", args.home).replace("__OUTPUT__", args.output)

    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
