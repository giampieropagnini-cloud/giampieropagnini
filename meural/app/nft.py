#!/usr/bin/env python3
"""Scarica le immagini degli NFT di un wallet nella cartella dello slideshow.

Usa l'API NFT di Alchemy (piano gratuito: https://www.alchemy.com/), chiave
in variabile d'ambiente ALCHEMY_KEY oppure con --key. Nessuna dipendenza.

Uso:
  ALCHEMY_KEY=xxx python3 nft.py 0xIL_TUO_WALLET [--chain eth-mainnet] [--out immagini/nft]

Reti: eth-mainnet, polygon-mainnet, arb-mainnet, opt-mainnet, base-mainnet.
Le immagini ipfs:// vengono risolte con un gateway pubblico.
"""
import argparse
import json
import os
import re
import sys
import urllib.parse
import urllib.request

GATEWAY = "https://ipfs.io/ipfs/"


def fetch_json(url):
    with urllib.request.urlopen(url, timeout=30) as r:
        return json.load(r)


def resolve(url):
    if not url:
        return None
    if url.startswith("ipfs://"):
        return GATEWAY + url[7:].lstrip("/").replace("ipfs/", "", 1)
    return url


def safe_name(s):
    return re.sub(r"[^\w\-. ]+", "_", s)[:80].strip() or "nft"


def nfts_for_owner(key, chain, owner):
    base = f"https://{chain}.g.alchemy.com/nft/v3/{key}/getNFTsForOwner"
    page = None
    while True:
        q = {"owner": owner, "withMetadata": "true", "pageSize": "100"}
        if page:
            q["pageKey"] = page
        data = fetch_json(base + "?" + urllib.parse.urlencode(q))
        for n in data.get("ownedNfts", []):
            yield n
        page = data.get("pageKey")
        if not page:
            break


def image_url(nft):
    img = nft.get("image") or {}
    for k in ("cachedUrl", "pngUrl", "originalUrl", "thumbnailUrl"):
        if img.get(k):
            return resolve(img[k])
    raw = (nft.get("raw") or {}).get("metadata") or {}
    return resolve(raw.get("image") or raw.get("image_url"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("wallet")
    ap.add_argument("--chain", default="eth-mainnet")
    ap.add_argument("--out", default="immagini/nft")
    ap.add_argument("--key", default=os.environ.get("ALCHEMY_KEY"))
    a = ap.parse_args()
    if not a.key:
        sys.exit("Serve la chiave Alchemy: ALCHEMY_KEY=... oppure --key")
    os.makedirs(a.out, exist_ok=True)
    n_ok = n_skip = 0
    for nft in nfts_for_owner(a.key, a.chain, a.wallet):
        url = image_url(nft)
        name = nft.get("name") or f"{(nft.get('contract') or {}).get('name', 'nft')} #{nft.get('tokenId')}"
        if not url:
            print(f"  salto {name}: nessuna immagine")
            n_skip += 1
            continue
        ext = os.path.splitext(urllib.parse.urlparse(url).path)[1].lower()
        if ext not in (".jpg", ".jpeg", ".png", ".gif"):
            ext = ".png"
        dest = os.path.join(a.out, safe_name(name) + ext)
        if os.path.exists(dest):
            n_ok += 1
            continue
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "meural-locale/1.0"})
            with urllib.request.urlopen(req, timeout=60) as r, open(dest, "wb") as f:
                f.write(r.read())
            print(f"  scaricato {dest}")
            n_ok += 1
        except Exception as e:  # noqa: BLE001
            print(f"  salto {name}: {e}")
            n_skip += 1
    print(f"Fatto: {n_ok} immagini pronte, {n_skip} saltate. Cartella: {a.out}")


if __name__ == "__main__":
    main()
