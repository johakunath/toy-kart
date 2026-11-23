"""Generate the game's music: a calm menu tune and an upbeat race tune, both seamless loops.
No downloads, no licences: everything is synthesised here, like tools/make_sfx.py.

    tools\\.venv\\Scripts\\python.exe tools\\make_music.py

Writes assets/music/menu.wav, race.wav and race_final.wav (16-bit stereo). The .import files are
set to loop, so Godot plays them round and round without a gap.

Songs are written as text: one bar per string, eight eighth notes per bar.
A note name ("C5") starts a note, "~" holds the note before, "." is a rest.
"""
import os
import re
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "music")
SR = 44100
rng = np.random.default_rng(3)

NOTE_INDEX = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
CHORDS = {
    "C": ["C3", "E3", "G3"], "G": ["G2", "B2", "D3"], "Am": ["A2", "C3", "E3"], "F": ["F2", "A2", "C3"],
    "Dm": ["D3", "F3", "A3"], "Em": ["E3", "G3", "B3"],
}


def freq(name):
    m = re.match(r"^([A-G])([#b]?)(\d)$", name)
    n = NOTE_INDEX[m.group(1)] + {"#": 1, "b": -1, "": 0}[m.group(2)]
    midi = 12 * (int(m.group(3)) + 1) + n
    return 440.0 * 2 ** ((midi - 69) / 12)


def t(n):
    return np.arange(n) / SR


def adsr(n, a=0.01, d=0.08, s=0.6, r=0.08):
    e = np.full(n, s)
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = max(1, min(na, n))
    e[:na] = np.linspace(0, 1, na)
    if na + nd < n:
        e[na:na + nd] = np.linspace(1, s, nd)
    nr = max(1, min(nr, n))
    e[-nr:] *= np.linspace(1, 0, nr)
    return e


# --- Instruments: each returns a mono signal for one note of n samples -------------------------

def lead(f, n):
    """Bright, friendly square-ish lead with a little vibrato."""
    x = t(n)
    phase = 2 * np.pi * f * x + 0.004 * f * np.sin(2 * np.pi * 5.5 * x) * np.clip(x * 4, 0, 1)
    y = np.tanh(2.2 * np.sin(phase)) * 0.7 + 0.3 * np.sin(2 * phase)
    return y * adsr(n, 0.008, 0.12, 0.55, 0.06)


def marimba(f, n):
    x = t(n)
    y = np.sin(2 * np.pi * f * x) + 0.35 * np.sin(2 * np.pi * f * 4 * x) * np.exp(-30 * x)
    return y * np.exp(-5.5 * x) * adsr(n, 0.003, 0.0, 1.0, 0.03)


def bell(f, n):
    x = t(n)
    y = np.sin(2 * np.pi * f * x) + 0.4 * np.sin(2 * np.pi * f * 2.76 * x) * np.exp(-8 * x)
    return y * np.exp(-3.0 * x) * adsr(n, 0.002, 0.0, 1.0, 0.05)


def bass(f, n):
    x = t(n)
    y = 2 / np.pi * np.arcsin(np.sin(2 * np.pi * f * x)) + 0.25 * np.sin(4 * np.pi * f * x)
    return y * adsr(n, 0.005, 0.1, 0.7, 0.04)


def pad(freqs, n):
    x = t(n)
    y = np.zeros(n)
    for f in freqs:
        for detune in (0.997, 1.003):
            ph = (f * detune * x) % 1.0
            y += 2 * ph - 1  # saw
    k = 24
    y = np.convolve(y, np.ones(k) / k, "same")  # soften
    return y / (len(freqs) * 2) * adsr(n, 0.15, 0.2, 0.8, 0.25)


def kick(n):
    x = t(n)
    f = 45 + 90 * np.exp(-28 * x)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-9 * x)


def snare(n):
    x = t(n)
    noise = rng.standard_normal(n)
    noise = np.diff(noise, prepend=0)
    return (0.7 * noise * np.exp(-18 * x) + 0.4 * np.sin(2 * np.pi * 190 * x) * np.exp(-25 * x))


def hat(n):
    x = t(n)
    noise = np.diff(np.diff(rng.standard_normal(n), prepend=0), prepend=0)
    return noise * np.exp(-60 * x) * 0.5


def shaker(n):
    x = t(n)
    noise = np.diff(rng.standard_normal(n), prepend=0)
    return noise * np.exp(-35 * x) * adsr(n, 0.01, 0.0, 1.0, 0.01) * 0.35


# --- Sequencer ---------------------------------------------------------------------------------

def render_line(bars, instrument, eighth, total, gain=1.0):
    """Melody text -> signal. A note lasts until the next note or rest."""
    out = np.zeros(total + SR * 2)
    tokens = []
    for bar in bars:
        tokens += bar.split()
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if tok in (".", "~"):
            i += 1
            continue
        length = 1
        while i + length < len(tokens) and tokens[i + length] == "~":
            length += 1
        n = int(length * eighth * SR)
        start = int(i * eighth * SR)
        sig = instrument(freq(tok), n + int(0.05 * SR))
        out[start:start + len(sig)] += sig * gain
        i += length
    return out


