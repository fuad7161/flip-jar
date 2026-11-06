#!/usr/bin/env python3
"""Generates the game's sound effects as 16-bit mono WAV files in game/audio (no external deps)."""
import math, random, struct, wave, os, sys

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = 0.9 / peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * gain)) * 32767)) for s in samples))


def env(i, n, attack=0.005, decay=None):
    t = i / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    d = decay if decay else n / RATE
    return a * math.exp(-t / d * 4.0)


def tone(dur, f0, f1=None, decay=None, harmonics=(1.0,), noise=0.0, attack=0.005):
    n = int(dur * RATE)
    f1 = f0 if f1 is None else f1
    out, phase = [], 0.0
    rnd = random.Random(1)
    for i in range(n):
        k = i / n
        f = f0 * (f1 / f0) ** k
        phase += 2 * math.pi * f / RATE
        s = sum(h * math.sin(phase * (j + 1)) for j, h in enumerate(harmonics))
        s += noise * (rnd.random() * 2 - 1)
        out.append(s * env(i, n, attack, decay))
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]


def delay(samples, seconds):
    return [0.0] * int(seconds * RATE) + samples


# Soft wet thud for a landing piece.
write("drop", mix(tone(0.12, 160, 70, decay=0.05, harmonics=(1.0, 0.3)), tone(0.04, 900, 300, decay=0.015, noise=0.6)))
# Bubble pop for a merge; the game pitches it per tier.
write("pop", mix(tone(0.16, 720, 260, decay=0.07, harmonics=(1.0, 0.4, 0.15)), tone(0.03, 2000, 800, decay=0.01, noise=0.5)))
# Whoosh for the jar flip.
write("flip", mix(tone(0.45, 120, 480, decay=0.3, noise=1.6, attack=0.08), tone(0.45, 60, 240, decay=0.3, harmonics=(1.0,), attack=0.08)))
# Descending "overflow" tones.
write("over", mix(tone(0.25, 440, 440, decay=0.2), delay(tone(0.25, 370, 370, decay=0.2), 0.2), delay(tone(0.45, 294, 294, decay=0.4, harmonics=(1.0, 0.3)), 0.4)))
# Rising jingle for a new best.
write("best", mix(tone(0.18, 523, 523, decay=0.15), delay(tone(0.18, 659, 659, decay=0.15), 0.12), delay(tone(0.18, 784, 784, decay=0.15), 0.24), delay(tone(0.5, 1047, 1047, decay=0.45, harmonics=(1.0, 0.3)), 0.36)))
# UI click.
write("click", tone(0.05, 1200, 900, decay=0.02, harmonics=(1.0, 0.2)))
print("wrote", sorted(os.listdir(OUT)))
