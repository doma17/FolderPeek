#!/usr/bin/env python3
from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Assets" / "AppIcon"
ICONSET = OUT / "FolderPeek.iconset"
BASE = OUT / "FolderPeekAppIcon-1024.png"
SVG = OUT / "FolderPeekAppIcon.svg"
ICNS = OUT / "FolderPeek.icns"
ICON_COMPOSER_NOTES = OUT / "IconComposer.md"

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

    # Liquid Glass app tile: a soft Apple-system blue/purple field under a
    # translucent rounded-square lens. The folder silhouette stays simple and
    # SF Symbols-like so it remains legible at menu/app-icon sizes.
    for y in range(H):
        for x in range(W):
            a = rounded_rect_alpha(x + 0.5, y + 0.5, 34, 34, 990, 990, 218)
            if a <= 0:
                continue
            t = (x * 0.55 + y * 0.45) / W
            bg = mix((10, 132, 255, 255), (126, 87, 255, 255), t)
            cool = max(0, 1 - math.hypot((x - 285) / 520, (y - 235) / 520))
            warm = max(0, 1 - math.hypot((x - 775) / 520, (y - 760) / 520))
            bg = mix(bg, (100, 210, 255, 255), cool * 0.28)
            bg = mix(bg, (255, 214, 102, 255), warm * 0.12)
            vignette = max(0, math.hypot((x - 512) / 690, (y - 520) / 690) - 0.48)
            bg = tuple(bg[i] * (1 - vignette * 0.34) for i in range(3)) + (255,)
            alpha_blend(px, x, y, (bg[0], bg[1], bg[2], 255 * a))

    # Frosted glass lens and reflected highlights.
    draw_radial(px, 360, 230, 420, (255, 255, 255, 78), power=2.4)
    draw_radial(px, 690, 780, 420, (35, 23, 128, 72), power=2.1)
    draw_rounded_rect(px, (88, 88, 936, 936), 190, (255, 255, 255, 58), (255, 255, 255, 18))
    draw_line(px, 178, 178, 760, 118, 18, (255, 255, 255, 72))
    draw_line(px, 186, 206, 548, 166, 7, (255, 255, 255, 110))
    draw_line(px, 246, 875, 812, 820, 8, (255, 255, 255, 42))

    # Ambient glow coming out of the slightly open folder.
    draw_radial(px, 518, 516, 350, (255, 255, 238, 185), power=1.9)
    draw_radial(px, 518, 535, 260, (255, 204, 77, 150), power=2.2)
    draw_radial(px, 520, 710, 320, (16, 22, 78, 105), power=2.6)

    # SF Symbols-inspired folder silhouette: large, simple, rounded, with a
    # clear tab and open front plane.
    back = [(204, 330), (382, 330), (438, 392), (810, 392), (810, 690), (204, 690)]
    draw_poly(px, back, (255, 222, 105, 222), (255, 159, 42, 210))
    draw_rounded_rect(px, (184, 382, 842, 746), 62, (255, 229, 126, 230), (243, 142, 36, 224))

    # Glassy inner opening.
    opening = [(232, 440), (808, 416), (762, 626), (272, 648)]
    draw_poly(px, opening, (255, 255, 244, 218), (255, 210, 93, 118))
    draw_line(px, 252, 455, 782, 432, 9, (255, 255, 255, 126))
    for angle, length, width in [(-68, 210, 12), (-40, 270, 10), (-14, 320, 9), (14, 320, 9), (42, 260, 9), (70, 205, 11)]:
        rad = math.radians(angle)
        draw_line(px, 518, 520, 518 + math.cos(rad) * length, 518 + math.sin(rad) * length, width, (255, 252, 205, 86))

    # Open front folder cover with liquid-glass shine.
    front = [(176, 474), (858, 442), (790, 800), (228, 824)]
    draw_poly(px, front, (255, 205, 72, 245), (239, 121, 30, 248))
    lip = [(206, 491), (826, 462), (814, 526), (218, 552)]
    draw_poly(px, lip, (255, 245, 158, 132), (255, 196, 72, 44))
    draw_line(px, 236, 507, 786, 482, 8, (255, 255, 218, 142))
    draw_line(px, 256, 790, 758, 770, 14, (128, 55, 28, 60))
    draw_radial(px, 520, 610, 265, (255, 234, 111, 70), power=2.7)

    # Fine glass rim around the app tile.
    draw_line(px, 214, 86, 810, 86, 5, (255, 255, 255, 72))
    draw_line(px, 118, 260, 118, 720, 5, (255, 255, 255, 38))

    OUT.mkdir(parents=True, exist_ok=True)
    write_png(BASE, W, H, px)
    return px

