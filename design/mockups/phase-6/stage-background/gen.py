# Task-25 stage backgrounds, v2: one-point perspective, pixel art at 1/4 scale (1 art px = 4 css px).
# Usage: python3 -I gen.py png <outdir>          -> writes atlas PNGs to <outdir>/png
#        python3 -I gen.py html <outdir> <blobs.json> -> writes project/*.dc.html
import os, sys, math, zlib, struct, json

U = 4                      # css px per art px
LW = 88                    # low-res stage width (352 css, stage is 350, clipped 1px each side)
CX = LW / 2
HOME = dict(H=75, yh=38)   # 300 css tall, horizon at 152 css
RUN = dict(H=65, yh=36)    # 260 css tall, horizon at 144 css
FAR_H = 12                 # far scenery band above the horizon (48 css)
FRAMES, COLS = 32, 4       # run sheet: 32 frames in a 4-column grid
PERIOD = 2.0               # world period in camera-height units (dash spacing 1, objects 2)
LOOP_S = 4.0               # seconds per loop -> 0.5 units/s toward the vanishing point
ZMAX = 14.0

def hx(c, a=255):
    return (int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16), a)

COMMON = {
 'light': dict(sky='#E3F6C8', grass='#CDEBA8', tuft='#B3DB82', bg='#F3F5EE', muted='#5B6357', ink='#16200F',
               soft='#E8ECE2', bubble='#FFFFFF', bubbleInk='#16200F', rim=None, shadow='rgba(22,32,15,0.14)'),
 'dark':  dict(sky='#1D2C15', grass='#2A3F1D', tuft='#3E5C2A', bg='#10160D', muted='#A3AE99', ink='#EEF4E6',
               soft='#28331F', bubble='#44573A', bubbleInk='#EEF4E6', rim='#EEF4E6', shadow='rgba(0,0,0,0.30)'),
}
PAL = {
 'road': {
  'light': dict(asphalt='#B9C0B1', line='#F5F7F0', curb='#E7EBE0', walk='#D6DCCD', joint='#C9D0BF',
                lamp='#8E9987', bulb='#FFFFFF', bld='#D5DECA', bld2='#CCD6BF', win='#E6ECDC', hedge='#C3E29E'),
  'dark':  dict(asphalt='#2B3228', line='#5C6655', curb='#46503F', walk='#343D2F', joint='#2C3428',
                lamp='#56634E', bulb='#D8D2A2', bld='#23311B', bld2='#283720', win='#31422A', hedge='#2F4621'),
 },
 'park': {
  'light': dict(path='#EBE0C6', edge='#DCCCA8', pebble='#D2C199', pebbleHi='#F6F0DF', canopy='#A9D07F',
                canopyHi='#BEDE98', trunk='#A88B66', far='#BFE09A', far2='#D1E9B2', flower='#FFFFFF', flowerC='#E7C35A'),
  'dark':  dict(path='#3A3427', edge='#4A4331', pebble='#50483A', pebbleHi='#463F2F', canopy='#2E4A22',
                canopyHi='#3A5B2B', trunk='#4B3C29', far='#263E1C', far2='#22361A', flower='#C9D3BE', flowerC='#9C8A45'),
 },
 'track': {
  'light': dict(track='#D98C72', line='#F8F1E9', grain='#CB7C63', top='#D4DCC9', inner='#C6CFB9', front='#BAC5AC',
                seat='#AEB9A0', tunnel='#9FAA93'),
  'dark':  dict(track='#5B3127', line='#8C665A', grain='#4F2A21', top='#2B3923', inner='#26331F', front='#22301C',
                seat='#364630', tunnel='#18220F'),
 },
}

