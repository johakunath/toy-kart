"""Compose the logo: 3D letters + white and navy outline + checkered banner + speed lines.
python tools/make_logo.py <letters.png> assets/ui/logo.png
"""
import math, sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageEnhance

NAVY = (16, 28, 92, 255)
WHITE = (255, 255, 255, 255)
W = 1900
SS = 2  # supersampling for the drawn parts

letters = Image.open(sys.argv[1]).convert("RGBA")
letters = letters.crop(letters.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox())
lw = 1330
letters = letters.resize((lw, round(letters.height * lw / letters.width)), Image.LANCZOS)
lh = letters.height
_a = letters.getchannel("A")
letters = ImageEnhance.Contrast(ImageEnhance.Color(letters.convert("RGB")).enhance(1.3)).enhance(1.08).convert("RGBA")
letters.putalpha(_a)

pad = 60
H = lh + 2 * pad + 70
lx, ly = 330, pad

# --- checkered banner behind the lower part of the letters (wavy, 2 rows) ---
banner = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
d = ImageDraw.Draw(banner)
cols, rows = 26, 2
bx0, bx1 = 300, lx + lw + 30
sq = (bx1 - bx0) / cols
by = ly + lh * 0.80


def wave(x):
    return 14 * math.sin((x - bx0) / (bx1 - bx0) * math.pi * 2.2)


def pt(x, y):
    return ((x) * SS, (y + wave(x)) * SS)


outline = [pt(bx0 + t * (bx1 - bx0) / 80, by - 8) for t in range(81)]
outline += [pt(bx1 - t * (bx1 - bx0) / 80, by + rows * sq + 8) for t in range(81)]
d.polygon(outline, fill=NAVY)
for c in range(cols):
    for r in range(rows):
        x0, x1 = bx0 + c * sq, bx0 + (c + 1) * sq
        y0, y1 = by + r * sq, by + (r + 1) * sq
        col = (255, 255, 255, 255) if (c + r) % 2 == 0 else (20, 20, 30, 255)
        d.polygon([pt(x0, y0), pt(x1, y0), pt(x1, y1), pt(x0, y1)], fill=col)
banner = banner.resize((W, H), Image.LANCZOS)

# --- speed lines left of the T ---
speed = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
d = ImageDraw.Draw(speed)
for i, (y, length) in enumerate([(0.24, 150), (0.44, 210), (0.64, 130)]):
    yy = ly + lh * y
    x1 = lx + 10 - i * 12
    x0 = x1 - length
    d.rounded_rectangle([x0 * SS, (yy - 13) * SS, x1 * SS, (yy + 13) * SS], radius=13 * SS, fill=[(235, 30, 30, 255), (255, 196, 0, 255), (20, 90, 225, 255)][i])
speed = speed.resize((W, H), Image.LANCZOS)

# --- letters layer ---
let = Image.new("RGBA", (W, H), (0, 0, 0, 0))
let.alpha_composite(letters, (lx, ly))


def grow(alpha, r):
    """Round dilation: blur then threshold."""
    a = alpha.filter(ImageFilter.GaussianBlur(r / 2))
    return a.point(lambda v: 0 if v < 14 else 255 if v > 26 else int((v - 14) * 255 / 12))


def flat(alpha, rgba):
    im = Image.new("RGBA", alpha.size, rgba)
    im.putalpha(alpha)
    return im


front = Image.new("RGBA", (W, H), (0, 0, 0, 0))
front.alpha_composite(speed)
front.alpha_composite(let)
a = front.getchannel("A")
white_a = grow(a, 26)
navy_a = grow(white_a, 22)

base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
# banner gets its own white rim so it pops
ba = banner.getchannel("A")
all_navy = ImageChops.lighter(navy_a, grow(ba, 20))
shadow = flat(all_navy.filter(ImageFilter.GaussianBlur(10)).point(lambda v: v * 0.45), (5, 10, 50, 255))
base.alpha_composite(shadow, (10, 16))
base.alpha_composite(flat(grow(ba, 20), NAVY))
base.alpha_composite(banner)
base.alpha_composite(flat(navy_a, NAVY))
base.alpha_composite(flat(white_a, WHITE))
# navy strokes on the speed lines for contrast
sa = speed.getchannel("A")
base.alpha_composite(flat(grow(sa, 10), NAVY))
base.alpha_composite(speed)
base.alpha_composite(let)

base = base.crop(base.getchannel("A").point(lambda v: 255 if v > 3 else 0).getbbox())
OUT_W = 1600
inner = OUT_W - 24
base = base.resize((inner, round(base.height * inner / base.width)), Image.LANCZOS)
canvas = Image.new("RGBA", (OUT_W, base.height + 24), (0, 0, 0, 0))
canvas.alpha_composite(base, (12, 12))
canvas.save(sys.argv[2])
print("LOGO", canvas.size)
