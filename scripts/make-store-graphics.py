#!/usr/bin/env python3
"""Draws the app icon and the store graphics from code, so they can be regenerated and the name stays in one place (app/lib/branding.dart).

Writes:
  app/android/app/src/main/res/mipmap-*/ic_launcher*.png and mipmap-anydpi-v26/ic_launcher.xml   (Android icon, adaptive + legacy)
  app/ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png                                         (iPhone icon set, no alpha)
  store/art/icon-1024.png, play-icon-512.png, play-feature-1024x500.png                           (store uploads)

Needs Pillow. Fonts: Roboto (Apache-2.0) from the Flutter SDK.
Run:  python scripts/make-store-graphics.py
"""
import json
import re
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "app/android/app/src/main/res"
IOS = ROOT / "app/ios/Runner/Assets.xcassets/AppIcon.appiconset"
OUT = ROOT / "store/art"
FONTS = Path(r"C:\dev\flutter\bin\cache\artifacts\material_fonts")

TEAL_LIGHT = (0, 137, 123)
TEAL_DARK = (0, 70, 60)
WHITE = (255, 255, 255, 255)
SS = 4  # supersampling for smooth edges


def app_name() -> str:
    text = (ROOT / "app/lib/branding.dart").read_text(encoding="utf-8")
    return re.search(r"const String appName = '([^']+)'", text).group(1)


def gradient(size: int) -> Image.Image:
    v = Image.linear_gradient("L").resize((size, size))
    h = v.rotate(90)
    diag = ImageChops.add(v, h, scale=2)
    return Image.composite(Image.new("RGB", (size, size), TEAL_DARK), Image.new("RGB", (size, size), TEAL_LIGHT), diag)


def _line(d: ImageDraw.ImageDraw, p0, p1, w):
    d.line([p0, p1], fill=WHITE, width=int(w))
    r = w / 2
    for x, y in (p0, p1):
        d.ellipse([x - r, y - r, x + r, y + r], fill=WHITE)


def _arc(d: ImageDraw.ImageDraw, cx, cy, r, a0, a1, w):
    import math
    # Pillow draws the stroke inward from the box, so the box is [w/2] larger than the centre line the end caps sit on.
    ro = r + w / 2
    d.arc([cx - ro, cy - ro, cx + ro, cy + ro], a0, a1, fill=WHITE, width=int(w))
    rr = w / 2
    for a in (a0, a1):
        x = cx + r * math.cos(math.radians(a))
        y = cy + r * math.sin(math.radians(a))
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=WHITE)


def glyph(size: int, g: float) -> Image.Image:
    """A TV with a microphone and sound waves on its screen, white on transparent, [g] = TV width as a fraction of the canvas."""
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    W = g * S
    cx = S / 2
    H = 0.66 * W
    total = H + 0.12 * W
    y0 = (S - total) / 2
    y1 = y0 + H
    stroke = 0.07 * W
    # screen
    d.rounded_rectangle([cx - W / 2, y0, cx + W / 2, y1], radius=0.12 * W, outline=WHITE, width=int(stroke))
    # stand
    _line(d, (cx, y1 + 0.01 * W), (cx, y1 + 0.08 * W), 0.05 * W)
    _line(d, (cx - 0.2 * W, y1 + 0.095 * W), (cx + 0.2 * W, y1 + 0.095 * W), 0.05 * W)
    # microphone
    mic_cy = y0 + H / 2 - 0.03 * W
    cap_w, cap_h = 0.13 * W, 0.25 * W
    d.rounded_rectangle([cx - cap_w / 2, mic_cy - cap_h / 2, cx + cap_w / 2, mic_cy + cap_h / 2], radius=cap_w / 2, fill=WHITE)
    cr = 0.115 * W
    _arc(d, cx, mic_cy + 0.01 * W, cr, 15, 165, 0.035 * W)
    stem_top = mic_cy + 0.01 * W + cr
    _line(d, (cx, stem_top), (cx, stem_top + 0.045 * W), 0.035 * W)
    _line(d, (cx - 0.06 * W, stem_top + 0.045 * W), (cx + 0.06 * W, stem_top + 0.045 * W), 0.035 * W)
    # sound waves either side of the microphone
    for r in (0.21 * W, 0.285 * W):
        _arc(d, cx, mic_cy, r, -34, 34, 0.032 * W)
        _arc(d, cx, mic_cy, r, 146, 214, 0.032 * W)
    return img.resize((size, size), Image.LANCZOS)


