# Erzeugt das CurseForge-Logo (512x512 PNG) aus den ManaSigil-Texturen.
import math, struct, zlib, sys, os

MEDIA, OUT = sys.argv[1], sys.argv[2]
W = H = 512

def load_tga(name):
    d = open(os.path.join(MEDIA, name + '.tga'), 'rb').read()
    w, h = struct.unpack('<HH', d[12:16])
    px = d[18:]
    lum = [px[i * 4] / 255 for i in range(w * h)]
    alp = [px[i * 4 + 3] / 255 for i in range(w * h)]
    return w, h, lum, alp

cache = {}
def tex(name):
    if name not in cache: cache[name] = load_tga(name)
    return cache[name]

# Leinwand (linear RGB 0..1)
R = [0.0] * (W * H); G = [0.0] * (W * H); B = [0.0] * (W * H)

# Hintergrund: radialer Verlauf (tiefes Blau -> Violett am Rand)
for y in range(H):
    for x in range(W):
        dx, dy = (x - W / 2) / (W / 2), (y - H / 2) / (H / 2)
        d = min(1.0, math.hypot(dx, dy))
        k = y * W + x
        side = 0.5 + 0.5 * math.tanh(dx * 2.5)   # weicher Übergang links (blau) -> rechts (violett)
        R[k] = 0.05 + 0.10 * d * (0.5 + 0.5 * side)
        G[k] = 0.05 + 0.02 * d
        B[k] = 0.13 + 0.10 * d

def sample(t, u, v):
    w, h, lum, alp = t
    fx, fy = u * w - 0.5, v * h - 0.5
    x0, y0 = int(math.floor(fx)), int(math.floor(fy))
    ax, ay = fx - x0, fy - y0
    L = A = 0.0
    for (xx, yy, wt) in ((x0, y0, (1 - ax) * (1 - ay)), (x0 + 1, y0, ax * (1 - ay)),
                         (x0, y0 + 1, (1 - ax) * ay), (x0 + 1, y0 + 1, ax * ay)):
        if 0 <= xx < w and 0 <= yy < h and wt > 0:
            i = yy * w + xx
            a = alp[i] * wt
            L += lum[i] * a; A += a
    return (L / A if A > 0 else 0), A

def draw(name, cx, cy, size, color, alpha=1.0, add=False, mirror=False, rot=0.0, sy=1.0):
    t = tex(name)
    half = size / 2 * 1.42
    c, s = math.cos(-rot), math.sin(-rot)
    for y in range(max(0, int(cy - half)), min(H, int(cy + half) + 1)):
        for x in range(max(0, int(cx - half)), min(W, int(cx + half) + 1)):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            rx, ry = dx * c - dy * s, dx * s + dy * c
            u, v = rx / size + 0.5, ry / (size * sy) + 0.5
            if not (0 <= u <= 1 and 0 <= v <= 1): continue
            if mirror: u = 1 - u
            l, a = sample(t, u, v)
            a *= alpha
            if a <= 0.002: continue
            k = y * W + x
            cr, cg, cb = color[0] * l, color[1] * l, color[2] * l
            if add:
                R[k] += cr * a; G[k] += cg * a; B[k] += cb * a
            else:
                R[k] = R[k] * (1 - a) + cr * a
                G[k] = G[k] * (1 - a) + cg * a
                B[k] = B[k] * (1 - a) + cb * a

CX, CY = 256, 272
S = 300  # Ringgröße

# Leuchten links (heilig) und rechts (teuflisch)
draw('glow', 150, 250, 420, (1.0, 0.85, 0.45), 0.35, add=True)
draw('glow', 362, 250, 420, (0.35, 1.0, 0.25), 0.30, add=True)
draw('glow', CX, CY, 520, (0.35, 0.45, 1.0), 0.45, add=True)

# Teufelssiegel hinter dem Ring
draw('sigil', CX, CY, S * 1.42, (0.40, 1.00, 0.25), 0.25, add=True, rot=0.2)

# Flügel: links Engel, rechts Dämon
draw('wing', CX - S * 0.58, CY - S * 0.02, S * 1.08, (1.0, 0.96, 0.86))
draw('wing', CX + S * 0.58, CY - S * 0.02, S * 1.08, (0.45, 0.22, 0.45), mirror=True)
draw('wing', CX + S * 0.58, CY - S * 0.02, S * 1.08, (0.30, 0.90, 0.20), 0.15, add=True, mirror=True)

# Heiligenschein (Ellipse) links oben, Dämonenhorn rechts oben
draw('rim', CX - S * 0.20, CY - S * 0.62, S * 0.40, (1.0, 0.85, 0.4), 1.0, add=True, sy=0.32)
draw('horn', CX + S * 0.34, CY - S * 0.50, S * 0.55, (0.62, 0.42, 0.40), mirror=True)

# Scheibe + Rand
draw('disc', CX, CY, S * 0.98, (0.05, 0.04, 0.10), 0.95)
draw('rim', CX, CY, S * 0.87, (0.45, 0.70, 1.0), 0.7)

# Äußerer Mana-Ring (72 % gefüllt) und innerer FSR-Ring (55 %)
def ring(shape, n, radius, size, frac, col, empty, rotate=True):
    for i in range(n):
        a = math.pi / 2 - (i + 0.5) / n * 2 * math.pi
        x, y = CX + math.cos(a) * radius, CY - math.sin(a) * radius
        v = frac * n - i
        if v >= 1:   draw(shape, x, y, size, col, 1.0, rot=(math.pi / 2 - a) if rotate else 0)
        elif v > 0:  draw(shape, x, y, size, col, 0.3 + 0.7 * v, rot=(math.pi / 2 - a) if rotate else 0)
        else:        draw(shape, x, y, size, empty, 0.5, rot=(math.pi / 2 - a) if rotate else 0)
ring('sym_dot', 40, S * 0.42, S * 0.085, 0.72, (0.45, 0.75, 1.0), (0.12, 0.18, 0.30))
ring('sym_star', 22, S * 0.30, S * 0.075, 0.55, (1.0, 0.84, 0.35), (0.28, 0.22, 0.10))

# Funke am Ende des Mana-Rings
a = math.pi / 2 - 0.72 * 2 * math.pi
draw('glow', CX + math.cos(a) * S * 0.42, CY - math.sin(a) * S * 0.42, S * 0.28, (0.75, 0.9, 1.0), 1.0, add=True)

# Mittelpunkt: leuchtendes Siegel
draw('glow', CX, CY, S * 0.45, (0.5, 0.65, 1.0), 0.6, add=True)
draw('sigil', CX, CY, S * 0.36, (1.0, 0.86, 0.45), 0.95, add=True)

# Vignette + Tonemapping, PNG schreiben
raw = bytearray()
for y in range(H):
    raw.append(0)
    for x in range(W):
        k = y * W + x
        dx, dy = (x - W / 2) / (W / 2), (y - H / 2) / (H / 2)
        vig = 1 - 0.35 * min(1, (dx * dx + dy * dy) ** 1.2)
        for ch in (R[k], G[k], B[k]):
            v = ch * vig
            v = v / (1 + max(0, v - 0.85) * 1.5) if v > 0.85 else v   # weiches Abfangen von Überstrahlung
            raw.append(int(max(0, min(1, v)) ** (1 / 1.05) * 255 + 0.5))
def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0))
                      + chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b''))
print('ok', OUT)