# ---------------- raster ----------------
class Img:
    def __init__(s, w, h):
        s.w, s.h = w, h
        s.p = [[(0, 0, 0, 0)] * w for _ in range(h)]
    def set(s, x, y, c):
        if 0 <= x < s.w and 0 <= y < s.h:
            s.p[y][x] = c
    def blit(s, o, ox, oy):
        for y in range(o.h):
            for x in range(o.w):
                if o.p[y][x][3]:
                    s.set(ox + x, oy + y, o.p[y][x])
    def save(s, path):
        raw = b''.join(b'\x00' + bytes(v for px in row for v in px) for row in s.p)
        def ch(t, d):
            return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
        open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + ch(b'IHDR', struct.pack('>IIBBBBB', s.w, s.h, 8, 6, 0, 0, 0))
                               + ch(b'IDAT', zlib.compress(raw, 9)) + ch(b'IEND', b''))

class Scene:
    def __init__(s, H, yh):
        s.H, s.yh, s.K = H, yh, H - yh
    def sx(s, X, z): return CX + X * s.K / z
    def sy(s, h, z): return s.yh + s.K * (1 - h) / z      # h in camera heights, 0 = ground
    def zrow(s, y):
        d = y + 0.5 - s.yh
        return s.K / d
    def zspan(s, y):
        top = s.K / max(y - s.yh, 1e-3)
        return s.K / (y + 1 - s.yh), min(top, 1e3)

def frac_in(z0, z1, t, period, a, b):
    n, hit = 24, 0
    for i in range(n):
        Z = z0 + (z1 - z0) * (i + 0.5) / n - t
        m = Z % period
        if a <= m < b:
            hit += 1
    return hit / n

def fill_vspan(img, xc, hw, y0, y1, col, ymax=None):
    hw = max(hw, 0.5)
    for y in range(int(math.floor(y0)), int(math.ceil(y1))):
        if not (y0 <= y + 0.5 < y1) and not (y1 - y0 < 1 and y == int(math.floor((y0 + y1) / 2))):
            continue
        if ymax is not None and y + 0.5 > ymax:
            continue
        for x in range(int(math.floor(xc - hw - 1)), int(math.ceil(xc + hw + 1))):
            if abs(x + 0.5 - xc) <= hw:
                img.set(x, y, col)

def disc(img, xc, yc, r, col, ymax=None):
    r = max(r, 0.5)
    for y in range(int(yc - r - 1), int(yc + r + 2)):
        if ymax is not None and y + 0.5 > ymax:
            continue
        for x in range(int(xc - r - 1), int(xc + r + 2)):
            if (x + 0.5 - xc) ** 2 + (y + 0.5 - yc) ** 2 <= r * r + 0.15:
                img.set(x, y, col)

def poly(img, pts, col):
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    n = len(pts)
    for y in range(int(min(ys)) - 1, int(max(ys)) + 2):
        for x in range(int(min(xs)) - 1, int(max(xs)) + 2):
            px, py = x + 0.5, y + 0.5
            inside = False
            j = n - 1
            for i in range(n):
                xi, yi = pts[i]; xj, yj = pts[j]
                if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi:
                    inside = not inside
                j = i
            if inside:
                img.set(x, y, col)

