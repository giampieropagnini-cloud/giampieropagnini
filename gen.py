#!/usr/bin/env python3
"""Static site generator for giampieropagnini — builds dist/ from content.json.

Usage: python3 gen.py [--imgs]   (--imgs also regenerates image derivatives)
"""
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.request

ROOT = os.path.dirname(os.path.abspath(__file__))


def argval(flag, default=None):
    if flag in sys.argv:
        i = sys.argv.index(flag)
        if i + 1 < len(sys.argv):
            return sys.argv[i + 1]
    return default


THEME = argval("--theme", "")  # "", "oscura", "pin"
DIST = os.path.join(ROOT, argval("--out", "dist"))
IMG_SRC = os.path.join(ROOT, "assets", "img")
SITE_URL = argval("--url", "https://giampieropagnini.com").rstrip("/")
DOMAIN = SITE_URL.split("//", 1)[-1]

content = json.load(open(os.path.join(ROOT, "content.json")))
site = content["site"]
scrape = json.load(open(os.path.join(ROOT, "scrape", "site.json")))
old_pages = {p["slug"]: p for p in scrape["pages"].values()}

# images shared across >=3 old pages are navigation chrome, not artworks
from collections import defaultdict

occ = defaultdict(set)
for p in scrape["pages"].values():
    for im in p["images"]:
        occ[im["uri"]].add(p["slug"])
CHROME = {u for u, s in occ.items() if len(s) >= 3}
KEEP_CHROME = {site["home_hero"], site["portrait"]}  # legit uses

FEATURED = {
    "red-chairs": "redpost 004",
    "cheat-your-eyes": "IMGP0679",
    "disappearing": "4pin 010",
    "pimp-my-camera": "pimp",
    "seek-deep-inside": "mm",
}
HOME_SELECTION = [
    "red-chairs", "cheat-your-eyes", "aperitivo-stenopeico", "disappearing",
    "seats", "pimp-my-camera", "emulsion-ball", "dripping-city-dreams",
]


def gallery_for(project):
    old = old_pages.get(project["old_slug"])
    if not old:
        return []
    out, seen = [], set()
    for im in old["images"]:
        u = im["uri"]
        if u in seen or not u.startswith("39e78d_"):
            continue
        if u in CHROME and u not in KEEP_CHROME:
            continue
        seen.add(u)
        out.append({"uri": u, "title": im.get("title", ""), "w": im.get("width"), "h": im.get("height")})
    return out


def featured_uri(project, gallery):
    want = FEATURED.get(project["slug"])
    if want:
        for im in gallery:
            if want.lower() in (im["title"] or "").lower():
                return im["uri"]
    return gallery[0]["uri"] if gallery else None


# ---------- image derivatives ----------
def wp(uri):
    """nome del file in versione WebP"""
    return re.sub(r"\.(jpe?g|png|gif)$", ".webp", uri, flags=re.I)


def make_derivatives(uris, yt_ids):
    large_d = os.path.join(DIST, "img", "large")
    thumb_d = os.path.join(DIST, "img", "thumb")
    yt_d = os.path.join(DIST, "img", "yt")
    for d in (large_d, thumb_d, yt_d):
        os.makedirs(d, exist_ok=True)
    for i, u in enumerate(sorted(uris)):
        src = os.path.join(IMG_SRC, u)
        if not os.path.exists(src):
            print("missing src", u)
            continue
        for out_d, size, q in ((large_d, 1600, "82"), (thumb_d, 560, "80")):
            out = os.path.join(out_d, wp(u))
            if os.path.exists(out):
                continue
            tmp = os.path.join(out_d, "_tmp_" + u)
            subprocess.run(
                ["sips", "-Z", str(size), "-s", "format", "jpeg", "-s", "formatOptions", "92", src, "--out", tmp],
                capture_output=True,
            )
            if os.path.exists(tmp):
                subprocess.run(["cwebp", "-quiet", "-q", q, "-m", "5", tmp, "-o", out], capture_output=True)
                os.remove(tmp)
        # ripulisce eventuali JPEG di build precedenti
        for out_d in (large_d, thumb_d):
            old = os.path.join(out_d, u)
            if os.path.exists(old) and os.path.exists(os.path.join(out_d, wp(u))):
                os.remove(old)
    for vid in yt_ids:
        out = os.path.join(yt_d, vid + ".jpg")
        if not os.path.exists(out):
            try:
                req = urllib.request.Request(
                    f"https://i.ytimg.com/vi/{vid}/hqdefault.jpg", headers={"User-Agent": "Mozilla/5.0"}
                )
                open(out, "wb").write(urllib.request.urlopen(req, timeout=20).read())
            except Exception as e:
                print("yt fail", vid, e)


