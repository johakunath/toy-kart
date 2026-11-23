"""App icon: glossy "TR" letters with white/navy outline on a rounded sky tile with a checkered band.
python tools/make_app_icon.py <tr.png> assets/ui/icon.png assets/ui/icon.ico
"""
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

N = 1024
NAVY = (16, 28, 92, 255)
tile = Image.new("RGBA", (N, N), (0, 0, 0, 0))
mask = Image.new("L", (N, N), 0)
ImageDraw.Draw(mask).rounded_rectangle([16, 16, N - 16, N - 16], radius=190, fill=255)
grad = Image.new("RGB", (1, N))
for y in range(N):
    t = y / N
    grad.putpixel((0, y), (round(18 + 100 * t), round(110 + 95 * t), 235 + round(20 * t)))
bg = grad.resize((N, N)).convert("RGBA")
d = ImageDraw.Draw(bg)
# checkered band near the bottom
sq = N / 10
for c in range(10):
    for r in range(2):
        col = (255, 255, 255, 255) if (c + r) % 2 == 0 else (20, 20, 30, 255)
        d.rectangle([c * sq, N - 270 + r * sq, (c + 1) * sq, N - 270 + (r + 1) * sq], fill=col)
d.rectangle([0, N - 270 - 14, N, N - 270], fill=NAVY)
d.rectangle([0, N - 270 + 2 * sq, N, N - 270 + 2 * sq + 14], fill=NAVY)
d.rectangle([0, N - 270 + 2 * sq + 14, N, N], fill=(60, 175, 30, 255))
tile.paste(bg, (0, 0), mask)
# navy rim
rim = Image.new("RGBA", (N, N), (0, 0, 0, 0))
ImageDraw.Draw(rim).rounded_rectangle([16, 16, N - 16, N - 16], radius=190, outline=NAVY, width=28)
tile.alpha_composite(rim)

tr = Image.open(sys.argv[1]).convert("RGBA")
tr = tr.crop(tr.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox())
a = tr.getchannel("A")
tr = ImageEnhance.Color(tr.convert("RGB")).enhance(1.3).convert("RGBA")
tr.putalpha(a)
tw = 800
tr = tr.resize((tw, round(tr.height * tw / tr.width)), Image.LANCZOS)
layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
pos = ((N - tw) // 2, (N - tr.height) // 2 - 70)
layer.alpha_composite(tr, pos)


def grow(alpha, r):
    b = alpha.filter(ImageFilter.GaussianBlur(r / 2))
    return b.point(lambda v: 0 if v < 14 else 255 if v > 26 else int((v - 14) * 255 / 12))


def flat(alpha, rgba):
    im = Image.new("RGBA", alpha.size, rgba)
    im.putalpha(alpha)
    return im


la = layer.getchannel("A")
wa = grow(la, 36)
na = grow(wa, 28)
tile.alpha_composite(flat(na, NAVY))
tile.alpha_composite(flat(wa, (255, 255, 255, 255)))
tile.alpha_composite(layer)

icon = tile.resize((256, 256), Image.LANCZOS)
icon.save(sys.argv[2])
tile.save(sys.argv[3], sizes=[(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)])
print("ICON done")