# ---------------- ground plane (layer 3) ----------------
def ground(opt, theme, sc, t):
    c = {k: hx(v) for k, v in COMMON[theme].items() if isinstance(v, str) and v.startswith('#')}
    p = {k: hx(v) for k, v in PAL[opt][theme].items()}
    img = Img(LW, sc.H)
    for y in range(sc.yh, sc.H):
        z = sc.zrow(y)
        z0, z1 = sc.zspan(y)
        for x in range(LW):
            X = abs((x + 0.5 - CX) * z / sc.K)
            if opt == 'road':
                col = p['asphalt'] if X < 1.0 else p['curb'] if X < 1.07 else p['walk'] if X < 1.75 else c['grass']
                if 1.07 <= X < 1.75 and z < 8 and frac_in(z0, z1, t, 0.5, 0, 0.06) >= 0.5:
                    col = p['joint']
            elif opt == 'park':
                col = p['path'] if X < 0.85 else p['edge'] if X < 0.93 else c['grass']
            else:
                col = p['track'] if X < 1.05 else p['line'] if X < 1.11 else c['grass']
            img.set(x, y, col)
        # longitudinal lines / periodic marks
        def lines(xs, w, col, period=None, a=0, b=0, zcap=99):
            if period is not None and (z > zcap or frac_in(z0, z1, t, period, a, b) < 0.5):
                return
            for X in xs:
                xc = sc.sx(X, z); hw = w * sc.K / z / 2
                hw = max(hw, 0.5)
                for x in range(int(xc - hw - 1), int(xc + hw + 2)):
                    if abs(x + 0.5 - xc) <= hw:
                        img.set(x, y, col)
        if opt == 'road':
            lines((-0.94, 0.94), 0.04, p['line'])
            lines((-0.33, 0.33), 0.05, p['line'], 1.0, 0, 0.45, zcap=9)
        elif opt == 'track':
            lines((-0.95, -0.32, 0.32, 0.95), 0.035, p['line'])
            # transverse marks across the outer lanes every unit
            if z < 7 and frac_in(z0, z1, t, 1.0, 0, 0.07) >= 0.5:
                for x in range(LW):
                    X = (x + 0.5 - CX) * z / sc.K
                    if 0.36 < abs(X) < 0.92:
                        img.set(x, y, p['line'])
    # stamps on the plane: (X, Z0, size, colour)
    stamps = []
    if opt == 'park':
        stamps = [(-0.55, 0.1, 0.05, 'pebble'), (0.42, 0.6, 0.07, 'pebble'), (-0.2, 1.05, 0.05, 'pebbleHi'),
                  (0.65, 1.4, 0.05, 'pebble'), (0.1, 1.75, 0.04, 'pebble'), (-0.7, 1.55, 0.06, 'pebbleHi'),
                  (-1.3, 0.3, 0.06, 'tuft'), (1.25, 0.9, 0.06, 'tuft'), (-1.15, 1.3, 0.05, 'flower'),
                  (1.4, 1.8, 0.06, 'tuft'), (1.05, 0.2, 0.05, 'flower'), (-1.6, 1.0, 0.06, 'tuft')]
    elif opt == 'track':
        stamps = [(-0.7, 0.2, 0.04, 'grain'), (0.6, 0.7, 0.04, 'grain'), (-0.1, 1.2, 0.03, 'grain'),
                  (0.15, 0.45, 0.03, 'grain'), (-0.5, 1.6, 0.04, 'grain'), (0.8, 1.35, 0.04, 'grain'),
                  (-1.4, 0.5, 0.06, 'tuft'), (1.5, 1.5, 0.06, 'tuft')]
    elif opt == 'road':
        stamps = [(-1.6, 0.4, 0.06, 'tuft_g'), (1.9, 1.3, 0.06, 'tuft_g')]
    for X, Z0, s, key in stamps:
        col = p.get(key) or c.get(key) or (c['tuft'] if key == 'tuft_g' else None)
        if key == 'tuft': col = c['tuft']
        for k in range(-1, int(ZMAX / PERIOD) + 2):
            z = Z0 + k * PERIOD + t
            if not (0.9 < z < 5.5):
                continue
            xc, yc = sc.sx(X, z), sc.yh + sc.K / z
            size = max(1, round(s * sc.K / z))
            x0, y0 = int(round(xc - size / 2)), int(round(yc - size / 2))
            for yy in range(y0, y0 + size):
                for xx in range(x0, x0 + size):
                    if yy >= sc.yh:
                        img.set(xx, yy, col)
            if key == 'flower' and size >= 1 and yc - size / 2 - 1 >= sc.yh:
                img.set(int(round(xc - 0.5)), y0 - 1, col)
    return img

