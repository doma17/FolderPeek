#!/usr/bin/env python3
from __future__ import annotations

import math
import struct
import subprocess
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Assets" / "AppIcon"
ICONSET = OUT / "FolderPeek.iconset"
BASE = OUT / "FolderPeekAppIcon-1024.png"
SVG = OUT / "FolderPeekAppIcon.svg"
ICNS = OUT / "FolderPeek.icns"

W = H = 1024


def clamp(v: float, lo: int = 0, hi: int = 255) -> int:
    return max(lo, min(hi, int(round(v))))


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def mix(c1, c2, t: float):
    return tuple(lerp(c1[i], c2[i], t) for i in range(4))


def write_png(path: Path, width: int, height: int, pixels: bytearray) -> None:
    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)
        raw.extend(pixels[y * stride : (y + 1) * stride])
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def alpha_blend(px: bytearray, x: int, y: int, rgba) -> None:
    if x < 0 or y < 0 or x >= W or y >= H:
        return
    r, g, b, a = rgba
    a = clamp(a)
    if a <= 0:
        return
    i = (y * W + x) * 4
    inv = 255 - a
    px[i] = clamp((r * a + px[i] * inv) / 255)
    px[i + 1] = clamp((g * a + px[i + 1] * inv) / 255)
    px[i + 2] = clamp((b * a + px[i + 2] * inv) / 255)
    px[i + 3] = clamp(a + px[i + 3] * inv / 255)


def rounded_rect_alpha(x: float, y: float, left: float, top: float, right: float, bottom: float, radius: float) -> float:
    cx = min(max(x, left + radius), right - radius)
    cy = min(max(y, top + radius), bottom - radius)
    d = math.hypot(x - cx, y - cy) - radius
    return max(0.0, min(1.0, 0.5 - d))


def draw_rounded_rect(px, box, radius, top_color, bottom_color, shadow=False):
    left, top, right, bottom = box
    for y in range(max(0, int(top - 4)), min(H, int(bottom + 5))):
        t = 0 if bottom == top else (y - top) / (bottom - top)
        color = mix(top_color, bottom_color, max(0, min(1, t)))
        for x in range(max(0, int(left - 4)), min(W, int(right + 5))):
            a = rounded_rect_alpha(x + 0.5, y + 0.5, left, top, right, bottom, radius)
            if a:
                alpha_blend(px, x, y, (color[0], color[1], color[2], color[3] * a))


def point_in_poly(x: float, y: float, poly) -> bool:
    inside = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y):
            cross = (xj - xi) * (y - yi) / ((yj - yi) or 1e-9) + xi
            if x < cross:
                inside = not inside
        j = i
    return inside


