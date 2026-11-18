# Erzeugt die Grafiken fuer ManaSigil (weiss/graustufig, werden im Spiel eingefaerbt).
# Ausgabe: 32-bit TGA (fuer WoW) + PNG-Vorschau auf dunklem Grund.
import math, struct, sys, os, zlib, random

OUT = sys.argv[1]
PREV = sys.argv[2]
os.makedirs(OUT, exist_ok=True)
os.makedirs(PREV, exist_ok=True)

def clamp(v, a=0.0, b=1.0):
    return a if v < a else b if v > b else v

class Canvas:
    """Painter-Canvas im Bereich [-1,1]^2 (y nach oben), mit Supersampling."""
    def __init__(self, size, ss=3):
        self.size, self.ss = size, ss
        self.n = size * ss
        self.L = [0.0] * (self.n * self.n)
        self.A = [0.0] * (self.n * self.n)
        self.px = 2.0 / self.n

    def paint(self, fn, bbox=(-1, -1, 1, 1)):
        n = self.n
        x0, y0, x1, y1 = bbox
        i0 = max(0, int((x0 + 1) / 2 * n) - 1); i1 = min(n, int((x1 + 1) / 2 * n) + 2)
        j0 = max(0, int((1 - y1) / 2 * n) - 1); j1 = min(n, int((1 - y0) / 2 * n) + 2)
        L, A = self.L, self.A
        for j in range(j0, j1):
            y = 1 - (j + 0.5) * self.px
            row = j * n
            for i in range(i0, i1):
                x = (i + 0.5) * self.px - 1
                r = fn(x, y)
                if r is None:
                    continue
                l, a = r
                if a <= 0:
                    continue
                k = row + i
                ao = A[k]
                an = a + ao * (1 - a)
                L[k] = (l * a + L[k] * ao * (1 - a)) / an
                A[k] = an

    def pixels(self):
        s, ss, n = self.size, self.ss, self.n
        out = []
        for py in range(s):
            for px in range(s):
                la = aa = 0.0
                for sy in range(ss):
                    base = (py * ss + sy) * n + px * ss
                    for sx in range(ss):
                        a = self.A[base + sx]
                        la += self.L[base + sx] * a
                        aa += a
                l = la / aa if aa > 0 else 0
                out.append((l, aa / (ss * ss)))
        return out

def save(name, cv):
    pix = cv.pixels()
    s = cv.size
    # TGA (unkomprimiert, BGRA, Ursprung oben links)
    hdr = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, s, s, 32, 0x28)
    body = bytearray()
    for l, a in pix:
        v = int(clamp(l) * 255 + 0.5)
        body += bytes((v, v, v, int(clamp(a) * 255 + 0.5)))
    with open(os.path.join(OUT, name + '.tga'), 'wb') as f:
        f.write(hdr + body)
    # PNG-Vorschau (auf dunkelblauem Grund)
    raw = bytearray()
    bg = (20, 22, 35)
    for y in range(s):
        raw.append(0)
        for x in range(s):
            l, a = pix[y * s + x]
            v = clamp(l) * 255
            raw += bytes(int(bg[c] * (1 - a) + v * a) for c in range(3))
    def chunk(t, d):
        c = struct.pack('>I', len(d)) + t + d
        return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', s, s, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b'')
    with open(os.path.join(PREV, name + '.png'), 'wb') as f:
        f.write(png)
    print('ok', name)

def aa(d, w):
    """Weiche Kante: d = Abstand innerhalb (positiv = innen)."""
    return clamp(d / w + 0.5)

def seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    t = clamp(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy))
    cx, cy = ax + t * dx, ay + t * dy
    return math.hypot(px - cx, py - cy)

# ---------------------------------------------------------------- Grundformen
def make_pip():
    cv = Canvas(32, 4)
    def f(x, y):
        d = math.hypot(x, y)
        return (1 - 0.3 * d, aa(0.86 - d, 0.1))
    cv.paint(f); save('pip', cv)

def make_glow():
    cv = Canvas(64, 2)
    def f(x, y):
        d = math.hypot(x, y)
        if d >= 1: return None
        return (1, (1 - d) ** 2.2)
    cv.paint(f); save('glow', cv)

def make_disc():
    cv = Canvas(128, 3)
    def f(x, y):
        d = math.hypot(x, y)
        l = 0.75 + 0.25 * (1 - d * d)
        if d > 0.9: l = 1.0
        return (l, aa(0.97 - d, 0.03))
    cv.paint(f); save('disc', cv)

