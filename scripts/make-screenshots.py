#!/usr/bin/env python3
"""Turns the raw emulator captures in store/screenshots/raw/ into captioned store screenshots.

  store/screenshots/play/*.png                       1080x1920   (Google Play phone screenshots)
  store/screenshots/appstore/6.9in-1320x2868/*.png   (App Store, iPhone 6.9")
  store/screenshots/appstore/6.7in-1290x2796/*.png   (App Store, iPhone 6.7")

Each image is the real app screen (system status bar cropped away) floating under a caption on the brand gradient. No device frame:
the App Store does not allow another platform's device in its screenshots. If you later capture real iPhone screens, replace the
raw files (same names) and run this again.

Needs Pillow. Fonts: Roboto (Apache-2.0) from the Flutter SDK.   Run: python scripts/make-screenshots.py
"""
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "store/screenshots/raw"
OUT = ROOT / "store/screenshots"
FONTS = Path(r"C:\dev\flutter\bin\cache\artifacts\material_fonts")

TEAL_LIGHT = (0, 137, 123)
TEAL_DARK = (0, 70, 60)

# (raw file, caption) in the order they appear in the store
SHOTS = [
    ("04-open-netflix.png", "Say it. Your TV does it."),
    ("03-remote.png", "A full remote, too"),
    ("05-apps.png", "One tap to your apps"),
    ("06-edit-apps.png", "Your apps, your order"),
    ("07-add-app.png", "Add any app on your TV"),
    ("02b-code-filled.png", "Pair with one code"),
    ("08-dark.png", "Light and dark themes"),
]

TARGETS = {
    "play": (1080, 1920),
    "appstore/6.9in-1320x2868": (1320, 2868),
    "appstore/6.7in-1290x2796": (1290, 2796),
}


def gradient(w: int, h: int) -> Image.Image:
    v = Image.linear_gradient("L").resize((w, h))
    hz = Image.linear_gradient("L").rotate(90).resize((w, h))
    diag = ImageChops.add(v, hz, scale=2)
    return Image.composite(Image.new("RGB", (w, h), TEAL_DARK), Image.new("RGB", (w, h), TEAL_LIGHT), diag)


def wrap(draw, text, font, max_w):
    words, lines, cur = text.split(), [], ""
    for w in words:
        trial = (cur + " " + w).strip()
        if draw.textlength(trial, font=font) <= max_w or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = w
    lines.append(cur)
    return lines


def compose(raw_path: Path, caption: str, size, out_path: Path, bleed: bool = False):
    """[bleed]: the screen is as wide as fits and runs off the bottom edge, the caption is centred in the space above it
    (for the tall iPhone canvases). Otherwise the caption sits at the top and the screen follows it."""
    W, H = size
    canvas = gradient(W, H).convert("RGBA")
    d = ImageDraw.Draw(canvas)

    shot = Image.open(raw_path).convert("RGB")
    shot = shot.crop((0, 66, shot.width, shot.height))  # drop the system status bar
    if bleed:
        target_w = int(W * 0.94)
        target_h = int(shot.height * target_w / shot.width)
        top = H - target_h + int(W * 0.03)  # a little of the bottom is cut off by the canvas edge
        font_px = int(W * 0.092)
    else:
        target_w = int(W * 0.84)
        target_h = int(shot.height * target_w / shot.width)
        top = None
        font_px = int(W * 0.078)

    font = ImageFont.truetype(str(FONTS / "roboto-bold.ttf"), font_px)
    lines = wrap(d, caption, font, W * 0.86)
    line_h = int(font_px * 1.2)
    if bleed:
        y = max(int(H * 0.03), (top - line_h * len(lines)) // 2)
    else:
        y = int(H * 0.055)
    for ln in lines:
        d.text(((W - d.textlength(ln, font=font)) / 2, y), ln, font=font, fill=(255, 255, 255, 255))
        y += line_h
    if top is None:
        top = y + int(H * 0.035)

    shot = shot.resize((target_w, target_h), Image.LANCZOS)

    radius = int(W * 0.05)
    mask = Image.new("L", (target_w * 2, target_h * 2), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, target_w * 2 - 1, target_h * 2 - 1], radius=radius * 2, fill=255)
    mask = mask.resize((target_w, target_h), Image.LANCZOS)

    x = (W - target_w) // 2
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([x, top + 14, x + target_w, top + target_h + 14], radius=radius, fill=(0, 0, 0, 110))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(int(W * 0.018))))
    canvas.paste(shot, (x, top), mask)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out_path)  # 24-bit, no alpha: both stores want that


if __name__ == "__main__":
    n = 0
    for sub, size in TARGETS.items():
        for i, (raw, caption) in enumerate(SHOTS, start=1):
            compose(RAW / raw, caption, size, OUT / sub / f"{i:02d}-{Path(raw).stem.split('-', 1)[1]}.png",
                    bleed=sub.startswith("appstore"))
            n += 1
    print(n, "screenshots written under", OUT)
