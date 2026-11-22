"""Stronger, toy-brick colours for the Kenney models (karts, characters, track pieces, trees).

    tools\\.venv\\Scripts\\python.exe tools\\make_strong_colors.py [--strength 1.0]

Kenney's models are coloured by one small palette picture per kit (Textures/colormap.png).
This makes their pastel colours stronger (more saturated, a little darker); greys and whites
stay. The untouched Kenney pictures are kept in art/kenney_colors/ and are always the starting
point, so running it again with another --strength is safe. --strength 0 restores Kenney's.
Johannes' own toys are not affected (their textures are elsewhere).
"""
import argparse
import colorsys
import os
import shutil

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KITS = {
    "car_kit": "assets/kenney_car_kit/Textures/colormap.png",
    "racing": "assets/kenney_racing/models/Textures/colormap.png",
    "toy_car_kit": "assets/kenney_toy_car_kit/Textures/colormap.png",
    "mini_characters": "assets/characters/kenney_mini/Textures/colormap.png",
}


def stronger(rgb, k):
    r, g, b = (c / 255.0 for c in rgb)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    # Greys (also bluish ones: road, metal) stay; the boost fades in between 0.2 and 0.4 saturation.
    ramp = min(1.0, max(0.0, (s - 0.2) / 0.2))
    if 0.02 < h < 0.12 and v > 0.55 and s < 0.6:
        ramp *= 0.25  # skin tones: only a little, or faces turn orange
    if ramp <= 0.0:
        return rgb
    # Saturation up (pastels gain most), value down a little for the strongly coloured ones.
    s2 = min(1.0, s + (1.0 - s) * 0.55 * k * ramp)
    v2 = v * (1.0 - 0.10 * k * ramp * s2)
    r, g, b = colorsys.hsv_to_rgb(h, s2, v2)
    return tuple(int(round(c * 255)) for c in (r, g, b))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--strength", type=float, default=1.0)
    args = ap.parse_args()
    keep = os.path.join(ROOT, "art", "kenney_colors")
    os.makedirs(keep, exist_ok=True)
    for kit, rel in KITS.items():
        target = os.path.join(ROOT, rel)
        original = os.path.join(keep, kit + ".png")
        if not os.path.exists(original):
            shutil.copy(target, original)
        img = Image.open(original).convert("RGBA")
        cache = {}
        px = img.load()
        for y in range(img.height):
            for x in range(img.width):
                r, g, b, a = px[x, y]
                if (r, g, b) not in cache:
                    cache[(r, g, b)] = stronger((r, g, b), args.strength)
                px[x, y] = cache[(r, g, b)] + (a,)
        img.save(target)
        print("COLORS", kit, len(cache), "colours")
    print("STRONG COLORS OK (strength %.2f)" % args.strength)


if __name__ == "__main__":
    main()
