#!/usr/bin/env python3
"""Generate the Forever Funny brand assets.

The mark is intentionally built from plain rectangles so the SVG and the
rasterised PNG/ICO files stay pixel-identical: a rounded brand-orange square
with a white double-F monogram.

Run from the repository root:

    python scripts/gen-brand-assets.py

Requires Pillow. Outputs are committed, so this only needs to run when the
mark or the brand colour changes.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
STATIC = ROOT / "static"

BRAND = (198, 87, 13)  # #c6570d
BRAND_DARK = (214, 97, 18)  # #d66112
WHITE = (255, 255, 255)
INK = (28, 25, 23)  # #1c1917
MUTED = (120, 113, 108)  # #78716c
BG = (250, 250, 249)  # #fafaf9

# Double-F geometry in a 32x32 box.
BARS = [
    # left F: stem, top bar, middle bar
    (6.0, 8.0, 2.8, 16.0),
    (6.0, 8.0, 9.0, 3.2),
    (6.0, 14.0, 7.0, 2.2),
    # right F
    (17.2, 8.0, 2.8, 16.0),
    (17.2, 8.0, 9.0, 3.2),
    (17.2, 14.0, 7.0, 2.2),
]
RADIUS = 7.0


def svg(fill: str) -> str:
    rects = "\n".join(
        f'    <rect x="{x:g}" y="{y:g}" width="{w:g}" height="{h:g}"/>'
        for x, y, w, h in BARS
    )
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" fill="none">\n'
        f'  <rect width="32" height="32" rx="{RADIUS:g}" fill="{fill}"/>\n'
        f'  <g fill="#fff">\n{rects}\n  </g>\n'
        "</svg>\n"
    )


def raster(size: int, fill: tuple[int, int, int]) -> Image.Image:
    scale = 8
    big = size * scale
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    unit = big / 32.0
    draw.rounded_rectangle(
        (0, 0, big - 1, big - 1), radius=RADIUS * unit, fill=fill + (255,)
    )
    for x, y, w, h in BARS:
        draw.rectangle(
            (
                round(x * unit),
                round(y * unit),
                round((x + w) * unit) - 1,
                round((y + h) * unit) - 1,
            ),
            fill=WHITE + (255,),
        )
    return img.resize((size, size), Image.LANCZOS)


def font(paths: list[str], size: int) -> ImageFont.FreeTypeFont:
    for candidate in paths:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default(size=size)


def og_image() -> Image.Image:
    img = Image.new("RGB", (1200, 630), BG)
    draw = ImageDraw.Draw(img)
    mark = raster(140, BRAND)
    img.paste(mark, (96, 245), mark)
    draw.rectangle((96, 96, 1104, 100), fill=BRAND)

    title_font = font(
        [r"C:\Windows\Fonts\arialbd.ttf", "/System/Library/Fonts/Supplemental/Arial Bold.ttf"],
        76,
    )
    sub_font = font(
        [r"C:\Windows\Fonts\arial.ttf", "/System/Library/Fonts/Supplemental/Arial.ttf"],
        32,
    )
    small_font = font(
        [r"C:\Windows\Fonts\arial.ttf", "/System/Library/Fonts/Supplemental/Arial.ttf"],
        24,
    )

    draw.text((280, 248), "Forever Funny", font=title_font, fill=INK)
    draw.text((284, 356), "Notes · Projects · Essays", font=sub_font, fill=MUTED)

    domain = "forever-funny.github.io"
    width = draw.textlength(domain, font=small_font)
    draw.text((1104 - width, 548), domain, font=small_font, fill=MUTED)
    return img


def main() -> None:
    images_dir = STATIC / "images"
    images_dir.mkdir(parents=True, exist_ok=True)

    (images_dir / "logo.svg").write_text(svg("#c6570d"), encoding="utf-8")
    (images_dir / "logo-dark.svg").write_text(svg("#d66112"), encoding="utf-8")
    (STATIC / "favicon.svg").write_text(svg("#c6570d"), encoding="utf-8")

    for size in (16, 32):
        raster(size, BRAND).save(STATIC / f"favicon-{size}x{size}.png")
    raster(180, BRAND).save(STATIC / "apple-touch-icon.png")
    raster(192, BRAND).save(STATIC / "android-chrome-192x192.png")
    raster(512, BRAND).save(STATIC / "android-chrome-512x512.png")

    raster(256, BRAND).save(
        STATIC / "favicon.ico",
        sizes=[(16, 16), (32, 32), (48, 48)],
    )

    og_image().save(images_dir / "og.png", optimize=True)

    print("brand assets written to", STATIC)


if __name__ == "__main__":
    main()
