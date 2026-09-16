#!/usr/bin/env python3
"""Prepara una scheda SD con playlist permanenti per la cornice, senza cloud.

La cornice legge dalla radice della scheda fino a 4 cartelle chiamate
`meural1`, `meural2`, `meural3`, `meural4` e le mostra come playlist.

Uso:
  python3 scheda_sd.py <cartella-immagini> <percorso-scheda> [--slot 1] [--orientation auto|landscape|portrait] [--fit fit|crop]

Esempio su Mac, con la scheda che si chiama "MEURAL":
  python3 scheda_sd.py immagini/nft /Volumes/MEURAL --slot 1

Con Pillow installato le immagini vengono adattate a 1920x1080 / 1080x1920,
altrimenti vengono copiate così come sono.
"""
import argparse
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import images  # noqa: E402


def prepara(src, sd, slot=1, orientation="auto", fit="fit", background="#000000", svuota=False):
    if slot not in (1, 2, 3, 4):
        raise ValueError("slot deve essere 1, 2, 3 o 4")
    if not os.path.isdir(sd):
        raise FileNotFoundError(f"scheda non trovata: {sd}")
    files = images.list_images(src)
    if not files:
        raise FileNotFoundError(f"nessuna immagine in {src}")
    dest = os.path.join(sd, f"meural{slot}")
    if svuota and os.path.isdir(dest):
        shutil.rmtree(dest)
    os.makedirs(dest, exist_ok=True)
    n = 0
    for i, name in enumerate(files, 1):
        data, out_name, _ = images.prepare(os.path.join(src, name), orientation, fit, background)
        # numero davanti: la cornice le mostra in ordine di nome
        out_path = os.path.join(dest, f"{i:03d}_{out_name}")
        with open(out_path, "wb") as f:
            f.write(data)
        n += 1
    return dest, n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("sd")
    ap.add_argument("--slot", type=int, default=1)
    ap.add_argument("--orientation", default="auto", choices=["auto", "landscape", "portrait"])
    ap.add_argument("--fit", default="fit", choices=["fit", "crop"])
    ap.add_argument("--svuota", action="store_true", help="cancella prima il contenuto della cartella meuralN")
    a = ap.parse_args()
    try:
        dest, n = prepara(a.src, a.sd, a.slot, a.orientation, a.fit, svuota=a.svuota)
    except (ValueError, FileNotFoundError) as e:
        sys.exit(f"Errore: {e}")
    print(f"Pronte {n} immagini in {dest}")
    print("Espelli la scheda, inseriscila nella cornice: la playlist compare tra quelle locali.")
    if not images.HAVE_PIL:
        print("Nota: Pillow non installato, immagini copiate senza adattamento (pip3 install pillow).")


if __name__ == "__main__":
    main()