def make_rim():
    cv = Canvas(128, 3)
    def f(x, y):
        d = math.hypot(x, y)
        return (1, aa(0.06 - abs(d - 0.92), 0.025))
    cv.paint(f); save('rim', cv)

# ---------------------------------------------------------------- Feder / Fluegel
def feather(cv, root, ang_deg, length, width, shade, rachis=True, barbs=True):
    a = math.radians(ang_deg)
    dx, dy = math.cos(a), math.sin(a)
    nx, ny = -dy, dx
    rx, ry = root
    tx, ty = rx + dx * length, ry + dy * length
    m = width * 1.3
    bbox = (min(rx, tx) - m, min(ry, ty) - m, max(rx, tx) + m, max(ry, ty) + m)
    edge_w = 0.012
    def f(x, y):
        px, py = x - rx, y - ry
        s = (px * dx + py * dy) / length
        if s < 0 or s > 1: return None
        q = px * nx + py * ny
        w = width * (s ** 0.45) * ((1 - s) ** 0.32) * 1.55
        if w <= 1e-4: return None
        e = abs(q) / w
        alpha = aa(w - abs(q), 0.012)
        if alpha <= 0: return None
        l = shade * (0.82 + 0.18 * (1 - e))
        if w - abs(q) < edge_w * 1.6:          # Umriss
            l *= 0.5
        if rachis and abs(q) < 0.007 and s < 0.88:  # Kiel
            l *= 0.62
        if barbs:                                # feine Fahnen-Struktur
            l *= 0.96 + 0.04 * math.sin(s * 70 - abs(q) * 90)
        return (l, alpha)
    cv.paint(f, bbox)

def make_wing():
    cv = Canvas(256, 2)
    # Arm-Linie: Schulter (rechts) -> Handgelenk (oben links)
    S, E, W = (0.85, -0.12), (0.30, 0.50), (-0.25, 0.72)
    def arm(t):
        # quadratische Bezierkurve
        u = 1 - t
        return (u * u * S[0] + 2 * u * t * E[0] + t * t * W[0],
                u * u * S[1] + 2 * u * t * E[1] + t * t * W[1])
    # Handschwingen (lang, an der Spitze, nach aussen/oben gefaechert)
    for k in range(7):
        t = k / 6
        root = arm(0.70 + 0.30 * t)
        feather(cv, root, 222 - 58 * t, 0.62 + 0.10 * t, 0.085, 0.70)
    # Armschwingen (haengen nach unten)
    for k in range(10):
        t = k / 9
        root = arm(0.05 + 0.75 * t)
        ang = 258 - 52 * t
        feather(cv, root, ang, 0.95 + 0.15 * math.sin(t * math.pi) - 0.25 * t, 0.10, 0.80)
    # Deckfedern (kuerzer, heller)
    for k in range(9):
        t = k / 8
        root = arm(0.02 + 0.92 * t)
        feather(cv, (root[0], root[1] + 0.03), 252 - 50 * t, 0.50 - 0.12 * t, 0.085, 0.92)
    # kleine Deckfedern direkt am Arm
    for k in range(11):
        t = k / 10
        root = arm(0.0 + 0.97 * t)
        feather(cv, (root[0], root[1] + 0.05), 245 - 45 * t, 0.26, 0.07, 1.0, rachis=False)
    save('wing', cv)

# ---------------------------------------------------------------- Horn
def make_horn():
    cv = Canvas(128, 3)
    P0, P1, P2, P3 = (0.62, -0.78), (-0.55, -0.55), (-0.75, 0.35), (-0.15, 0.88)
    N = 60
    pts = []
    for k in range(N + 1):
        t = k / N; u = 1 - t
        x = u**3 * P0[0] + 3*u*u*t * P1[0] + 3*u*t*t * P2[0] + t**3 * P3[0]
        y = u**3 * P0[1] + 3*u*u*t * P1[1] + 3*u*t*t * P2[1] + t**3 * P3[1]
        r = 0.25 * (1 - t) ** 0.85 + 0.008
        pts.append((x, y, r, t))
    def f(x, y):
        best = None
        for (cx, cy, r, t) in pts:
            d = math.hypot(x - cx, y - cy) - r
            if best is None or d < best[0]:
                best = (d, r, t, math.hypot(x - cx, y - cy) / r)
        d, r, t, rel = best
        alpha = aa(-d, 0.02)
        if alpha <= 0: return None
        l = 0.55 + 0.45 * (1 - rel ** 2)                 # Rundung
        l *= 0.78 + 0.22 * math.sin(t * 46) ** 2         # Rillen
        l = l * (0.7 + 0.3 * t)                          # Spitze heller
        if -d < 0.018: l *= 0.5                          # Umriss
        return (clamp(l), alpha)
    cv.paint(f); save('horn', cv)

