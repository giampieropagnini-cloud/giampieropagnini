#!/usr/bin/env python3
"""Scarica l'archivio di un profilo Instagram usando la sessione del proprio account.

Non usa servizi di terze parti: parla direttamente con Instagram, con i cookie di
un browser dove sei già entrato con l'account. Serve per prendere i propri post.

  1. Apri instagram.com in Chrome o Safari, entrato con @weedgadget.
  2. Copia il valore del cookie "sessionid" (Chrome: F12 ▸ Application ▸ Cookies
     ▸ https://www.instagram.com ▸ sessionid; Safari: Sviluppo ▸ Mostra
     Inspector Web ▸ Archiviazione).
  3. Lancia:

       export IG_SESSIONID='il-valore-copiato'
       python3 scrape/ig_scrape.py --user weedgadget --top 98

Scarica i post (foto singole e caroselli) dentro assets/wg/ig/, tiene da parte i
dati grezzi in scrape/ig_weedgadget.json e scrive un elenco pronto per la griglia.
Poi si finisce con:

       python3 scrape/wg_ingest.py --from-json scrape/ig_weedgadget-grid.json
       python3 gen.py --theme oscura --out docs

Opzioni: --user (profilo) · --top N (quanti post, 98) · --out (cartella immagini)
         --only-json (scarica solo i dati, non le immagini) · --sleep secondi
"""
import argparse
import json
import os
import random
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)

# l'id dell'applicazione web di Instagram: senza questa intestazione l'API risponde 403
IG_APP_ID = "936619743392459"
UA_WEB = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
          "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")
UA_APP = "Instagram 275.0.0.27.98 (iPhone14,3; iOS 17_4; it_IT; it; scale=3.00; 1170x2532)"


def cookies():
    sid = os.environ.get("IG_SESSIONID", "").strip().strip('"')
    if not sid:
        sys.exit("Manca IG_SESSIONID. Vedi le istruzioni in cima a questo file.")
    parts = [f"sessionid={sid}"]
    for env, name in (("IG_DS_USER_ID", "ds_user_id"), ("IG_CSRFTOKEN", "csrftoken"),
                      ("IG_MID", "mid")):
        v = os.environ.get(env, "").strip()
        if v:
            parts.append(f"{name}={v}")
    return "; ".join(parts)


def get(url, ua=UA_WEB, tries=4):
    """Una GET con i cookie della sessione, e un po' di pazienza se Instagram frena."""
    last = None
    for n in range(tries):
        req = urllib.request.Request(url, headers={
            "User-Agent": ua,
            "X-IG-App-ID": IG_APP_ID,
            "Accept": "*/*",
            "Accept-Language": "it-IT,it;q=0.9,en;q=0.8",
            "Referer": "https://www.instagram.com/",
            "Cookie": cookies(),
        })
        try:
            with urllib.request.urlopen(req, timeout=45) as r:
                return json.loads(r.read().decode("utf-8", "replace"))
        except urllib.error.HTTPError as e:
            last = e
            if e.code in (401, 403):
                sys.exit(f"Instagram risponde {e.code}: la sessione non è valida o è scaduta. "
                         "Rientra nel browser e ricopia il cookie sessionid.")
            if e.code == 429:  # troppe richieste: si aspetta e si riprova
                wait = 30 * (n + 1)
                print(f"  429, aspetto {wait}s…")
                time.sleep(wait)
                continue
            raise
        except (urllib.error.URLError, TimeoutError) as e:
            last = e
            time.sleep(2 ** n)
    raise SystemExit(f"Instagram non risponde: {last}")


def profile(username):
    url = ("https://www.instagram.com/api/v1/users/web_profile_info/?username="
           + urllib.parse.quote(username))
    user = get(url)["data"]["user"]
    return {
        "id": user["id"],
        "username": user["username"],
        "full_name": user.get("full_name", ""),
        "biography": user.get("biography", ""),
        "followers": user.get("edge_followed_by", {}).get("count"),
        "posts": user.get("edge_owner_to_timeline_media", {}).get("count"),
        "external_url": user.get("external_url") or "",
    }


