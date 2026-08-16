#!/usr/bin/env python3
"""Scarica l'archivio di un profilo Instagram tuo in scrape/ig/<profilo>.json.

Due strade, stesso risultato:

  1) DAL VIVO — usa la sessione del browser in cui sei già entrato.
     Copia il cookie una volta sola in scrape/ig-cookies.txt (vedi
     INSTAGRAM-COME-FARE.md), poi:

         python3 scrape/instagram.py giamps1982

  2) DALL'ESPORTAZIONE UFFICIALE — Instagram ▸ Impostazioni ▸ La tua attività
     ▸ Scarica le tue informazioni (formato JSON). Nessun cookie, nessun
     limite, ma senza il numero di "mi piace":

         python3 scrape/instagram.py giamps1982 --export ~/Downloads/instagram-giamps1982.zip

Le foto finiscono in assets/ig/<profilo>/orig/ (restano in locale, non su
GitHub); il testo di ogni post in scrape/ig/<profilo>.json.
"""
import argparse
import glob
import json
import os
import re
import shutil
import sys
import time
import urllib.error
import urllib.request
import zipfile
from concurrent.futures import ThreadPoolExecutor

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)
OUT_DIR = os.path.join(BASE, "ig")

APP_ID = "936619743392459"  # l'app-id del sito web di Instagram
UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/122.0 Safari/537.36")


# ---------------------------------------------------------------- cookie ----
def load_cookies(arg=None):
    """Cookie dell'ordine: --cookie, IG_COOKIE, IG_SESSIONID, scrape/ig-cookies.txt."""
    raw = arg or os.environ.get("IG_COOKIE") or ""
    if not raw and os.environ.get("IG_SESSIONID"):
        raw = "sessionid=" + os.environ["IG_SESSIONID"]
    if not raw:
        path = os.path.join(BASE, "ig-cookies.txt")
        if os.path.exists(path):
            raw = open(path).read()
    raw = " ".join(raw.split()).strip()
    if raw.lower().startswith("cookie:"):
        raw = raw.split(":", 1)[1].strip()
    if not raw:
        sys.exit(
            "Manca il cookie della sessione.\n"
            "  ▸ apri instagram.com nel browser dove hai già fatto l'accesso\n"
            "  ▸ segui INSTAGRAM-COME-FARE.md e incolla il cookie in scrape/ig-cookies.txt\n"
            "  (in alternativa: --export con l'esportazione ufficiale dei dati)"
        )
    if "sessionid=" not in raw:
        raw = "sessionid=" + raw
    return raw


def csrf(cookies):
    m = re.search(r"csrftoken=([^;]+)", cookies)
    return m.group(1) if m else ""


# ------------------------------------------------------------------ rete ----
class Stop(Exception):
    pass


def api(url, cookies, referer, tries=4):
    wait = 5
    for n in range(tries):
        req = urllib.request.Request(url, headers={
            "User-Agent": UA,
            "X-IG-App-ID": APP_ID,
            "X-CSRFToken": csrf(cookies),
            "X-Requested-With": "XMLHttpRequest",
            "Accept": "*/*",
            "Accept-Language": "it-IT,it;q=0.9,en-US;q=0.8",
            "Referer": referer,
            "Cookie": cookies,
        })
        try:
            with urllib.request.urlopen(req, timeout=45) as r:
                return json.loads(r.read().decode("utf-8", "replace"))
        except urllib.error.HTTPError as e:
            if e.code in (401, 403):
                raise Stop(
                    f"Instagram risponde {e.code}: la sessione non è valida.\n"
                    "  ▸ rientra su instagram.com dal browser e ricopia il cookie in scrape/ig-cookies.txt"
                )
            if e.code == 404:
                raise Stop("Instagram risponde 404: profilo inesistente o non visibile da questa sessione.")
            if e.code in (429, 560) or e.code >= 500:
                print(f"   … Instagram frena ({e.code}), aspetto {wait}s")
                time.sleep(wait)
                wait *= 2
                continue
            raise
        except (urllib.error.URLError, TimeoutError) as e:
            print(f"   … rete incerta ({e}), riprovo fra {wait}s")
            time.sleep(wait)
            wait *= 2
    raise Stop("Instagram continua a rispondere male: riprova fra qualche minuto.")


# ------------------------------------------------------- normalizzazione ----
HASHTAG = re.compile(r"#([0-9A-Za-zÀ-ÿ_]+)")
MENTION = re.compile(r"@([0-9A-Za-z_.]+)")


def best(cands):
    """La candidata più grande fra le versioni offerte da Instagram."""
    if not cands:
        return None
    return sorted(cands, key=lambda c: (c.get("width") or 0) * (c.get("height") or 0))[-1]


