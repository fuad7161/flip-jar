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


def lowpass(samples, cutoff):
    """One-pole low-pass: rounds off harsh edges."""
    a = 1.0 - math.exp(-2 * math.pi * cutoff / RATE)
    out, y = [], 0.0
    for s in samples:
        y += a * (s - y)
        out.append(y)
    return out


def jelly_plop():
    """Landing sound: a round, rising 'bloop' (like a drop into water) over a soft low thump,
    a woody overtone for body and a tiny muffled tap. The game pitches it by piece size."""
    dur = 0.26
    n = int(dur * RATE)
    rnd = random.Random(3)
    out = []
    ph_body = ph_over = ph_sub = 0.0
    noise = 0.0
    for i in range(n):
        t = i / RATE
        # Pitch glides up quickly then settles: the 'bloop' of a jelly hitting something.
        f_body = 200.0 * (1.0 + 0.65 * (1.0 - math.exp(-t / 0.014)))
        f_sub = 92.0 * (1.0 - 0.3 * (1.0 - math.exp(-t / 0.03)))
        ph_body += 2 * math.pi * f_body / RATE
        ph_over += 2 * math.pi * f_body * 2.76 / RATE
        ph_sub += 2 * math.pi * f_sub / RATE
        attack = 1.0 - math.exp(-t / 0.0018)
        body = math.sin(ph_body) * math.exp(-t / 0.065)
        # A light wobble on the body makes it read as squishy rather than a pure beep.
        body *= 1.0 + 0.18 * math.sin(2 * math.pi * 26.0 * t) * math.exp(-t / 0.08)
        over = 0.22 * math.sin(ph_over) * math.exp(-t / 0.016)
        sub = 0.75 * math.sin(ph_sub) * math.exp(-t / 0.045)
        noise += 0.22 * ((rnd.random() * 2 - 1) - noise)  # muffled noise
        tap = 0.35 * noise * math.exp(-t / 0.005)
        s = attack * (body + over + sub) + tap
        if i > n - int(0.015 * RATE):
            s *= (n - i) / (0.015 * RATE)
        out.append(s)
    return lowpass(out, 3800.0)


def chime(freq, dur=0.5):
    """Bright bell for each star earned: inharmonic partials decaying at different rates."""
    n = int(dur * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        a = 1.0 - math.exp(-t / 0.002)
        s = (math.sin(2 * math.pi * freq * t) * math.exp(-t / 0.22)
             + 0.35 * math.sin(2 * math.pi * freq * 2.0 * t) * math.exp(-t / 0.12)
             + 0.18 * math.sin(2 * math.pi * freq * 2.76 * t) * math.exp(-t / 0.06)
             + 0.08 * math.sin(2 * math.pi * freq * 5.4 * t) * math.exp(-t / 0.03))
        out.append(a * s)
    return out


# Jelly plop for a landing piece.
write("drop", jelly_plop())
# Star chime on the level result screen (pitched up for each star).
write("star", mix(chime(1318.5), delay(chime(1975.5, 0.4), 0.05)))
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


# --- Background music: a gentle, seamless 16-bar loop (C - Am - F - G - C - Em - F - G, twice). ---
def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def music():
    bpm = 112
    beat = 60.0 / bpm
    bars = 16
    total = int(bars * 4 * beat * RATE)
    buf = [0.0] * total
    rnd = random.Random(7)

    def note(start, dur, freq, vol, harmonics=(1.0,), decay=0.3, attack=0.004, drop=None):
        """Adds a note; samples past the end wrap to the start so the loop is seamless."""
        n = int(dur * RATE)
        s0 = int(start * RATE)
        phase = 0.0
        for i in range(n):
            t = i / RATE
            f = freq if drop is None else freq * (drop + (1 - drop) * math.exp(-t * 30))
            phase += 2 * math.pi * f / RATE
            a = min(1.0, t / attack) * math.exp(-t / decay)
            if i > n - 200:
                a *= (n - i) / 200.0  # tiny release so nothing clicks
            buf[(s0 + i) % total] += vol * a * sum(h * math.sin(phase * (j + 1)) for j, h in enumerate(harmonics))

    def hat(start, vol):
        s0 = int(start * RATE)
        prev = 0.0
        for i in range(int(0.05 * RATE)):
            w = rnd.random() * 2 - 1
            hp = w - prev  # crude high-pass keeps it airy
            prev = w
            buf[(s0 + i) % total] += vol * hp * math.exp(-i / RATE / 0.012)

    chords = [[48, 60, 64, 67], [45, 57, 60, 64], [41, 57, 60, 65], [43, 55, 59, 62],
              [48, 60, 64, 67], [40, 55, 59, 64], [41, 57, 60, 65], [43, 55, 59, 62]]
    melody = [
        [(0, 76, 1), (1, 79, 1), (2, 84, 1.5), (3.5, 79, 0.5)],
        [(0, 81, 1.5), (1.5, 79, 0.5), (2, 76, 2)],
        [(0, 77, 1), (1, 81, 1), (2, 84, 1), (3, 81, 1)],
        [(0, 79, 1.5), (1.5, 77, 0.5), (2, 74, 2)],
        [(0, 76, 0.5), (0.5, 79, 0.5), (1, 84, 1), (2, 86, 1), (3, 84, 1)],
        [(0, 83, 1.5), (1.5, 79, 0.5), (2, 76, 2)],
        [(0, 77, 1), (1, 76, 1), (2, 74, 1), (3, 72, 1)],
        [(0, 74, 2), (2, 79, 2)],
    ]
    arp = [1, 2, 3, 2, 1, 2, 3, 2]
    for bar in range(bars):
        t0 = bar * 4 * beat
        ch = chords[bar % 8]
        # Round bass on beats 1 and 3.
        for b in (0, 2):
            note(t0 + b * beat, beat * 1.9, midi(ch[0] - 12 if ch[0] > 44 else ch[0]), 0.55, (1.0, 0.25), decay=0.45)
        # Marimba-like arpeggio in eighths.
        for k, idx in enumerate(arp):
            note(t0 + k * beat / 2, beat * 0.9, midi(ch[idx]), 0.16, (1.0, 0.0, 0.0, 0.12), decay=0.16)
        # Soft kick and airy hats.
        for b in (0, 2):
            note(t0 + b * beat, 0.18, 110.0, 0.5, (1.0,), decay=0.06, drop=0.45)
        for b in range(4):
            hat(t0 + (b + 0.5) * beat, 0.05)
        # Bell melody: full on the first pass, only the second half on the repeat.
        if bar < 8 or bar >= 12:
            for (b, n, d) in melody[bar % 8]:
                note(t0 + b * beat, d * beat + 0.25, midi(n), 0.24, (1.0, 0.35, 0.0, 0.08), decay=0.35 + d * 0.12)
    return buf


write("music", music())
print("wrote", sorted(os.listdir(OUT)))
