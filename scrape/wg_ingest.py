#!/usr/bin/env python3
"""Riempie la griglia dell'archivio WeedGadget dentro content.json.

Prende le immagini da una di queste tre fonti:

  1. l'esportazione ufficiale dei dati Instagram (Impostazioni ▸ Centro gestione
     account ▸ Le tue informazioni ▸ Scarica le tue informazioni, formato JSON):

       python3 scrape/wg_ingest.py --from-export ~/Downloads/instagram-weedgadget

  2. una cartella di immagini già scaricate (ordine alfabetico del nome file):

       python3 scrape/wg_ingest.py --from-dir ~/Desktop/vetro

  3. un elenco JSON scritto a mano, [{"file": "...", "cap_it": "...", "cap_en": "..."}, ...]:

       python3 scrape/wg_ingest.py --from-json miei-pezzi.json

Per ogni pezzo scrive due file dentro assets/wg/grid/:
  <nome>.jpg (+ .webp)      la mattonella della griglia, lato 640
  large/<nome>.jpg          la versione grande che si apre col clic, lato 1600

e poi aggiorna la voce "grid" di content.json. Dopo, si ricostruisce il sito:

  python3 gen.py --theme oscura --out docs

Opzioni: --top N (quanti pezzi, 98 di default) · --sort date|likes|name
         --prefix wg (come si chiamano i file) · --dry-run (non scrive niente)
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)
GRID = os.path.join(ROOT, "assets", "wg", "grid")
LARGE = os.path.join(GRID, "large")
CONTENT = os.path.join(ROOT, "content.json")

TILE, FULL = 640, 1600
EXT = (".jpg", ".jpeg", ".png", ".webp", ".heic", ".tif", ".tiff")


# ---------------------------------------------------------------- lettura fonti
def fix_mojibake(s):
    """Instagram esporta i testi in UTF-8 letto come latin-1: qui si raddrizza."""
    try:
        return s.encode("latin-1").decode("utf-8")
    except (UnicodeEncodeError, UnicodeDecodeError):
        return s


def clean_caption(s):
    """Prima riga utile della didascalia, senza hashtag e senza menzioni."""
    s = fix_mojibake(s or "")
    s = re.sub(r"[#@][\w.]+", " ", s)
    s = re.sub(r"https?://\S+", " ", s)
    s = re.sub(r"\s+", " ", s).strip(" -–—·|")
    first = s.split("\n")[0].strip()
    return first[:120].strip()


def from_export(path):
    """Trova i post dentro l'esportazione Instagram, ovunque siano finiti."""
    candidates = []
    for dirpath, _dirnames, filenames in os.walk(path):
        for fn in filenames:
            if re.fullmatch(r"posts_\d+\.json", fn) or fn == "profile_photos.json":
                candidates.append(os.path.join(dirpath, fn))
    if not candidates:
        sys.exit(f"Nessun posts_*.json dentro {path}. È l'esportazione in formato JSON?")

    items = []
    for c in sorted(candidates):
        data = json.load(open(c, encoding="utf-8"))
        posts = data if isinstance(data, list) else data.get("photos", [])
        for post in posts:
            media = post.get("media", []) if isinstance(post, dict) else []
            cap = post.get("title", "") if isinstance(post, dict) else ""
            for m in media:
                uri = m.get("uri", "")
                if not uri.lower().endswith(EXT):
                    continue
                src = os.path.join(path, uri)
                if not os.path.exists(src):  # a volte l'uri è relativo a un livello più in su
                    alt = os.path.join(os.path.dirname(path), uri)
                    src = alt if os.path.exists(alt) else src
                if not os.path.exists(src):
                    continue
                items.append({
                    "src": src,
                    "ts": m.get("creation_timestamp") or post.get("creation_timestamp") or 0,
                    "cap": clean_caption(m.get("title") or cap),
                    "likes": 0,
                })
    return items


def from_dir(path):
    out = []
    for fn in sorted(os.listdir(path)):
        if fn.lower().endswith(EXT) and not fn.startswith("."):
            f = os.path.join(path, fn)
            out.append({"src": f, "ts": int(os.path.getmtime(f)), "cap": "", "likes": 0})
    if not out:
        sys.exit(f"Nessuna immagine dentro {path}.")
    return out


def from_json(path):
    data = json.load(open(path, encoding="utf-8"))
    out = []
    for i, rec in enumerate(data):
        src = rec["file"] if os.path.isabs(rec["file"]) else os.path.join(os.path.dirname(path), rec["file"])
        out.append({
            "src": src,
            "ts": rec.get("ts", len(data) - i),
            "cap": rec.get("cap_it", ""),
            "cap_en": rec.get("cap_en", ""),
            "likes": rec.get("likes", 0),
        })
    return out


