"""Draws the key and pad-button pictures for the menu (assets/icons/key_*.svg, pad_*.svg)
and a few action icons (horn, brake, drift, swap). Plain stdlib, no fonts: every letter is a
stroked path, so Godot's SVG importer draws them the same everywhere.

    python tools/make_key_icons.py

Keycaps and pad buttons are full colour (draw them with modulate white).
Action icons are white shapes like the other icons (tinted by the UI).
"""
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "icons"
INK = "#1d2b53"
KEY_TOP = "#ffffff"
KEY_SIDE = "#c3cbe0"

# Letters as strokes in a 40 x 48 cell (y down).
GLYPHS = {
    "W": "M0,0 L9,48 L20,14 L31,48 L40,0",
    "A": "M2,48 L20,0 L38,48 M8,33 L32,33",
    "S": "M35,8 C31,2 25,0 20,0 C11,0 5,5 5,12 C5,30 37,18 37,36 C37,44 30,48 20,48 C12,48 6,45 3,39",
    "D": "M5,0 L5,48 L18,48 C31,48 37,38 37,24 C37,10 31,0 18,0 Z",
    "Q": "M20,0 C30,0 38,10 38,23 C38,37 30,46 20,46 C10,46 2,37 2,23 C2,10 10,0 20,0 Z M24,34 L38,50",
    "E": "M35,0 L5,0 L5,48 L35,48 M5,24 L30,24",
    "R": "M5,48 L5,0 L22,0 C32,0 36,6 36,13 C36,21 31,26 22,26 L5,26 M20,26 L36,48",
    "M": "M2,48 L2,0 L20,30 L38,0 L38,48",
    "X": "M3,0 L37,48 M37,0 L3,48",
    "Y": "M2,0 L20,24 L38,0 M20,24 L20,48",
    "B": "M5,24 L5,0 L21,0 C29,0 34,5 34,12 C34,19 29,24 21,24 L5,24 L5,48 L23,48 C32,48 37,43 37,36 C37,29 32,24 23,24",
    "L": "M5,0 L5,48 L35,48",
    "T": "M1,0 L39,0 M20,0 L20,48",
    ",": "M20,34 L20,40 C20,46 17,50 12,53",
    ".": "M20,42 L20,42.5",
}


def svg(width: int, height: int, body: str) -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width * 2}" height="{height * 2}" '
            f'viewBox="0 0 {width} {height}">{body}</svg>\n')


def stroke(d: str, color: str, width: float, transform: str = "") -> str:
    t = f' transform="{transform}"' if transform else ""
    return (f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{width}" '
            f'stroke-linecap="round" stroke-linejoin="round"{t}/>')


def text(chars: str, cx: float, cy: float, color: str, scale: float = 1.0, width: float = 9.0) -> str:
    """Letters centred on (cx, cy), 48 * scale tall."""
    advance = 50.0
    total = (len(chars) - 1) * advance + 40.0
    out = ""
    for i, ch in enumerate(chars):
        x = cx - total * scale / 2 + i * advance * scale
        y = cy - 24.0 * scale
        out += stroke(GLYPHS[ch], color, width / scale, f"translate({x:.1f},{y:.1f}) scale({scale})")
    return out


def keycap(width: int, inner: str) -> str:
    """A light key with a dark rim and a visible lower edge, 100 high."""
    body = (f'<rect x="3" y="3" width="{width - 6}" height="94" rx="20" fill="{INK}"/>'
            f'<rect x="9" y="9" width="{width - 18}" height="82" rx="15" fill="{KEY_SIDE}"/>'
            f'<rect x="9" y="9" width="{width - 18}" height="70" rx="15" fill="{KEY_TOP}"/>')
    return svg(width, 100, body + inner)


def write(name: str, content: str) -> None:
    (OUT / f"{name}.svg").write_text(content, encoding="utf-8")


def triangle(cx: float, cy: float, direction: str, r: float = 20.0) -> str:
    pts = {
        "up": [(cx, cy - r), (cx + r, cy + r * 0.75), (cx - r, cy + r * 0.75)],
        "down": [(cx, cy + r), (cx + r, cy - r * 0.75), (cx - r, cy - r * 0.75)],
        "left": [(cx - r, cy), (cx + r * 0.75, cy - r), (cx + r * 0.75, cy + r)],
        "right": [(cx + r, cy), (cx - r * 0.75, cy - r), (cx - r * 0.75, cy + r)],
    }[direction]
    p = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
    return f'<polygon points="{p}" fill="{INK}" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>'


