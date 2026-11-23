"""Compose the splash: sky with sunburst, clouds, green hill, the rendered toys and the logo.
python tools/make_splash.py <toys.png> <logo.png> <out.png>
"""
import math, sys
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

W, H = 1920, 1080
SS = 2
toys = Image.open(sys.argv[1]).convert("RGBA").resize((W, H), Image.LANCZOS)
logo = Image.open(sys.argv[2]).convert("RGBA")

# sky gradient
sky = Image.new("RGB", (1, H))
top, bottom = (18, 110, 235), (120, 205, 255)
for y in range(H):
    t = min(1.0, y / (H * 0.62))
    sky.putpixel((0, y), tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
bg = sky.resize((W, H)).convert("RGBA")

# sunburst rays from behind the logo
cx, cy = W / 2, 200
rays = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
d = ImageDraw.Draw(rays)
n = 24
R = 2600
for i in range(n):
    if i % 2:
        continue
    a0 = 2 * math.pi * i / n
    a1 = 2 * math.pi * (i + 1) / n
    d.polygon([(cx * SS, cy * SS),
               ((cx + R * math.cos(a0)) * SS, (cy + R * math.sin(a0)) * SS),
               ((cx + R * math.cos(a1)) * SS, (cy + R * math.sin(a1)) * SS)], fill=(255, 255, 255, 34))
rays = rays.resize((W, H), Image.LANCZOS)
bg.alpha_composite(rays)

# puffy clouds
clouds = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
d = ImageDraw.Draw(clouds)
for (x, y, s) in [(140, 610, 1.0), (1780, 640, 1.15), (560, 520, 0.7), (1380, 520, 0.75)]:
    for dx, dy, r in [(-70, 10, 48), (-20, -22, 62), (45, -8, 54), (95, 14, 40), (10, 24, 50)]:
        X, Y, Rr = (x + dx * s) * SS, (y + dy * s) * SS, r * s * SS
        d.ellipse([X - Rr, Y - Rr, X + Rr, Y + Rr], fill=(255, 255, 255, 235))
clouds = clouds.resize((W, H), Image.LANCZOS)
bg.alpha_composite(clouds)

# green hill the toys stand on, with a lighter rim
hill = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
d = ImageDraw.Draw(hill)
d.ellipse([-700 * SS, 640 * SS, (W + 700) * SS, 2300 * SS], fill=(120, 215, 40, 255))
d.ellipse([-700 * SS, 662 * SS, (W + 700) * SS, 2300 * SS], fill=(60, 175, 30, 255))
hill = hill.resize((W, H), Image.LANCZOS)
bg.alpha_composite(hill)
# soft darker vignette towards the bottom of the grass
shade = Image.new("L", (1, H))
for y in range(H):
    shade.putpixel((0, y), int(max(0, (y - 800) / 280) * 70))
shade = shade.resize((W, H))
dark = Image.new("RGBA", (W, H), (20, 90, 20, 255))
dark.putalpha(shade)
bg.alpha_composite(dark)

# toys: a touch more colour
ta = toys.getchannel("A")
toys_rgb = ImageEnhance.Color(toys.convert("RGB")).enhance(1.15).convert("RGBA")
toys_rgb.putalpha(ta)
bg.alpha_composite(toys_rgb)

# logo on top
lw = int(sys.argv[4]) if len(sys.argv) > 4 else 1240
logo = logo.resize((lw, round(logo.height * lw / logo.width)), Image.LANCZOS)
bg.alpha_composite(logo, ((W - lw) // 2, 18))

bg.convert("RGB").save(sys.argv[3])
print("SPLASH", sys.argv[3])
