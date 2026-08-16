#!/usr/bin/env python3
"""Da scrape/ig/<profilo>.json ricava instagram.json: il contenuto della pagina.

    python3 scrape/ig_build.py giamps1982 --top 12

Sceglie i post migliori (per mi piace, o in ordine di tempo se i mi piace non
ci sono), ripulisce le didascalie, conta gli hashtag e scrive instagram.json
nella cartella principale — che è il file che gen.py legge per costruire la
pagina. instagram.json si può correggere a mano: è testo, e resta su GitHub.
"""
import argparse
import json
import os
import re
import time
from collections import Counter

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)

HASHTAG = re.compile(r"(?:^|\s)#[0-9A-Za-zÀ-ÿ_]+")
SPACE = re.compile(r"[ \t]+")


def pulisci(caption):
    """Toglie la coda di hashtag e restituisce (titolo, testo)."""
    txt = (caption or "").replace("\r", "")
    righe = [r.rstrip() for r in txt.split("\n")]
    # via le righe finali fatte solo di hashtag o menzioni
    while righe and (not righe[-1].strip()
                     or re.fullmatch(r"[\s#@0-9A-Za-zÀ-ÿ_.·•\-—]*", righe[-1]) and "#" in righe[-1]):
        righe.pop()
    corpo = "\n".join(righe).strip()
    corpo = HASHTAG.sub("", corpo)  # hashtag rimasti dentro al testo
    corpo = SPACE.sub(" ", corpo)
    corpo = re.sub(r"\n{3,}", "\n\n", corpo).strip(" \n·•-—")

    prima = next((r.strip() for r in corpo.split("\n") if r.strip()), "")
    titolo = prima
    if len(titolo) > 72:
        taglio = re.split(r"(?<=[.!?…])\s", titolo)[0]
        titolo = taglio if len(taglio) <= 72 else titolo[:69].rsplit(" ", 1)[0] + "…"
    return titolo, corpo


def anno(ts):
    return time.strftime("%Y", time.localtime(ts)) if ts else ""


def data_it(ts):
    if not ts:
        return ""
    mesi = ["gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio",
            "agosto", "settembre", "ottobre", "novembre", "dicembre"]
    t = time.localtime(ts)
    return f"{t.tm_mday} {mesi[t.tm_mon - 1]} {t.tm_year}"


def data_en(ts):
    return time.strftime("%d %B %Y", time.localtime(ts)).lstrip("0") if ts else ""