def write_svg():
    SVG.write_text('''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="FolderPeek Liquid Glass app icon: an SF Symbols style open folder glowing from inside">
  <defs>
    <linearGradient id="bg" x1="104" y1="96" x2="920" y2="928" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#0A84FF"/>
      <stop offset="0.55" stop-color="#5E5CE6"/>
      <stop offset="1" stop-color="#7E57FF"/>
    </linearGradient>
    <linearGradient id="glass" x1="170" y1="88" x2="850" y2="936" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.27"/>
      <stop offset="0.52" stop-color="#FFFFFF" stop-opacity="0.08"/>
      <stop offset="1" stop-color="#FFFFFF" stop-opacity="0.16"/>
    </linearGradient>
    <linearGradient id="folderBack" x1="340" y1="315" x2="680" y2="750" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FFDE69" stop-opacity="0.94"/>
      <stop offset="1" stop-color="#F38E24" stop-opacity="0.90"/>
    </linearGradient>
    <linearGradient id="folderFront" x1="350" y1="440" x2="650" y2="830" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FFCD48" stop-opacity="0.96"/>
      <stop offset="1" stop-color="#EF791E" stop-opacity="0.98"/>
    </linearGradient>
    <radialGradient id="glow" cx="50.6%" cy="50%" r="37%">
      <stop offset="0" stop-color="#FFFFF0" stop-opacity="0.95"/>
      <stop offset="0.48" stop-color="#FFD65D" stop-opacity="0.62"/>
      <stop offset="1" stop-color="#FFD65D" stop-opacity="0"/>
    </radialGradient>
    <filter id="softShadow" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="36" stdDeviation="36" flood-color="#07104A" flood-opacity="0.36"/></filter>
  </defs>
  <rect id="AppIcon-Background" x="34" y="34" width="956" height="956" rx="218" fill="url(#bg)"/>
  <rect id="LiquidGlass-Lens" x="88" y="88" width="848" height="848" rx="190" fill="url(#glass)"/>
  <path id="LiquidGlass-SpecularTop" d="M178 178C346 146 536 134 760 118" fill="none" stroke="#FFFFFF" stroke-width="18" stroke-linecap="round" opacity="0.28"/>
  <path id="LiquidGlass-SpecularFine" d="M186 206C300 188 418 176 548 166" fill="none" stroke="#FFFFFF" stroke-width="7" stroke-linecap="round" opacity="0.42"/>
  <circle id="InteriorGlow" cx="518" cy="516" r="350" fill="url(#glow)"/>
  <g id="SFSymbolsStyle-Folder" filter="url(#softShadow)">
    <path d="M204 330h178l56 62h372v298H204z" fill="url(#folderBack)"/>
    <rect x="184" y="382" width="658" height="364" rx="62" fill="url(#folderBack)"/>
    <path d="M232 440l576-24-46 210-490 22z" fill="#FFFFF4" opacity="0.74"/>
    <g stroke="#FFFCCD" stroke-linecap="round" opacity="0.44">
      <path d="M518 520l78-195" stroke-width="12"/>
      <path d="M518 520l207-174" stroke-width="10"/>
      <path d="M518 520l310-78" stroke-width="9"/>
      <path d="M518 520l310 76" stroke-width="9"/>
      <path d="M518 520l193 174" stroke-width="9"/>
      <path d="M518 520l70 192" stroke-width="11"/>
    </g>
    <path d="M176 474l682-32-68 358-562 24z" fill="url(#folderFront)"/>
    <path d="M206 491l620-29-12 64-596 26z" fill="#FFF59E" opacity="0.40"/>
    <path d="M236 507l550-25" stroke="#FFFFDA" stroke-width="8" stroke-linecap="round" opacity="0.56"/>
    <path d="M256 790l502-20" stroke="#80371C" stroke-width="14" stroke-linecap="round" opacity="0.24"/>
  </g>
</svg>
''', encoding="utf-8")


def write_icon_composer_notes():
    ICON_COMPOSER_NOTES.write_text('''# FolderPeek Icon Composer Source Notes

FolderPeek's generated icon is designed as an Icon Composer-friendly layered source:

- `FolderPeekAppIcon.svg` contains named layers:
  - `AppIcon-Background`
  - `LiquidGlass-Lens`
  - `LiquidGlass-SpecularTop`
  - `LiquidGlass-SpecularFine`
  - `InteriorGlow`
  - `SFSymbolsStyle-Folder`
- `FolderPeekAppIcon-1024.png` is the rendered 1024px master.
- `FolderPeek.icns` is the shipping macOS app icon.

The silhouette intentionally follows the simple SF Symbols `folder` grammar while keeping the app-icon artwork as project-owned vector/raster output. Icon Composer is installed with Xcode and can open/import the SVG/PNG master for manual Liquid Glass layer tuning when a GUI design pass is desired.
''', encoding="utf-8")



