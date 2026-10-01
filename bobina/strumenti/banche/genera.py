#!/usr/bin/env python3
"""Dieci banche di suoni per la drum machine di nastro del TP-7.

Ogni banca è un WAV (48 kHz, 24 bit, stereo) con 16 suoni, uno ogni 2 secondi:
il silenzio in mezzo evita che un suono «sbavi» nel successivo quando il nastro corre.
Dentro ogni file ci sono già i 16 segni, scritti come li scrive il TP-7 stesso (letto il 1/10/2026 da un
file segnato a mano): chunk «cue» in fondo al file con id 0-15 in ordine di posizione, e un chunk
«LIST/adtl» che lega ogni segno a una nota col suo nome, «C2» = nota 36 = pad 1 di Bobina … «D#3» = pad 16.
Il tempo è nel chunk «acid» (120 bpm).
Tutti i suoni sono sintetizzati qui: niente campioni presi da altri.

    python3 genera.py          # scrive in ~/Downloads/tp7-banche BANCA01-….WAV … BANCA10-….WAV e ELENCO.txt
    python3 genera.py cartella # oppure in un'altra cartella
"""
import struct
from pathlib import Path

import numpy as np

SR = 48000
SLOT = 2.0          # secondi fra un suono e l'altro
MAXLEN = 1.6        # nessun suono dura di più: resta silenzio prima del successivo
PAD_NOTE = 36       # il primo pad di Bobina
TEMPO = 120.0
OUT = Path.home() / "Downloads" / "tp7-banche"

rng = np.random.default_rng(7)


# ---------------------------------------------------------------- mattoni

def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def noise(dur, seed=None):
    g = np.random.default_rng(seed) if seed is not None else rng
    return g.uniform(-1, 1, int(dur * SR))


def env(dur, decay, attack=0.0005, curve=1.0):
    t = t_axis(dur)
    e = np.exp(-t / decay) ** curve
    if attack > 0:
        a = np.clip(t / attack, 0, 1)
        e = e * a
    return e


def filt(x, lo=None, hi=None, order=2):
    """Filtro passa-alto/passa-basso/passa-banda fatto nello spettro (butterworth di modulo)."""
    n = len(x)
    if n == 0:
        return x
    size = 1 << (n - 1).bit_length()
    X = np.fft.rfft(x, size)
    f = np.fft.rfftfreq(size, 1 / SR)
    f[0] = 1e-6
    H = np.ones_like(f)
    if hi:
        H *= 1 / np.sqrt(1 + (f / hi) ** (2 * order))
    if lo:
        H *= 1 / np.sqrt(1 + (lo / f) ** (2 * order))
    return np.fft.irfft(X * H, size)[:n]


def sweep(dur, f_start, f_end, time):
    """Seno con l'altezza che scende da f_start a f_end (esponenziale, costante «time»)."""
    t = t_axis(dur)
    f = f_end + (f_start - f_end) * np.exp(-t / time)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def sine(dur, f, phase=0.0):
    return np.sin(2 * np.pi * f * t_axis(dur) + phase)


def square(dur, f):
    return np.sign(np.sin(2 * np.pi * f * t_axis(dur)) + 1e-9)


def saw(dur, f, detune=0.0):
    t = t_axis(dur)
    return 2 * ((f * (1 + detune) * t) % 1.0) - 1


def sat(x, drive=2.0):
    return np.tanh(drive * x) / np.tanh(drive)


def crush(x, bits=8, down=4):
    y = np.repeat(x[::down], down)[: len(x)]
    q = 2 ** (bits - 1)
    return np.round(y * q) / q


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def pad_to(x, dur):
    n = int(dur * SR)
    return x[:n] if len(x) >= n else np.concatenate([x, np.zeros(n - len(x))])


# ---------------------------------------------------------------- strumenti

def kick808(f=48, start=140, sweep_t=0.045, decay=0.75, click=0.25):
    d = min(MAXLEN, decay * 4)
    body = sweep(d, start, f, sweep_t) * env(d, decay)
    clk = filt(noise(0.01), lo=1500) * env(0.01, 0.002) * click
    return sat(mix(body, clk), 1.3)


