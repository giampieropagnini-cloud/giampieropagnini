#!/usr/bin/env python3
"""Un «album» per il TP-7: fino a 16 registrazioni una dopo l'altra in un solo file,
con un segno all'inizio di ognuna già legato ai pad di Bobina (C2 = pad 1 … D#3 = pad 16).

Il TP-7 via MIDI non sa passare a un altro file, ma dentro lo stesso file salta ai segni:
così i pad, e i tasti ⏮ ⏭ canzone di Bobina, cambiano canzone.

    python3 album.py cartella-con-i-file            # scrive ALBUM-<NOME>.WAV accanto alla cartella
    python3 album.py cartella-con-i-file --pausa 2  # secondi di silenzio fra una canzone e l'altra (1 se non lo dici)

Le canzoni entrano in ordine di nome. Qualsiasi formato che ffmpeg legga; esce WAV 48 kHz, 24 bit, stereo.
Il formato dei segni è quello che scrive il TP-7 stesso (vedi genera.py).
"""
import argparse
import struct
import subprocess
from pathlib import Path

import numpy as np

SR = 48000
PAD_NOTE = 36
TEMPO = 120.0
AUDIO = {".wav", ".aif", ".aiff", ".mp3", ".m4a", ".flac", ".ogg", ".caf"}
NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def note_name(n):
    return f"{NOTE_NAMES[n % 12]}{n // 12 - 1}"


def read_audio(path):
    """Decodifica con ffmpeg in float stereo a 48 kHz."""
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-map", "0:a:0", "-ac", "2", "-ar", str(SR),
         "-f", "f32le", "-acodec", "pcm_f32le", "-"],
        check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype="<f4").reshape(-1, 2).astype(np.float64)


def to_24bit(stereo):
    ints = np.round(np.clip(stereo, -1, 1).reshape(-1) * 8388607).astype("<i4")
    return ints.view(np.uint8).reshape(-1, 4)[:, :3].tobytes()


def chunk(cid, body):
    pad = b"\x00" if len(body) % 2 else b""
    return cid + struct.pack("<I", len(body)) + body + pad


def build(folder, gap):
    files = sorted(p for p in Path(folder).iterdir() if p.suffix.lower() in AUDIO and not p.name.startswith("."))
    if not files:
        raise SystemExit("nessun file audio nella cartella")
    if len(files) > 16:
        print(f"attenzione: {len(files)} file, i pad sono 16: entrano i primi 16")
        files = files[:16]
    silence = np.zeros((int(gap * SR), 2))
    parts, offsets, names = [], [], []
    pos = 0
    for f in files:
        x = read_audio(f)
        offsets.append(pos)
        names.append((f.stem, len(x) / SR))
        parts += [x, silence]
        pos += len(x) + len(silence)
    audio = np.concatenate(parts)
    data = to_24bit(audio)

    fmt = struct.pack("<HHIIHH", 1, 2, SR, SR * 6, 6, 24)
    beats = int(len(audio) / SR * TEMPO / 60)
    acid = struct.pack("<IHHfIHHf", 0, 60, 0x8000, 0.0, beats, 4, 4, TEMPO)
    cue = struct.pack("<I", len(offsets)) + b"".join(
        struct.pack("<II4sIII", k, 0, b"data", 0, 0, off) for k, off in enumerate(offsets))
    adtl = b"adtl" + b"".join(
        chunk(b"note", struct.pack("<I", k) + note_name(PAD_NOTE + k).encode("ascii").ljust(4, b"\x00"))
        for k in range(len(offsets)))
    body = chunk(b"fmt ", fmt) + chunk(b"acid", acid) + chunk(b"data", data) + chunk(b"cue ", cue) + chunk(b"LIST", adtl)

    folder = Path(folder).resolve()
    nome = "".join(c if c.isalnum() else "-" for c in folder.name.upper()).strip("-")
    out = folder.parent / f"ALBUM-{nome}.WAV"
    out.write_bytes(b"RIFF" + struct.pack("<I", 4 + len(body)) + b"WAVE" + body)

    elenco = [f"{out.name}: {len(files)} canzoni, {len(audio) / SR / 60:.1f} minuti", ""]
    for k, ((stem, dur), off) in enumerate(zip(names, offsets), start=1):
        m, s = divmod(off / SR, 60)
        elenco.append(f"  pad {k:2d}  {note_name(PAD_NOTE + k - 1):>3}  da {int(m)}:{s:04.1f}  ({dur:.1f} s)  {stem}")
    (folder.parent / f"ALBUM-{nome}.txt").write_text("\n".join(elenco) + "\n", encoding="utf-8")
    print("\n".join(elenco))


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("cartella")
    ap.add_argument("--pausa", type=float, default=1.0, help="secondi di silenzio fra le canzoni")
    a = ap.parse_args()
    build(a.cartella, a.pausa)


if __name__ == "__main__":
    main()