def render_song(bpm, chords, melody, lead_instr, style):
    eighth = 60.0 / bpm / 2
    bar_len = eighth * 8
    total = int(len(chords) * bar_len * SR)
    left = np.zeros(total + SR * 2)
    right = np.zeros(total + SR * 2)

    def add(sig, at, gain, pan=0.0):
        s = int(at * SR)
        left[s:s + len(sig)] += sig * gain * (1 - pan)
        right[s:s + len(sig)] += sig * gain * (1 + pan)

    mel = render_line(melody, lead_instr, eighth, total)
    left[:len(mel)] += mel * 0.30
    right[:len(mel)] += mel * 0.30
    for b, chord in enumerate(chords):
        at = b * bar_len
        notes = CHORDS[chord]
        add(pad([freq(x) * 2 for x in notes], int(bar_len * SR)), at, 0.16 if style == "race" else 0.2, -0.3)
        root = freq(notes[0])
        if style == "race":
            # Driving eighth-note bass, octave jumps on the off-beats.
            for k in range(8):
                f = root if k % 2 == 0 else root * 2
                add(bass(f, int(eighth * SR * 0.9)), at + k * eighth, 0.30)
            for beat in range(4):
                add(kick(int(0.3 * SR)), at + beat * 2 * eighth, 0.55)
                if beat % 2 == 1:
                    add(snare(int(0.25 * SR)), at + beat * 2 * eighth, 0.32, 0.1)
            for k in range(8):
                add(hat(int(0.08 * SR)), at + k * eighth, 0.22 if k % 2 else 0.12, 0.35)
            # Little bell answer on the last beat of every second bar.
            if b % 2 == 1:
                for k, f in enumerate([notes[2], notes[1]]):
                    add(bell(freq(f) * 4, int(0.5 * SR)), at + (6 + k) * eighth, 0.10, 0.4)
        else:
            # Calm: bass on beats 1 and 3, soft shaker on the off-beats, no drums.
            for beat in (0, 2):
                add(bass(root, int(eighth * 2 * SR * 0.95)), at + beat * 2 * eighth, 0.28)
            add(bass(freq(notes[2]) / 2, int(eighth * 2 * SR * 0.9)), at + 6 * eighth, 0.2)
            for k in range(1, 8, 2):
                add(shaker(int(0.1 * SR)), at + k * eighth, 0.5, 0.3)
            add(kick(int(0.25 * SR)), at, 0.25)

    # Small room: two short echoes, quieter on the other side.
    for delay, g in ((0.11, 0.18), (0.23, 0.10)):
        d = int(delay * SR)
        left[d:] += right[:-d] * g
        right[d:] += left[:-d] * g

    # Seamless loop: whatever rings past the end is folded back onto the start.
    tail = len(left) - total
    left[:tail] += left[total:]
    right[:tail] += right[total:]
    left, right = left[:total], right[:total]
    stereo = np.stack([left, right], axis=1)
    stereo /= np.max(np.abs(stereo)) + 1e-9
    return stereo * 0.8


def save(name, stereo):
    os.makedirs(OUT, exist_ok=True)
    data = (stereo * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("%s: %.1f s" % (name, len(stereo) / SR))


MENU_CHORDS = ["C", "Am", "F", "G", "C", "Am", "Dm", "G", "C", "Am", "F", "G", "F", "G", "C", "C"]
MENU_MELODY = [
    "E5 ~ G5 ~ C6 ~ G5 ~", "A5 ~ ~ ~ E5 ~ C5 ~", "F5 ~ A5 ~ C6 ~ A5 G5", "G5 ~ ~ ~ D5 ~ ~ ~",
    "E5 ~ G5 ~ C6 ~ D6 ~", "E6 ~ D6 ~ C6 ~ A5 ~", "F5 ~ A5 ~ G5 ~ F5 D5", "D5 ~ ~ ~ . . G4 ~",
    "C5 ~ E5 G5 ~ ~ E5 ~", "A5 ~ G5 E5 C5 ~ ~ ~", "F5 ~ ~ A5 G5 ~ F5 ~", "D5 ~ B4 ~ D5 ~ G5 ~",
    "A5 ~ G5 ~ F5 ~ A5 ~", "G5 ~ F5 ~ D5 ~ B4 ~", "C5 ~ ~ ~ E5 ~ G5 ~", "C6 ~ ~ ~ ~ ~ . .",
]

RACE_CHORDS = ["C", "G", "Am", "F", "C", "G", "Am", "F", "F", "G", "Em", "Am", "F", "G", "C", "C"]
RACE_MELODY = [
    "C5 . E5 G5 ~ E5 G5 A5", "G5 ~ ~ D5 ~ . B4 D5", "E5 . C5 E5 A5 ~ G5 E5", "F5 ~ E5 ~ D5 ~ C5 D5",
    "C5 . E5 G5 ~ E5 G5 C6", "B5 ~ ~ G5 ~ . D5 G5", "A5 ~ G5 E5 C5 ~ E5 A5", "G5 ~ F5 ~ E5 ~ D5 ~",
    "A5 ~ C6 ~ A5 ~ F5 ~", "G5 ~ B5 ~ D6 ~ B5 ~", "G5 ~ E5 G5 B5 ~ G5 E5", "A5 ~ ~ E5 C6 ~ A5 ~",
    "F5 A5 C6 A5 F5 A5 C6 D6", "D6 ~ B5 ~ G5 ~ B5 D6", "E6 ~ ~ ~ D6 ~ C6 ~", "C6 ~ ~ ~ . . G5 ~",
]

if __name__ == "__main__":
    save("menu.wav", render_song(100, MENU_CHORDS, MENU_MELODY, marimba, "calm"))
    save("race.wav", render_song(144, RACE_CHORDS, RACE_MELODY, lead, "race"))
    # Last lap: the same tune, faster (Mario Kart style); the game cross-fades into it.
    save("race_final.wav", render_song(166, RACE_CHORDS, RACE_MELODY, lead, "race"))
