"""Erzeugt die eigenen Warntöne von ManaSigil (Media/snd_*.ogg).

Alle Töne werden hier synthetisch berechnet - keine fremden Aufnahmen.
Aufruf im Addon-Ordner:  python tools/make_sounds.py   (braucht numpy und soundfile)
"""
import os
import numpy as np
import soundfile as sf

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "Media")


def t(sec):
    return np.arange(int(RATE * sec)) / RATE


def env(x, attack=0.01, release=0.05):
    """weiches Ein- und Ausblenden gegen Knacken"""
    n = len(x)
    e = np.ones(n)
    a, r = max(1, int(RATE * attack)), max(1, int(RATE * release))
    e[:a] = np.linspace(0, 1, a)
    e[-r:] = np.linspace(1, 0, r)
    return x * e


def square(f, x, harmonics=9):
    out = np.zeros_like(x)
    for k in range(1, harmonics * 2, 2):
        out += np.sin(2 * np.pi * f * k * x) / k
    return out


def saw(f, x, harmonics=12):
    out = np.zeros_like(x)
    for k in range(1, harmonics + 1):
        out += np.sin(2 * np.pi * f * k * x) / k
    return out


def silence(sec):
    return np.zeros(int(RATE * sec))


def horn():          # Autohupe: zweimal kurz, zwei verstimmte Töne
    x = t(0.32)
    honk = env(square(415, x, 6) + square(520, x, 6), 0.01, 0.04)
    return np.concatenate([honk, silence(0.08), honk])


def airhorn():       # Drucklufthorn: lang, Dreiklang mit Sägezahn
    x = t(1.2)
    tone = saw(233, x) + saw(294, x) + saw(349, x)
    return env(tone, 0.03, 0.15)


def siren():         # Sirene: zweimal auf und ab
    x = t(1.6)
    f = 750 + 450 * np.sin(2 * np.pi * 1.25 * x - np.pi / 2)
    phase = 2 * np.pi * np.cumsum(f) / RATE
    tone = np.sin(phase) + 0.3 * np.sin(2 * phase)
    return env(tone, 0.02, 0.1)


def buzzer():        # Summer: tief und rau
    x = t(0.7)
    return env(square(150, x, 15) + 0.5 * square(152, x, 15), 0.005, 0.05)


def beeps():         # dreimal Piepen
    x = t(0.12)
    b = env(np.sin(2 * np.pi * 1200 * x), 0.005, 0.02)
    return np.concatenate([b, silence(0.08), b, silence(0.08), b])


def chime():         # Glockenspiel: zwei Töne mit Nachklang
    def bell(f, sec):
        x = t(sec)
        tone = np.sin(2 * np.pi * f * x) + 0.5 * np.sin(2 * np.pi * f * 2.76 * x) + 0.25 * np.sin(2 * np.pi * f * 5.4 * x)
        return env(tone * np.exp(-x * 3.5), 0.003, 0.05)
    return np.concatenate([bell(988, 0.5), bell(784, 1.0)])


def alarm():         # Alarm: zwei Töne im Wechsel
    parts = []
    for i in range(6):
        parts.append(env(square(950 if i % 2 == 0 else 700, t(0.18), 7), 0.005, 0.02))
    return np.concatenate(parts)


SOUNDS = {
    "horn": horn, "airhorn": airhorn, "siren": siren, "buzzer": buzzer,
    "beeps": beeps, "chime": chime, "alarm2": alarm,
}

if __name__ == "__main__":
    for name, fn in SOUNDS.items():
        data = fn()
        data = 0.9 * data / np.max(np.abs(data))
        path = os.path.normpath(os.path.join(OUT, "snd_%s.ogg" % name))
        sf.write(path, data.astype(np.float32), RATE, format="OGG", subtype="VORBIS")
        print(path, "%.2f s" % (len(data) / RATE), os.path.getsize(path), "bytes")
