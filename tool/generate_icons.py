"""Builds Hugo's launcher icons from the logo geometry.

The geometry matches assets/logo/hugo_logo.svg and HugoLogo in
lib/widgets/common.dart (a 32x32 grid). Change all three together.

    python tool/generate_icons.py

Needs Pillow (pip install pillow). Writes:
  - Android legacy icons: android/app/src/main/res/mipmap-*/ic_launcher.png
  - iOS app icons:        ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png
  - Store icons:          assets/logo/hugo_icon_1024.png, play_store_512.png

The Android adaptive icon (Android 8+) is a vector drawable and is not
generated here: see res/drawable/ic_launcher_foreground.xml.
"""

import json
import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
AMBER = (0xF5, 0xB8, 0x3D, 255)
INK = (0x1A, 0x13, 0x00, 255)
SUPERSAMPLE = 8

TOP_FACE = [(16, 8), (23, 12), (16, 16), (9, 12)]
CUBE = [(16, 8), (23, 12), (23, 20), (16, 24), (9, 20), (9, 12), (16, 8)]
CUBE_STEM = [(16, 16), (16, 24)]
ARMS = [
    ((5.5, 13), (4.5, 22.5), (12, 25.5)),
    ((26.5, 13), (27.5, 22.5), (20, 25.5)),
]
STROKE = 2


def quad(p0, c, p1, steps=48):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        a, b, d = (1 - t) ** 2, 2 * (1 - t) * t, t**2
        pts.append((a * p0[0] + b * c[0] + d * p1[0], a * p0[1] + b * c[1] + d * p1[1]))
    return pts


def render(size, rounded):
    """Renders the logo at size x size. rounded=False gives a full-bleed square."""
    big = size * SUPERSAMPLE
    s = big / 32
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    if rounded:
        draw.rounded_rectangle([0, 0, big - 1, big - 1], radius=8 * s, fill=AMBER)
    else:
        draw.rectangle([0, 0, big, big], fill=AMBER)

    def scaled(points):
        return [(x * s, y * s) for x, y in points]

    width = STROKE * s
    r = width / 2

    def stroke(points):
        pts = scaled(points)
        draw.line(pts, fill=INK, width=round(width), joint="curve")
        for x, y in pts:  # round caps and joins
            draw.ellipse([x - r, y - r, x + r, y + r], fill=INK)

    draw.polygon(scaled(TOP_FACE), fill=INK)
    stroke(CUBE)
    stroke(CUBE_STEM)
    for p0, c, p1 in ARMS:
        curve = quad(p0, c, p1)
        draw.line(scaled(curve), fill=INK, width=round(width), joint="curve")
        for x, y in scaled([curve[0], curve[-1]]):
            draw.ellipse([x - r, y - r, x + r, y + r], fill=INK)

    return img.resize((size, size), Image.LANCZOS)


def save_opaque(img, path):
    """App stores reject icons with an alpha channel."""
    img.convert("RGB").save(path, optimize=True)


def android():
    res = ROOT / "android/app/src/main/res"
    for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        render(size, rounded=True).save(res / f"mipmap-{density}/ic_launcher.png", optimize=True)
        print(f"android {density}: {size}px")


def ios():
    icon_set = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((icon_set / "Contents.json").read_text())
    for image in contents["images"]:
        name = image.get("filename")
        if not name:
            continue
        points = float(image["size"].split("x")[0])
        scale = int(re.match(r"(\d+)x", image["scale"]).group(1))
        size = round(points * scale)
        # iOS applies its own corner mask, so the icon is a full square.
        save_opaque(render(size, rounded=False), icon_set / name)
        print(f"ios {name}: {size}px")


def store():
    logo = ROOT / "assets/logo"
    save_opaque(render(1024, rounded=False), logo / "hugo_icon_1024.png")
    save_opaque(render(512, rounded=False), logo / "play_store_512.png")
    print("store icons: 1024px, 512px")


if __name__ == "__main__":
    android()
    ios()
    store()