# ---------- html helpers ----------
def esc(s):
    return (s or "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def bi(it, en, tag="p", cls=""):
    """bilingual block"""
    c = f' class="{cls}"' if cls else ""
    return (
        f'<{tag} lang="it" data-lang="it"{c}>{it}</{tag}>'
        f'<{tag} lang="en" data-lang="en"{c} hidden>{en}</{tag}>'
    )


def page(title, body, depth=0, desc="", active="", url_path="", og_image=""):
    r = "../" * depth
    canon = f"{SITE_URL}/{url_path}" if url_path else f"{SITE_URL}/"
    og_im = f"{SITE_URL}/img/{og_image}" if og_image else f"{SITE_URL}/img/og.jpg"
    social = site["social"]
    jsonld = json.dumps(
        {
            "@context": "https://schema.org",
            "@type": "Person",
            "name": site["name"],
            "jobTitle": "Artista visivo",
            "url": SITE_URL + "/",
            "image": f"{SITE_URL}/img/hero-{site['portrait']}",
            "email": site["email"],
            "address": {"@type": "PostalAddress", "addressLocality": "Pescara", "addressCountry": "IT"},
            "sameAs": [social["instagram"], social["facebook"], social["flickr"]],
            "description": site["intro_it"],
        },
        ensure_ascii=False,
    )
    seo = f"""<link rel="canonical" href="{canon}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="{esc(site['name'])}">
<meta property="og:title" content="{esc(title)}">
<meta property="og:description" content="{esc(desc or site['intro_it'])}">
<meta property="og:image" content="{og_im}">
<meta property="og:url" content="{canon}">
<meta property="og:locale" content="it_IT">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{esc(title)}">
<meta name="twitter:description" content="{esc(desc or site['intro_it'])}">
<meta name="twitter:image" content="{og_im}">
<meta name="author" content="{esc(site['name'])}">
<meta name="theme-color" content="#0b0b0d">
<script type="application/ld+json">{jsonld}</script>"""
    theme_pick = "" if THEME else """
  var q = new URLSearchParams(location.search), t = q.get('theme');
  if (t) { try { localStorage.setItem('gp-theme', t); } catch(e){} }
  else { try { t = localStorage.getItem('gp-theme'); } catch(e){} }
  if (t) document.documentElement.setAttribute('data-theme', t);"""
    themes_js = f"""
(function(){{{theme_pick}
  var l = null;
  try {{ l = localStorage.getItem('gp-lang'); }} catch(e){{}}
  if (l === 'en') document.documentElement.setAttribute('data-lang','en');
}})();"""
    theme_attr = f' data-theme="{THEME}"' if THEME else ""
    grain = '<div class="grain" aria-hidden="true"></div>' if THEME == "oscura" else ""
    return f"""<!DOCTYPE html>
<html lang="it"{theme_attr}>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(title)}</title>
<meta name="description" content="{esc(desc or site['intro_it'])}">
<link rel="icon" href="{r}img/favicon.png">
<link rel="apple-touch-icon" href="{r}img/favicon.png">
{seo}
<link rel="stylesheet" href="{r}css/base.css">
<link rel="stylesheet" href="{r}css/theme.css">
<script>{themes_js}</script>
</head>
<body data-page="{active}">
{grain}
<header class="hd">
  <a class="wordmark" href="{r}index.html">GIAMPIERO<b>PAGNINI</b></a>
  <nav class="nav">
    <a href="{r}opere.html" {('class="on"' if active=='opere' else '')}>{'<span data-lang="it">Opere</span><span data-lang="en" hidden>Works</span>'}</a>
    <a href="{r}about.html" {('class="on"' if active=='about' else '')}>About</a>
    <a href="{r}contact.html" {('class="on"' if active=='contact' else '')}>{'<span data-lang="it">Contatti</span><span data-lang="en" hidden>Contact</span>'}</a>
    <button class="lang" id="langBtn" title="Language">IT/EN</button>
  </nav>
</header>
{body}
<footer class="ft">
  <div class="ft-name">GIAMPIERO PAGNINI</div>
  <div class="ft-links">
    <a href="{esc(site['social']['instagram'])}" rel="noopener">Instagram</a>
    <a href="{esc(site['social']['facebook'])}" rel="noopener">Facebook</a>
    <a href="{esc(site['social']['flickr'])}" rel="noopener">Flickr</a>
    <a href="mailto:{esc(site['email'])}">{esc(site['email'])}</a>
  </div>
  <div class="ft-note">© {esc(site['name'])} — Pescara, Italia</div>
</footer>
<div class="lb" id="lb" hidden><button class="lb-x" id="lbX">×</button><button class="lb-p" id="lbP">‹</button><img id="lbImg" alt=""><button class="lb-n" id="lbN">›</button><div class="lb-cap" id="lbCap"></div></div>
<script src="{r}js/main.js"></script>
</body>
</html>"""


def card(pr, depth=0):
    r = "../" * depth
    f = pr["_featured"]
    if not f:
        return ""
    yr = f' <span class="yr">{esc(pr["year"])}</span>' if pr["year"] else ""
    return f"""<a class="card" href="{r}progetti/{pr['slug']}.html" data-cat="{pr['category']}">
  <span class="card-im"><img src="{r}img/thumb/{wp(f)}" alt="{esc(pr['title'])}" loading="lazy"></span>
  <span class="card-t">{esc(pr['title'])}{yr}</span>
  <span class="card-c">{esc(pr['_catlabel_it'])}</span>
</a>"""


def video_embed(vid, depth=0):
    r = "../" * depth
    return f"""<div class="vid" data-vid="{esc(vid)}">
  <img src="{r}img/yt/{esc(vid)}.jpg" alt="video" loading="lazy">
  <button class="vid-play" aria-label="Play">▶</button>
</div>"""


# ---------- build ----------
def build():
    if os.path.exists(DIST) and "--clean" in sys.argv:
        shutil.rmtree(DIST)
    for d in ("css", "js", "progetti", "img"):
        os.makedirs(os.path.join(DIST, d), exist_ok=True)

    cats = {c["slug"]: c for c in content["categories"]}
    projects = content["projects"]
    uris = {site["home_hero"], site["portrait"], site["logo"]}
    yt_ids = set()
    for pr in projects:
        g = gallery_for(pr)
        pr["_gallery"] = g
        pr["_featured"] = featured_uri(pr, g)
        pr["_catlabel_it"] = cats[pr["category"]]["label_it"]
        pr["_catlabel_en"] = cats[pr["category"]]["label_en"]
        uris.update(im["uri"] for im in g)
        yt_ids.update(pr.get("videos", []))
    yt_ids.add(content["about"]["documentary_video"])

    if "--imgs" in sys.argv:
        make_derivatives(uris, yt_ids)
        for u in (site["home_hero"], site["portrait"]):
            src = os.path.join(IMG_SRC, u)
            out = os.path.join(DIST, "img", "hero-" + u)
            if not os.path.exists(out):
                subprocess.run(["sips", "-Z", "2200", "-s", "format", "jpeg", "-s", "formatOptions", "80", src, "--out", out], capture_output=True)
        fav = os.path.join(DIST, "img", "favicon.png")
        if not os.path.exists(fav):
            subprocess.run(["sips", "-Z", "64", "-s", "format", "png", os.path.join(IMG_SRC, site["logo"]), "--out", fav], capture_output=True)
        # anteprime social per progetto: restano JPEG (WhatsApp/Facebook le preferiscono)
        og_d = os.path.join(DIST, "img", "og")
        os.makedirs(og_d, exist_ok=True)
        for pr in projects:
            if not pr["_featured"]:
                continue
            out = os.path.join(og_d, pr["slug"] + ".jpg")
            src = os.path.join(IMG_SRC, pr["_featured"])
            if not os.path.exists(out) and os.path.exists(src):
                subprocess.run(
                    ["sips", "-Z", "1200", "-s", "format", "jpeg", "-s", "formatOptions", "70", src, "--out", out],
                    capture_output=True,
                )

    # ---- home
    sel = [pr for s in HOME_SELECTION for pr in projects if pr["slug"] == s]
    cat_links = "".join(
        f'<a class="chip" href="opere.html#{c["slug"]}"><span data-lang="it">{c["label_it"]}</span><span data-lang="en" hidden>{c["label_en"]}</span></a>'
        for c in content["categories"]
    )
    marq_items = "SENSIBILE ALLA LUCE ● FOTOGRAFIA ● LUCE ● POLAROID ● CAMERE ● VIDEO ● PITTURA ● STREET ● "
    marquee = (
        f'<div class="marq" aria-hidden="true"><div class="marq-t"><span>{marq_items}</span><span>{marq_items}</span></div></div>'
        if THEME == "pin" else ""
    )
    hero_media = f'<img class="hero-im" src="img/hero-{site["home_hero"]}" alt="Studio di Giampiero Pagnini">'
    if THEME == "oscura" and os.path.exists(os.path.join(DIST, "img", "hero.mp4")):
        hero_media = (
            f'<video class="hero-im" autoplay muted loop playsinline preload="metadata" '
            f'poster="img/hero-{site["home_hero"]}" aria-label="Lo studio di Giampiero Pagnini">'
            f'<source src="img/hero.mp4" type="video/mp4"></video>'
        )
    home = f"""
<section class="hero">
  {hero_media}
  <div class="hero-tx">
    <h1 class="hero-h"><span data-lang="it">{esc(site['tagline_it'])}</span><span data-lang="en" hidden>{esc(site['tagline_en'])}</span></h1>
    {bi(esc(site['intro_it']), esc(site['intro_en']), 'p', 'hero-sub')}
    <a class="btn" href="opere.html"><span data-lang="it">Guarda le opere</span><span data-lang="en" hidden>View works</span></a>
  </div>
</section>
{marquee}
<section class="sec">
  <h2 class="sec-h"><span data-lang="it">Opere scelte</span><span data-lang="en" hidden>Selected works</span></h2>
  <div class="grid">{''.join(card(p) for p in sel)}</div>
</section>
<section class="sec sec-cats">
  <h2 class="sec-h"><span data-lang="it">Percorsi</span><span data-lang="en" hidden>Paths</span></h2>
  <div class="chips">{cat_links}</div>
</section>"""
    open(os.path.join(DIST, "index.html"), "w").write(
        page("Giampiero Pagnini — Sensibile alla luce", home, 0, active="home", url_path="")
    )

    # ---- works index
    filter_chips = (
        '<button class="chip on" data-f="*"><span data-lang="it">Tutte</span><span data-lang="en" hidden>All</span></button>'
        + "".join(
            f'<button class="chip" data-f="{c["slug"]}" id="{c["slug"]}"><span data-lang="it">{c["label_it"]}</span><span data-lang="en" hidden>{c["label_en"]}</span></button>'
            for c in content["categories"]
        )
    )
    if THEME == "pin":
        # archivio cronologico: numerazione = ordine per anno
        def year_key(pr):
            m = re.search(r"(19|20)\d\d", pr.get("year") or "")
            return (int(m.group(0)) if m else 9999, pr["title"])

        rows = []
        for n, pr in enumerate(sorted([p for p in projects if p["_featured"]], key=year_key), 1):
            rows.append(f"""<a class="arch-r card" href="progetti/{pr['slug']}.html" data-cat="{pr['category']}">
  <span class="arch-n">{n:02d}</span>
  <span class="arch-im"><img src="img/thumb/{wp(pr['_featured'])}" alt="" loading="lazy"></span>
  <span class="arch-t">{esc(pr['title'])}</span>
  <span class="arch-y">{esc(pr['year'])}</span>
  <span class="arch-c"><span data-lang="it">{esc(pr['_catlabel_it'])}</span><span data-lang="en" hidden>{esc(pr['_catlabel_en'])}</span></span>
</a>""")
        works_markup = f'<p class="arch-note"><span data-lang="it">Indice cronologico</span><span data-lang="en" hidden>Chronological index</span></p><div class="arch" id="worksGrid">{"".join(rows)}</div>'
    else:
        works_markup = f'<div class="grid" id="worksGrid">{"".join(card(p) for p in projects if p["_featured"])}</div>'
    opere = f"""
<section class="sec sec-top">
  <h1 class="pg-h"><span data-lang="it">Opere</span><span data-lang="en" hidden>Works</span></h1>
  <div class="chips" id="filters">{filter_chips}</div>
  {works_markup}
</section>"""
    open(os.path.join(DIST, "opere.html"), "w").write(
        page("Opere — Giampiero Pagnini", opere, 0, active="opere", url_path="opere.html",
             desc="Tutte le opere di Giampiero Pagnini: fotografia stenopeica, lightbox, Polaroid, camere autocostruite, video, pittura.")
    )

    # ---- project pages
    visible = [p for p in projects if p["_featured"] or p.get("videos")]
    for i, pr in enumerate(visible):
        prev_p = visible[i - 1]
        next_p = visible[(i + 1) % len(visible)]
        gal = "".join(
            f'<figure class="ph"><img src="../img/large/{wp(im["uri"])}" alt="{esc(im["title"] or pr["title"])}" loading="lazy" data-i="{j}"></figure>'
            for j, im in enumerate(pr["_gallery"])
        )
        vids = "".join(video_embed(v, 1) for v in pr.get("videos", []))
        mat = bi(esc(pr["materials"]), esc(pr["materials"]), "p", "mat") if pr.get("materials") else ""
        yr = f'<span class="yr">{esc(pr["year"])}</span>' if pr["year"] else ""
        body = f"""
<article class="proj">
  <header class="proj-hd">
    <div class="proj-cat"><span data-lang="it">{esc(pr['_catlabel_it'])}</span><span data-lang="en" hidden>{esc(pr['_catlabel_en'])}</span></div>
    <h1 class="pg-h">{esc(pr['title'])} {yr}</h1>
    {mat}
    {bi(esc(pr['text_it']), esc(pr['text_en']))}
  </header>
  {f'<div class="vids">{vids}</div>' if vids else ''}
  <div class="gal">{gal}</div>
  <nav class="pn">
    <a href="{prev_p['slug']}.html">‹ {esc(prev_p['title'])}</a>
    <a href="{next_p['slug']}.html">{esc(next_p['title'])} ›</a>
  </nav>
</article>"""
        open(os.path.join(DIST, "progetti", pr["slug"] + ".html"), "w").write(
            page(f"{pr['title']} — Giampiero Pagnini", body, 1, desc=pr["text_it"][:150], active="opere",
                 url_path=f"progetti/{pr['slug']}.html",
                 og_image=f"og/{pr['slug']}.jpg" if pr["_featured"] else "")
        )

    # ---- about
    bio_it = "".join(f"<p>{esc(t)}</p>" for t in content["about"]["bio_it"])
    bio_en = "".join(f"<p>{esc(t)}</p>" for t in content["about"]["bio_en"])
    ex_g = "".join(f"<li>{esc(x)}</li>" for x in content["about"]["exhibitions_group"])
    ex_s = "".join(f"<li>{esc(x)}</li>" for x in content["about"]["exhibitions_solo"])
    about = f"""
<section class="sec sec-top about">
  <div class="about-cols">
    <div class="about-im"><img src="img/hero-{site['portrait']}" alt="Ritratto di Giampiero Pagnini"></div>
    <div class="about-tx">
      <h1 class="pg-h">About</h1>
      <div lang="it" data-lang="it">{bio_it}</div>
      <div lang="en" data-lang="en" hidden>{bio_en}</div>
    </div>
  </div>
  <div class="doc">
    <h2 class="sec-h">Sensibili alla luce — <span data-lang="it">il documentario</span><span data-lang="en" hidden>the documentary</span> (2011)</h2>
    {video_embed(content['about']['documentary_video'], 0)}
  </div>
  <div class="ex">
    <div><h2 class="sec-h">Group exhibitions</h2><ul class="ex-l">{ex_g}</ul></div>
    <div><h2 class="sec-h">Solo exhibitions</h2><ul class="ex-l">{ex_s}</ul></div>
  </div>
</section>"""
    open(os.path.join(DIST, "about.html"), "w").write(
        page("About — Giampiero Pagnini", about, 0, active="about", url_path="about.html",
             desc=content["about"]["bio_it"][0][:155], og_image=f"hero-{site['portrait']}")
    )

    # ---- contact
    contact = f"""
<section class="sec sec-top contact">
  <h1 class="pg-h"><span data-lang="it">Contatti</span><span data-lang="en" hidden>Contact</span></h1>
  {bi("Per opere, mostre, collaborazioni o semplicemente per parlare di luce:",
      "For works, exhibitions, collaborations or simply to talk about light:")}
  <div class="c-big"><a href="mailto:{esc(site['email'])}">{esc(site['email'])}</a></div>
  <div class="c-rows">
    <div><span class="c-k">Tel</span> <a href="tel:{esc(site['phone']).replace(' ','')}">{esc(site['phone'])}</a></div>
    <div><span class="c-k">Studio</span> {esc(site['address'])}</div>
    <div><span class="c-k">Social</span> <a href="{esc(site['social']['instagram'])}">Instagram</a> · <a href="{esc(site['social']['facebook'])}">Facebook</a> · <a href="{esc(site['social']['flickr'])}">Flickr</a></div>
  </div>
</section>"""
    open(os.path.join(DIST, "contact.html"), "w").write(
        page("Contatti — Giampiero Pagnini", contact, 0, active="contact", url_path="contact.html",
             desc=f"Contatta Giampiero Pagnini — {site['email']} — studio a Pescara.")
    )

    # ---- 404
    nf = """
<section class="sec sec-top" style="min-height:52vh">
  <h1 class="pg-h">404</h1>
  <p><span data-lang="it">Questa pagina non esiste — come certe immagini stenopeiche, è sfuggita all'inquadratura.</span><span data-lang="en" hidden>This page doesn't exist — like some pinhole images, it escaped the frame.</span></p>
  <p style="margin-top:1.5rem"><a class="btn" href="/"><span data-lang="it">Torna alla home</span><span data-lang="en" hidden>Back home</span></a></p>
</section>"""
    open(os.path.join(DIST, "404.html"), "w").write(page("Pagina non trovata — Giampiero Pagnini", nf, 0))

    # ---- sitemap / robots / CNAME
    urls = ["", "opere.html", "about.html", "contact.html"] + [f"progetti/{p['slug']}.html" for p in visible]
    entries = "".join(
        f"  <url><loc>{SITE_URL}/{u}</loc><changefreq>monthly</changefreq>"
        f"<priority>{'1.0' if u == '' else '0.8' if '/' not in u else '0.6'}</priority></url>\n"
        for u in urls
    )
    open(os.path.join(DIST, "sitemap.xml"), "w").write(
        f'<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n{entries}</urlset>\n'
    )
    open(os.path.join(DIST, "robots.txt"), "w").write(
        f"User-agent: *\nAllow: /\n\nSitemap: {SITE_URL}/sitemap.xml\n"
    )
    open(os.path.join(DIST, "CNAME"), "w").write(DOMAIN + "\n")
    # GitHub Pages: non processare con Jekyll (i file che iniziano per _ verrebbero ignorati)
    open(os.path.join(DIST, ".nojekyll"), "w").write("")

    # ---- immagine anteprima social (og.jpg) dall'hero
    og = os.path.join(DIST, "img", "og.jpg")
    src_hero = os.path.join(IMG_SRC, site["home_hero"])
    if not os.path.exists(og) and os.path.exists(src_hero):
        subprocess.run(
            ["sips", "-Z", "1200", "-s", "format", "jpeg", "-s", "formatOptions", "72", src_hero, "--out", og],
            capture_output=True,
        )

    print(f"built {len(visible)} project pages, {len(urls)} urls in sitemap, domain {DOMAIN}")


if __name__ == "__main__":
    build()