# ---------------------------------------------------------------- Siegel (Pentagramm)
def make_sigil():
    cv = Canvas(256, 2)
    star = [(0.80 * math.cos(math.radians(90 + 144 * k)), 0.80 * math.sin(math.radians(90 + 144 * k))) for k in range(5)]
    segs = [(star[k], star[(k + 1) % 5]) for k in range(5)]
    def f(x, y):
        d = math.hypot(x, y)
        a = 0.0
        a = max(a, aa(0.022 - abs(d - 0.93), 0.012))
        a = max(a, aa(0.012 - abs(d - 0.82), 0.010))
        a = max(a, aa(0.010 - abs(d - 0.40), 0.010))
        # Runen-Striche zwischen den Kreisen
        if 0.84 < d < 0.91:
            th = math.atan2(y, x)
            k = (th / (2 * math.pi) * 40) % 1
            if abs(k - 0.5) < 0.06: a = max(a, 0.9)
            if abs(k - 0.0) < 0.02 or abs(k - 1) < 0.02: a = max(a, 0.6)
        for (p, q) in segs:
            a = max(a, aa(0.018 - seg_dist(x, y, p[0], p[1], q[0], q[1]), 0.012))
        for (sx, sy) in star:
            a = max(a, aa(0.055 - math.hypot(x - sx, y - sy), 0.012))
        if a <= 0: return None
        return (1.0, a)
    cv.paint(f); save('sigil', cv)

# ---------------------------------------------------------------- Arkane Runen
def make_runes():
    cv = Canvas(256, 2)
    rnd = random.Random(7)
    glyph_segs = []
    G = 12
    for g in range(G):
        th = 2 * math.pi * g / G
        cx, cy = 0.74 * math.cos(th), 0.74 * math.sin(th)
        for _ in range(3):
            ax, ay = rnd.uniform(-1, 1) * 0.06, rnd.uniform(-1, 1) * 0.06
            bx, by = rnd.uniform(-1, 1) * 0.06, rnd.uniform(-1, 1) * 0.06
            glyph_segs.append((cx + ax, cy + ay, cx + bx, cy + by))
    tri = []
    for off in (90, 270):
        pts = [(0.56 * math.cos(math.radians(off + 120 * k)), 0.56 * math.sin(math.radians(off + 120 * k))) for k in range(3)]
        tri += [(pts[k], pts[(k + 1) % 3]) for k in range(3)]
    def f(x, y):
        d = math.hypot(x, y)
        a = 0.0
        a = max(a, aa(0.016 - abs(d - 0.95), 0.012))
        a = max(a, aa(0.010 - abs(d - 0.88), 0.010))
        a = max(a, aa(0.012 - abs(d - 0.58), 0.010))
        if 0.62 < d < 0.86:
            for (ax, ay, bx, by) in glyph_segs:
                a = max(a, aa(0.011 - seg_dist(x, y, ax, ay, bx, by), 0.010))
        if d < 0.6:
            for (p, q) in tri:
                a = max(a, aa(0.010 - seg_dist(x, y, p[0], p[1], q[0], q[1]), 0.010))
        if a <= 0: return None
        return (1.0, a)
    cv.paint(f); save('runes', cv)

# ---------------------------------------------------------------- Sonnenstrahlen
def make_rays():
    cv = Canvas(256, 2)
    def f(x, y):
        d = math.hypot(x, y)
        if d >= 1: return None
        th = math.atan2(y, x)
        r1 = abs(math.cos(th * 8)) ** 10
        r2 = abs(math.cos(th * 8 + math.pi / 2)) ** 18 * 0.6
        a = max(r1, r2) * clamp((1 - d) * 1.6) * clamp((d - 0.25) * 4)
        a += 0.25 * clamp(1 - d) ** 3
        return (1.0, clamp(a))
    cv.paint(f); save('rays', cv)

# ---------------------------------------------------------------- Blatt
def make_leaf():
    cv = Canvas(128, 3)
    rx, ry, ang, length = 0.75, -0.75, math.radians(128), 2.0
    dx, dy = math.cos(ang), math.sin(ang); nx, ny = -dy, dx
    def f(x, y):
        px, py = x - rx, y - ry
        s = (px * dx + py * dy) / length
        if s < 0 or s > 1: return None
        q = px * nx + py * ny
        if s < 0.12:  # Stiel
            return (0.6, aa(0.022 - abs(q), 0.015))
        t = (s - 0.12) / 0.88
        w = 0.36 * math.sin(math.pi * t) ** 0.75 * (1 - 0.25 * t)
        if w <= 1e-4: return None
        alpha = aa(w - abs(q), 0.015)
        if alpha <= 0: return None
        e = abs(q) / w
        l = 0.75 + 0.25 * (1 - e)
        if abs(q) < 0.012: l *= 0.6                                   # Mittelrippe
        v = (t * 9 - e * 1.6) % 1                                     # Adern
        if v < 0.07: l *= 0.72
        if w - abs(q) < 0.025: l *= 0.55                              # Rand
        return (l, alpha)
    cv.paint(f); save('leaf', cv)

