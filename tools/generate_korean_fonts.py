#!/usr/bin/env python3
"""
Generate SimpleGraphic bitmap fonts with the Korean glyphs used by the
render-time localization tables.

The generated files preserve the upstream SimpleGraphic ASCII atlas and
metrics, then append explicit Unicode mappings as:

    GLYPH U+AC00 x y width left right;
"""

from __future__ import annotations

import argparse
import math
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


HEIGHTS = (10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 32, 36, 40, 48, 56, 64)

FONT_TARGETS = (
    ("Bitstream Vera Sans Mono", "regular"),
    ("Liberation Sans", "regular"),
    ("Liberation Sans Bold", "bold"),
    ("Fontin SmallCaps", "regular"),
    ("Fontin SmallCaps Italic", "regular"),
    ("Fontin", "regular"),
    ("Fontin Italic", "regular"),
)

EXTRA_TEXT = "\uc635\uc158\n\ud328\uc2dc\ube0c \ud2b8\ub9ac\n\uc2a4\ud0ac"


class Glyph:
    def __init__(self, codepoint: int, width: int, sp_left: int, sp_right: int, mask: Image.Image):
        self.codepoint = codepoint
        self.width = width
        self.sp_left = sp_left
        self.sp_right = sp_right
        self.mask = mask
        self.x = 0
        self.y = 0


class FontSection:
    def __init__(self, height: int):
        self.height = height
        self.lines: list[str] = []
        self.codepoints: set[int] = set()


def next_power_of_two(value: int) -> int:
    ret = 1
    while ret < value:
        ret <<= 1
    return ret


def collect_codepoints(project_root: Path) -> list[int]:
    text = EXTRA_TEXT
    locale_dir = project_root / "src" / "Modules" / "Localization"
    for name in ("ko.lua", "ko_official_generated.lua", "ko_user.lua"):
        path = locale_dir / name
        if path.exists():
            text += "\n" + path.read_text(encoding="utf-8")

    codepoints = {ord(ch) for ch in text if ord(ch) >= 128}
    return sorted(codepoints)


def korean_font_size(height: int) -> int:
    return max(1, height - max(1, int(round(height * 0.12))))


def render_glyph(font: ImageFont.FreeTypeFont, codepoint: int, height: int) -> Glyph:
    ch = chr(codepoint)
    if ch.isspace():
        advance = max(1, int(round(height * 0.35)))
        return Glyph(codepoint, 1, 0, advance - 1, Image.new("L", (1, height), 0))

    bbox = font.getbbox(ch)
    advance = int(math.ceil(font.getlength(ch)))

    if not bbox:
        return Glyph(codepoint, 1, 0, max(advance - 1, 0), Image.new("L", (1, height), 0))

    left, top, right, bottom = bbox
    glyph_width = max(1, right - left)
    glyph_height = max(1, bottom - top)
    sp_left = int(math.floor(left))
    sp_right = int(advance - sp_left - glyph_width)

    mask = Image.new("L", (glyph_width, height), 0)
    draw = ImageDraw.Draw(mask)
    max_top = max(0, height - glyph_height)
    target_top = min(max_top, max(1, int(round(height * 0.16))))
    draw.text((-left, target_top - top), ch, font=font, fill=255)

    return Glyph(codepoint, glyph_width, sp_left, sp_right, mask)


def parse_base_tgf(path: Path) -> list[FontSection]:
    sections: list[FontSection] = []
    current: FontSection | None = None
    glyph_re = re.compile(r"^GLYPH\s+(?:U\+([0-9A-Fa-f]+)|.*//\s*(\d+))")

    for line in path.read_text(encoding="utf-8").splitlines():
        height_match = re.match(r"^HEIGHT\s+(\d+);", line)
        if height_match:
            current = FontSection(int(height_match.group(1)))
            sections.append(current)
            continue
        if current is None:
            continue

        current.lines.append(line)
        glyph_match = glyph_re.match(line)
        if glyph_match:
            if glyph_match.group(1):
                current.codepoints.add(int(glyph_match.group(1), 16))
            elif glyph_match.group(2):
                current.codepoints.add(int(glyph_match.group(2)))

    return sections