def norm_item(it):
    """Un post nel formato api/v1 (quello che usa il sito di Instagram)."""
    kind = {1: "image", 2: "video", 8: "carousel"}.get(it.get("media_type"), "image")
    cap = (it.get("caption") or {}).get("text", "") or ""

    def media_of(m):
        im = best((m.get("image_versions2") or {}).get("candidates") or [])
        vid = (m.get("video_versions") or [{}])[0].get("url") if m.get("video_versions") else None
        return {
            "kind": "video" if vid else "image",
            "url": im.get("url") if im else None,
            "video_url": vid,
            "w": m.get("original_width"),
            "h": m.get("original_height"),
        }

    media = [media_of(m) for m in (it.get("carousel_media") or [it])]
    return {
        "id": str(it.get("pk") or it.get("id") or ""),
        "shortcode": it.get("code") or "",
        "taken_at": it.get("taken_at") or it.get("device_timestamp"),
        "caption": cap,
        "hashtags": HASHTAG.findall(cap),
        "mentions": MENTION.findall(cap),
        "likes": it.get("like_count"),
        "comments": it.get("comment_count"),
        "kind": kind,
        "is_reel": it.get("product_type") == "clips",
        "views": it.get("play_count") or it.get("view_count"),
        "location": ((it.get("location") or {}).get("name") or ""),
        "media": [m for m in media if m["url"] or m["video_url"]],
    }


def norm_node(n):
    """Un post nel formato graphql (la prima pagina del profilo)."""
    typ = n.get("__typename", "")
    kind = {"GraphImage": "image", "GraphVideo": "video", "GraphSidecar": "carousel"}.get(typ, "image")
    edges = (n.get("edge_media_to_caption") or {}).get("edges") or []
    cap = edges[0]["node"]["text"] if edges else ""

    def media_of(m):
        return {
            "kind": "video" if m.get("is_video") else "image",
            "url": m.get("display_url"),
            "video_url": m.get("video_url"),
            "w": (m.get("dimensions") or {}).get("width"),
            "h": (m.get("dimensions") or {}).get("height"),
        }

    children = [e["node"] for e in ((n.get("edge_sidecar_to_children") or {}).get("edges") or [])]
    media = [media_of(m) for m in (children or [n])]
    return {
        "id": str(n.get("id") or ""),
        "shortcode": n.get("shortcode") or "",
        "taken_at": n.get("taken_at_timestamp"),
        "caption": cap,
        "hashtags": HASHTAG.findall(cap),
        "mentions": MENTION.findall(cap),
        "likes": (n.get("edge_media_preview_like") or {}).get("count"),
        "comments": (n.get("edge_media_to_comment") or {}).get("count"),
        "kind": kind,
        "is_reel": n.get("product_type") == "clips",
        "views": n.get("video_view_count"),
        "location": ((n.get("location") or {}) or {}).get("name", "") or "",
        "media": [m for m in media if m["url"] or m["video_url"]],
    }


# ------------------------------------------------------------- dal vivo -----
def scrape_live(handle, limit, cookies, pause):
    ref = f"https://www.instagram.com/{handle}/"
    print(f"▸ profilo @{handle}")
    prof = api(f"https://www.instagram.com/api/v1/users/web_profile_info/?username={handle}",
               cookies, ref)
    user = (prof.get("data") or {}).get("user")
    if not user:
        raise Stop("Instagram non ha restituito il profilo: cookie scaduto o profilo non raggiungibile.")

    profile = {
        "handle": handle,
        "id": str(user.get("id") or ""),
        "full_name": user.get("full_name") or "",
        "biography": user.get("biography") or "",
        "external_url": user.get("external_url") or "",
        "followers": (user.get("edge_followed_by") or {}).get("count"),
        "following": (user.get("edge_follow") or {}).get("count"),
        "n_posts": (user.get("edge_owner_to_timeline_media") or {}).get("count"),
        "is_private": user.get("is_private"),
        "profile_pic": user.get("profile_pic_url_hd") or user.get("profile_pic_url") or "",
    }
    print(f"   {profile['full_name'] or handle} · {profile['n_posts']} post · "
          f"{profile['followers']} follower")

    posts, seen = [], set()
    for e in ((user.get("edge_owner_to_timeline_media") or {}).get("edges") or []):
        p = norm_node(e["node"])
        if p["shortcode"] and p["shortcode"] not in seen:
            seen.add(p["shortcode"])
            posts.append(p)
    print(f"   prima pagina: {len(posts)} post")

    uid = profile["id"]
    max_id, page = None, 1
    while uid and (limit <= 0 or len(posts) < limit):
        url = f"https://www.instagram.com/api/v1/feed/user/{uid}/?count=33"
        if max_id:
            url += f"&max_id={max_id}"
        data = api(url, cookies, ref)
        items = data.get("items") or []
        if not items:
            break
        nuovi = 0
        for it in items:
            p = norm_item(it)
            if p["shortcode"] and p["shortcode"] not in seen:
                seen.add(p["shortcode"])
                posts.append(p)
                nuovi += 1
        page += 1
        print(f"   pagina {page}: +{nuovi} (totale {len(posts)})")
        if not data.get("more_available") or not data.get("next_max_id"):
            break
        max_id = data["next_max_id"]
        time.sleep(pause)

    if limit > 0:
        posts = posts[:limit]
    return profile, posts


