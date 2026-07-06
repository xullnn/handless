#!/usr/bin/env python3
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ICONSET = ROOT / ".build" / "app-icon.iconset"
OUTPUT = ROOT / "Resources" / "AppIcon.icns"


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Helvetica.ttc",
        "/System/Library/Fonts/SFNS.ttf",
    ]
    for candidate in candidates:
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            continue
    return ImageFont.load_default()


def make_icon(size: int) -> Image.Image:
    scale = size / 1024.0
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    margin = int(92 * scale)
    radius = int(220 * scale)
    rect = [margin, margin, size - margin, size - margin]

    draw.rounded_rectangle(rect, radius=radius, fill=(22, 107, 236, 255))
    inner = [margin + int(38 * scale), margin + int(38 * scale), size - margin - int(38 * scale), size - margin - int(38 * scale)]
    draw.rounded_rectangle(inner, radius=int(180 * scale), outline=(124, 198, 255, 230), width=max(2, int(22 * scale)))

    font = load_font(int(286 * scale))
    text = "LVI"
    box = draw.textbbox((0, 0), text, font=font)
    text_width = box[2] - box[0]
    text_height = box[3] - box[1]
    x = (size - text_width) / 2
    y = size * 0.36 - text_height / 2
    draw.text((x, y), text, font=font, fill=(255, 255, 255, 255))

    wave_y = int(size * 0.66)
    bar_width = max(2, int(32 * scale))
    gap = max(2, int(26 * scale))
    heights = [78, 146, 214, 286, 214, 146, 78]
    total_width = len(heights) * bar_width + (len(heights) - 1) * gap
    start_x = (size - total_width) / 2
    for index, raw_height in enumerate(heights):
        height = int(raw_height * scale)
        x0 = int(start_x + index * (bar_width + gap))
        y0 = wave_y - height // 2
        x1 = x0 + bar_width
        y1 = wave_y + height // 2
        draw.rounded_rectangle([x0, y0, x1, y1], radius=bar_width // 2, fill=(255, 255, 255, 235))

    return image


def write_iconset() -> None:
    ICONSET.mkdir(parents=True, exist_ok=True)
    specs = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]
    for filename, size in specs:
        make_icon(size).save(ICONSET / filename)


def main() -> None:
    write_iconset()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["iconutil", "-c", "icns", str(ICONSET), "-o", str(OUTPUT)], check=True)
    print(f"Wrote {OUTPUT}")


if __name__ == "__main__":
    main()