def keys() -> None:
    for ch, name in [("W", "w"), ("A", "a"), ("S", "s"), ("D", "d"), ("Q", "q"), ("E", "e"),
                     ("R", "r"), ("M", "m"), (",", "comma"), (".", "period")]:
        inner = text(ch, 50, 44, INK, 0.82, 9.5)
        if ch == ".":
            inner = f'<circle cx="50" cy="56" r="8" fill="{INK}"/>'
        write(f"key_{name}", keycap(100, inner))
    for direction in ["up", "down", "left", "right"]:
        write(f"key_{direction}", keycap(100, triangle(50, 44, direction, 19)))
    # Space bar: a long key with the "space" bracket.
    write("key_space", keycap(220, stroke("M70,36 L70,56 L150,56 L150,36", INK, 9)))
    # Enter: the bent return arrow.
    write("key_enter", keycap(140, stroke("M100,22 L100,50 L42,50", INK, 9)
                              + stroke("M56,36 L40,50 L56,64", INK, 9)))
    # Backspace: a long arrow to the left.
    write("key_backspace", keycap(140, stroke("M104,44 L38,44", INK, 9)
                                  + stroke("M54,28 L36,44 L54,60", INK, 9)))


def pad() -> None:
    colours = {"a": "#3fb34f", "b": "#e5423c", "x": "#2f86e0", "y": "#f4c22b"}
    for name, colour in colours.items():
        letter = "#ffffff" if name != "y" else INK
        body = (f'<circle cx="50" cy="53" r="44" fill="{INK}"/>'
                f'<circle cx="50" cy="48" r="42" fill="{colour}" stroke="{INK}" stroke-width="5"/>'
                + text(name.upper(), 50, 48, letter, 0.85, 10))
        write(f"pad_{name}", svg(100, 100, body))
    # Shoulder buttons: dark pills. Triggers: taller dark caps.
    for name in ["lb", "rb"]:
        body = (f'<rect x="4" y="18" width="152" height="70" rx="35" fill="{INK}"/>'
                f'<rect x="10" y="14" width="140" height="64" rx="30" fill="#4a5578"/>'
                + text(name.upper(), 80, 46, "#ffffff", 0.72, 9.5))
        write(f"pad_{name}", svg(160, 100, body))
    for name in ["lt", "rt"]:
        body = (f'<path d="M24,96 L18,40 C18,14 38,4 60,4 C82,4 102,14 102,40 L96,96 Z" fill="{INK}"/>'
                f'<path d="M30,88 L25,40 C25,18 41,11 60,11 C79,11 95,18 95,40 L90,88 Z" fill="#4a5578"/>'
                + text(name.upper(), 60, 52, "#ffffff", 0.62, 9.5))
        write(f"pad_{name}", svg(120, 100, body))
    # Stick: seen from above, a ring with a grippy cap.
    body = (f'<circle cx="50" cy="50" r="46" fill="{INK}"/>'
            f'<circle cx="50" cy="50" r="40" fill="#8a93ad"/>'
            f'<circle cx="50" cy="50" r="27" fill="#4a5578" stroke="{INK}" stroke-width="4"/>'
            f'<circle cx="50" cy="50" r="15" fill="none" stroke="#8a93ad" stroke-width="4"/>')
    write("pad_stick", svg(100, 100, body))
    # D-pad: a plus with the up arm lit.
    plus = "M38,6 L62,6 L62,38 L94,38 L94,62 L62,62 L62,94 L38,94 L38,62 L6,62 L6,38 L38,38 Z"
    body = (f'<path d="{plus}" fill="#4a5578" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>'
            f'<polygon points="50,14 58,28 42,28" fill="#ffffff"/>')
    write("pad_dpad", svg(100, 100, body))


def actions() -> None:
    white = "#ffffff"
    # Horn: a bulb horn with sound waves.
    horn = ('<circle cx="22" cy="50" r="16" fill="#ffffff"/>'
            '<path d="M34,44 L62,30 L62,70 L34,56 Z" fill="#ffffff"/>'
            + stroke("M72,38 C78,44 78,56 72,62", white, 7)
            + stroke("M82,28 C94,40 94,60 82,72", white, 7))
    write("horn", svg(100, 100, horn))
    # Brake: a stop sign (octagon with a bar).
    # The bar is a hole, so the icon stays one colour when the UI tints it.
    brake = ('<path fill-rule="evenodd" fill="#ffffff" d="M30,6 L70,6 L94,30 L94,70 L70,94 L30,94 '
             'L6,70 L6,30 Z M24,42 L76,42 L76,58 L24,58 Z"/>')
    write("brake", svg(100, 100, brake))
    # Drift: a curved skid with sparks.
    drift = (stroke("M14,80 C30,80 40,70 46,52 C52,34 64,24 84,22", white, 11)
             + stroke("M70,10 L84,22 L72,36", white, 9)
             + '<circle cx="24" cy="56" r="7" fill="#ffffff"/><circle cx="12" cy="38" r="5" fill="#ffffff"/>')
    write("drift", svg(100, 100, drift))
    # Swap: two arrows, one over the other, pointing opposite ways.
    swap = (stroke("M16,34 L82,34", white, 11) + stroke("M64,16 L84,34 L64,52", white, 11)
            + stroke("M84,68 L18,68", white, 11) + stroke("M36,50 L16,68 L36,86", white, 11))
    write("swap", svg(100, 100, swap))


if __name__ == "__main__":
    keys()
    pad()
    actions()
    print("key icons written to", OUT)