# ---------------------------------------------------------------- Blitz
def make_bolt():
    cv = Canvas(128, 3)
    poly = [(0.30, 0.95), (-0.35, 0.10), (0.02, 0.10), (-0.42, -0.95), (0.40, -0.05), (0.02, -0.05), (0.62, 0.95)]
    edges = [(poly[k], poly[(k + 1) % len(poly)]) for k in range(len(poly))]
    def inside(x, y):
        c = False
        for (a, b) in edges:
            if (a[1] > y) != (b[1] > y):
                xi = a[0] + (y - a[1]) * (b[0] - a[0]) / (b[1] - a[1])
                if x < xi: c = not c
        return c
    def f(x, y):
        dmin = min(seg_dist(x, y, a[0], a[1], b[0], b[1]) for (a, b) in edges)
        if inside(x, y):
            return (1.0 if dmin > 0.03 else 0.8, 1.0)
        g = clamp(1 - dmin / 0.12) ** 2 * 0.55   # Leuchten
        if g <= 0: return None
        return (1.0, g)
    cv.paint(f); save('bolt', cv)

# ---------------------------------------------------------------- einzelne Feder (Jaeger)
def make_feather():
    cv = Canvas(128, 3)
    feather(cv, (0.70, -0.85), 122, 1.95, 0.27, 0.95)
    save('feather', cv)

# ---------------------------------------------------------------- Ring-Symbole (64 px, zeigen nach oben)
def point_in_poly(x, y, poly):
    c = False
    n = len(poly)
    for k in range(n):
        ax, ay = poly[k]; bx, by = poly[(k + 1) % n]
        if (ay > y) != (by > y):
            xi = ax + (y - ay) * (bx - ax) / (by - ay)
            if x < xi: c = not c
    return c

def poly_dist(x, y, poly):
    n = len(poly)
    return min(seg_dist(x, y, poly[k][0], poly[k][1], poly[(k + 1) % n][0], poly[(k + 1) % n][1]) for k in range(n))

def sym(name, fn):
    cv = Canvas(64, 4)
    cv.paint(fn)
    save('sym_' + name, cv)

def shaded_poly(poly, edge=0.07):
    def f(x, y):
        d = poly_dist(x, y, poly)
        if point_in_poly(x, y, poly):
            l = 1.0 if d > edge else 0.72
            return (l, 1.0)
        return (1.0, aa(-d + 0.0, 0.04) * 0) if False else None
    return f

