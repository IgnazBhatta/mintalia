#!/usr/bin/env python3
"""Set the persisted Noctalia wallpaper without clobbering other GUI overrides."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


def strip_wallpaper_sections(text: str) -> str:
    lines = text.splitlines()
    out: list[str] = []
    skipping = False
    for line in lines:
        if line.lstrip().startswith("["):
            header = line.strip()
            skipping = bool(
                re.match(
                    r"\[wallpaper\.(default|last|monitors(\..+)?)\]$",
                    header,
                )
            )
        if not skipping:
            out.append(line)
    return "\n".join(out).rstrip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("settings", type=Path)
    parser.add_argument("--wallpaper", required=True)
    parser.add_argument("--output", default="")
    args = parser.parse_args()

    existing = args.settings.read_text() if args.settings.exists() else ""
    text = strip_wallpaper_sections(existing)
    if text.strip():
        text += "\n"

    text += f'[wallpaper.default]\npath = "{args.wallpaper}"\n\n'
    text += f'[wallpaper.last]\npath = "{args.wallpaper}"\n'
    if args.output:
        text += f'\n[wallpaper.monitors.{args.output}]\npath = "{args.wallpaper}"\n'

    args.settings.parent.mkdir(parents=True, exist_ok=True)
    args.settings.write_text(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
