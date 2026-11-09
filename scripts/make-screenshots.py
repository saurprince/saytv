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


# ---- iPad 13" (2064x2752), from real captures of the app on a tablet-size screen (raw-ipad/, 1536x2048) ----
RAW_IPAD = ROOT / "store/screenshots/raw-ipad"
IPAD_SIZE = (2064, 2752)
IPAD_DIR = "appstore/ipad-13in-2064x2752"
# (raw file, caption, crop box in the raw capture). The box drops the status bar at the top and the tablet's taskbar at the bottom;
# the short screens (setup, code) are also cut after their content so they are not mostly empty.
IPAD_SHOTS = [
    ("ipad-03-remote.png", "A full remote, too", (0, 50, 1536, 1925)),
    ("ipad-02-open-netflix.png", "Say it. Your TV does it.", (0, 50, 1536, 1925)),
    ("ipad-05-apps.png", "Your apps, your order", (0, 50, 1536, 1925)),
    ("ipad-06-suggestions.png", "Add any app on your TV", (0, 50, 1536, 1925)),
    ("ipad-08-dark-apps.png", "Light and dark themes", (0, 50, 1536, 1925)),
    # Not used: the setup and code screens are mostly empty on an iPad canvas (raw captures kept: ipad-01-setup, ipad-04-code-filled).
]


def compose_ipad(raw_path: Path, caption: str, box, out_path: Path):
    """Caption on top, the real screen below it, centred, as large as fits (width 84% at most)."""
    W, H = IPAD_SIZE
    canvas = gradient(W, H).convert("RGBA")
    d = ImageDraw.Draw(canvas)
    font_px = int(W * 0.052)
    font = ImageFont.truetype(str(FONTS / "roboto-bold.ttf"), font_px)
    y = int(H * 0.05)
    for ln in wrap(d, caption, font, W * 0.86):
        d.text(((W - d.textlength(ln, font=font)) / 2, y), ln, font=font, fill=(255, 255, 255, 255))
        y += int(font_px * 1.2)
    top = y + int(H * 0.03)

    shot = Image.open(raw_path).convert("RGB").crop(box)
    scale = min(W * 0.84 / shot.width, (H - top - int(H * 0.05)) / shot.height)
    tw, th = int(shot.width * scale), int(shot.height * scale)
    shot = shot.resize((tw, th), Image.LANCZOS)

    radius = int(W * 0.03)
    mask = Image.new("L", (tw * 2, th * 2), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, tw * 2 - 1, th * 2 - 1], radius=radius * 2, fill=255)
    mask = mask.resize((tw, th), Image.LANCZOS)
    x = (W - tw) // 2
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([x, top + 14, x + tw, top + th + 14], radius=radius, fill=(0, 0, 0, 110))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(int(W * 0.012))))
    canvas.paste(shot, (x, top), mask)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out_path)


if __name__ == "__main__":
    n = 0
    for sub, size in TARGETS.items():
        for i, (raw, caption) in enumerate(SHOTS, start=1):
            compose(RAW / raw, caption, size, OUT / sub / f"{i:02d}-{Path(raw).stem.split('-', 1)[1]}.png",
                    bleed=sub.startswith("appstore"))
            n += 1
    print(n, "screenshots written under", OUT)
    m = 0
    for raw, caption, box in IPAD_SHOTS:
        if (RAW_IPAD / raw).exists():  # the connected-remote captures are added once the emulator is paired
            m += 1
            compose_ipad(RAW_IPAD / raw, caption, box, OUT / IPAD_DIR / f"{m:02d}-{Path(raw).stem.split('-', 1)[1]}.png")
    print(m, "iPad screenshots written under", OUT / IPAD_DIR)