# ------------------------------------------------------------------ ridimensiona
def have(cmd):
    return shutil.which(cmd) is not None


try:
    from PIL import Image, ImageOps  # noqa
    PIL = True
except ImportError:
    PIL = False


def resize(src, dst, side, quality=72, webp=False):
    """Riduce il lato lungo a `side`. Usa Pillow, altrimenti sips (Mac) o ImageMagick."""
    if PIL:
        im = Image.open(src)
        im = ImageOps.exif_transpose(im)
        if im.mode not in ("RGB", "L"):
            im = im.convert("RGB")
        im.thumbnail((side, side), Image.LANCZOS)
        if webp:
            im.save(dst, "WEBP", quality=quality, method=6)
        else:
            im.save(dst, "JPEG", quality=quality, optimize=True, progressive=True)
        return im.size
    if webp:  # senza Pillow il webp si salta: il sito usa il jpg
        return None
    if have("sips"):
        subprocess.run(["sips", "-Z", str(side), "-s", "format", "jpeg",
                        "-s", "formatOptions", str(quality), src, "--out", dst],
                       capture_output=True, check=True)
    elif have("magick") or have("convert"):
        cmd = "magick" if have("magick") else "convert"
        subprocess.run([cmd, src, "-auto-orient", "-resize", f"{side}x{side}>",
                        "-quality", str(quality), dst], capture_output=True, check=True)
    else:
        shutil.copy2(src, dst)
    return None


def measure(path):
    if PIL:
        with Image.open(path) as im:
            return im.size
    return (1080, 1080)


# ------------------------------------------------------------------------ main
def main():
    ap = argparse.ArgumentParser(description="Riempie la griglia WeedGadget del sito.")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--from-export", metavar="CARTELLA", help="esportazione dati Instagram")
    g.add_argument("--from-dir", metavar="CARTELLA", help="cartella di immagini")
    g.add_argument("--from-json", metavar="FILE", help="elenco scritto a mano")
    ap.add_argument("--top", type=int, default=98, help="quanti pezzi (98)")
    ap.add_argument("--sort", choices=("date", "likes", "name"), default="date")
    ap.add_argument("--prefix", default="wg")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    if a.from_export:
        items = from_export(os.path.expanduser(a.from_export))
    elif a.from_dir:
        items = from_dir(os.path.expanduser(a.from_dir))
    else:
        items = from_json(os.path.expanduser(a.from_json))

    if a.sort == "date":
        items.sort(key=lambda i: i["ts"], reverse=True)   # come stanno sul profilo
    elif a.sort == "likes":
        items.sort(key=lambda i: i["likes"], reverse=True)
    else:
        items.sort(key=lambda i: os.path.basename(i["src"]))
    items = items[: a.top]
    print(f"{len(items)} pezzi, ordinati per {a.sort}")

    if a.dry_run:
        for i, it in enumerate(items[:10], 1):
            print(f"  {i:02d} {os.path.basename(it['src'])}  {it['cap'][:60]}")
        print("  … (--dry-run: non ho scritto niente)")
        return

    os.makedirs(LARGE, exist_ok=True)
    grid = []
    for i, it in enumerate(items, 1):
        name = f"{a.prefix}-{i:03d}"
        tile = os.path.join(GRID, name + ".jpg")
        big = os.path.join(LARGE, name + ".jpg")
        try:
            resize(it["src"], big, FULL, quality=78)
            resize(it["src"], tile, TILE, quality=72)
            if PIL:
                resize(it["src"], os.path.join(GRID, name + ".webp"), TILE, quality=68, webp=True)
        except Exception as e:  # un file rotto non deve fermare tutta la griglia
            print(f"  salto {os.path.basename(it['src'])}: {e}")
            continue
        w, h = measure(tile)
        grid.append({
            "file": name,
            "w": w, "h": h,
            "cap_it": it.get("cap", ""),
            "cap_en": it.get("cap_en", it.get("cap", "")),
        })
        if i % 20 == 0:
            print(f"  … {i}")

    content = json.load(open(CONTENT, encoding="utf-8"))
    content["weedgadget"]["grid"] = grid
    content["weedgadget"]["grid_max"] = max(a.top, len(grid))
    json.dump(content, open(CONTENT, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    open(CONTENT, "a", encoding="utf-8").write("\n")

    print(f"scritti {len(grid)} pezzi in assets/wg/grid/ e in content.json")
    print("ora: python3 gen.py --theme oscura --out docs")


if __name__ == "__main__":
    main()