def kick909(f=52, start=260, decay=0.32, drive=2.5):
    d = min(MAXLEN, decay * 4)
    body = sweep(d, start, f, 0.03) * env(d, decay)
    clk = filt(noise(0.02), lo=800, hi=9000) * env(0.02, 0.004) * 0.6
    return sat(mix(body, clk), drive)


def snare(tone=185, noise_decay=0.18, tone_decay=0.08, bright=7000, snap=0.7):
    d = min(MAXLEN, noise_decay * 5)
    tn = (sine(d, tone) + 0.5 * sine(d, tone * 1.78)) * env(d, tone_decay) * 0.6
    nz = filt(noise(d), lo=1200, hi=bright) * env(d, noise_decay) * snap
    return sat(mix(tn, nz), 1.6)


def clap(spread=0.011, tail=0.16, lo=900, hi=3500):
    d = 0.7
    out = np.zeros(int(d * SR))
    for k in range(4):
        start = int(k * spread * SR)
        burst = filt(noise(0.03), lo=lo, hi=hi) * env(0.03, 0.006)
        out[start:start + len(burst)] += burst * (0.8 if k < 3 else 1.0)
    t0 = int(3 * spread * SR)
    tl = filt(noise(d), lo=lo, hi=hi) * env(d, tail)
    out[t0:] += tl[: len(out) - t0] * 0.7
    return out


METAL = [205.3, 304.4, 369.6, 522.7, 540.0, 800.0]


def metal(dur, scale=1.0):
    return sum(square(dur, f * scale) for f in METAL) / len(METAL)


def hat(decay=0.045, scale=1.0, lo=7000):
    d = min(MAXLEN, max(0.15, decay * 6))
    m = filt(metal(d, scale), lo=lo, hi=16000) * 0.8 + filt(noise(d), lo=lo) * 0.35
    return m * env(d, decay)


def cymbal(decay=0.9, scale=1.0, lo=4500):
    d = MAXLEN
    m = filt(metal(d, scale * 1.5), lo=lo, hi=15000) * 0.6 + filt(noise(d), lo=lo) * 0.6
    return m * env(d, decay, attack=0.002)


def ride(decay=1.0, bell=0.4):
    d = MAXLEN
    m = filt(metal(d, 2.1), lo=3000, hi=12000) * 0.5 * env(d, decay)
    b = (sine(d, 760) + sine(d, 1140) * 0.6) * env(d, 0.4) * bell
    return mix(m, b)


def tom(start=210, end=120, decay=0.28):
    d = min(MAXLEN, decay * 4)
    body = sweep(d, start, end, 0.08) * env(d, decay)
    skin = filt(noise(0.03), lo=500, hi=4000) * env(0.03, 0.008) * 0.3
    return mix(body, skin)


def conga(f=330, decay=0.18, slap=0.25):
    d = 0.8
    body = sweep(d, f * 1.35, f, 0.012) * env(d, decay)
    s = filt(noise(0.02), lo=1500, hi=6000) * env(0.02, 0.004) * slap
    return mix(body, s)


def rim(f=1700, decay=0.012):
    d = 0.12
    return mix(sine(d, f) * env(d, decay), filt(noise(d), lo=2000, hi=8000) * env(d, decay * 0.6) * 0.6,
               sine(d, 520) * env(d, decay * 2) * 0.5)


def cowbell(decay=0.22, f1=540, f2=800):
    d = 0.9
    x = (square(d, f1) + square(d, f2)) * 0.5
    return filt(x, lo=500, hi=2600) * mix(env(d, 0.012) * 0.6, env(d, decay) * 0.6)


def clave(f=2500, decay=0.035):
    d = 0.3
    return sine(d, f) * env(d, decay)


def woodblock(f=1100, decay=0.05):
    d = 0.35
    return mix(sine(d, f) * env(d, decay), sine(d, f * 2.7) * env(d, decay * 0.4) * 0.3)


def shaker(decay=0.07, attack=0.015, lo=5000):
    d = 0.4
    return filt(noise(d), lo=lo, hi=14000) * env(d, decay, attack=attack)


def guiro(n=9, gap=0.028):
    d = n * gap + 0.08
    out = np.zeros(int(d * SR))
    for k in range(n):
        g = filt(noise(0.02), lo=1800, hi=7000) * env(0.02, 0.005) * (0.6 + 0.4 * k / n)
        s = int(k * gap * SR)
        out[s:s + len(g)] += g
    return out


