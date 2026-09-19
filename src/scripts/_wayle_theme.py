#!/usr/bin/env python3
"""Extract Wayle GUI palettes from per-theme config.toml files."""

from __future__ import annotations

import sys
import tomllib
from pathlib import Path

PALETTE_KEYS = [
    ("bg", "bg"),
    ("surface", "surface"),
    ("elevated", "elevated"),
    ("fg", "fg"),
    ("fg-muted", "fg_muted"),
    ("primary", "primary"),
    ("red", "red"),
    ("yellow", "yellow"),
    ("green", "green"),
    ("blue", "blue"),
]


def palette_from_config(config_path: Path) -> dict[str, str]:
    data = tomllib.loads(config_path.read_text())
    raw = data.get("styling", {}).get("palette", {})
    palette: dict[str, str] = {}
    for config_key, _out_key in PALETTE_KEYS:
        value = raw.get(config_key)
        if value is None:
            raise SystemExit(f"{config_path}: missing styling.palette.{config_key}")
        palette[config_key] = str(value)
    return palette


def write_gui_palette(config_path: Path, dest: Path) -> None:
    palette = palette_from_config(config_path)
    dest.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        f"# Palette extracted from {config_path.name} for the Wayle settings GUI.",
        "# https://wayle.app/guide/themes",
    ]
    for config_key, out_key in PALETTE_KEYS:
        if out_key in {"fg", "fg_muted", "primary"}:
            lines.append("")
        lines.append(f'{out_key} = "{palette[config_key]}"')
    dest.write_text("\n".join(lines) + "\n")


def extract_all(themes_dir: Path, dest_dir: Path) -> int:
    count = 0
    dest_dir.mkdir(parents=True, exist_ok=True)
    for config in sorted(themes_dir.glob("*/config.toml")):
        write_gui_palette(config, dest_dir / f"{config.parent.name}.toml")
        count += 1
    return count


def main(argv: list[str]) -> int:
    if len(argv) == 4 and argv[1] == "extract-palette":
        write_gui_palette(Path(argv[2]), Path(argv[3]))
        return 0
    if len(argv) == 4 and argv[1] == "extract-all":
        count = extract_all(Path(argv[2]), Path(argv[3]))
        print(f"extracted {count} Wayle palettes")
        return 0
    print(
        "usage: _wayle_theme.py extract-palette CONFIG.toml DEST.toml | "
        "extract-all THEMES_DIR DEST_DIR",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