def main():
    ap = argparse.ArgumentParser(description="Costruisce instagram.json dalla raccolta.")
    ap.add_argument("handle", help="il profilo, senza @")
    ap.add_argument("--top", type=int, default=12, help="quanti post nella griglia dei migliori")
    ap.add_argument("--max", type=int, default=0, help="quanti post in tutto nell'archivio (0 = tutti)")
    ap.add_argument("--exclude", default="", help="codici di post da saltare, separati da virgola")
    ap.add_argument("--pin", default="", help="codici di post sempre fra i migliori, in quest'ordine")
    ap.add_argument("--title", default="", help="titolo della pagina (altrimenti il nome del profilo)")
    ap.add_argument("--out", default="instagram.json")
    a = ap.parse_args()

    handle = a.handle.lstrip("@")
    src = os.path.join(BASE, "ig", handle + ".json")
    if not os.path.exists(src):
        raise SystemExit(f"Manca {src}: prima lancia  python3 scrape/instagram.py {handle}")
    arch = json.load(open(src))
    profile = arch.get("profile") or {}
    orig = os.path.join(ROOT, "assets", "ig", handle, "orig")

    escludi = {s.strip() for s in a.exclude.split(",") if s.strip()}
    fissati = [s.strip() for s in a.pin.split(",") if s.strip()]

    posts = []
    senza_file = 0
    for p in arch.get("posts", []):
        if p.get("shortcode") in escludi:
            continue
        media = []
        for m in p.get("media", []):
            f = m.get("file")
            if not f or not os.path.exists(os.path.join(orig, f)):
                continue
            media.append({"file": f, "w": m.get("w"), "h": m.get("h"),
                          "kind": m.get("kind", "image"),
                          "video": m.get("video_file")})
        if not media:
            senza_file += 1
            continue
        titolo, testo = pulisci(p.get("caption"))
        ts = p.get("taken_at")
        posts.append({
            "code": p.get("shortcode"),
            "url": f"https://www.instagram.com/p/{p['shortcode']}/" if p.get("shortcode", "").isalnum() and not p.get("shortcode", "").startswith("post-") else "",
            "date": ts,
            "date_it": data_it(ts),
            "date_en": data_en(ts),
            "year": anno(ts),
            "title": titolo,
            "text": testo,
            "hashtags": p.get("hashtags") or [],
            "likes": p.get("likes"),
            "comments": p.get("comments"),
            "kind": p.get("kind", "image"),
            "is_reel": bool(p.get("is_reel")),
            "location": p.get("location") or "",
            "media": media,
        })

    if senza_file:
        print(f"   {senza_file} post saltati: le immagini non sono in assets/ig/{handle}/orig")
    posts.sort(key=lambda p: p["date"] or 0, reverse=True)
    if a.max > 0:
        posts = posts[:a.max]

    # --- i migliori: mi piace + commenti, con i fissati sempre davanti
    def punteggio(p):
        return (p["likes"] or 0) + 3 * (p["comments"] or 0)

    ha_like = any(p["likes"] for p in posts)
    indice = {p["code"]: p for p in posts}
    top = [indice[c] for c in fissati if c in indice]
    resto = [p for p in posts if p["code"] not in {t["code"] for t in top}]
    resto.sort(key=punteggio if ha_like else (lambda p: p["date"] or 0), reverse=True)
    top = [p["code"] for p in (top + resto)[:a.top]]

    tag = Counter(t.lower() for p in posts for t in p["hashtags"])
    anni = sorted({p["year"] for p in posts if p["year"]}, reverse=True)
    date_note = [p["date"] for p in posts if p["date"]]

    out = {
        "handle": handle,
        "url": f"https://www.instagram.com/{handle}/",
        "title": a.title or profile.get("full_name") or "@" + handle,
        "aggiornato": arch.get("scraped_at"),
        "fonte": arch.get("source"),
        "profilo": {
            "nome": profile.get("full_name") or "",
            "bio": profile.get("biography") or "",
            "link": profile.get("external_url") or "",
            "follower": profile.get("followers"),
            "seguiti": profile.get("following"),
            "n_post": profile.get("n_posts") or len(posts),
            "foto": profile.get("profile_file") or "",
        },
        "stat": {
            "post": len(posts),
            "mi_piace": sum(p["likes"] or 0 for p in posts) if ha_like else None,
            "commenti": sum(p["comments"] or 0 for p in posts) if ha_like else None,
            "dal": data_it(min(date_note)) if date_note else "",
            "al": data_it(max(date_note)) if date_note else "",
            "anni": anni,
        },
        "hashtag": [{"tag": t, "n": n} for t, n in tag.most_common(18)],
        "top": top,
        "posts": posts,
        # testi della pagina: da correggere a mano quando vuoi
        "intro_it": "",
        "intro_en": "",
        "kicker_it": "Instagram",
        "kicker_en": "Instagram",
    }

    # se instagram.json esiste già, non calpesto i testi scritti a mano
    dest = os.path.join(ROOT, a.out)
    if os.path.exists(dest):
        try:
            vecchio = json.load(open(dest))
            for k in ("intro_it", "intro_en", "kicker_it", "kicker_en", "title"):
                if vecchio.get(k):
                    out[k] = vecchio[k]
            if vecchio.get("top") and not fissati and vecchio.get("_top_a_mano"):
                out["top"] = vecchio["top"]
                out["_top_a_mano"] = True
        except Exception:
            pass

    json.dump(out, open(dest, "w"), indent=1, ensure_ascii=False)
    print(f"✅ {a.out}: {len(posts)} post, {len(top)} in vetrina, {len(out['hashtag'])} hashtag")
    if not ha_like:
        print("   (senza mi piace: la vetrina è in ordine di tempo — normale con l'esportazione ufficiale)")
    print("   ora: python3 gen.py --out docs --theme oscura --imgs")


if __name__ == "__main__":
    main()