def make_symbols():
    # weicher Punkt
    sym('dot', lambda x, y: (1 - 0.3 * math.hypot(x, y), aa(0.86 - math.hypot(x, y), 0.08)))
    # harte Kugel (für den durchgehenden Kreis)
    sym('solid', lambda x, y: (1.0, aa(0.94 - math.hypot(x, y), 0.06)))
    # hohler Ring
    sym('circle', lambda x, y: (1.0, aa(0.17 - abs(math.hypot(x, y) - 0.70), 0.06)))
    # Raute
    def diamond(x, y):
        v = abs(x) / 0.62 + abs(y) / 0.95
        if v > 1.05: return None
        l = 1.0 if v < 0.82 else 0.72
        return (l, aa((1 - v) * 0.6, 0.04))
    sym('diamond', diamond)
    # Stern
    star = []
    for k in range(10):
        r = 0.95 if k % 2 == 0 else 0.42
        a = math.radians(90 + 36 * k)
        star.append((r * math.cos(a), r * math.sin(a) - 0.05))
    def starf(x, y):
        d = poly_dist(x, y, star)
        inside = point_in_poly(x, y, star)
        if not inside and d > 0.05: return None
        a = aa(d if inside else -d, 0.05)
        return (1.0 if (inside and d > 0.08) else 0.72, a)
    sym('star', starf)
    # Quadrat (abgerundet)
    def square(x, y):
        qx, qy = max(abs(x) - 0.52, 0), max(abs(y) - 0.52, 0)
        d = math.hypot(qx, qy) - 0.18
        l = 1.0 if d < -0.12 else 0.72
        return (l, aa(-d, 0.05))
    sym('square', square)
    # Herz
    def in_heart(x, y, k):
        X, Y = x * k, (y + 0.12) * k
        return (X * X + Y * Y - 1) ** 3 - X * X * Y ** 3 <= 0
    def heart(x, y):
        if not in_heart(x, y, 1.18): return None
        return (1.0 if in_heart(x, y, 1.36) else 0.72, 1.0)
    sym('heart', heart)
    # Flamme (Tropfenform mit geschwungener Spitze)
    def flame_w(y, scale):
        cy = -0.38
        r = 0.55 * scale
        if y <= cy:
            dy = y - cy
            return math.sqrt(max(0.0, r * r - dy * dy)), 0.0
        t = (y - cy) / (1.32 * scale)
        if t >= 1: return 0.0, 0.0
        return r * (1 - t) ** 1.3, 0.13 * math.sin(t * 3.2) * t
    def flame(x, y):
        w, off = flame_w(y, 1.0)
        if w <= 0: return None
        q = abs(x - off)
        a = aa(w - q, 0.05)
        if a <= 0: return None
        wi, oi = flame_w(y + 0.18, 0.55)
        core = wi > 0 and abs(x - oi) < wi
        return (1.0 if core else 0.72, a)
    sym('flame', flame)
    # Kreuz
    def cross(x, y):
        d1 = max(abs(x) - 0.17, abs(y) - 0.92)
        d2 = max(abs(x) - 0.62, abs(y - 0.30) - 0.17)
        d = min(d1, d2)
        l = 1.0 if d < -0.07 else 0.72
        return (l, aa(-d, 0.05))
    sym('cross', cross)
    # Totenkopf
    def skull(x, y):
        head = math.hypot(x, (y - 0.18) * 1.05) - 0.70
        jx, jy = max(abs(x) - 0.30, 0), max(abs(y + 0.50) - 0.30, 0)
        jaw = math.hypot(jx, jy) - 0.12
        d = min(head, jaw)
        if d > 0.05: return None
        eye = min(math.hypot(x - 0.27, y - 0.10), math.hypot(x + 0.27, y - 0.10)) - 0.19
        nose = max(abs(x) * 1.6 + (y + 0.18) * 1.0 - 0.18, -(y + 0.30))
        teeth = (y < -0.42 and y > -0.78 and abs(((x + 0.3) / 0.15) % 1 - 0.5) < 0.09 and abs(x) < 0.3)
        if eye < 0 or nose < 0:
            return (0.15, aa(-d, 0.05))
        l = 0.6 if teeth else (1.0 if d < -0.08 else 0.72)
        return (l, aa(-d, 0.05))
    sym('skull', skull)
    # Blatt (nach oben)
    def leaf(x, y):
        s = (y + 0.95) / 1.9
        if s < 0 or s > 1: return None
        if s < 0.1:
            return (0.7, aa(0.05 - abs(x), 0.04))
        t = (s - 0.1) / 0.9
        w = 0.5 * math.sin(math.pi * t) ** 0.75 * (1 - 0.2 * t)
        if w <= 1e-3: return None
        a = aa(w - abs(x), 0.05)
        if a <= 0: return None
        l = 0.65 if abs(x) < 0.04 else (0.72 if w - abs(x) < 0.07 else 1.0)
        return (l, a)
    sym('leaf', leaf)

# ---------------------------------------------------------------- Tortenstück (für den Torten-Modus)
# Schmaler Keil vom Mittelpunkt nach oben; 90 Stück ergeben eine volle Torte (je 4°, mit Überlappung).
def make_wedge():
    cv = Canvas(256, 2)
    half = math.radians(2.8)
    def f(x, y):
        r = math.hypot(x, y)
        if r > 0.99: return None
        th = abs(math.atan2(x, y))          # Winkel zur Achse "oben"
        if th > half + 0.05: return None
        d = r * math.sin(half - th) if th < half else -r * math.sin(th - half)
        a = aa(d, 0.012) * aa(0.97 - r, 0.02)
        if r < 0.02: a = 1.0
        return (1.0, a)
    cv.paint(f); save('wedge', cv)

if __name__ == '__main__':
    # Aufruf: python tools/gen_media.py <Media-Ordner> <Vorschau-Ordner> [name ...]
    which = sys.argv[3:] or ['glow', 'disc', 'rim', 'wing', 'horn', 'sigil', 'runes', 'rays', 'leaf', 'bolt', 'feather', 'symbols', 'wedge']
    for w in which:
        globals()['make_' + w]()
