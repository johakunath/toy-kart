"""Generate the game's small sound effects and the sparkle sprite. No downloads, no licences:
everything is synthesised here. Run via tools/make_sfx.ps1 (or the venv python directly).

Writes 16-bit mono WAV files to assets/sfx/ and assets/fx/sparkle.png.
"""
import os
import wave

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX = os.path.join(ROOT, "assets", "sfx")
FX = os.path.join(ROOT, "assets", "fx")
SR = 44100
rng = np.random.default_rng(7)


def t(seconds):
    return np.arange(int(SR * seconds)) / SR


def env(n, attack=0.005, release=0.05):
    e = np.ones(n)
    a = max(1, int(SR * attack))
    r = max(1, int(SR * release))
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r)
    return e


def tone(freq, seconds, shape="sine", decay=0.0, vibrato=0.0):
    x = t(seconds)
    phase = 2 * np.pi * freq * x
    if vibrato:
        phase += vibrato * np.sin(2 * np.pi * 6 * x)
    if shape == "sine":
        y = np.sin(phase)
    elif shape == "tri":
        y = 2 / np.pi * np.arcsin(np.sin(phase))
    elif shape == "soft_square":
        y = np.tanh(3.0 * np.sin(phase))
    else:
        y = np.sin(phase) + 0.5 * np.sin(2 * phase) + 0.25 * np.sin(3 * phase)
    if decay:
        y = y * np.exp(-decay * x)
    return y * env(len(y))


def mix_at(buf, sound, at_seconds, gain=1.0):
    i = int(at_seconds * SR)
    end = min(len(buf), i + len(sound))
    buf[i:end] += sound[: end - i] * gain