def agogo(f=880, decay=0.25):
    d = 0.9
    return (sine(d, f) + 0.4 * sine(d, f * 2.4) + 0.2 * sine(d, f * 3.9)) * env(d, decay) * 0.7


def tabla(f=290, bend=1.4, decay=0.3):
    d = 0.9
    t = t_axis(d)
    freq = f * (1 + (bend - 1) * (1 - np.exp(-t / 0.05)))
    return np.sin(2 * np.pi * np.cumsum(freq) / SR) * env(d, decay) * 0.9


def zap(start=3000, end=60, time=0.03, decay=0.12):
    d = 0.5
    return sweep(d, start, end, time) * env(d, decay)


def bleep(f=1200, dur=0.06, wave="square"):
    x = square(dur, f) if wave == "square" else sine(dur, f)
    return x * env(dur, dur * 0.5) * 0.6


def ringmod(f1=320, f2=1170, decay=0.15):
    d = 0.6
    return sine(d, f1) * sine(d, f2) * env(d, decay)


def noise_hit(decay=0.06, lo=300, hi=6000, bits=6, down=6):
    d = 0.4
    return crush(filt(noise(d), lo=lo, hi=hi) * env(d, decay), bits, down)


def bass808(note, decay=0.9):
    f = 440 * 2 ** ((note - 69) / 12)
    d = MAXLEN
    body = sweep(d, f * 2.2, f, 0.02) * env(d, decay)
    return sat(body, 1.8)


def stab(notes, decay=0.35, cutoff=4500, wave="saw"):
    d = 0.9
    x = np.zeros(int(d * SR))
    for n in notes:
        f = 440 * 2 ** ((n - 69) / 12)
        if wave == "saw":
            x += saw(d, f) * 0.5 + saw(d, f, 0.006) * 0.5
        else:
            x += square(d, f)
    x /= len(notes)
    # filtro che si chiude: tre fette con taglio diverso, sfumate
    a = filt(x, hi=cutoff) * env(d, 0.06)
    b = filt(x, hi=cutoff * 0.35) * (env(d, decay) - env(d, 0.06)).clip(0)
    return (a + b) * 0.9


def fm(note, ratio=3.5, index=4.0, decay=0.6, idx_decay=0.15):
    f = 440 * 2 ** ((note - 69) / 12)
    d = min(MAXLEN, decay * 3)
    t = t_axis(d)
    mod = np.sin(2 * np.pi * f * ratio * t) * index * np.exp(-t / idx_decay)
    return np.sin(2 * np.pi * f * t + mod) * env(d, decay)


def marimba(note, decay=0.35):
    f = 440 * 2 ** ((note - 69) / 12)
    d = 1.2
    return (sine(d, f) + 0.3 * sine(d, f * 4) * env(d, 0.05) + 0.1 * sine(d, f * 9.8) * env(d, 0.01)) * env(d, decay)


def lofi(x, bits=7, down=3, hi=6500):
    return sat(filt(crush(x, bits, down), hi=hi), 1.4)


def vinyl(x):
    d = len(x) / SR
    crackle = np.zeros(len(x))
    pos = rng.integers(0, len(x), size=max(3, int(d * 40)))
    crackle[pos] = rng.uniform(-0.3, 0.3, size=len(pos))
    return x + filt(crackle, lo=1500) * 0.5 + filt(noise(d), lo=200, hi=3000) * 0.01


# ---------------------------------------------------------------- le banche