def resize_rgba(src: bytearray, src_w: int, src_h: int, dst_w: int, dst_h: int) -> bytearray:
    if src_w == dst_w and src_h == dst_h:
        return bytearray(src)
    dst = bytearray(dst_w * dst_h * 4)
    for y in range(dst_h):
        sy = (y + 0.5) * src_h / dst_h - 0.5
        y0 = max(0, min(src_h - 1, int(math.floor(sy))))
        y1 = max(0, min(src_h - 1, y0 + 1))
        fy = sy - math.floor(sy)
        for x in range(dst_w):
            sx = (x + 0.5) * src_w / dst_w - 0.5
            x0 = max(0, min(src_w - 1, int(math.floor(sx))))
            x1 = max(0, min(src_w - 1, x0 + 1))
            fx = sx - math.floor(sx)
            out = (y * dst_w + x) * 4
            for c in range(4):
                p00 = src[(y0 * src_w + x0) * 4 + c]
                p10 = src[(y0 * src_w + x1) * 4 + c]
                p01 = src[(y1 * src_w + x0) * 4 + c]
                p11 = src[(y1 * src_w + x1) * 4 + c]
                top = p00 * (1 - fx) + p10 * fx
                bottom = p01 * (1 - fx) + p11 * fx
                dst[out + c] = clamp(top * (1 - fy) + bottom * fy)
    return dst


def packbits_channel(channel: bytes) -> bytes:
    # ICNS legacy RGB chunks store each color plane with PackBits-style RLE.
    out = bytearray()
    i = 0
    n = len(channel)
    while i < n:
        run = 1
        while i + run < n and run < 130 and channel[i + run] == channel[i]:
            run += 1
        if run >= 3:
            out.append(0x80 + run - 3)
            out.append(channel[i])
            i += run
            continue

        start = i
        i += 1
        while i < n and i - start < 128:
            run = 1
            while i + run < n and run < 130 and channel[i + run] == channel[i]:
                run += 1
            if run >= 3:
                break
            i += 1
        out.append(i - start - 1)
        out.extend(channel[start:i])
    return bytes(out)


def rgb_and_mask(rgba: bytearray) -> tuple[bytes, bytes]:
    red = bytearray()
    green = bytearray()
    blue = bytearray()
    mask = bytearray()
    for i in range(0, len(rgba), 4):
        red.append(rgba[i])
        green.append(rgba[i + 1])
        blue.append(rgba[i + 2])
        mask.append(rgba[i + 3])
    rgb = packbits_channel(bytes(red)) + packbits_channel(bytes(green)) + packbits_channel(bytes(blue))
    return rgb, bytes(mask)


def write_icns_fallback(rendered: dict[int, bytearray]) -> None:
    # Modern ICNS files can embed PNG payloads for large artwork, but small
    # application-icon PNG slots can render scrambled in Spotlight/IconServices
    # on some macOS versions. Use legacy PackBits-encoded planar RGB + 8-bit
    # mask chunks for 16/32/48 and PNG chunks only for 128px and larger.
    # Length fields include the 8-byte element header as required by ICNS.
    rgb16, mask16 = rgb_and_mask(rendered[16])
    rgb32, mask32 = rgb_and_mask(rendered[32])
    rgb48, mask48 = rgb_and_mask(rendered[48])
    mapping = [
        (b"is32", rgb16),
        (b"s8mk", mask16),
        (b"il32", rgb32),
        (b"l8mk", mask32),
        (b"ih32", rgb48),
        (b"h8mk", mask48),
        (b"ic07", (ICONSET / "icon_128x128.png").read_bytes()),
        (b"ic08", (ICONSET / "icon_256x256.png").read_bytes()),
        (b"ic09", (ICONSET / "icon_512x512.png").read_bytes()),
        (b"ic10", (ICONSET / "icon_512x512@2x.png").read_bytes()),
    ]
    chunks = []
    for kind, data in mapping:
        chunks.append(kind + struct.pack(">I", len(data) + 8) + data)
    payload = b"".join(chunks)
    ICNS.write_bytes(b"icns" + struct.pack(">I", len(payload) + 8) + payload)

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    if ICONSET.exists():
        import shutil
        shutil.rmtree(ICONSET)
    ICONSET.mkdir(parents=True, exist_ok=True)
    base_pixels = render_base()
    write_svg()
    write_icon_composer_notes()
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
    rendered = {1024: base_pixels}
    for name, size in sizes.items():
        rendered[size] = resize_rgba(base_pixels, W, H, size, size)
        write_png(ICONSET / name, size, size, rendered[size])
    rendered[48] = resize_rgba(base_pixels, W, H, 48, 48)
    if ICNS.exists():
        ICNS.unlink()
    write_icns_fallback(rendered)
    print(ICNS)


if __name__ == "__main__":
    main()