def save(name, y, peak=0.85):
    y = y / max(1e-9, np.max(np.abs(y))) * peak
    data = (y * 32767).astype("<i2")
    with wave.open(os.path.join(SFX, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def horn():
    # Toy "meep meep": two reedy notes a third apart, twice.
    one = tone(392, 0.16, "soft_square") + 0.8 * tone(494, 0.16, "soft_square")
    buf = np.zeros(int(SR * 0.42))
    mix_at(buf, one, 0.0)
    mix_at(buf, one, 0.22)
    save("horn.wav", buf, 0.7)


def star():
    buf = np.zeros(int(SR * 0.6))
    for i, f in enumerate([1047, 1319, 1568, 2093]):
        mix_at(buf, tone(f, 0.35, "sine", decay=9) + 0.3 * tone(f * 2, 0.35, "sine", decay=12), i * 0.06)
    save("star.wav", buf, 0.75)


def boost():
    n = t(0.8)
    sweep = np.sin(2 * np.pi * (280 * n + 520 * n * n))
    noise = rng.standard_normal(len(n))
    # crude rising band: smooth the noise less and less
    k = 60
    noise = np.convolve(noise, np.ones(k) / k, "same") * np.linspace(0.3, 1.0, len(n)) * 3
    y = (0.6 * sweep + noise) * env(len(n), 0.03, 0.35)
    buf = np.zeros(len(n))
    mix_at(buf, y, 0)
    for i, f in enumerate([1568, 2093, 2637]):
        mix_at(buf, tone(f, 0.25, "sine", decay=10), 0.05 + i * 0.07, 0.35)
    save("boost.wav", buf, 0.7)


def beeps():
    save("beep_low.wav", tone(440, 0.2, "tri", decay=4), 0.7)
    save("beep_high.wav", tone(880, 0.55, "tri", decay=3) + 0.4 * tone(1320, 0.55, "sine", decay=4), 0.75)


def ui():
    save("click.wav", tone(900, 0.05, "sine", decay=60), 0.5)
    buf = np.zeros(int(SR * 0.22))
    mix_at(buf, tone(660, 0.1, "tri", decay=14), 0.0)
    mix_at(buf, tone(990, 0.12, "tri", decay=12), 0.08)
    save("select.wav", buf, 0.6)
    n = t(0.3)
    f = 700 * np.exp(-6 * n) + 180
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(n), 0.005, 0.1)
    save("pop.wav", y, 0.7)


def fanfare():
    buf = np.zeros(int(SR * 2.6))
    notes = [(523, 0.0, 0.16), (523, 0.18, 0.16), (523, 0.36, 0.16), (659, 0.54, 0.3),
             (784, 0.86, 0.3), (1047, 1.2, 1.2)]
    for f, at, dur in notes:
        voice = tone(f, dur, "brass", decay=1.2, vibrato=0.02) + 0.5 * tone(f * 1.5, dur, "tri", decay=1.5)
        mix_at(buf, voice, at)
        mix_at(buf, tone(f / 2, dur, "tri", decay=1.0), at, 0.5)
    save("fanfare.wav", buf, 0.75)


def applause():
    seconds = 3.2
    buf = np.zeros(int(SR * seconds))
    clap_len = int(SR * 0.03)
    for _ in range(520):
        at = rng.uniform(0, seconds - 0.05)
        clap = rng.standard_normal(clap_len) * np.exp(-np.linspace(0, 7, clap_len))
        # light band-pass by differencing, so claps sound dry not boomy
        clap = np.diff(clap, prepend=0)
        fade = min(1.0, at / 0.4) * min(1.0, (seconds - at) / 1.2)
        mix_at(buf, clap, at, rng.uniform(0.3, 1.0) * fade)
    save("applause.wav", buf, 0.55)


def rumble():
    """Kerb rumble: quick low thuds, one per kerb stripe. A seamless 0.48 s loop."""
    seconds = 0.48
    n = int(SR * seconds)
    buf = np.zeros(n)
    thud_len = int(SR * 0.05)
    x = np.arange(thud_len) / SR
    for k in range(12):
        f = 70 + 20 * (k % 2)
        thud = np.sin(2 * np.pi * f * x) * np.exp(-55 * x)
        thud += 0.25 * rng.standard_normal(thud_len) * np.exp(-90 * x)
        mix_at(buf, thud, k * seconds / 12)
    save("rumble.wav", buf, 0.8)


def engine_high():
    """High engine layer, faded in at speed on top of the recorded engine: a buzzy toy-motor
    whine. A seamless 1 s loop (whole cycles of every partial and of the flutter)."""
    x = t(1.0)
    f = 180
    y = np.tanh(2.5 * np.sin(2 * np.pi * f * x)) * 0.6
    y += 0.35 * np.sin(2 * np.pi * 2 * f * x) + 0.15 * np.sin(2 * np.pi * 3 * f * x)
    y *= 0.8 + 0.2 * np.sin(2 * np.pi * 15 * x)  # cylinder flutter
    save("engine_high.wav", y, 0.6)


def turbo():
    """Turbo arrows: a short rising zip."""
    n = t(0.35)
    f = 300 + 1500 * n / 0.35
    y = np.tanh(2 * np.sin(2 * np.pi * np.cumsum(f) / SR)) * env(len(n), 0.005, 0.12)
    save("turbo.wav", y, 0.6)


def train_whistle():
    """Toy steam train: "tschu-tschuuu". Three breathy pipes a little out of tune, a short toot
    and a long one, each sliding up into pitch."""
    buf = np.zeros(int(SR * 1.35))
    for start, length in ((0.0, 0.28), (0.38, 0.85)):
        x = t(length)
        bend = 1.0 - 0.06 * np.exp(-x / 0.05)
        y = np.zeros(len(x))
        for f, g in ((587, 1.0), (740, 0.8), (880, 0.6)):
            y += g * np.sin(2 * np.pi * np.cumsum(f * bend) / SR)
        y += 0.35 * rng.standard_normal(len(x)) * (0.4 + 0.6 * np.exp(-x / 0.08))
        y = y * env(len(x), 0.03, 0.12) * (1.0 + 0.08 * np.sin(2 * np.pi * 5 * x))
        mix_at(buf, y, start)
    save("train_whistle.wav", buf, 0.6)


def train_chug():
    """Toy steam train: chuff-chuff-chuff-chuff with a soft rail clack. A seamless 1.0 s loop."""
    seconds = 1.0
    n = int(SR * seconds)
    buf = np.zeros(n)
    length = int(SR * 0.16)
    x = np.arange(length) / SR
    for k in range(4):
        noise = rng.standard_normal(length)
        # Crude low-pass: smooth the noise so the chuff is breathy, not hissy.
        noise = np.convolve(noise, np.ones(18) / 18, mode="same")
        chuff = noise * np.exp(-x / 0.045) * (1.0 if k % 2 == 0 else 0.7)
        mix_at(buf, chuff, k * seconds / 4)
        clack = np.sin(2 * np.pi * 1800 * x[: int(SR * 0.02)]) * np.exp(-x[: int(SR * 0.02)] / 0.004)
        mix_at(buf, clack, k * seconds / 4 + 0.11, 0.25)
    save("train_chug.wav", buf, 0.7)


def sparkle_png():
    size = 64
    yy, xx = np.mgrid[0:size, 0:size]
    cx = cy = (size - 1) / 2
    dx = np.abs(xx - cx) / (size / 2)
    dy = np.abs(yy - cy) / (size / 2)
    # four-point star: bright along the axes, falling off fast
    star_shape = np.clip(1.0 - (dx ** 0.55 + dy ** 0.55), 0, 1) ** 1.6
    glow = np.clip(1.0 - np.sqrt(dx * dx + dy * dy), 0, 1) ** 3 * 0.5
    a = np.clip(star_shape * 2.2 + glow, 0, 1)
    img = np.zeros((size, size, 4), dtype=np.uint8)
    img[:, :, :3] = 255
    img[:, :, 3] = (a * 255).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(os.path.join(FX, "sparkle.png"))


def dot_png():
    """Soft round glow for dust in the sunlight."""
    size = 32
    yy, xx = np.mgrid[0:size, 0:size]
    c = (size - 1) / 2
    r = np.sqrt((xx - c) ** 2 + (yy - c) ** 2) / (size / 2)
    a = np.clip(1.0 - r, 0, 1) ** 2.2
    img = np.zeros((size, size, 4), dtype=np.uint8)
    img[:, :, :3] = 255
    img[:, :, 3] = (a * 255).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(os.path.join(FX, "dot.png"))


def leaf_png():
    """A simple white leaf (tinted in the game) with a darker midrib."""
    size = 64
    yy, xx = np.mgrid[0:size, 0:size]
    x = (xx - (size - 1) / 2) / (size / 2)
    y = (yy - (size - 1) / 2) / (size / 2)
    # pointed oval: two circular arcs meeting at the tips
    inside = (np.abs(x) < 0.92) & (np.abs(y) < 0.46 * (1.0 - x * x) ** 0.8)
    edge = np.clip((0.46 * (1.0 - np.clip(x * x, 0, 1)) ** 0.8 - np.abs(y)) * 14, 0, 1)
    shade = np.where(np.abs(y) < 0.035, 0.72, 1.0) * (0.86 + 0.14 * (x + 1) / 2)
    img = np.zeros((size, size, 4), dtype=np.uint8)
    img[:, :, :3] = (255 * shade)[:, :, None].astype(np.uint8)
    img[:, :, 3] = (np.where(inside, edge, 0) * 255).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(os.path.join(FX, "leaf.png"))


def magic_rope():
    """The magic rope connects: a soft rising bell arpeggio with a shimmer on top."""
    buf = np.zeros(int(SR * 1.3))
    for i, f in enumerate([784, 988, 1175, 1568]):
        gain = 0.8 - 0.1 * i
        mix_at(buf, tone(f, 0.9, "sine", decay=4.5), i * 0.07, gain)
        mix_at(buf, tone(f * 2.01, 0.6, "sine", decay=7), i * 0.07, gain * 0.35)
        mix_at(buf, tone(f * 3.02, 0.4, "sine", decay=10), i * 0.07, gain * 0.15)
    n = t(1.0)
    shimmer = rng.standard_normal(len(n)) * np.sin(2 * np.pi * 7 * n) ** 2
    shimmer = np.convolve(shimmer, np.ones(6) / 6, mode="same") * np.exp(-3.5 * n)
    hp = shimmer - np.convolve(shimmer, np.ones(40) / 40, mode="same")
    mix_at(buf, hp * env(len(n), 0.05, 0.3), 0.05, 0.25)
    save("magic_rope.wav", buf, 0.6)


def gift():
    """A present flies over: a quick upward whoosh with a sparkly two-note chime."""
    buf = np.zeros(int(SR * 0.9))
    n = t(0.45)
    f = 300 + 900 * (n / 0.45) ** 1.5
    whoosh = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(n), 0.02, 0.15) * 0.5
    noise = rng.standard_normal(len(n))
    noise = (noise - np.convolve(noise, np.ones(12) / 12, mode="same")) * env(len(n), 0.05, 0.2) * 0.25
    mix_at(buf, whoosh + noise, 0.0)
    mix_at(buf, tone(1319, 0.4, "sine", decay=8), 0.3)
    mix_at(buf, tone(2637, 0.3, "sine", decay=12), 0.3, 0.3)
    mix_at(buf, tone(1760, 0.5, "sine", decay=6), 0.42)
    mix_at(buf, tone(3520, 0.3, "sine", decay=12), 0.42, 0.3)
    save("gift.wav", buf, 0.6)