def banks():
    C1, Eb1, F1, G1, Bb1 = 24, 27, 29, 31, 34
    pent = [48, 51, 53, 55, 58, 60, 63, 65, 67, 70, 72, 75, 77, 79, 82, 84]   # do minore pentatonica
    scale = [36, 38, 39, 41, 43, 44, 46, 48, 50, 51, 53, 55, 56, 58, 60, 62]  # do minore naturale
    return [
        ("808", [
            ("cassa lunga", kick808()), ("cassa corta", kick808(decay=0.28)), ("rullante", snare()),
            ("clap", clap()), ("charleston chiuso", hat()), ("charleston aperto", hat(decay=0.3)),
            ("tom basso", tom(150, 85, 0.35)), ("tom medio", tom(210, 120, 0.3)), ("tom alto", tom(300, 180, 0.25)),
            ("conga", conga()), ("rimshot", rim()), ("campanaccio", cowbell()),
            ("clave", clave()), ("maracas", shaker()), ("piatto", cymbal()), ("cassa + clap", mix(kick808(decay=0.4), clap() * 0.7)),
        ]),
        ("909", [
            ("cassa", kick909()), ("cassa sporca", kick909(drive=5, decay=0.4)), ("rullante", snare(tone=200, noise_decay=0.14, bright=9000, snap=0.9)),
            ("rullante corto", snare(tone=230, noise_decay=0.07, tone_decay=0.04)), ("clap", clap(spread=0.009, tail=0.12)),
            ("charleston chiuso", hat(decay=0.03, scale=1.3)), ("charleston aperto", hat(decay=0.25, scale=1.3)),
            ("charleston a pedale", hat(decay=0.06, scale=1.1, lo=5000) * 0.8), ("ride", ride()), ("crash", cymbal(decay=0.7, lo=5000)),
            ("tom basso", tom(130, 90, 0.3)), ("tom medio", tom(190, 130, 0.25)), ("tom alto", tom(270, 190, 0.2)),
            ("rimshot", rim(f=1900)), ("doppio clap", mix(clap(), np.concatenate([np.zeros(int(0.06 * SR)), clap() * 0.6]))),
            ("cassa + aperto", mix(kick909(), hat(decay=0.25, scale=1.3) * 0.6)),
        ]),
        ("legno e pelle", [
            ("cassa morbida", filt(kick808(f=60, start=110, decay=0.25), hi=2500)), ("rullante spazzola", filt(noise(0.5), lo=1500, hi=6000) * env(0.5, 0.22, attack=0.02) * 0.8),
            ("rullante pieno", snare(tone=170, noise_decay=0.22, bright=5000)), ("cerchio", rim(f=1400, decay=0.02)),
            ("charleston", hat(decay=0.05, scale=0.8, lo=5000)), ("charleston aperto", hat(decay=0.4, scale=0.8, lo=5000)),
            ("ride", ride(decay=1.3, bell=0.2)), ("campana del ride", ride(decay=0.6, bell=1.0)),
            ("timpano basso", tom(110, 80, 0.45)), ("timpano medio", tom(160, 120, 0.38)), ("timpano alto", tom(220, 170, 0.32)),
            ("bacchette", clave(f=1800, decay=0.02)), ("legnetto", woodblock()), ("legnetto basso", woodblock(f=700)),
            ("tamburello", mix(shaker(decay=0.12, attack=0.002, lo=6000), hat(decay=0.08, scale=2.2) * 0.5)),
            ("crash scuro", cymbal(decay=1.0, scale=0.7, lo=3000)),
        ]),
        ("lo-fi", [(n, vinyl(lofi(x))) for n, x in [
            ("cassa", kick808(decay=0.4)), ("cassa piena", kick909(drive=3)), ("rullante", snare(noise_decay=0.15)),
            ("rullante polveroso", snare(tone=160, bright=4000)), ("clap", clap()), ("charleston", hat(decay=0.04)),
            ("charleston aperto", hat(decay=0.22)), ("shaker", shaker()), ("rimshot", rim()), ("tom", tom(180, 110, 0.3)),
            ("campanaccio", cowbell()), ("schiocco", clave(f=1500, decay=0.02)), ("piatto", cymbal(decay=0.6)),
            ("cassa doppia", mix(kick808(decay=0.25), np.concatenate([np.zeros(int(0.18 * SR)), kick808(decay=0.25) * 0.7]))),
            ("accordo", stab([60, 63, 67, 70], decay=0.4, cutoff=3000)), ("basso", bass808(Eb1 + 12, decay=0.5)),
        ]]),
        ("elettro e industriale", [
            ("cassa distorta", kick909(drive=8, decay=0.3)), ("cassa metallica", mix(kick909(decay=0.25), ringmod(90, 610, 0.1) * 0.5)),
            ("rullante di rumore", noise_hit(decay=0.12, lo=800, hi=9000, bits=5, down=2)), ("clap metallico", mix(clap(), ringmod(400, 1500, 0.08) * 0.4)),
            ("charleston elettrico", hat(decay=0.02, scale=1.8)), ("aperto elettrico", hat(decay=0.18, scale=1.8)),
            ("zap", zap()), ("zap basso", zap(start=800, end=40, decay=0.25)), ("laser", zap(start=6000, end=400, time=0.08, decay=0.2)),
            ("lamiera", ringmod(220, 1430, 0.3)), ("martello", sat(mix(tom(400, 150, 0.06), filt(noise(0.2), lo=2000) * env(0.2, 0.03)), 4)),
            ("vapore", filt(noise(0.8), lo=2000, hi=12000) * env(0.8, 0.25, attack=0.05) * 0.8),
            ("scarica", noise_hit(decay=0.25, lo=100, hi=12000, bits=4, down=8)), ("bip", bleep(2400, 0.05)),
            ("ferro", cymbal(decay=0.5, scale=2.4, lo=2500)), ("colpo sordo", sat(filt(kick808(f=40, start=90, decay=0.5), hi=400), 3)),
        ]),
        ("percussioni", [
            ("conga bassa", conga(220, 0.22)), ("conga", conga(300, 0.18)), ("conga alta", conga(390, 0.15)),
            ("bongo basso", conga(450, 0.1, slap=0.4)), ("bongo alto", conga(620, 0.08, slap=0.4)),
            ("timbale", mix(tom(420, 380, 0.25), filt(noise(0.3), lo=3000) * env(0.3, 0.05) * 0.3)),
            ("timbale alto", mix(tom(560, 500, 0.2), filt(noise(0.3), lo=3000) * env(0.3, 0.05) * 0.3)),
            ("clave", clave()), ("legnetto", woodblock(1300)), ("guiro", guiro()), ("shaker", shaker(decay=0.1, attack=0.03)),
            ("cabasa", shaker(decay=0.05, attack=0.005, lo=7000)), ("agogò basso", agogo(660)), ("agogò alto", agogo(990)),
            ("tabla", tabla()), ("tabla bassa", tabla(f=110, bend=1.9, decay=0.45)),
        ]),
        ("glitch", [
            ("clic", filt(noise(0.005), lo=2000) * env(0.005, 0.001)), ("clic basso", sine(0.03, 120) * env(0.03, 0.004)),
            ("bip", bleep(1800)), ("bip doppio", np.concatenate([bleep(1800, 0.03), np.zeros(int(0.03 * SR)), bleep(2600, 0.03)])),
            ("bolla", sweep(0.15, 400, 1600, 0.05) * env(0.15, 0.05)), ("goccia", sweep(0.2, 2400, 500, 0.02) * env(0.2, 0.06)),
            ("granello", crush(sine(0.08, 3100) * env(0.08, 0.02), 3, 12)), ("errore", noise_hit(decay=0.04, bits=3, down=20)),
            ("modem", crush(mix(square(0.18, 1200) * 0.5, square(0.18, 2100) * 0.5) * env(0.18, 0.08), 4, 2)),
            ("salto", np.tile(crush(noise(0.012), 4, 4) * env(0.012, 0.004), 8)),
            ("ronzio", ringmod(60, 1200, 0.12)), ("cassa minuscola", kick909(f=70, start=400, decay=0.08)),
            ("rullante digitale", crush(snare(noise_decay=0.08), 5, 5)), ("charleston digitale", crush(hat(decay=0.03), 4, 3)),
            ("sirena corta", sweep(0.3, 900, 1500, 0.1) * env(0.3, 0.12)), ("vuoto", sat(sine(0.25, 45) * env(0.25, 0.08), 6)),
        ]),
        ("bassi 808", [(f"basso {k + 1}", bass808(n)) for k, n in enumerate(scale)]),
        ("accordi", [(f"accordo {k + 1}", stab(ch)) for k, ch in enumerate([
            [48, 51, 55, 58], [50, 53, 56, 60], [51, 55, 58, 62], [53, 56, 60, 63], [55, 58, 62, 65], [56, 60, 63, 67],
            [58, 62, 65, 68], [60, 63, 67, 70], [48, 55, 60, 63], [53, 60, 63, 68], [55, 62, 65, 70], [44, 51, 56, 60],
            [46, 53, 58, 62], [48, 52, 55, 59], [53, 57, 60, 64], [55, 59, 62, 65],
        ])]),
        ("campane e marimba", [(f"campana {k + 1}", fm(n + 12)) for k, n in enumerate(pent[:8])] +
                              [(f"marimba {k + 1}", marimba(n)) for k, n in enumerate(pent[:8])]),
    ]