def icon(size: int, g: float = 0.60) -> Image.Image:
    base = gradient(size).convert("RGBA")
    base.alpha_composite(glyph(size, g))
    return base


def rounded(img: Image.Image, radius_frac: float) -> Image.Image:
    s = img.size[0]
    mask = Image.new("L", (s * SS, s * SS), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, s * SS - 1, s * SS - 1], radius=radius_frac * s * SS, fill=255)
    mask = mask.resize((s, s), Image.LANCZOS)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def write_android():
    legacy = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    adaptive = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
    master = icon(1024)
    for dens, px in legacy.items():
        d = RES / f"mipmap-{dens}"
        d.mkdir(parents=True, exist_ok=True)
        rounded(master.resize((px, px), Image.LANCZOS), 0.22).save(d / "ic_launcher.png")
    for dens, px in adaptive.items():
        d = RES / f"mipmap-{dens}"
        gradient(px).convert("RGB").save(d / "ic_launcher_background.png")
        # the adaptive mask keeps a circle of about 61% of the canvas safe, so the glyph is drawn smaller here
        glyph(px, 0.47).save(d / "ic_launcher_foreground.png")
    any_dir = RES / "mipmap-anydpi-v26"
    any_dir.mkdir(parents=True, exist_ok=True)
    (any_dir / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@mipmap/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        "</adaptive-icon>\n",
        encoding="utf-8",
    )


def write_ios():
    master = icon(1024).convert("RGB")  # the App Store icon must have no transparency
    contents = json.loads((IOS / "Contents.json").read_text(encoding="utf-8"))
    for item in contents["images"]:
        m = re.match(r"(\d+(?:\.\d+)?)x\d+(?:\.\d+)?", item["size"])
        scale = int(item["scale"].rstrip("x"))
        px = round(float(m.group(1)) * scale)
        master.resize((px, px), Image.LANCZOS).save(IOS / item["filename"])


def write_store():
    OUT.mkdir(parents=True, exist_ok=True)
    master = icon(1024)
    master.convert("RGB").save(OUT / "icon-1024.png")
    master.resize((512, 512), Image.LANCZOS).save(OUT / "play-icon-512.png")  # Play masks it itself: full square, no rounding

    W, H = 1024, 500
    bg = gradient(1024).resize((W, W)).crop((0, 262, W, 262 + H)).convert("RGBA")
    badge = rounded(icon(512), 0.22).resize((300, 300), Image.LANCZOS)
    bg.alpha_composite(badge, (88, 100))
    d = ImageDraw.Draw(bg)
    title = ImageFont.truetype(str(FONTS / "roboto-bold.ttf"), 132)
    tag = ImageFont.truetype(str(FONTS / "roboto-medium.ttf"), 42)
    small = ImageFont.truetype(str(FONTS / "roboto-regular.ttf"), 30)
    d.text((440, 108), app_name(), font=title, fill=WHITE)
    d.text((444, 262), "Voice remote for OTT apps", font=tag, fill=WHITE)
    d.text((444, 322), "Open apps  \u2022  Volume  \u2022  Navigate", font=small, fill=(255, 255, 255, 220))
    bg.convert("RGB").save(OUT / "play-feature-1024x500.png")


if __name__ == "__main__":
    write_android()
    write_ios()
    write_store()
    print("icons and store graphics written for", app_name())