# ------------------------------------------- esportazione ufficiale dati ----
def fix_mojibake(s):
    """L'esportazione di Instagram scrive gli accenti in latin-1: li raddrizza."""
    if not isinstance(s, str):
        return s
    try:
        return s.encode("latin-1").decode("utf-8")
    except (UnicodeEncodeError, UnicodeDecodeError):
        return s


def scrape_export(handle, path):
    path = os.path.expanduser(path)
    if path.lower().endswith(".zip"):
        dest = os.path.join(OUT_DIR, "_export-" + handle)
        if not os.path.isdir(dest):
            print(f"▸ apro l'archivio in {dest}")
            os.makedirs(dest, exist_ok=True)
            with zipfile.ZipFile(path) as z:
                z.extractall(dest)
        path = dest
    if not os.path.isdir(path):
        raise Stop(f"Non trovo la cartella dell'esportazione: {path}")

    files = sorted(glob.glob(os.path.join(path, "**", "posts_*.json"), recursive=True))
    if not files:
        raise Stop("Nell'esportazione non ci sono file posts_*.json "
                   "(assicurati di aver scelto il formato JSON, non HTML).")
    print(f"▸ esportazione: {len(files)} file di post")

    posts = []
    for f in files:
        data = json.load(open(f))
        entries = data if isinstance(data, list) else data.get("posts") or []
        for e in entries:
            media = e.get("media") or []
            cap = fix_mojibake(e.get("title") or (media[0].get("title") if media else "") or "")
            ts = e.get("creation_timestamp") or (media[0].get("creation_timestamp") if media else None)
            mm = []
            for m in media:
                uri = m.get("uri") or ""
                meta = ((m.get("media_metadata") or {}).get("photo_metadata")
                        or (m.get("media_metadata") or {}).get("video_metadata") or {})
                mm.append({
                    "kind": "video" if uri.lower().endswith((".mp4", ".mov")) else "image",
                    "url": None,
                    "video_url": None,
                    "local": os.path.join(path, uri),
                    "w": (meta.get("exif_data") or [{}])[0].get("width") if meta.get("exif_data") else None,
                    "h": (meta.get("exif_data") or [{}])[0].get("height") if meta.get("exif_data") else None,
                })
            posts.append({
                "id": "",
                "shortcode": "",
                "taken_at": ts,
                "caption": cap,
                "hashtags": HASHTAG.findall(cap),
                "mentions": MENTION.findall(cap),
                "likes": None,
                "comments": None,
                "kind": "carousel" if len(mm) > 1 else (mm[0]["kind"] if mm else "image"),
                "is_reel": False,
                "views": None,
                "location": "",
                "media": mm,
            })

    posts.sort(key=lambda p: p["taken_at"] or 0, reverse=True)
    # l'esportazione non ha lo shortcode: numero i post per avere un nome file stabile
    for i, p in enumerate(posts):
        p["shortcode"] = p["shortcode"] or f"post-{len(posts) - i:04d}"

    profile = {"handle": handle, "id": "", "full_name": "", "biography": "",
               "external_url": "", "followers": None, "following": None,
               "n_posts": len(posts), "is_private": None, "profile_pic": ""}
    for pj in glob.glob(os.path.join(path, "**", "personal_information.json"), recursive=True):
        try:
            d = json.load(open(pj))
            pi = (d.get("profile_user") or [{}])[0].get("string_map_data") or {}
            profile["full_name"] = fix_mojibake((pi.get("Name") or {}).get("value", ""))
            profile["biography"] = fix_mojibake((pi.get("Bio") or {}).get("value", ""))
        except Exception:
            pass
    return profile, posts