# ---------------- roadside objects (layer 4) ----------------
def roadside(opt, theme, sc, t):
    p = {k: hx(v) for k, v in PAL[opt][theme].items()}
    img = Img(LW, sc.H)
    objs = []
    for k in range(-1, int(ZMAX / PERIOD) + 2):
        for side, Z0 in ((-1, 0.0), (1, 1.0)):
            z = Z0 + k * PERIOD + t
            if 0.85 < z < ZMAX:
                objs.append((z, side, 'a'))
        if opt in ('park',):
            for side, Z0 in ((1, 0.45), (-1, 1.5)):
                z = Z0 + k * PERIOD + t
                if 0.85 < z < ZMAX:
                    objs.append((z, side, 'b'))
        if opt == 'track':
            z = 0.4 + k * PERIOD + t
            if 0.6 < z < ZMAX:
                objs.append((z, -1, 's')); objs.append((z, 1, 's'))
    objs.sort(key=lambda o: -o[0])
    for z, side, kind in objs:
        gy = sc.sy(0, z)
        if opt == 'road' and kind == 'a':
            X = 1.35 * side
            fill_vspan(img, sc.sx(X, z), 0.06 * sc.K / z / 2, sc.sy(1.4, z), gy, p['lamp'])
            xa0, xa1 = sorted((sc.sx(X, z), sc.sx(X - 0.16 * side, z)))
            ya = sc.sy(1.4, z)
            th = max(1.0, 0.04 * sc.K / z)
            for yy in range(int(round(ya)), int(round(ya)) + int(round(th))):
                for xx in range(int(math.floor(xa0)), int(math.ceil(xa1))):
                    img.set(xx, yy, p['lamp'])
            disc(img, sc.sx(X - 0.16 * side, z), sc.sy(1.35, z), 0.035 * sc.K / z, p['bulb'])
        elif opt == 'park' and kind == 'a':
            X = 1.7 * side
            fill_vspan(img, sc.sx(X, z), 0.11 * sc.K / z / 2, sc.sy(0.8, z), gy, p['trunk'])
            disc(img, sc.sx(X, z), sc.sy(1.05, z), 0.42 * sc.K / z, p['canopy'])
            if 0.42 * sc.K / z >= 2.5:
                disc(img, sc.sx(X - 0.12, z), sc.sy(1.17, z), 0.2 * sc.K / z, p['canopyHi'])
        elif opt == 'park' and kind == 'b':
            X = 1.15 * side
            disc(img, sc.sx(X, z), sc.sy(0.06, z), 0.2 * sc.K / z, p['canopy'], ymax=gy)
            if 0.2 * sc.K / z >= 2:
                disc(img, sc.sx(X - 0.06, z), sc.sy(0.12, z), 0.08 * sc.K / z, p['canopyHi'], ymax=gy)
        elif opt == 'track' and kind == 's':
            Xi, Xo, Hs, L = 1.35 * side, 2.6 * side, 0.42, 1.2
            z1, z2 = z, z + L
            P = lambda X, h, zz: (sc.sx(X, zz), sc.sy(h, zz))
            poly(img, [P(Xi, Hs, z1), P(Xo, Hs, z1), P(Xo, Hs, z2), P(Xi, Hs, z2)], p['top'])
            for f in (0.25, 0.5, 0.75):
                Xa = Xi + (Xo - Xi) * f
                Xb = Xa + 0.06 * side
                poly(img, [P(Xa, Hs, z1), P(Xb, Hs, z1), P(Xb, Hs, z2), P(Xa, Hs, z2)], p['seat'])
            poly(img, [P(Xi, 0, z1), P(Xi, Hs, z1), P(Xi, Hs, z2), P(Xi, 0, z2)], p['inner'])
            poly(img, [P(Xi, 0, z1), P(Xo, 0, z1), P(Xo, Hs, z1), P(Xi, Hs, z1)], p['front'])
        elif opt == 'track' and kind == 'a':
            X = 1.2 * side  # distance marker post with a small board
            fill_vspan(img, sc.sx(X, z), 0.04 * sc.K / z / 2, sc.sy(0.35, z), gy, p['seat'])
            fill_vspan(img, sc.sx(X, z), 0.1 * sc.K / z / 2, sc.sy(0.42, z), sc.sy(0.3, z), p['line'])
    return img

