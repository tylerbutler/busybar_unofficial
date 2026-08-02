#!/usr/bin/env python3
"""Generate the Gleam logo PNGs used by the display examples and tests.

Stdlib only (zlib + struct) — no Pillow. Run from the repository root:

    python3 priv/generate_logo.py

Emits:
  priv/gleam_logo_72x16.png   front RGB LED matrix (72x16)
  priv/gleam_logo_160x80.png  back screen (160x80, 16 shades of grey on the
                              device, so the pink renders as a grey ramp there)

The BUSY Bar draw API cannot take inline image data, and it does not resize:
an asset has to be uploaded already scaled to the target display.
"""

import struct
import zlib
from pathlib import Path

# Gleam pink.
FG = (0xFF, 0xAF, 0xF3, 0xFF)
BG = (0x00, 0x00, 0x00, 0x00)

FRONT_W, FRONT_H = 72, 16
BACK_W, BACK_H = 160, 80

# Lucy, reduced to a 14x14 five-point star. Any more detail is mud at 16px tall.
STAR = [
    "......##......",
    "......##......",
    ".....####.....",
    ".....####.....",
    "##############",
    ".############.",
    "..##########..",
    "..##########..",
    "...########...",
    "...########...",
    "..####..####..",
    "..###....###..",
    ".###......###.",
    ".##........##.",
]

# "gleam" as 9-row glyphs with a 5px x-height, so `l` keeps its ascender and
# `g` its descender.
GLYPHS = {
    "g": [
        ".....",
        ".....",
        ".####",
        "#...#",
        "#...#",
        ".####",
        "....#",
        "#...#",
        ".###.",
    ],
    "l": [
        "##..",
        ".#..",
        ".#..",
        ".#..",
        ".#..",
        ".#..",
        ".#..",
        ".###",
        "....",
    ],
    "e": [
        ".....",
        ".....",
        ".###.",
        "#...#",
        "#####",
        "#....",
        "#...#",
        ".###.",
        ".....",
    ],
    "a": [
        ".....",
        ".....",
        ".###.",
        "....#",
        ".####",
        "#...#",
        "#...#",
        ".####",
        ".....",
    ],
    "m": [
        ".......",
        ".......",
        "##.###.",
        "#.#...#",
        "#.#...#",
        "#.#...#",
        "#.#...#",
        "#.#...#",
        ".......",
    ],
}

WORD = "gleam"
LETTER_GAP = 1
STAR_GAP = 4


def blit(pixels, sprite, ox, oy, scale):
    """Draw a `#`/`.` sprite into `pixels` at (ox, oy), scaled up `scale`x."""
    height = len(pixels)
    width = len(pixels[0])
    for sy, row in enumerate(sprite):
        for sx, cell in enumerate(row):
            if cell != "#":
                continue
            for dy in range(scale):
                for dx in range(scale):
                    x = ox + sx * scale + dx
                    y = oy + sy * scale + dy
                    if 0 <= x < width and 0 <= y < height:
                        pixels[y][x] = FG


def word_width(scale):
    glyphs = [GLYPHS[c] for c in WORD]
    return (
        sum(len(g[0]) for g in glyphs) + LETTER_GAP * (len(glyphs) - 1)
    ) * scale


def draw_logo(width, height, scale):
    """Render the star + wordmark lockup centred on a transparent canvas."""
    pixels = [[BG] * width for _ in range(height)]

    star_w = len(STAR[0]) * scale
    star_h = len(STAR) * scale
    text_w = word_width(scale)
    text_h = len(GLYPHS["g"]) * scale

    total_w = star_w + STAR_GAP * scale + text_w
    ox = (width - total_w) // 2

    blit(pixels, STAR, ox, (height - star_h) // 2, scale)

    x = ox + star_w + STAR_GAP * scale
    text_y = (height - text_h) // 2
    for char in WORD:
        glyph = GLYPHS[char]
        blit(pixels, glyph, x, text_y, scale)
        x += (len(glyph[0]) + LETTER_GAP) * scale

    return pixels


def chunk(tag, data):
    body = tag + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))


def write_png(path, pixels):
    height = len(pixels)
    width = len(pixels[0])
    raw = bytearray()
    for row in pixels:
        raw.append(0)  # filter type 0 (None)
        for r, g, b, a in row:
            raw += bytes((r, g, b, a))

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )
    path.write_bytes(png)
    print(f"{path}: {width}x{height}, {len(png)} bytes")


def main():
    out = Path(__file__).resolve().parent
    write_png(out / "gleam_logo_72x16.png", draw_logo(FRONT_W, FRONT_H, 1))
    write_png(out / "gleam_logo_160x80.png", draw_logo(BACK_W, BACK_H, 3))


if __name__ == "__main__":
    main()
