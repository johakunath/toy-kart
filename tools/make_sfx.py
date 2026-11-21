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
    sparkle_png()
    print("sfx written to", SFX)