# ---------------- far scenery on the horizon (layer 2, static) ----------------
def far(opt, theme):
    p = {k: hx(v) for k, v in PAL[opt][theme].items()}
    c = {k: hx(v) for k, v in COMMON[theme].items() if isinstance(v, str) and v.startswith('#')}
    img = Img(LW, FAR_H)
    B = FAR_H  # bottom (horizon) row index is FAR_H-1
    def rect(x, y, w, h, col):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                img.set(xx, yy, col)
    if opt == 'road':
        for i, (x, w, h) in enumerate([(0, 6, 8), (6, 5, 5), (11, 7, 10), (18, 4, 6), (22, 6, 9), (28, 5, 4), (33, 4, 6),
                                       (51, 4, 5), (55, 6, 8), (61, 4, 4), (65, 7, 11), (72, 5, 6), (77, 6, 9), (83, 5, 5)]):
            col = p['bld'] if i % 2 == 0 else p['bld2']
            rect(x, B - h, w, h, col)
            for wy in range(B - h + 1, B - 2, 2):
                for wx in range(x + 1, x + w - 1, 2):
                    if (wx + wy + i) % 3:
                        img.set(wx, wy, p['win'])
        rect(0, B - 1, LW, 1, p['hedge'])
    elif opt == 'park':
        for i, x in enumerate(range(-2, LW + 4, 7)):
            r = 3.4 + (i * 37 % 5) * 0.45
            disc(img, x + 0.5, B - 1.2, r + 0.8, p['far2'])
        for i, x in enumerate(range(1, LW + 4, 6)):
            r = 2.4 + (i * 53 % 4) * 0.5
            disc(img, x + 0.5, B - 0.2, r, p['far'])
    else:
        rect(0, B - 7, LW, 7, p['inner'])
        rect(0, B - 8, LW, 1, p['top'])
        for yy in range(B - 6, B - 1, 2):
            rect(0, yy, LW, 1, p['seat'])
        rect(39, B - 4, 10, 4, p['tunnel'])
        rect(0, B - 1, LW, 1, p['front'])
    return img

