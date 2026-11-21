"""Erzeugt die eigenen Balkentexturen von ManaSigil (Media/bar_*.tga).

Graustufen mit Alpha, werden im Spiel eingefärbt. Alles hier berechnet - keine fremden Grafiken.
Aufruf im Addon-Ordner:  python tools/make_bars.py   (braucht numpy)
"""
import os
import struct
import numpy as np

W, H = 256, 32          # Zweierpotenzen (Pflicht für Texturen im Spiel)
OUT = os.path.join(os.path.dirname(__file__), "..", "Media")

x = (np.arange(W) + 0.5) / W           # 0..1 von links nach rechts
v = (np.arange(H) + 0.5) / H           # 0..1 von oben nach unten
X, V = np.meshgrid(x, v)


def gloss():         # Glanz: helle obere Hälfte, leicht dunklere untere
    return np.where(V < 0.5, 0.95 - 0.2 * V, 0.72 - 0.15 * (V - 0.5))


def glass():         # Glasröhre: rund schattiert mit Lichtkante oben
    base = 0.5 + 0.45 * np.sin(np.pi * V)
    spec = 0.35 * np.exp(-((V - 0.22) / 0.07) ** 2)
    return base + spec


def bevel():         # Kante: hell oben, dunkel unten, flach in der Mitte
    l = np.full_like(V, 0.8)
    edge = 2.5 / H
    l = np.where(V < edge, 1.0, l)
    l = np.where(V > 1 - edge, 0.45, l)
    return l


def soft():          # Weich: sanfter Verlauf von oben nach unten
    return 1.0 - 0.4 * V


def shine():         # Lichtstreifen in der Mitte
    return 0.6 + 0.4 * np.exp(-((V - 0.5) / 0.18) ** 2)


def stripes():       # schräge Streifen
    phase = (X * W + V * H) / 16.0
    s = 0.5 + 0.5 * np.sin(2 * np.pi * phase)
    return 0.68 + 0.26 * (s > 0.5) + 0.1 * (1 - V)


def segments():      # einzelne Zellen mit dunklen Fugen
    l = 0.95 - 0.3 * V
    gap = (np.floor(X * W) % 32) < 2
    return np.where(gap, 0.3, l)


def grain():         # Körnung: leichtes Rauschen (fester Startwert = immer gleich)
    rng = np.random.default_rng(85)
    return 0.82 - 0.15 * V + rng.uniform(-0.12, 0.12, V.shape)


BARS = {
    "gloss": gloss, "glass": glass, "bevel": bevel, "soft": soft,
    "shine": shine, "stripes": stripes, "segments": segments, "grain": grain,
}


def save_tga(path, lum):
    lum = np.clip(lum, 0, 1)
    hdr = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, W, H, 32, 0x28)   # BGRA, Ursprung oben links
    g = (lum * 255 + 0.5).astype(np.uint8)
    a = np.full_like(g, 255)
    body = np.stack([g, g, g, a], axis=-1).tobytes()
    with open(path, "wb") as f:
        f.write(hdr + body)


if __name__ == "__main__":
    for name, fn in BARS.items():
        path = os.path.normpath(os.path.join(OUT, "bar_%s.tga" % name))
        save_tga(path, fn())
        print(path, os.path.getsize(path), "bytes")
