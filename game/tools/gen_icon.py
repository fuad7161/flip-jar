#!/usr/bin/env python3
"""Generates launcher icons (PNG, no external deps): a jar with a smiling jelly piece inside."""
import math, os, struct, zlib

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "icon")
BG = (20, 23, 36)
JAR = (217, 230, 255)
BALL = (255, 224, 102)
BALL_EDGE = (190, 160, 50)
INK = (31, 26, 41)
BLUSH = (255, 140, 140)


def png(path, size, pixel):
    ss = 3  # supersampling for smooth edges
    rows = []
    for y in range(size):
        row = bytearray()
        for x in range(size):
            r = g = b = 0
            for sy in range(ss):
                for sx in range(ss):
                    c = pixel((x + (sx + 0.5) / ss) / size, (y + (sy + 0.5) / ss) / size)
                    r += c[0]; g += c[1]; b += c[2]
            n = ss * ss
            row += bytes((r // n, g // n, b // n))
        rows.append(b"\x00" + bytes(row))
    raw = b"".join(rows)

    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


def inside_circle(u, v, cx, cy, r):
    return (u - cx) ** 2 + (v - cy) ** 2 <= r * r


def art(u, v, inset):
    """u, v in 0..1. `inset` shrinks the drawing (adaptive icons crop the outer ring)."""
    u = (u - 0.5) / inset + 0.5
    v = (v - 0.5) / inset + 0.5
    # Jar outline: open top, rounded bottom corners.
    jl, jr, jt, jb, w = 0.2, 0.8, 0.22, 0.86, 0.045
    in_jar = jl <= u <= jr and jt <= v <= jb
    on_wall = in_jar and (u < jl + w or u > jr - w or v > jb - w)
    # Jelly ball.
    cx, cy, r = 0.5, 0.6, 0.23
    if inside_circle(u, v, cx, cy, r):
        if inside_circle(u, v, cx - 0.085, cy - 0.04, 0.03) or inside_circle(u, v, cx + 0.085, cy - 0.04, 0.03):
            return INK
        # smile
        d = math.hypot(u - cx, v - (cy + 0.02))
        ang = math.atan2(v - (cy + 0.02), u - cx)
        if 0.085 < d < 0.105 and 0.35 < ang < 2.8:
            return INK
        if inside_circle(u, v, cx - 0.13, cy + 0.06, 0.03) or inside_circle(u, v, cx + 0.13, cy + 0.06, 0.03):
            return tuple((a + b) // 2 for a, b in zip(BALL, BLUSH))
        if inside_circle(u, v, cx - 0.09, cy - 0.1, 0.045):
            return tuple(min(255, c + 70) for c in BALL)
        if not inside_circle(u, v, cx, cy, r - 0.012):
            return BALL_EDGE
        return BALL
    if on_wall:
        return JAR
    return None


def full(u, v):
    # rounded square background
    k = 0.18
    cu, cv = min(max(u, k), 1 - k), min(max(v, k), 1 - k)
    if (u - cu) ** 2 + (v - cv) ** 2 > k * k:
        return (0, 0, 0)
    c = art(u, v, 1.0)
    return c if c else BG


png(os.path.join(OUT, "icon_192.png"), 192, full)
png(os.path.join(OUT, "icon_fg_432.png"), 432, lambda u, v: art(u, v, 0.62) or BG)
png(os.path.join(OUT, "icon_bg_432.png"), 432, lambda u, v: BG)
print("wrote icons")
