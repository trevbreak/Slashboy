#!/usr/bin/env python3
"""Generate every texture Slashboy uses (PBR sets, city, sky, creatures) into godot/assets/textures.

Each PBR set is drawn as four layers (albedo, height, roughness, metalness); a tangent-space
normal map and cavity AO are derived from the height layer. Outputs per set:
  <name>_albedo.png, <name>_normal.png, <name>_orm.png   (ORM = R: AO, G: roughness, B: metal)
Run:  tools/.venv/bin/python tools/gen_textures.py
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(__file__), '..', 'godot', 'assets', 'textures')
FONT_DIR = os.path.join(os.path.dirname(__file__), '..', 'godot', 'assets', 'fonts')
os.makedirs(ROOT, exist_ok=True)


def font(size, bold=False):
    path = os.path.join(FONT_DIR, 'ShareTechMono-Regular.ttf')
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


class Layers:
    def __init__(self, S, albedo, height=90, rough=150, metal=160):
        self.S = S
        self.alb = Image.new('RGB', (S, S), albedo)
        self.hgt = Image.new('L', (S, S), height)
        self.rgh = Image.new('L', (S, S), rough)
        self.mtl = Image.new('L', (S, S), metal)
        self.a = ImageDraw.Draw(self.alb, 'RGBA')
        self.h = ImageDraw.Draw(self.hgt)
        self.r = ImageDraw.Draw(self.rgh)
        self.m = ImageDraw.Draw(self.mtl)

    def bake(self, name, normal_strength=2.5, ao_strength=2.2):
        H = np.asarray(self.hgt, dtype=np.float32) / 255.0
        dx = -(np.roll(H, -1, axis=1) - np.roll(H, 1, axis=1)) * normal_strength
        dy = (np.roll(H, -1, axis=0) - np.roll(H, 1, axis=0)) * normal_strength
        # Godot expects OpenGL-style normal maps (+Y up)
        dy = -dy
        l = np.sqrt(dx * dx + dy * dy + 1.0)
        n = np.stack([dx / l, dy / l, 1.0 / l], axis=-1) * 0.5 + 0.5
        Image.fromarray((n * 255).astype(np.uint8), 'RGB').save(os.path.join(ROOT, f'{name}_normal.png'))
        blur = ndimage.uniform_filter(H, size=15, mode='wrap')
        ao = np.clip(1.0 - (blur - H) * ao_strength, 0.25, 1.0)
        orm = np.stack([ao * 255, np.asarray(self.rgh, dtype=np.float32), np.asarray(self.mtl, dtype=np.float32)], axis=-1)
        Image.fromarray(orm.astype(np.uint8), 'RGB').save(os.path.join(ROOT, f'{name}_orm.png'))
        self.alb.save(os.path.join(ROOT, f'{name}_albedo.png'))
        print('  wrote', name)


def g(v):
    return int(max(0, min(255, v)))


def speckle(L, rnd, n, a=0.05, rough=0):
    S = L.S
    for _ in range(n):
        x, y, s = rnd.random() * S, rnd.random() * S, 0.5 + rnd.random() * 1.8
        c = (0, 0, 0, int(255 * a)) if rnd.random() < 0.5 else (255, 255, 255, int(255 * a * 0.6))
        L.a.rectangle([x, y, x + s, y + s], fill=c)
        if rough:
            L.r.rectangle([x, y, x + s, y + s], fill=g(128 + (rnd.random() - 0.5) * rough))


def blobs(L, rnd, n, dark=0.08, rough=220):
    """Soft grime: radial falloff blobs composited onto albedo and roughness."""
    S = L.S
    alb = np.asarray(L.alb, dtype=np.float32)
    rg = np.asarray(L.rgh, dtype=np.float32)
    yy, xx = np.mgrid[0:S, 0:S]
    for _ in range(n):
        x, y, s = rnd.random() * S, rnd.random() * S, 10 + rnd.random() * 90
        x0, x1 = int(max(0, x - s)), int(min(S, x + s))
        y0, y1 = int(max(0, y - s)), int(min(S, y + s))
        if x1 <= x0 or y1 <= y0:
            continue
        d = np.sqrt((xx[y0:y1, x0:x1] - x) ** 2 + (yy[y0:y1, x0:x1] - y) ** 2) / s
        w = np.clip(1 - d, 0, 1) ** 2
        k = dark * (0.3 + rnd.random())
        alb[y0:y1, x0:x1] = alb[y0:y1, x0:x1] * (1 - w[..., None] * k * 3) + np.array([8, 6, 4]) * w[..., None] * k
        a = 0.15 + rnd.random() * 0.25
        rg[y0:y1, x0:x1] = rg[y0:y1, x0:x1] * (1 - w * a) + rough * w * a
    L.alb.paste(Image.fromarray(np.clip(alb, 0, 255).astype(np.uint8)))
    L.rgh.paste(Image.fromarray(np.clip(rg, 0, 255).astype(np.uint8)))
    L.a = ImageDraw.Draw(L.alb, 'RGBA')
    L.r = ImageDraw.Draw(L.rgh)


STENCILS = ['C-04', 'MAINT 7', 'KRG-9', 'NO STEP', 'SECTOR C', '04-B', 'VENT 12', 'AUX', 'HAZ 3', 'PRESS.', 'RING C', 'LV-2']


def panel(name, seed, base, S=1024, wear=1.0, decals=True):
    rnd = random.Random(seed)
    L = Layers(S, tuple(base))
    rects = []
    G = 32

    def split(x, y, w, h, d):
        if d > 4 or (d > 1 and rnd.random() < 0.28) or w < 96 or h < 96:
            rects.append((x, y, w, h))
            return
        if (rnd.random() < 0.75) if w > h else (rnd.random() < 0.25):
            k = max(G, round((0.3 + rnd.random() * 0.4) * w / G) * G)
            split(x, y, k, h, d + 1); split(x + k, y, w - k, h, d + 1)
        else:
            k = max(G, round((0.3 + rnd.random() * 0.4) * h / G) * G)
            split(x, y, w, k, d + 1); split(x, y + k, w, h - k, d + 1)

    split(0, 0, S, S, 0)
    br, bg, bb = base
    for (x, y, w, h) in rects:
        v = (rnd.random() - 0.5) * 16
        tint = (12, -2, -10) if rnd.random() < 0.12 else (-6, 0, 8) if rnd.random() < 0.1 else (0, 0, 0)
        kind = rnd.random()
        L.h.rectangle([x, y, x + w, y + h], fill=20)
        L.a.rectangle([x, y, x + w, y + h], fill=(8, 9, 11))
        ins = 3
        for k in range(6):
            L.h.rectangle([x + ins + k, y + ins + k, x + w - ins - k - 1, y + h - ins - k - 1], fill=110 + k * 18)
        L.a.rectangle([x + ins, y + ins, x + w - ins - 1, y + h - ins - 1], fill=(g(br + v + tint[0]), g(bg + v + tint[1]), g(bb + v + tint[2])))
        L.r.rectangle([x + ins, y + ins, x + w - ins - 1, y + h - ins - 1], fill=g(110 + rnd.random() * 80))
        L.m.rectangle([x + ins, y + ins, x + w - ins - 1, y + h - ins - 1], fill=g(60 if kind < 0.15 else 150 + rnd.random() * 80))
        if wear:
            L.a.rectangle([x + ins + 1, y + ins + 1, x + w - ins - 2, y + h - ins - 2], outline=(150, 160, 170, int(255 * (0.08 + rnd.random() * 0.1))), width=2)
            L.r.rectangle([x + ins + 1, y + ins + 1, x + w - ins - 2, y + h - ins - 2], outline=70, width=2)
        if w > 80 and h > 80 and rnd.random() < 0.65:
            for (px, py) in [(x + 14, y + 14), (x + w - 14, y + 14), (x + 14, y + h - 14), (x + w - 14, y + h - 14)]:
                for rr, val in [(5, 160), (4, 210), (2, 250)]:
                    L.h.ellipse([px - rr, py - rr, px + rr, py + rr], fill=val)
                L.a.ellipse([px - 4, py - 4, px + 4, py + 4], fill=(120, 125, 130, 128))
                L.r.ellipse([px - 4, py - 4, px + 4, py + 4], fill=80)
        if kind > 0.82 and w > 120 and h > 70:
            for k in range(int((h - 40) / 12)):
                yy = y + 20 + k * 12
                for j in range(9):
                    L.h.line([x + 20, yy + j, x + w - 20, yy + j], fill=g(40 + j * 12))
                L.a.rectangle([x + 20, yy, x + w - 20, yy + 4], fill=(0, 0, 0, 140))
        elif kind > 0.7 and w > 140 and h > 140:
            hx, hy, hw, hh = x + w * 0.2, y + h * 0.2, w * 0.6, h * 0.6
            L.h.rectangle([hx, hy, hx + hw, hy + hh], fill=60)
            L.h.rectangle([hx + 4, hy + 4, hx + hw - 4, hy + hh - 4], fill=100)
            L.h.rectangle([hx + hw / 2 - 20, hy + hh / 2 - 4, hx + hw / 2 + 20, hy + hh / 2 + 4], fill=200)
            L.a.rectangle([hx, hy, hx + hw, hy + 3], fill=(0, 0, 0, 80))
        elif kind > 0.6 and h > 60:
            cy = y + h / 2
            for k, col in enumerate([(26, 26, 28), (58, 42, 20), (20, 38, 42)]):
                yy = cy - 14 + k * 11
                for j in range(10):
                    L.h.line([x + 8, yy - 5 + j, x + w - 8, yy - 5 + j], fill=g(120 + math.sin(j / 9 * math.pi) * 110))
                L.a.rectangle([x + 8, yy - 4, x + w - 8, yy + 4], fill=col)
                L.m.rectangle([x + 8, yy - 5, x + w - 8, yy + 5], fill=10)
                L.r.rectangle([x + 8, yy - 5, x + w - 8, yy + 5], fill=120)
        if rnd.random() < 0.05:
            for k in range(-60, int(w), 28):
                L.a.polygon([(x + k, y + 46), (x + k + 14, y + 46), (x + k + 54, y), (x + k + 40, y)], fill=(200, 150, 30, 140))
        if decals and rnd.random() < 0.18 and w > 140:
            txt = STENCILS[rnd.randrange(len(STENCILS))]
            col = (210, 210, 200) if rnd.random() < 0.5 else (220, 160, 60)
            f = font(int(18 + rnd.random() * 14))
            L.a.text((x + 16, y + h - 40), txt, font=f, fill=col + (int(255 * (0.35 + rnd.random() * 0.3)),))
            L.r.text((x + 16, y + h - 40), txt, font=f, fill=200)
    for _ in range(int(160 * wear)):
        x, y, a, l = rnd.random() * S, rnd.random() * S, rnd.random() * math.pi, 6 + rnd.random() * 40
        L.a.line([x, y, x + math.cos(a) * l, y + math.sin(a) * l], fill=(170, 175, 180, int(255 * (0.06 + rnd.random() * 0.12))), width=1)
        L.r.line([x, y, x + math.cos(a) * l, y + math.sin(a) * l], fill=60, width=1)
    for _ in range(70):
        x, y, l = rnd.random() * S, rnd.random() * S, 30 + rnd.random() * 200
        wdt = 1 + rnd.random() * 4
        for j in range(int(l)):
            L.a.rectangle([x, y + j, x + wdt, y + j + 1], fill=(10, 8, 5, int(255 * (0.15 + 0.2 * rnd.random()) * (1 - j / l))))
    blobs(L, rnd, 110)
    speckle(L, rnd, 9000, 0.05, 60)
    L.bake(name)


def floor(name, seed, S=1024, puddles=0.6):
    rnd = random.Random(seed)
    L = Layers(S, (22, 25, 29), height=40, rough=160, metal=200)
    P = 256
    for y in range(0, S, P):
        for x in range(0, S, P):
            v = (rnd.random() - 0.5) * 10
            k = rnd.random()
            for b in range(4):
                L.h.rectangle([x + 3 + b, y + 3 + b, x + P - 4 - b, y + P - 4 - b], fill=120 + b * 25)
            L.a.rectangle([x + 3, y + 3, x + P - 4, y + P - 4], fill=(g(32 + v), g(35 + v), g(39 + v)))
            L.r.rectangle([x + 3, y + 3, x + P - 4, y + P - 4], fill=g(120 + rnd.random() * 60))
            if k < 0.4:
                for s in range(16, P - 16, 14):
                    L.h.rectangle([x + 16, y + s, x + P - 16, y + s + 6], fill=0)
                    L.a.rectangle([x + 16, y + s, x + P - 16, y + s + 6], fill=(0, 0, 0, 235))
                    L.r.rectangle([x + 16, y + s, x + P - 16, y + s + 6], fill=255)
            elif k < 0.8:
                for yy in range(12, P - 12, 18):
                    for xx in range(12 + (9 if (yy // 18) % 2 else 0), P - 12, 18):
                        cx, cy = x + xx, y + yy
                        ang = 0.78 if ((xx + yy) // 18) % 2 else -0.78
                        dx, dy = math.cos(ang) * 6, math.sin(ang) * 6
                        L.h.line([cx - dx, cy - dy, cx + dx, cy + dy], fill=225, width=3)
                        L.a.line([cx - dx, cy - dy, cx + dx, cy + dy], fill=(255, 255, 255, 14), width=2)
            else:
                for s in range(-P, P, 40):
                    L.a.polygon([(x + s, y + P - 3), (x + s + 20, y + P - 3), (x + s + 20 + P, y + 3), (x + s + P, y + 3)], fill=(190, 140, 40, 64))
                L.r.rectangle([x + 3, y + 3, x + P - 4, y + P - 4], fill=200)
                L.m.rectangle([x + 3, y + 3, x + P - 4, y + P - 4], fill=30)
            for (px, py) in [(x + 10, y + 10), (x + P - 10, y + 10), (x + 10, y + P - 10), (x + P - 10, y + P - 10)]:
                L.h.ellipse([px - 4, py - 4, px + 4, py + 4], fill=240)
    for _ in range(260):
        x, y, a, l = rnd.random() * S, rnd.random() * S, rnd.random() * math.pi, 10 + rnd.random() * 60
        L.a.line([x, y, x + math.cos(a) * l, y + math.sin(a) * l], fill=(160, 165, 170, int(255 * (0.05 + rnd.random() * 0.1))))
    blobs(L, rnd, 160, dark=0.12, rough=230)
    # puddles: dark, mirror-smooth
    alb = np.asarray(L.alb, dtype=np.float32); rg = np.asarray(L.rgh, dtype=np.float32); hg = np.asarray(L.hgt, dtype=np.float32)
    yy, xx = np.mgrid[0:S, 0:S]
    for _ in range(int(9 * puddles)):
        x, y, s, sx = rnd.random() * S, rnd.random() * S, 30 + rnd.random() * 110, 0.6 + rnd.random() * 0.8
        d = np.sqrt(((xx - x) / sx) ** 2 + (yy - y) ** 2) / s
        w = np.clip((1 - d) / 0.3, 0, 1)
        alb = alb * (1 - w[..., None] * 0.55) + 5 * w[..., None] * 0.55
        rg = rg * (1 - w * 0.95) + 8 * w * 0.95
        hg = hg * (1 - w * 0.6) + 70 * w * 0.6
    L.alb.paste(Image.fromarray(np.clip(alb, 0, 255).astype(np.uint8)))
    L.rgh.paste(Image.fromarray(np.clip(rg, 0, 255).astype(np.uint8)))
    L.hgt.paste(Image.fromarray(np.clip(hg, 0, 255).astype(np.uint8)))
    L.a = ImageDraw.Draw(L.alb, 'RGBA'); L.r = ImageDraw.Draw(L.rgh)
    speckle(L, rnd, 12000, 0.06, 80)
    L.bake(name, normal_strength=3)


def skin(name, seed, base, rough=90, metal=40, cells=140, S=512):
    rnd = random.Random(seed)
    L = Layers(S, tuple(base), height=60, rough=rough, metal=metal)
    hg = np.asarray(L.hgt, dtype=np.float32)
    alb = np.asarray(L.alb, dtype=np.float32)
    yy, xx = np.mgrid[0:S, 0:S]
    for _ in range(cells):
        x, y, s = rnd.random() * S, rnd.random() * S, 10 + rnd.random() * 34
        dxw = np.minimum(np.abs(xx - x), S - np.abs(xx - x))
        dyw = np.minimum(np.abs(yy - y), S - np.abs(yy - y))
        d = np.sqrt(dxw ** 2 + dyw ** 2) / s
        w = np.clip(1 - d, 0, 1)
        hg = np.maximum(hg, 60 + w ** 0.7 * 140)
        v = (rnd.random() - 0.5) * 20
        alb += (np.array([20 + v, 10 + v, 25 + v]) * 0.35) * (w[..., None] > 0.3)
    hg[np.asarray([[rnd.random() < 0.02 for _ in range(S)] for _ in range(S)])] = 30
    L.hgt.paste(Image.fromarray(np.clip(hg, 0, 255).astype(np.uint8)))
    L.alb.paste(Image.fromarray(np.clip(alb, 0, 255).astype(np.uint8)))
    L.h = ImageDraw.Draw(L.hgt)
    for _ in range(90):
        x, y, a = rnd.random() * S, rnd.random() * S, rnd.random() * 6.28
        pts = [(x, y)]
        for _ in range(8):
            a += (rnd.random() - 0.5) * 0.8
            x += math.cos(a) * 9; y += math.sin(a) * 9
            pts.append((x, y))
        L.h.line(pts, fill=30, width=2)
    L.bake(name, normal_strength=4, ao_strength=3)


def blade():
    W, H = 64, 1024
    rnd = random.Random(17)
    img = Image.new('RGB', (W, H))
    px = img.load()
    for x in range(W):
        t = x / (W - 1)
        c = (216 * (1 - t) + 106 * t, 222 * (1 - t) + 115 * t, 230 * (1 - t) + 128 * t)
        for y in range(H):
            px[x, y] = tuple(int(v) for v in c)
    d = ImageDraw.Draw(img, 'RGBA')
    pts = [(0, 0)]
    for y in range(0, H + 1, 8):
        pts.append((W * (0.32 + math.sin(y * 0.045) * 0.06 + math.sin(y * 0.13) * 0.03 + (rnd.random() - 0.5) * 0.02), y))
    pts.append((0, H))
    d.polygon(pts, fill=(245, 248, 255, 140))
    d.rectangle([W * 0.62, 0, W * 0.62 + 2, H], fill=(40, 46, 56, 150))
    for _ in range(300):
        x, y = rnd.random() * W, rnd.random() * H
        d.line([x, y, x, y + 6 + rnd.random() * 30], fill=(255, 255, 255, int(rnd.random() * 20)))
    img.save(os.path.join(ROOT, 'blade_albedo.png'))
    r = Image.new('L', (W, H), 70)
    ImageDraw.Draw(r).rectangle([0, 0, W * 0.3, H], fill=45)
    r.save(os.path.join(ROOT, 'blade_rough.png'))
    print('  wrote blade')


def windows(seed, hue):
    W, H = 128, 512
    rnd = random.Random(seed)
    img = Image.new('RGB', (W, H), (2, 3, 6))
    d = ImageDraw.Draw(img)
    pal = [(255, 190, 120), (120, 230, 255), (255, 90, 200), (190, 160, 255), (255, 240, 220)]
    main = pal[hue % len(pal)]
    cols, rows = 8, 48
    for y in range(rows):
        lit = rnd.random() < 0.55
        for x in range(cols):
            if not lit or rnd.random() < 0.55:
                continue
            c = main if rnd.random() < 0.8 else pal[rnd.randrange(len(pal))]
            a = 0.25 + rnd.random() * 0.75
            d.rectangle([x * W / cols + 3, y * H / rows + 2, (x + 1) * W / cols - 3, (y + 1) * H / rows - 3], fill=tuple(int(v * a) for v in c))
    if rnd.random() < 0.5:
        c = pal[rnd.randrange(1, 4)]
        xx = 0 if rnd.random() < 0.5 else W - 3
        d.rectangle([xx, 0, xx + 2, H], fill=c)
    img.save(os.path.join(ROOT, f'windows_{hue}.png'))


def neon(seed, color, name):
    W, H = 256, 64
    rnd = random.Random(seed)
    img = Image.new('RGB', (W, H), (0, 0, 0))
    d = ImageDraw.Draw(img)
    n = 4 + rnd.randrange(4)
    gw = (W - 20) / n
    for i in range(n):
        x0 = 10 + i * gw + 4; x1 = x0 + gw - 10; y0, y1 = 12, H - 12
        pts = [(x0, y0), (x1, y0), (x0, y1), (x1, y1), ((x0 + x1) / 2, y0), ((x0 + x1) / 2, y1), (x0, (y0 + y1) / 2), (x1, (y0 + y1) / 2)]
        for _ in range(2 + rnd.randrange(3)):
            d.line([pts[rnd.randrange(8)], pts[rnd.randrange(8)]], fill=color, width=4)
    glow = img.filter(ImageFilter.GaussianBlur(4))
    img = Image.fromarray(np.clip(np.asarray(img, dtype=np.float32) + np.asarray(glow, dtype=np.float32) * 1.2, 0, 255).astype(np.uint8))
    img.save(os.path.join(ROOT, f'{name}.png'))


def stars():
    W, H = 4096, 2048
    rnd = np.random.default_rng(5)
    img = np.zeros((H, W, 3), dtype=np.float32)
    # faint galactic band
    yy, xx = np.mgrid[0:H, 0:W]
    band = np.exp(-((yy - H * 0.45 - np.sin(xx / W * 6.28) * H * 0.12) / (H * 0.08)) ** 2)
    noise = ndimage.gaussian_filter(rnd.random((H // 8, W // 8)), 2)
    noise = np.kron(noise, np.ones((8, 8)))
    img += (band * noise * 0.08)[..., None] * np.array([0.6, 0.65, 0.9])
    n = 9000
    xs, ys = rnd.integers(0, W, n), rnd.integers(0, H, n)
    br = rnd.random(n) ** 3 * 1.0 + 0.05
    for x, y, b in zip(xs, ys, br):
        c = np.array([1.0, 0.95, 0.9]) if rnd.random() < 0.6 else np.array([0.75, 0.85, 1.0])
        img[y, x] += c * b
        if b > 0.6:
            img[max(0, y - 1):y + 2, max(0, x - 1):x + 2] += c * b * 0.25
    Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(os.path.join(ROOT, 'stars.png'))
    print('  wrote stars')


def planet():
    W, H = 1024, 512
    rnd = random.Random(99)
    img = Image.new('RGB', (W, H))
    d = ImageDraw.Draw(img, 'RGBA')
    for y in range(H):
        t = y / H
        c = (int(42 + 32 * math.sin(t * math.pi)), int(53 + 42 * math.sin(t * math.pi)), int(80 + 42 * math.sin(t * math.pi)))
        d.line([0, y, W, y], fill=c)
    for _ in range(140):
        y, h = rnd.random() * H, 2 + rnd.random() * 14
        d.rectangle([0, y, W, y + h], fill=(int(150 + rnd.random() * 80), int(160 + rnd.random() * 60), int(190 + rnd.random() * 60), int(255 * (0.05 + rnd.random() * 0.12))))
    img = img.filter(ImageFilter.GaussianBlur(1.5))
    img.save(os.path.join(ROOT, 'planet.png'))


def glow():
    S = 128
    yy, xx = np.mgrid[0:S, 0:S]
    d = np.sqrt((xx - S / 2 + 0.5) ** 2 + (yy - S / 2 + 0.5) ** 2) / (S / 2)
    a = np.clip(1 - d, 0, 1) ** 2.2
    img = np.stack([np.ones_like(a), np.ones_like(a), np.ones_like(a), a], axis=-1)
    Image.fromarray((img * 255).astype(np.uint8), 'RGBA').save(os.path.join(ROOT, 'glow.png'))


def screen(seed, color, name):
    W, H = 256, 160
    rnd = random.Random(seed)
    img = Image.new('RGB', (W, H), (1, 6, 8))
    d = ImageDraw.Draw(img, 'RGBA')
    for y in range(10, H - 10, 9):
        x = 10
        while x < W - 20 and rnd.random() < 0.93:
            w = 4 + rnd.random() * 26
            d.rectangle([x, y, x + w, y + 3], fill=color + (int(255 * (0.3 + rnd.random() * 0.6)),))
            x += w + 5
    d.rectangle([4, 4, W - 5, H - 5], outline=color)
    img.save(os.path.join(ROOT, f'{name}.png'))



def concrete(name, seed, base=(48, 50, 54), S=1024, lines=True):
    """Wet street concrete/asphalt: aggregate, cracks, painted lane marks, puddles."""
    rnd = random.Random(seed)
    L = Layers(S, base, height=120, rough=170, metal=0)
    a = np.asarray(L.alb, dtype=np.float32)
    n = ndimage.gaussian_filter(np.random.default_rng(seed).random((S, S)), 1.2)
    n2 = ndimage.gaussian_filter(np.random.default_rng(seed + 1).random((S // 8, S // 8)), 2)
    n2 = np.kron(n2, np.ones((8, 8)))
    a = a * (0.8 + 0.4 * n[..., None]) * (0.85 + 0.3 * n2[..., None])
    L.alb.paste(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)))
    h = np.clip(120 + (n - 0.5) * 120, 0, 255)
    L.hgt.paste(Image.fromarray(h.astype(np.uint8)))
    L.a = ImageDraw.Draw(L.alb, 'RGBA'); L.h = ImageDraw.Draw(L.hgt); L.r = ImageDraw.Draw(L.rgh)
    # expansion joints
    for k in range(0, S, S // 2):
        L.h.line([0, k, S, k], fill=30, width=4); L.a.line([0, k, S, k], fill=(10, 10, 12, 200), width=3)
    # cracks
    for _ in range(26):
        x, y, ang = rnd.random() * S, rnd.random() * S, rnd.random() * 6.28
        pts = [(x, y)]
        for _ in range(14):
            ang += (rnd.random() - 0.5) * 1.2
            x += math.cos(ang) * 14; y += math.sin(ang) * 14
            pts.append((x, y))
        L.h.line(pts, fill=20, width=3); L.a.line(pts, fill=(8, 8, 9, 220), width=2)
    if lines:
        for k in range(0, S, 160):
            L.a.rectangle([S * 0.47, k, S * 0.53, k + 90], fill=(200, 180, 90, 120))
            L.r.rectangle([S * 0.47, k, S * 0.53, k + 90], fill=200)
    blobs(L, rnd, 140, dark=0.1, rough=230)
    # puddles: mirror-smooth
    rg = np.asarray(L.rgh, dtype=np.float32); al = np.asarray(L.alb, dtype=np.float32)
    yy, xx = np.mgrid[0:S, 0:S]
    for _ in range(12):
        x, y, r = rnd.random() * S, rnd.random() * S, 40 + rnd.random() * 140
        d = np.sqrt(((xx - x) / (0.6 + rnd.random())) ** 2 + (yy - y) ** 2) / r
        w = np.clip((1 - d) / 0.25, 0, 1)
        rg = rg * (1 - w) + 6 * w
        al = al * (1 - w[..., None] * 0.5)
    L.rgh.paste(Image.fromarray(np.clip(rg, 0, 255).astype(np.uint8)))
    L.alb.paste(Image.fromarray(np.clip(al, 0, 255).astype(np.uint8)))
    L.bake(name, normal_strength=2.0)


def facade(name, seed, base=(36, 38, 46), S=1024):
    """Building facade: tiled cladding with recessed dark windows and lit sills."""
    rnd = random.Random(seed)
    L = Layers(S, base, height=150, rough=120, metal=120)
    cw, ch = S // 8, S // 8
    for y in range(0, S, ch):
        for x in range(0, S, cw):
            v = (rnd.random() - 0.5) * 12
            L.a.rectangle([x + 2, y + 2, x + cw - 3, y + ch - 3], fill=(g(base[0] + v), g(base[1] + v), g(base[2] + v)))
            L.h.rectangle([x, y, x + cw, y + ch], outline=40, width=3)
            if rnd.random() < 0.7:
                wx0, wy0 = x + cw * 0.18, y + ch * 0.2
                L.a.rectangle([wx0, wy0, x + cw * 0.82, y + ch * 0.72], fill=(6, 8, 12))
                L.h.rectangle([wx0, wy0, x + cw * 0.82, y + ch * 0.72], fill=50)
                L.r.rectangle([wx0, wy0, x + cw * 0.82, y + ch * 0.72], fill=20)
                L.m.rectangle([wx0, wy0, x + cw * 0.82, y + ch * 0.72], fill=230)
                L.a.rectangle([wx0, y + ch * 0.74, x + cw * 0.82, y + ch * 0.78], fill=(90, 92, 100))
    for _ in range(80):
        x, y, l = rnd.random() * S, rnd.random() * S, 40 + rnd.random() * 220
        for j in range(int(l)):
            L.a.rectangle([x, y + j, x + 2, y + j + 1], fill=(6, 5, 4, int(60 * (1 - j / l))))
    blobs(L, rnd, 90)
    speckle(L, rnd, 6000, 0.05, 50)
    L.bake(name)


def rust(name, seed, S=1024):
    """Heavy corroded plate for the foundry: scale, pitting, bright worn edges."""
    rnd = random.Random(seed)
    L = Layers(S, (70, 52, 40), height=100, rough=200, metal=90)
    rngn = np.random.default_rng(seed)
    n = ndimage.gaussian_filter(rngn.random((S // 4, S // 4)), 3); n = np.kron(n, np.ones((4, 4)))
    m = ndimage.gaussian_filter(rngn.random((S, S)), 1.5)
    rustmask = np.clip((n - 0.33) * 4, 0, 1)
    steel = np.array([58, 60, 64]); rusty = np.array([120, 58, 28]); dark = np.array([40, 22, 14])
    a = steel * (1 - rustmask[..., None]) + (rusty * (0.6 + 0.6 * m[..., None]) * (1 - 0.4 * n[..., None])) * rustmask[..., None]
    a = a * 0.8 + dark * 0.2 * (m[..., None] > 0.6)
    L.alb.paste(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)))
    L.rgh.paste(Image.fromarray(np.clip(120 + rustmask * 120, 0, 255).astype(np.uint8)))
    L.mtl.paste(Image.fromarray(np.clip(220 - rustmask * 190, 0, 255).astype(np.uint8)))
    L.hgt.paste(Image.fromarray(np.clip(110 + (m - 0.5) * 90 + rustmask * 25, 0, 255).astype(np.uint8)))
    L.a = ImageDraw.Draw(L.alb, 'RGBA'); L.h = ImageDraw.Draw(L.hgt); L.r = ImageDraw.Draw(L.rgh)
    P = S // 2
    for y in range(0, S, P):
        for x in range(0, S, P):
            L.h.rectangle([x, y, x + P, y + P], outline=20, width=6)
            L.a.rectangle([x + 2, y + 2, x + P - 3, y + P - 3], outline=(150, 150, 150, 70), width=2)
            for (px, py) in [(x + 24, y + 24), (x + P - 24, y + 24), (x + 24, y + P - 24), (x + P - 24, y + P - 24)]:
                L.h.ellipse([px - 9, py - 9, px + 9, py + 9], fill=230)
                L.a.ellipse([px - 7, py - 7, px + 7, py + 7], fill=(90, 70, 50))
    for _ in range(40):
        x, y, l = rnd.random() * S, rnd.random() * S, 60 + rnd.random() * 260
        for j in range(int(l)):
            L.a.rectangle([x, y + j, x + 3, y + j + 1], fill=(110, 45, 15, int(90 * (1 - j / l))))
    L.bake(name, normal_strength=3.0)


def ice(name, seed, S=1024):
    """Frosted metal with crystalline frost and glassy ice patches (archives)."""
    rnd = random.Random(seed)
    L = Layers(S, (150, 170, 190), height=110, rough=120, metal=60)
    rngn = np.random.default_rng(seed)
    n = ndimage.gaussian_filter(rngn.random((S, S)), 2.0)
    n2 = ndimage.gaussian_filter(rngn.random((S // 8, S // 8)), 2); n2 = np.kron(n2, np.ones((8, 8)))
    a = np.stack([150 + n * 60, 172 + n * 50, 195 + n * 45], -1) * (0.75 + 0.35 * n2[..., None])
    L.alb.paste(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)))
    L.a = ImageDraw.Draw(L.alb, 'RGBA'); L.h = ImageDraw.Draw(L.hgt); L.r = ImageDraw.Draw(L.rgh)
    P = S // 4
    for y in range(0, S, P):
        for x in range(0, S, P):
            L.h.rectangle([x, y, x + P, y + P], outline=40, width=3)
            L.a.rectangle([x, y, x + P, y + P], outline=(90, 110, 130, 120), width=2)
    # frost ferns
    for _ in range(60):
        x, y, ang = rnd.random() * S, rnd.random() * S, rnd.random() * 6.28
        for k in range(5):
            l = 20 + rnd.random() * 40
            x2, y2 = x + math.cos(ang) * l, y + math.sin(ang) * l
            L.a.line([x, y, x2, y2], fill=(235, 245, 255, 120), width=1)
            L.h.line([x, y, x2, y2], fill=200, width=1)
            for side in (-1, 1):
                L.a.line([(x + x2) / 2, (y + y2) / 2, (x + x2) / 2 + math.cos(ang + side * 0.8) * l * 0.4, (y + y2) / 2 + math.sin(ang + side * 0.8) * l * 0.4], fill=(235, 245, 255, 90), width=1)
            x, y = x2, y2
            ang += (rnd.random() - 0.5) * 0.6
    # glassy ice patches
    rg = np.asarray(L.rgh, dtype=np.float32)
    yy, xx = np.mgrid[0:S, 0:S]
    for _ in range(14):
        x, y, r = rnd.random() * S, rnd.random() * S, 50 + rnd.random() * 120
        d = np.sqrt((xx - x) ** 2 + (yy - y) ** 2) / r
        w = np.clip((1 - d) / 0.3, 0, 1)
        rg = rg * (1 - w) + 15 * w
    L.rgh.paste(Image.fromarray(np.clip(rg, 0, 255).astype(np.uint8)))
    L.bake(name, normal_strength=2.0)


def archive_stone(name, seed, S=1024):
    """Pale carved stone with glowing-groove circuit engravings (lit by emission map)."""
    rnd = random.Random(seed)
    L = Layers(S, (168, 170, 176), height=150, rough=150, metal=10)
    em = Image.new('L', (S, S), 0)
    e = ImageDraw.Draw(em)
    rngn = np.random.default_rng(seed)
    n = ndimage.gaussian_filter(rngn.random((S, S)), 1.5)
    a = np.asarray(L.alb, dtype=np.float32) * (0.85 + 0.25 * n[..., None])
    L.alb.paste(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)))
    L.a = ImageDraw.Draw(L.alb, 'RGBA')
    B = S // 4
    for y in range(0, S, B):
        for x in range(0, S, B):
            L.h.rectangle([x, y, x + B, y + B], outline=60, width=4)
    for _ in range(70):
        x, y = rnd.randrange(0, S, 16), rnd.randrange(0, S, 16)
        pts = [(x, y)]
        for _ in range(rnd.randrange(3, 9)):
            if rnd.random() < 0.5:
                x += rnd.choice([-1, 1]) * rnd.randrange(16, 96, 16)
            else:
                y += rnd.choice([-1, 1]) * rnd.randrange(16, 96, 16)
            pts.append((x, y))
        L.h.line(pts, fill=70, width=5)
        L.a.line(pts, fill=(60, 70, 90, 200), width=3)
        e.line(pts, fill=255, width=2)
        e.ellipse([x - 4, y - 4, x + 4, y + 4], fill=255)
    speckle(L, rnd, 8000, 0.04, 40)
    L.bake(name, normal_strength=2.2)
    em.save(os.path.join(ROOT, f'{name}_emission.png'))


def fleshwall(name, seed, S=1024):
    """Wet organic wall: folded tissue, vessels, glossy mucus (Bloom Heart)."""
    rnd = random.Random(seed)
    L = Layers(S, (70, 26, 52), height=100, rough=60, metal=0)
    rngn = np.random.default_rng(seed)
    n = ndimage.gaussian_filter(rngn.random((S // 2, S // 2)), 6); n = np.kron(n, np.ones((2, 2)))
    folds = np.sin(n * 40.0) * 0.5 + 0.5
    a = np.stack([70 + folds * 60, 22 + folds * 20, 48 + folds * 40], -1)
    L.alb.paste(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)))
    L.hgt.paste(Image.fromarray(np.clip(60 + folds * 160, 0, 255).astype(np.uint8)))
    L.rgh.paste(Image.fromarray(np.clip(40 + (1 - folds) * 120, 0, 255).astype(np.uint8)))
    L.a = ImageDraw.Draw(L.alb, 'RGBA'); L.h = ImageDraw.Draw(L.hgt)
    for _ in range(50):
        x, y, ang = rnd.random() * S, rnd.random() * S, rnd.random() * 6.28
        w = 2 + rnd.random() * 5
        pts = [(x, y)]
        for _ in range(20):
            ang += (rnd.random() - 0.5) * 0.7
            x += math.cos(ang) * 12; y += math.sin(ang) * 12
            pts.append((x, y))
        L.a.line(pts, fill=(140, 30, 120, 200), width=int(w))
        L.h.line(pts, fill=220, width=int(w))
    L.bake(name, normal_strength=3.5, ao_strength=3)


def city_backdrop():
    """Tall strip of a distant chasm wall dense with lights (Undercity sky)."""
    W, H = 2048, 1024
    rnd = np.random.default_rng(31)
    img = np.zeros((H, W, 3), dtype=np.float32)
    yy = np.arange(H)[:, None] / H
    img += np.stack([0.02 + 0.05 * (1 - yy), 0.02 + 0.03 * (1 - yy), 0.05 + 0.06 * (1 - yy)], -1)
    for _ in range(26000):
        x, y = rnd.integers(0, W), int(rnd.random() ** 0.6 * H)
        c = [np.array([1.0, 0.7, 0.4]), np.array([0.4, 0.9, 1.0]), np.array([1.0, 0.35, 0.8]), np.array([0.9, 0.9, 1.0])][rnd.integers(0, 4)]
        img[y, x] += c * (0.3 + rnd.random() * 0.8) * (0.4 + 0.6 * y / H)
    img = ndimage.gaussian_filter(img, (0.6, 0.6, 0))
    Image.fromarray((np.clip(img * 1.3, 0, 1) * 255).astype(np.uint8)).save(os.path.join(ROOT, 'chasm_wall.png'))


if __name__ == '__main__':
    print('PBR surfaces...')
    panel('wall', 11, (62, 67, 76))
    panel('wall_dark', 23, (44, 47, 55))
    panel('ceiling', 37, (34, 36, 42), decals=False)
    panel('door', 51, (78, 82, 92), S=512)
    panel('mech', 3, (78, 82, 92), S=512, wear=0.6, decals=False)
    floor('floor', 5)
    print('creature skins...')
    skin('chitin', 5, (30, 22, 38), rough=70, metal=90, cells=120)
    skin('flesh', 9, (40, 14, 46), rough=110, metal=10, cells=220)
    skin('stalker', 21, (18, 16, 24), rough=95, metal=40, cells=90)
    print('misc...')
    blade()
    for i in range(10):
        windows(100 + i, i)
    for i, (c, n) in enumerate([((255, 58, 176), 'neon_pink'), ((58, 240, 255), 'neon_cyan'), ((255, 180, 58), 'neon_amber'), ((160, 123, 255), 'neon_violet')]):
        neon(13 + i * 7, c, n)
    screen(3, (255, 136, 68), 'screen_amber')
    screen(8, (85, 255, 255), 'screen_cyan')
    stars()
    planet()
    glow()
    print('sector sets...')
    concrete('concrete', 61)
    concrete('pavement', 62, base=(58, 58, 60), lines=False)
    facade('facade', 63)
    panel('facade_metal', 64, (40, 42, 50))
    rust('rust', 65)
    panel('foundry_plate', 66, (60, 52, 46), decals=True)
    ice('ice', 67)
    archive_stone('archive', 68)
    fleshwall('fleshwall', 69)
    skin('bone', 70, (150, 140, 120), rough=120, metal=0, cells=160)
    city_backdrop()
    print('done')