# ---------------------------------------------------------------- il file per il TP-7

def to_24bit(stereo):
    x = np.clip(stereo, -1, 1)
    ints = np.round(x * 8388607).astype(np.int32)
    b = ints.astype("<i4").view(np.uint8).reshape(-1, 4)[:, :3]
    return b.tobytes()


def acid_chunk(beats):
    body = struct.pack("<IHHfIHHf", 0, 60, 0x8000, 0.0, beats, 4, 4, TEMPO)
    return b"acid" + struct.pack("<I", len(body)) + body


NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def note_name(n):
    """Come le chiama il TP-7: 36 = «C2», 37 = «C#2»."""
    return f"{NOTE_NAMES[n % 12]}{n // 12 - 1}"


def cue_chunk(offsets):
    """Id da 0 in ordine di posizione e «position» a 0, come nei file del TP-7."""
    body = struct.pack("<I", len(offsets))
    for k, off in enumerate(offsets):
        body += struct.pack("<II4sIII", k, 0, b"data", 0, 0, off)
    return b"cue " + struct.pack("<I", len(body)) + body


def note_chunk(count):
    """LIST/adtl con un «note» per segno: id del segno + nome della nota, in 4 byte chiusi da zeri."""
    body = b"adtl"
    for k in range(count):
        text = note_name(PAD_NOTE + k).encode("ascii").ljust(4, b"\x00")
        sub = struct.pack("<I", k) + text
        body += b"note" + struct.pack("<I", len(sub)) + sub
    return b"LIST" + struct.pack("<I", len(body)) + body