def found():
    """Entdecken: a lost thing is found. A quick music-box run up with a sparkle on top."""
    buf = np.zeros(int(SR * 1.4))
    for i, f in enumerate([1047, 1319, 1568, 2093, 2637]):
        mix_at(buf, tone(f, 0.9, "sine", decay=5.5), i * 0.06, 0.8)
        mix_at(buf, tone(f * 2.0, 0.5, "sine", decay=9), i * 0.06, 0.25)
        mix_at(buf, tone(f * 4.07, 0.25, "sine", decay=18), i * 0.06, 0.1)
    n = t(0.8)
    sparkle = rng.standard_normal(len(n))
    sparkle = (sparkle - np.convolve(sparkle, np.ones(30) / 30, mode="same")) * np.exp(-5 * n)
    mix_at(buf, sparkle * env(len(n), 0.02, 0.3), 0.25, 0.12)
    save("found.wav", buf, 0.7)


def friend_happy():
    """Entdecken: a toy friend gets its thing back. Two bouncy boings up and a happy trill."""
    buf = np.zeros(int(SR * 1.3))
    for k, (f0, f1) in enumerate([(220, 440), (330, 660)]):
        n = t(0.28)
        f = f0 + (f1 - f0) * (n / 0.28) ** 0.6
        boing = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-6 * n) * env(len(n), 0.005, 0.05)
        mix_at(buf, boing, k * 0.22, 0.8)
    for i in range(8):
        f = [1319, 1568][i % 2]
        mix_at(buf, tone(f, 0.12, "tri", decay=12), 0.5 + i * 0.07, 0.35)
    save("friend_happy.wav", buf, 0.7)


def sleepy():
    """Entdecken: bedtime. A slow music-box tune going down, like a yawn."""
    buf = np.zeros(int(SR * 2.8))
    for i, f in enumerate([1568, 1319, 1175, 988, 784]):
        mix_at(buf, tone(f, 1.4, "sine", decay=2.6), i * 0.38, 0.8 - i * 0.08)
        mix_at(buf, tone(f * 2.0, 0.8, "sine", decay=6), i * 0.38, 0.2)
    save("sleepy.wav", buf, 0.6)


if __name__ == "__main__":
    os.makedirs(SFX, exist_ok=True)
    os.makedirs(FX, exist_ok=True)
    horn()
    star()
    boost()
    beeps()
    ui()
    fanfare()
    applause()
    rumble()
    turbo()
    engine_high()
    train_whistle()
    train_chug()
    sparkle_png()
    dot_png()
    leaf_png()
    magic_rope()
    gift()
    found()
    friend_happy()
    sleepy()
    print("sfx written to", SFX)