def best(candidates):
    """La versione più grande fra quelle offerte."""
    if not candidates:
        return None
    return max(candidates, key=lambda c: (c.get("width", 0) * c.get("height", 0)))


def media_of(item):
    """Le immagini di un post: una sola, oppure tutte quelle del carosello."""
    out = []
    for child in item.get("carousel_media") or [item]:
        if child.get("media_type") == 2 and not child.get("image_versions2"):
            continue  # video senza copertina: si salta
        c = best((child.get("image_versions2") or {}).get("candidates"))
        if c and c.get("url"):
            out.append({"url": c["url"], "w": c.get("width"), "h": c.get("height")})
    return out


def feed(user_id, want, pause):
    """Scorre il profilo a pagine, dal post più recente all'indietro."""
    items, max_id = [], None
    while len(items) < want:
        url = f"https://i.instagram.com/api/v1/feed/user/{user_id}/?count=33"
        if max_id:
            url += "&max_id=" + urllib.parse.quote(max_id)
        page = get(url, ua=UA_APP)
        got = page.get("items") or []
        if not got:
            break
        items.extend(got)
        print(f"  {len(items)} post")
        if not page.get("more_available"):
            break
        max_id = page.get("next_max_id")
        if not max_id:
            break
        time.sleep(pause + random.random())
    return items[:want]


def caption_of(item):
    txt = ((item.get("caption") or {}).get("text") or "").strip()
    txt = re.sub(r"[#@][\w.]+", " ", txt)
    txt = re.sub(r"https?://\S+", " ", txt)
    txt = re.sub(r"\s+", " ", txt).strip(" -–—·|")
    return txt.split("\n")[0][:120].strip()


def download(url, dst):
    req = urllib.request.Request(url, headers={"User-Agent": UA_WEB})
    with urllib.request.urlopen(req, timeout=90) as r:
        data = r.read()
    with open(dst, "wb") as f:
        f.write(data)
    return len(data)


def main():
    ap = argparse.ArgumentParser(description="Scarica l'archivio di un profilo Instagram.")
    ap.add_argument("--user", default="weedgadget")
    ap.add_argument("--top", type=int, default=98, help="quanti post (98)")
    ap.add_argument("--out", default=os.path.join(ROOT, "assets", "wg", "ig"))
    ap.add_argument("--only-json", action="store_true", help="solo i dati, niente immagini")
    ap.add_argument("--sleep", type=float, default=2.0, help="pausa fra una pagina e l'altra")
    a = ap.parse_args()

    p = profile(a.user)
    print(f"@{p['username']} · {p['posts']} post · {p['followers']} follower")

    raw_path = os.path.join(BASE, f"ig_{a.user}.json")
    items = feed(p["id"], a.top, a.sleep)
    json.dump({"profile": p, "items": items}, open(raw_path, "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    print(f"dati grezzi in {os.path.relpath(raw_path, ROOT)} ({len(items)} post)")

    os.makedirs(a.out, exist_ok=True)
    grid, n = [], 0
    for i, item in enumerate(items, 1):
        cap = caption_of(item)
        for j, m in enumerate(media_of(item)):
            n += 1
            name = f"ig-{i:03d}" + (f"-{j + 1}" if j else "") + ".jpg"
            dst = os.path.join(a.out, name)
            if not a.only_json and not os.path.exists(dst):
                try:
                    download(m["url"], dst)
                except Exception as e:
                    print(f"  salto {name}: {e}")
                    continue
                time.sleep(.3)
            grid.append({"file": os.path.join(a.out, name), "cap_it": cap,
                         "ts": item.get("taken_at", 0), "likes": item.get("like_count", 0)})
            break  # della griglia fa parte solo la prima immagine del post

    out_json = os.path.join(BASE, f"ig_{a.user}-grid.json")
    json.dump(grid, open(out_json, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"{len(grid)} pezzi pronti · elenco in {os.path.relpath(out_json, ROOT)}")
    print(f"ora: python3 scrape/wg_ingest.py --from-json {os.path.relpath(out_json, ROOT)}")


if __name__ == "__main__":
    main()