def write_bank(path, sounds):
    slots = []
    offsets = []
    for k, (_, x) in enumerate(sounds):
        x = np.asarray(x, dtype=float)[: int(MAXLEN * SR)]
        peak = np.max(np.abs(x)) or 1.0
        x = x / peak * 0.89                      # −1 dB
        fade = min(int(0.008 * SR), len(x) // 4)
        x[len(x) - fade:] *= np.linspace(1, 0, fade)
        offsets.append(int(k * SLOT * SR))
        slots.append(pad_to(x, SLOT))
    mono = np.concatenate(slots)
    stereo = np.stack([mono, mono], axis=1).reshape(-1)
    data = to_24bit(stereo)
    fmt = struct.pack("<HHIIHH", 1, 2, SR, SR * 2 * 3, 6, 24)
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt
    chunks += acid_chunk(int(len(sounds) * SLOT * TEMPO / 60))
    chunks += b"data" + struct.pack("<I", len(data)) + data
    if len(data) % 2:
        chunks += b"\x00"
    chunks += cue_chunk(offsets)
    chunks += note_chunk(len(offsets))
    path.write_bytes(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)


def main():
    global OUT
    import sys
    if len(sys.argv) > 1:
        OUT = Path(sys.argv[1]).expanduser().resolve()
    OUT.mkdir(parents=True, exist_ok=True)
    lines = ["Banche per la drum machine di nastro del TP-7", "",
             f"Ogni file: 16 suoni, uno ogni {SLOT:g} secondi. Segni già scritti nel file e legati alle note {note_name(PAD_NOTE)}-{note_name(PAD_NOTE + 15)}: pad 1-16 di Bobina.", ""]
    for i, (name, sounds) in enumerate(banks(), start=1):
        assert len(sounds) == 16, (name, len(sounds))
        fname = f"BANCA{i:02d}-{name.upper().replace(' ', '-').replace('À', 'A').replace('Ò', 'O')}.WAV"
        write_bank(OUT / fname, sounds)
        lines.append(f"{fname}")
        for k, (label, _) in enumerate(sounds, start=1):
            lines.append(f"  pad {k:2d}  {note_name(PAD_NOTE + k - 1):>3}  ({k * SLOT - SLOT:4.0f} s)  {label}")
        lines.append("")
        print("scritto", fname)
    (OUT / "ELENCO.txt").write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    main()