def dist_to_segment(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    if dx == 0 and dy == 0:
        return math.hypot(px - ax, py - ay)
    t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def poly_alpha(x, y, poly):
    inside = point_in_poly(x, y, poly)
    d = min(dist_to_segment(x, y, *poly[i], *poly[(i + 1) % len(poly)]) for i in range(len(poly)))
    edge = max(0.0, min(1.0, 0.5 - d))
    if inside:
        return 1.0 if d >= 0.5 else max(edge, 0.55)
    return edge


def draw_poly(px, poly, top_color, bottom_color):
    minx = max(0, int(min(p[0] for p in poly) - 4))
    maxx = min(W, int(max(p[0] for p in poly) + 5))
    miny = max(0, int(min(p[1] for p in poly) - 4))
    maxy = min(H, int(max(p[1] for p in poly) + 5))
    for y in range(miny, maxy):
        t = 0 if maxy == miny else (y - miny) / (maxy - miny)
        color = mix(top_color, bottom_color, max(0, min(1, t)))
        for x in range(minx, maxx):
            a = poly_alpha(x + 0.5, y + 0.5, poly)
            if a:
                alpha_blend(px, x, y, (color[0], color[1], color[2], color[3] * a))


def draw_radial(px, cx, cy, radius, color, power=2.0):
    left, right = max(0, int(cx - radius)), min(W, int(cx + radius) + 1)
    top, bottom = max(0, int(cy - radius)), min(H, int(cy + radius) + 1)
    for y in range(top, bottom):
        for x in range(left, right):
            d = math.hypot(x - cx, y - cy) / radius
            if d < 1:
                a = color[3] * ((1 - d) ** power)
                alpha_blend(px, x, y, (color[0], color[1], color[2], a))


def draw_line(px, x1, y1, x2, y2, width, color):
    minx = max(0, int(min(x1, x2) - width - 2))
    maxx = min(W, int(max(x1, x2) + width + 3))
    miny = max(0, int(min(y1, y2) - width - 2))
    maxy = min(H, int(max(y1, y2) + width + 3))
    for y in range(miny, maxy):
        for x in range(minx, maxx):
            d = dist_to_segment(x + 0.5, y + 0.5, x1, y1, x2, y2)
            a = max(0, min(1, (width / 2 + 0.6 - d)))
            if a:
                alpha_blend(px, x, y, (color[0], color[1], color[2], color[3] * a))


def render_base():
    px = bytearray(W * H * 4)
    # macOS-style rounded square background.
    for y in range(H):
        for x in range(W):
            a = rounded_rect_alpha(x + 0.5, y + 0.5, 36, 36, 988, 988, 210)
            if a <= 0:
                continue
            t = (x * 0.35 + y * 0.65) / W
            bg = mix((30, 91, 186, 255), (103, 78, 221, 255), t)
            # Subtle vignette.
            d = math.hypot((x - 512) / 700, (y - 470) / 700)
            bg = tuple(bg[i] * (1 - max(0, d - 0.45) * 0.35) for i in range(3)) + (255,)
            alpha_blend(px, x, y, (bg[0], bg[1], bg[2], 255 * a))

    # Drop shadow and ambient glow behind folder.
    draw_radial(px, 524, 690, 360, (7, 16, 46, 115), power=2.4)
    draw_radial(px, 520, 500, 310, (255, 226, 113, 135), power=2.2)
    draw_radial(px, 520, 465, 190, (255, 255, 221, 185), power=1.7)

    # Back folder body and tab.
    tab = [(206, 318), (392, 318), (444, 386), (812, 386), (812, 710), (204, 710)]
    draw_poly(px, tab, (255, 214, 93, 255), (229, 145, 38, 255))
    draw_rounded_rect(px, (184, 378, 840, 746), 54, (255, 207, 82, 255), (222, 134, 31, 255))

    # Interior bright opening.
    opening = [(230, 432), (806, 410), (760, 618), (268, 642)]
    draw_poly(px, opening, (255, 250, 206, 215), (255, 182, 66, 125))
    draw_radial(px, 516, 495, 250, (255, 255, 226, 230), power=2.0)
    for angle, length, width in [(-70, 210, 13), (-42, 270, 11), (-16, 320, 10), (14, 320, 10), (43, 260, 10), (70, 205, 12)]:
        rad = math.radians(angle)
        draw_line(px, 516, 506, 516 + math.cos(rad) * length, 506 + math.sin(rad) * length, width, (255, 248, 186, 92))

    # Slightly open front cover.
    front = [(176, 468), (858, 436), (790, 796), (228, 820)]
    draw_poly(px, front, (255, 198, 67, 252), (235, 121, 24, 255))
    lip = [(206, 485), (826, 456), (815, 518), (218, 546)]
    draw_poly(px, lip, (255, 232, 129, 125), (255, 189, 64, 40))

    # Highlights and bottom depth.
    draw_line(px, 235, 503, 785, 477, 7, (255, 249, 194, 130))
    draw_line(px, 250, 790, 760, 770, 13, (142, 61, 27, 68))
    draw_radial(px, 522, 610, 250, (255, 221, 97, 55), power=2.5)

    OUT.mkdir(parents=True, exist_ok=True)
    write_png(BASE, W, H, px)


def write_svg():
    SVG.write_text('''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="FolderPeek app icon: an open folder glowing from inside">
  <defs>
    <linearGradient id="bg" x1="140" y1="80" x2="890" y2="940" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#1E5BBA"/>
      <stop offset="1" stop-color="#674EDD"/>
    </linearGradient>
    <linearGradient id="folder" x1="360" y1="300" x2="640" y2="820" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FFD65D"/>
      <stop offset="1" stop-color="#EB7918"/>
    </linearGradient>
    <linearGradient id="front" x1="420" y1="440" x2="600" y2="840" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FFC643"/>
      <stop offset="1" stop-color="#EB7918"/>
    </linearGradient>
    <radialGradient id="glow" cx="50%" cy="47%" r="36%">
      <stop offset="0" stop-color="#FFFFE2" stop-opacity="0.95"/>
      <stop offset="0.46" stop-color="#FFE271" stop-opacity="0.62"/>
      <stop offset="1" stop-color="#FFE271" stop-opacity="0"/>
    </radialGradient>
    <filter id="softShadow" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="34" stdDeviation="34" flood-color="#07102E" flood-opacity="0.36"/></filter>
  </defs>
  <rect x="36" y="36" width="952" height="952" rx="210" fill="url(#bg)"/>
  <circle cx="520" cy="500" r="330" fill="url(#glow)"/>
  <g filter="url(#softShadow)">
    <path d="M206 318h186l52 68h368v324H204z" fill="url(#folder)"/>
    <rect x="184" y="378" width="656" height="368" rx="54" fill="url(#folder)"/>
    <path d="M230 432l576-22-46 208-492 24z" fill="#FFF6CE" opacity="0.78"/>
    <g stroke="#FFF8BA" stroke-linecap="round" opacity="0.48">
      <path d="M516 506l72-197" stroke-width="13"/>
      <path d="M516 506l200-193" stroke-width="11"/>
      <path d="M516 506l307-86" stroke-width="10"/>
      <path d="M516 506l307 78" stroke-width="10"/>
      <path d="M516 506l190 178" stroke-width="10"/>
      <path d="M516 506l72 192" stroke-width="12"/>
    </g>
    <path d="M176 468l682-32-68 360-562 24z" fill="url(#front)"/>
    <path d="M206 485l620-29-11 62-597 28z" fill="#FFE881" opacity="0.38"/>
    <path d="M235 503l550-26" stroke="#FFF9C2" stroke-width="7" stroke-linecap="round" opacity="0.52"/>
    <path d="M250 790l510-20" stroke="#8E3D1B" stroke-width="13" stroke-linecap="round" opacity="0.27"/>
  </g>
</svg>\n''', encoding="utf-8")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    if ICONSET.exists():
        import shutil
        shutil.rmtree(ICONSET)
    ICONSET.mkdir(parents=True, exist_ok=True)
    render_base()
    write_svg()
    sizes = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    for name, size in sizes.items():
        dst = ICONSET / name
        subprocess.run(["sips", "-s", "format", "png", "-z", str(size), str(size), str(BASE), "--out", str(dst)], check=True, stdout=subprocess.DEVNULL)
    if ICNS.exists():
        ICNS.unlink()
    subprocess.run(["iconutil", "-c", "icns", str(ICONSET), "-o", str(ICNS)], check=True)
    print(ICNS)


if __name__ == "__main__":
    main()