def choose_atlas_size(base_image: Image.Image, glyphs: list[Glyph], height: int) -> tuple[int, int]:
    cell_padding = max(2, height >> 2)
    cell_height = height + cell_padding
    best_width = next_power_of_two(base_image.width)
    best_height = next_power_of_two(base_image.height)
    best_score = (1 << 60, 1 << 60, 1 << 60)

    for width in (128, 256, 512, 1024, 2048, 4096):
        if width < base_image.width:
            continue
        rows = 0
        row_width = 0
        for glyph in glyphs:
            cell_width = glyph.width + cell_padding
            if cell_width > width:
                rows = 999999
                break
            if row_width + cell_width <= width:
                row_width += cell_width
            else:
                rows += 1
                row_width = cell_width
        atlas_height = next_power_of_two(base_image.height + rows * cell_height)
        score = (width * atlas_height, max(width, atlas_height), width)
        if score < best_score:
            best_width = width
            best_height = atlas_height
            best_score = score

    return best_width, best_height


def build_height(base_image: Image.Image, font_path: Path, codepoints: list[int], height: int) -> tuple[Image.Image, list[Glyph]]:
    font = ImageFont.truetype(str(font_path), korean_font_size(height))
    glyphs = [render_glyph(font, codepoint, height) for codepoint in codepoints]
    atlas_width, atlas_height = choose_atlas_size(base_image, glyphs, height)

    atlas = Image.new("RGBA", (atlas_width, atlas_height), (255, 255, 255, 0))
    atlas.alpha_composite(base_image.convert("RGBA"), (0, 0))
    cell_padding = max(2, height >> 2)
    cell_height = height + cell_padding
    x = 0
    y = base_image.height

    for glyph in glyphs:
        cell_width = glyph.width + cell_padding
        if x + cell_width > atlas_width:
            x = 0
            y += cell_height

        glyph.x = x
        glyph.y = y
        glyph_rgba = Image.new("RGBA", (glyph.width, height), (255, 255, 255, 0))
        glyph_rgba.putalpha(glyph.mask)
        atlas.alpha_composite(glyph_rgba, (x, y))
        x += cell_width

    return atlas, glyphs


def write_font(font_name: str, font_path: Path, codepoints: list[int], base_dir: Path, output_dir: Path) -> None:
    base_tgf = base_dir / f"{font_name}.tgf"
    if not base_tgf.exists():
        raise FileNotFoundError(f"Base SimpleGraphic font not found: {base_tgf}")

    sections = parse_base_tgf(base_tgf)
    tgf_lines: list[str] = []

    for section in sections:
        height = section.height
        base_tga = base_dir / f"{font_name}.{height}.tga"
        if not base_tga.exists():
            raise FileNotFoundError(f"Base SimpleGraphic atlas not found: {base_tga}")

        missing_codepoints = [cp for cp in codepoints if cp not in section.codepoints]
        base_image = Image.open(base_tga)
        atlas, glyphs = build_height(base_image, font_path, missing_codepoints, height)
        atlas.save(output_dir / f"{font_name}.{height}.tga", compression="tga_rle")

        tgf_lines.append(f"HEIGHT {height};")
        tgf_lines.extend(section.lines)
        for glyph in glyphs:
            tgf_lines.append(
                f"GLYPH U+{glyph.codepoint:04X} {glyph.x:3d} {glyph.y:3d} "
                f"{glyph.width:2d} {glyph.sp_left:2d} {glyph.sp_right:2d};"
            )

    (output_dir / f"{font_name}.tgf").write_text("\n".join(tgf_lines) + "\n", encoding="utf-8")


def default_font(name: str) -> Path:
    candidates = {
        "regular": (
            Path(r"C:\Windows\Fonts\malgun.ttf"),
            Path(r"C:\Windows\Fonts\NotoSansKR-Regular.ttf"),
        ),
        "bold": (
            Path(r"C:\Windows\Fonts\malgunbd.ttf"),
            Path(r"C:\Windows\Fonts\NotoSansKR-Bold.ttf"),
        ),
    }[name]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    raise FileNotFoundError(f"No default Korean {name} font found")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--base-font-dir", type=Path, default=None)
    parser.add_argument("--regular-font", type=Path, default=default_font("regular"))
    parser.add_argument("--bold-font", type=Path, default=default_font("bold"))
    args = parser.parse_args()

    output = args.output
    output.mkdir(parents=True, exist_ok=True)
    base_dir = args.base_font_dir or args.project_root / "runtime" / "SimpleGraphic" / "Fonts"

    codepoints = collect_codepoints(args.project_root)
    for font_name, weight in FONT_TARGETS:
        font_path = args.bold_font if weight == "bold" else args.regular_font
        write_font(font_name, font_path, codepoints, base_dir, output)

    non_ascii = [cp for cp in codepoints if cp >= 128]
    print(f"Generated {len(FONT_TARGETS)} font families with {len(non_ascii)} Korean/non-ASCII glyphs.")


if __name__ == "__main__":
    main()