# ----------------------------------------------------------------- media ----
def download_media(handle, profile, posts, want_video):
    dest = os.path.join(ROOT, "assets", "ig", handle, "orig")
    os.makedirs(dest, exist_ok=True)
    jobs, copiati = [], 0

    if profile.get("profile_pic"):
        jobs.append((profile["profile_pic"], os.path.join(dest, "profilo.jpg")))
        profile["profile_file"] = "profilo.jpg"

    for p in posts:
        for i, m in enumerate(p["media"]):
            stem = p["shortcode"] + ("" if i == 0 else f"-{i + 1}")
            if m.get("local"):  # esportazione: il file ce l'abbiamo già
                ext = os.path.splitext(m["local"])[1] or ".jpg"
                out = os.path.join(dest, stem + ext)
                if os.path.exists(m["local"]) and not os.path.exists(out):
                    shutil.copy2(m["local"], out)
                    copiati += 1
                m["file"] = stem + ext if os.path.exists(out) else None
                # il percorso dell'esportazione è di questo computer: non lo conservo
                m.pop("local", None)
                continue
            if m.get("url"):
                m["file"] = stem + ".jpg"
                jobs.append((m["url"], os.path.join(dest, m["file"])))
            if want_video and m.get("video_url"):
                m["video_file"] = stem + ".mp4"
                jobs.append((m["video_url"], os.path.join(dest, m["video_file"])))

    if copiati:
        print(f"▸ copiate {copiati} immagini dall'esportazione in assets/ig/{handle}/orig")
    jobs = [(u, o) for u, o in jobs if not (os.path.exists(o) and os.path.getsize(o) > 0)]
    if not jobs:
        if not copiati:
            print(f"▸ immagini: già tutte in assets/ig/{handle}/orig")
        return

    print(f"▸ scarico {len(jobs)} file in assets/ig/{handle}/orig")

    def one(job):
        url, out = job
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=90) as r:
                data = r.read()
            open(out, "wb").write(data)
            return None
        except Exception as e:
            return f"{os.path.basename(out)}: {e}"

    fails = []
    with ThreadPoolExecutor(max_workers=6) as ex:
        for i, err in enumerate(ex.map(one, jobs), 1):
            if err:
                fails.append(err)
            if i % 25 == 0:
                print(f"   {i}/{len(jobs)}")
    print(f"   fatti {len(jobs) - len(fails)}, non riusciti {len(fails)}")
    for f in fails[:10]:
        print("   ✗", f)


# ------------------------------------------------------------------ main ----
def main():
    ap = argparse.ArgumentParser(description="Scarica l'archivio di un profilo Instagram.")
    ap.add_argument("handle", help="il profilo, senza @ (es. giamps1982)")
    ap.add_argument("--export", help="cartella o .zip dell'esportazione ufficiale dei dati")
    ap.add_argument("--cookie", help="il cookie della sessione, se non vuoi il file ig-cookies.txt")
    ap.add_argument("--limit", type=int, default=0, help="fermati dopo N post (0 = tutti)")
    ap.add_argument("--pause", type=float, default=2.5, help="secondi fra una pagina e l'altra")
    ap.add_argument("--no-media", action="store_true", help="solo i testi, niente immagini")
    ap.add_argument("--video", action="store_true", help="scarica anche i filmati (pesanti)")
    a = ap.parse_args()

    handle = a.handle.lstrip("@").strip("/").split("/")[-1] or a.handle
    os.makedirs(OUT_DIR, exist_ok=True)

    try:
        if a.export:
            profile, posts = scrape_export(handle, a.export)
            source = "export"
        else:
            profile, posts = scrape_live(handle, a.limit, load_cookies(a.cookie), a.pause)
            source = "live"
    except Stop as e:
        sys.exit("\n✗ " + str(e))

    if not posts:
        sys.exit("\n✗ Nessun post trovato.")

    if not a.no_media:
        download_media(handle, profile, posts, a.video)

    out = os.path.join(OUT_DIR, handle + ".json")
    # se c'era già un archivio, tengo i "mi piace" dei post che stavolta non ho ripreso
    if os.path.exists(out):
        try:
            vecchi = {p["shortcode"]: p for p in json.load(open(out)).get("posts", [])}
            nuovi = {p["shortcode"] for p in posts}
            for sc, p in vecchi.items():
                if sc not in nuovi:
                    posts.append(p)
            posts.sort(key=lambda p: p.get("taken_at") or 0, reverse=True)
        except Exception:
            pass

    json.dump(
        {"handle": handle, "source": source,
         "scraped_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
         "profile": profile, "posts": posts},
        open(out, "w"), indent=1, ensure_ascii=False,
    )
    con_like = sum(1 for p in posts if p.get("likes"))
    print(f"\n✅ {len(posts)} post in scrape/ig/{handle}.json"
          f" ({con_like} con i mi piace)")
    print(f"   ora: python3 scrape/ig_build.py {handle}")


if __name__ == "__main__":
    main()