OPTS = ('road', 'park', 'track')
THEMES = ('light', 'dark')
NUM = {'road': 1, 'park': 2, 'track': 3}
NAMES = {'road': '아스팔트 길', 'park': '공원 산책로', 'track': '육상 트랙'}
# atlas layout in art px
A_FAR = (0, 0)
A_HOME_G, A_HOME_R = (0, FAR_H), (LW, FAR_H)
A_RUN_G = (0, FAR_H + HOME['H'])
A_RUN_R = (0, FAR_H + HOME['H'] + RUN['H'] * FRAMES // COLS)
ATLAS_W = LW * COLS
ATLAS_H = A_RUN_R[1] + RUN['H'] * FRAMES // COLS

def build_atlas(opt, theme):
    at = Img(ATLAS_W, ATLAS_H)
    at.blit(far(opt, theme), *A_FAR)
    hs, rs = Scene(**HOME), Scene(**RUN)
    at.blit(ground(opt, theme, hs, 0.0), *A_HOME_G)
    at.blit(roadside(opt, theme, hs, 0.0), *A_HOME_R)
    for i in range(FRAMES):
        t = i * PERIOD / FRAMES
        ox, oy = (i % COLS) * LW, (i // COLS) * RUN['H']
        at.blit(ground(opt, theme, rs, t), A_RUN_G[0] + ox, A_RUN_G[1] + oy)
        at.blit(roadside(opt, theme, rs, t), A_RUN_R[0] + ox, A_RUN_R[1] + oy)
    return at

# ---------------- html ----------------
def layer_static(src, region, w, h, top=0):
    return (f'<div style="position: absolute; left: -{U // 4}px; top: {top}px; width: {w * U}px; height: {h * U}px; overflow: hidden">'
            f'<img src="{src}" alt="" width="{ATLAS_W * U}" height="{ATLAS_H * U}" style="position: absolute; left: -{region[0] * U}px; top: -{region[1] * U}px; width: {ATLAS_W * U}px; height: {ATLAS_H * U}px; max-width: none; image-rendering: pixelated">'
            '</div>')

def layer_anim(src, region, w, h):
    return (f'<div style="position: absolute; left: -{U // 4}px; top: 0; width: {w * U}px; height: {h * U}px; overflow: hidden">'
            f'<div class="recede" style="position: absolute; left: 0; top: 0">'
            f'<img src="{src}" alt="" width="{ATLAS_W * U}" height="{ATLAS_H * U}" style="position: absolute; left: -{region[0] * U}px; top: -{region[1] * U}px; width: {ATLAS_W * U}px; height: {ATLAS_H * U}px; max-width: none; image-rendering: pixelated">'
            '</div></div>')

def pet(theme, scale, Hcss, feet_bottom_css, sprites, run, W=350):
    c = COMMON[theme]
    box = 32 * scale
    bottom = Hcss - feet_bottom_css - 2 * scale  # sprite feet sit 2 rows above the frame bottom
    n = 4 if run else 2
    body, face, alt = sprites
    rim = ''
    if c['rim']:
        rc = c['rim']
        rim = f'; filter: drop-shadow(2px 0 0 {rc}) drop-shadow(-2px 0 0 {rc}) drop-shadow(0 2px 0 {rc}) drop-shadow(0 -2px 0 {rc})'
    cls = 'strip run' if run else 'strip idle'
    # pixel contact shadow, 4px grid, centred under the feet
    sw = 40 if scale == 8 else 30
    shadow = (f'<svg width="{sw * U}" height="12" viewBox="0 0 {sw * U} 12" shape-rendering="crispEdges" aria-hidden="true" '
              f'style="position: absolute; left: {(W - sw * U) // 2}px; top: {feet_bottom_css - 8}px; display: block">'
              f'<rect x="{U * 3}" y="0" width="{(sw - 6) * U}" height="4" fill="{c["shadow"]}"></rect>'
              f'<rect x="0" y="4" width="{sw * U}" height="4" fill="{c["shadow"]}"></rect>'
              f'<rect x="{U * 3}" y="8" width="{(sw - 6) * U}" height="4" fill="{c["shadow"]}"></rect></svg>')
    return (shadow +
            f'<div style="position: absolute; left: {(W - box) // 2}px; bottom: {bottom}px; width: {box}px; height: {box}px{rim}">'
            f'<div style="position: relative; width: {box}px; height: {box}px; overflow: hidden">'
            f'<div class="{cls}" style="position: absolute; left: 0; top: 0; width: {box * n}px; height: {box}px">'
            f'<img src="{body}" alt="{alt}" width="{box * n}" height="{box}" style="position: absolute; left: 0; top: 0; width: {box * n}px; height: {box}px; max-width: none; image-rendering: pixelated">'
            f'<img src="{face}" alt="" width="{box * n}" height="{box}" style="position: absolute; left: 0; top: 0; width: {box * n}px; height: {box}px; max-width: none; image-rendering: pixelated">'
            '</div></div></div>')

def bubble(theme, text):
    c = COMMON[theme]
    return (f'<div style="position: absolute; top: 16px; right: 16px; display: flex; flex-direction: column; align-items: flex-start">'
            f'<div style="background: {c["bubble"]}; color: {c["bubbleInk"]}; border-radius: 20px; padding: 10px 16px; font-size: 14px; line-height: 20px; font-weight: 700; white-space: nowrap">{text}</div>'
            f'<svg width="16" height="8" viewBox="0 0 16 8" aria-hidden="true" style="display: block; margin-left: 28px"><path d="M0 0H16L8 8Z" fill="{c["bubble"]}"></path></svg>'
            '</div>')

def stage(opt, theme, blobs, run, show=('sky', 'far', 'gnd', 'side', 'pet', 'bubble'), kind='chick', label=''):
    c = COMMON[theme]
    src = blobs[f'{opt}-{theme}']
    geo = RUN if run else HOME
    Hcss, yh = geo['H'] * U, geo['yh'] * U
    scale = 6 if run else 8
    feet = 228 if run else 252   # css y of the feet bottom (same as the old ground: 8px below the ground top)
    sky = c['sky'] if 'sky' in show else 'transparent'
    s = [f'<div role="img" aria-label="{label}" style="position: relative; flex-shrink: 0; width: 350px; height: {Hcss}px; border-radius: 24px; overflow: hidden; background: {sky}">']
    if 'far' in show:
        s.append(layer_static(src, A_FAR, LW, FAR_H, top=yh - FAR_H * U))
    if 'gnd' in show:
        s.append(layer_anim(src, A_RUN_G, LW, RUN['H']) if run else layer_static(src, A_HOME_G, LW, HOME['H']))
    if 'side' in show:
        s.append(layer_anim(src, A_RUN_R, LW, RUN['H']) if run else layer_static(src, A_HOME_R, LW, HOME['H']))
    if 'pet' in show:
        sp = blobs['pets'][kind]
        s.append(pet(theme, scale, Hcss, feet, (sp['run_body'], sp['run_face'], sp['alt']) if run else (sp['body'], sp['face'], sp['alt']), run))
    if 'bubble' in show and not run:
        s.append(bubble(theme, '다음 레벨까지 6.0km'))
    s.append('</div>')
    return ''.join(s)

def keyframes():
    fw, fh = LW * U, RUN['H'] * U
    parts = []
    for i in range(FRAMES):
        parts.append(f'{i * 100 / FRAMES:.4g}%{{transform:translate(-{(i % COLS) * fw}px,-{(i // COLS) * fh}px)}}')
    i = FRAMES - 1
    parts.append(f'100%{{transform:translate(-{(i % COLS) * fw}px,-{(i // COLS) * fh}px)}}')
    return '@keyframes recede{' + ''.join(parts) + '}'

BOARD_W = 800
def board(opt, theme, blobs):
    c = COMMON[theme]
    name = NAMES[opt]
    home = stage(opt, theme, blobs, False, label=f'{name} 무대, 홈, 서 있는 삐약이')
    run = stage(opt, theme, blobs, True, label=f'{name} 무대, 러닝 중, 길이 소실점 쪽으로 물러남')
    tiles = []
    for key, lab in (('sky', '1 하늘'), ('far', '2 먼 풍경'), ('gnd', '3 땅·길'), ('side', '4 앞 장식')):
        inner = stage(opt, theme, blobs, False, show=(key,), label=f'레이어 {lab}')
        tiles.append(
            f'<div style="display: flex; flex-direction: column; gap: 8px">'
            f'<div style="width: 154px; height: 132px; border-radius: 12px; overflow: hidden; background: {c["soft"]}">'
            f'<div style="width: 350px; height: 300px; transform: scale(0.44); transform-origin: 0 0">{inner}</div></div>'
            f'<div style="font-size: 13px; line-height: 18px; font-weight: 600; color: {c["muted"]}">{lab}</div></div>')
    cap = f'font-size: 14px; line-height: 20px; font-weight: 700; color: {c["muted"]}'
    extra = ''
    h = 612
    if theme == 'dark':
        minis = []
        for kind, lab in (('chick', '병아리'), ('jelly', '젤리'), ('acorn', '도토리')):
            inner = stage(opt, theme, blobs, False, show=('sky', 'far', 'gnd', 'side', 'pet'), kind=kind, label=f'{name} 다크 무대 위 {lab}')
            minis.append(
                f'<div style="display: flex; flex-direction: column; gap: 8px">'
                f'<div style="width: 210px; height: 180px; border-radius: 14px; overflow: hidden">'
                f'<div style="width: 350px; height: 300px; transform: scale(0.6); transform-origin: 0 0">{inner}</div></div>'
                f'<div style="font-size: 13px; line-height: 18px; font-weight: 600; color: {c["muted"]}">{lab} 3단계</div></div>')
        extra = (f'<div style="display: flex; flex-direction: column; gap: 8px"><div style="{cap}">종류별 대비 · 다크 · 0.6배 축소</div>'
                 f'<div style="display: flex; gap: 16px">{"".join(minis)}</div></div>')
        h = 612 + 32 + 28 + 206
    body = (f'<div style="width: {BOARD_W}px; height: {h}px; box-sizing: border-box; padding: 32px; background: {c["bg"]}; font-family: \'Pretendard\', sans-serif; color: {c["ink"]}; display: flex; flex-direction: column; gap: 32px">'
            f'<div style="display: flex; gap: 36px; align-items: flex-start">'
            f'<div style="display: flex; flex-direction: column; gap: 8px"><div style="{cap}">홈 · 8배</div>{home}</div>'
            f'<div style="display: flex; flex-direction: column; gap: 8px"><div style="{cap}">러닝 중 · 6배 · 길이 소실점 쪽으로 물러난다</div>{run}</div>'
            f'</div>'
            f'<div style="display: flex; flex-direction: column; gap: 8px"><div style="{cap}">레이어 — 상점 배경은 겹 단위로 갈아 끼운다</div>'
            f'<div style="display: flex; gap: 16px">{"".join(tiles)}</div></div>'
            f'{extra}</div>')
    theme_ko = '라이트' if theme == 'light' else '다크'
    html = f'''<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<title>배경 {NUM[opt]} {name} {theme_ko}</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<style>
@font-face{{font-family:'Pretendard';src:url({blobs['font']}) format('woff2');font-weight:45 920;font-style:normal;font-display:swap}}
body{{margin:0}}
@keyframes stripf{{to{{transform:translateX(-100%)}}}}
{keyframes()}
.idle{{animation:stripf .5s steps(2) infinite}}
.run{{animation:stripf .4s steps(4) infinite}}
.recede{{animation:recede {LOOP_S:g}s step-end infinite}}
@media (prefers-reduced-motion: reduce){{.idle,.run,.recede{{animation:none}}}}
</style>
</helmet>
{body}
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{{"$preview":{{"width":{BOARD_W},"height":{h}}}}}'>
class Component extends DCLogic {{
renderVals() {{
return {{}};
}}
}}
</script>
</body>
</html>
'''
    return html, h

if __name__ == '__main__':
    mode, out = sys.argv[1], sys.argv[2]
    if mode == 'png':
        os.makedirs(os.path.join(out, 'png'), exist_ok=True)
        for opt in OPTS:
            for th in THEMES:
                fn = os.path.join(out, 'png', f'atlas-{opt}-{th}.png')
                build_atlas(opt, th).save(fn)
                print(fn, os.path.getsize(fn), ATLAS_W, ATLAS_H)
    else:
        blobs = json.load(open(sys.argv[3]))
        os.makedirs(os.path.join(out, 'project'), exist_ok=True)
        heights = {}
        for opt in OPTS:
            for th in THEMES:
                html, h = board(opt, th, blobs)
                fn = os.path.join(out, 'project', f'bg{NUM[opt]}-{opt}-{th}.dc.html')
                open(fn, 'w').write(html)
                heights[os.path.basename(fn)] = h
                print(fn, os.path.getsize(fn), h)
        json.dump(heights, open(os.path.join(out, 'heights.json'), 'w'))
