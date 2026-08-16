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


# ---------- icone del sito, dal marchio "Camera Oscura" ----------
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


def make_icons():
    """Favicon e icona iOS ricavate dal marchio vettoriale.

    Il favicon è ambra: si vede sia sulle schede chiare sia su quelle scure.
    L'icona iOS ha il fondo scuro del sito, perché iOS non gestisce bene
    la trasparenza e appiattirebbe il marchio sul bianco.
    """
    img_d = os.path.join(DIST, "img")
    os.makedirs(img_d, exist_ok=True)
    mark = os.path.join(ROOT, "assets", "marchio", "marchio.svg")
    if not os.path.exists(mark) or not os.path.exists(CHROME):
        print("marchio o Chrome non trovati: icone saltate")
        return
    svg = open(mark).read()
    shutil.copy(mark, os.path.join(img_d, "marchio.svg"))

    jobs = [("favicon.png", 64, "transparent", "#ff9d00", 100),
            ("apple-touch-icon.png", 180, "#0b0b0d", "#ece7de", 62)]
    tmp = os.path.join(DIST, "_icon.html")
    for out, size, bg, fg, pct in jobs:
        open(tmp, "w").write(
            f'<meta charset="utf-8"><style>html,body{{margin:0;width:{size}px;height:{size}px;'
            f'background:{bg};display:grid;place-items:center}}'
            f'svg{{width:{pct}%;height:{pct}%;display:block;color:{fg}}}</style>{svg}'
        )
        subprocess.run(
            [CHROME, "--headless", "--disable-gpu", "--hide-scrollbars",
             "--default-background-color=00000000",
             f"--screenshot={os.path.join(img_d, out)}",
             f"--window-size={size},{size}", "file://" + tmp],
            capture_output=True,
        )
    if os.path.exists(tmp):
        os.remove(tmp)
    print("icone rigenerate dal marchio")


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
            "sameAs": [social["instagram"], social["facebook"], social["flickr"],
                       content["music"]["bandcamp"], content["music"]["instagram"]],
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
<link rel="icon" type="image/svg+xml" href="{r}img/marchio.svg">
<link rel="icon" type="image/png" sizes="32x32" href="{r}img/favicon.png">
<link rel="apple-touch-icon" href="{r}img/apple-touch-icon.png">
{seo}
<link rel="stylesheet" href="{r}css/base.css">
<link rel="stylesheet" href="{r}css/theme.css">
<script>{themes_js}</script>
</head>
<body data-page="{active}">
{grain}
<header class="hd">
  <a class="wordmark" href="{r}index.html">GIAMPIERO<b>PAGNINI</b></a>
  <button class="burger" id="burger" aria-label="Menu" aria-expanded="false" aria-controls="nav">
    <span class="burger-b" aria-hidden="true"><i></i><i></i><i></i></span>
  </button>
  <nav class="nav" id="nav">
    <a href="{r}opere.html" {('class="on"' if active=='opere' else '')}>{'<span data-lang="it">Opere</span><span data-lang="en" hidden>Works</span>'}</a>
    <a href="{r}art-direction.html" {('class="on"' if active=='ad' else '')}>Art Direction</a>
    <a href="{r}weedgadget.html" {('class="on"' if active=='wg' else '')}>WeedGadget</a>
    <a href="{r}musica.html" {('class="on"' if active=='musica' else '')}>{'<span data-lang="it">Musica</span><span data-lang="en" hidden>Music</span>'}</a>
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
    <a href="{esc(content['music']['bandcamp'])}" rel="noopener">Bandcamp</a>
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

    # fogli di stile e script: sempre riallineati dalla cartella src/
    for name, sub in (("base.css", "css"), ("theme.css", "css"), ("main.js", "js")):
        s = os.path.join(ROOT, "src", name)
        if os.path.exists(s):
            shutil.copy2(s, os.path.join(DIST, sub, name))

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
        make_icons()
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
    # richiamo al progetto musicale in home
    mu_home = content["music"]
    mu_covers = "".join(
        f'<span class="mu-c"><picture>'
        f'<source srcset="img/music/{r["slug"]}.webp" type="image/webp">'
        f'<img src="img/music/{r["slug"]}.jpg" alt="{esc(r["title"])}" loading="lazy" width="1200" height="1200">'
        f'</picture></span>'
        for r in mu_home["releases"]
    )
    music_teaser = f"""
<section class="sec sec-mu">
  <a class="mu-teaser" href="musica.html">
    <span class="mu-teaser-im">{mu_covers}</span>
    <span class="mu-teaser-tx">
      <span class="mu-k">{esc(mu_home['artist'])}</span>
      <span class="sec-h"><span data-lang="it">Anche musica</span><span data-lang="en" hidden>Music too</span></span>
      <span class="mu-teaser-p"><span data-lang="it">{esc(mu_home['tagline_it'])} Due dischi, ascoltabili per intero.</span><span data-lang="en" hidden>{esc(mu_home['tagline_en'])} Two records, playable in full.</span></span>
      <span class="btn btn-s"><span data-lang="it">Ascolta</span><span data-lang="en" hidden>Listen</span></span>
    </span>
  </a>
</section>"""
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
</section>
{music_teaser}"""
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

    # ---- direzione artistica
    ad = content["artdirection"]
    os.makedirs(os.path.join(DIST, "img", "ad"), exist_ok=True)
    for p in ad["projects"]:
        for ext in ("jpg", "webp"):
            s = os.path.join(ROOT, "assets", "ad", f'{p["slug"]}.{ext}')
            if os.path.exists(s):
                shutil.copy2(s, os.path.join(DIST, "img", "ad", f'{p["slug"]}.{ext}'))

    def ad_block(p, n):
        tags = "".join(
            f'<li><span data-lang="it">{esc(a)}</span><span data-lang="en" hidden>{esc(b)}</span></li>'
            for a, b in zip(p["tags_it"], p["tags_en"])
        )
        host = p["url"].split("//", 1)[-1].rstrip("/")
        return f"""
<article class="adp" id="{p['slug']}">
  <a class="adp-im" href="{esc(p['url'])}" rel="noopener" target="_blank">
    <picture>
      <source srcset="img/ad/{p['slug']}.webp" type="image/webp">
      <img src="img/ad/{p['slug']}.jpg" alt="Il sito di {esc(p['name'])}" loading="lazy" width="1440" height="780">
    </picture>
  </a>
  <div class="adp-tx">
    <span class="adp-n">{n:02d}</span>
    <p class="adp-k"><span data-lang="it">{esc(p['kicker_it'])}</span><span data-lang="en" hidden>{esc(p['kicker_en'])}</span> · {esc(p['year'])}</p>
    <h2 class="adp-t">{esc(p['name'])}</h2>
    {bi(esc(p['text_it']), esc(p['text_en']))}
    <ul class="adp-tags">{tags}</ul>
    <a class="btn btn-s" href="{esc(p['url'])}" rel="noopener" target="_blank">{esc(host)} ↗</a>
  </div>
</article>"""

    ad_intro_it = "".join(f"<p>{esc(t)}</p>" for t in ad["intro_it"])
    ad_intro_en = "".join(f"<p>{esc(t)}</p>" for t in ad["intro_en"])
    adpage = f"""
<section class="sec sec-top ad">
  <p class="mu-k">Art Direction</p>
  <h1 class="pg-h"><span data-lang="it">{esc(ad['title_it'])}</span><span data-lang="en" hidden>{esc(ad['title_en'])}</span></h1>
  <p class="mu-sub"><span data-lang="it">{esc(ad['tagline_it'])}</span><span data-lang="en" hidden>{esc(ad['tagline_en'])}</span></p>
  <div class="mu-bio">
    <div lang="it" data-lang="it">{ad_intro_it}</div>
    <div lang="en" data-lang="en" hidden>{ad_intro_en}</div>
  </div>
  <div class="adps">{''.join(ad_block(p, i) for i, p in enumerate(ad['projects'], 1))}</div>
</section>"""
    open(os.path.join(DIST, "art-direction.html"), "w").write(
        page("Art Direction — Giampiero Pagnini", adpage, 0, active="ad",
             url_path="art-direction.html",
             desc="Direzione artistica di Giampiero Pagnini: marchi, fotografia, siti e video per Badasscoast, YOKOZUNA e Panna Bags. Venticinque anni di lavoro, dalla grafica alla fotografia analogica.",
             og_image=f"ad/{ad['projects'][0]['slug']}.jpg")
    )

    # ---- weedgadget
    wg = content["weedgadget"]
    bk = wg["book"]
    os.makedirs(os.path.join(DIST, "img", "wg"), exist_ok=True)
    for base in ("weedgadget", bk["cover"]):
        for ext in ("png", "jpg", "webp"):
            s = os.path.join(ROOT, "assets", "wg", f"{base}.{ext}")
            if os.path.exists(s):
                shutil.copy2(s, os.path.join(DIST, "img", "wg", f"{base}.{ext}"))

    # la griglia dell'archivio: le immagini le mette scrape/wg_ingest.py
    wg_grid = wg.get("grid", [])[: wg.get("grid_max", 98)]
    if wg_grid:
        for sub in ("grid", os.path.join("grid", "large")):
            src_dir = os.path.join(ROOT, "assets", "wg", sub)
            if not os.path.isdir(src_dir):
                continue
            out_dir = os.path.join(DIST, "img", "wg", sub)
            os.makedirs(out_dir, exist_ok=True)
            for fn in os.listdir(src_dir):
                s = os.path.join(src_dir, fn)
                if os.path.isfile(s):
                    shutil.copy2(s, os.path.join(out_dir, fn))

    wg_body_it = "".join(f"<p>{esc(t)}</p>" for t in wg["body_it"])
    wg_body_en = "".join(f"<p>{esc(t)}</p>" for t in wg["body_en"])
    # nel testo del libro il corsivo del titolo è voluto, quindi niente esc()
    bk_it = "".join(f"<p>{t}</p>" for t in bk["text_it"])
    bk_en = "".join(f"<p>{t}</p>" for t in bk["text_en"])
    facts = "".join(
        f'<div class="wg-f"><dt><span data-lang="it">{esc(f["k_it"])}</span><span data-lang="en" hidden>{esc(f["k_en"])}</span></dt>'
        f'<dd><span data-lang="it">{esc(f["v_it"])}</span><span data-lang="en" hidden>{esc(f["v_en"])}</span></dd></div>'
        for f in wg["facts"]
    )
    # ogni sezione ha una cartella in assets/wg/sezioni/: se dentro ci sono
    # immagini, la prima fa da copertina e le altre stanno nel lightbox
    WG_IMG = (".jpg", ".jpeg", ".png", ".webp")
    SEZ = os.path.join(ROOT, "assets", "wg", "sezioni")

    def sez_images(s):
        d = os.path.join(SEZ, s.get("dir", ""))
        if not s.get("dir") or not os.path.isdir(d):
            return []
        names = sorted(f for f in os.listdir(d)
                       if f.lower().endswith(WG_IMG) and not f.startswith("."))
        # il .webp è la versione leggera del .jpg omonimo, non una foto in più
        jpgs = [n for n in names if not n.lower().endswith(".webp")]
        return jpgs or names

    def wg_sec(s):
        imgs = sez_images(s)
        cov = ""
        if imgs:
            out = os.path.join(DIST, "img", "wg", "sezioni", s["dir"])
            os.makedirs(out, exist_ok=True)
            for fn in os.listdir(os.path.join(SEZ, s["dir"])):
                src = os.path.join(SEZ, s["dir"], fn)
                if fn.lower().endswith(WG_IMG) and os.path.isfile(src):
                    shutil.copy2(src, os.path.join(out, fn))
            tiles = []
            for i, fn in enumerate(imgs):
                stem = os.path.splitext(fn)[0]
                rel = f"img/wg/sezioni/{s['dir']}/{fn}"
                webp = os.path.exists(os.path.join(SEZ, s["dir"], stem + ".webp"))
                src = (f'<source srcset="img/wg/sezioni/{s["dir"]}/{stem}.webp" type="image/webp">'
                       if webp else "")
                # si vedono le prime quattro, le altre stanno solo nel lightbox
                cls = "wg-s-th" if i < 4 else "wg-s-more"
                tiles.append(
                    f'<picture class="{cls}">{src}<img src="{rel}"'
                    f' data-cap="{esc(s["t_it"])}" data-cap-en="{esc(s["t_en"])}"'
                    f' alt="{esc(s["t_it"])}" loading="lazy"></picture>'
                )
            cov = f'<div class="wg-s-im">{"".join(tiles)}</div>'
        return (
            f'<li class="wg-s">'
            f'<span class="wg-s-n">{esc(s["n"])}</span>'
            f'<h3 class="wg-s-t"><span data-lang="it">{esc(s["t_it"])}</span>'
            f'<span data-lang="en" hidden>{esc(s["t_en"])}</span></h3>'
            f'<p class="wg-s-d"><span data-lang="it">{esc(s["d_it"])}</span>'
            f'<span data-lang="en" hidden>{esc(s["d_en"])}</span></p>'
            f'{cov}</li>'
        )

    wg_secs = "".join(wg_sec(s) for s in wg.get("sections", []))
    wg_secs_html = f"""
  <section class="wg-block">
    <h2 class="sec-h"><span data-lang="it">{esc(wg.get('sections_title_it', ''))}</span><span data-lang="en" hidden>{esc(wg.get('sections_title_en', ''))}</span></h2>
    <ol class="wg-secs">{wg_secs}</ol>
  </section>""" if wg_secs else ""

    def wg_tile(it):
        f = it["file"]
        w, h = it.get("w", 1080), it.get("h", 1080)
        cap_it, cap_en = it.get("cap_it", ""), it.get("cap_en", "") or it.get("cap_it", "")
        webp = os.path.exists(os.path.join(ROOT, "assets", "wg", "grid", f + ".webp"))
        src = "".join(
            [f'<source srcset="img/wg/grid/{f}.webp" type="image/webp">'] if webp else []
        )
        full = f"img/wg/grid/large/{f}.jpg" if os.path.exists(
            os.path.join(ROOT, "assets", "wg", "grid", "large", f + ".jpg")
        ) else f"img/wg/grid/{f}.jpg"
        alt = esc(cap_it) or "Pezzo dall&#39;archivio WeedGadget"
        return (
            f'<figure class="wg-tile"><picture>{src}'
            f'<img src="img/wg/grid/{f}.jpg" data-full="{full}"'
            f' data-cap="{esc(cap_it)}" data-cap-en="{esc(cap_en)}"'
            f' alt="{alt}" loading="lazy"'
            f' width="{w}" height="{h}"></picture></figure>'
        )

    wg_grid_html = f"""
  <section class="wg-block" id="griglia">
    <h2 class="sec-h"><span data-lang="it">{esc(wg.get('grid_title_it', ''))}</span><span data-lang="en" hidden>{esc(wg.get('grid_title_en', ''))}</span></h2>
    <p class="wg-note"><span data-lang="it">{esc(wg.get('grid_note_it', ''))}</span><span data-lang="en" hidden>{esc(wg.get('grid_note_en', ''))}</span> <b>{len(wg_grid)}</b></p>
    <div class="wg-grid">{''.join(wg_tile(i) for i in wg_grid)}</div>
  </section>""" if wg_grid else ""

    wgpage = f"""
<section class="sec sec-top wg">
  <div class="wg-hd">
    <div class="wg-mark">
      <picture>
        <source srcset="img/wg/weedgadget.webp" type="image/webp">
        <img src="img/wg/weedgadget.png" alt="Marchio WeedGadget" width="1200" height="1200">
      </picture>
    </div>
    <div class="wg-hd-tx">
      <p class="mu-k"><span data-lang="it">{esc(wg['kicker_it'])}</span><span data-lang="en" hidden>{esc(wg['kicker_en'])}</span></p>
      <h1 class="pg-h">{esc(wg['name'])}</h1>
      <p class="mu-sub"><span data-lang="it">{esc(wg['tagline_it'])}</span><span data-lang="en" hidden>{esc(wg['tagline_en'])}</span></p>
    </div>
  </div>

  <div class="mu-bio">
    <div lang="it" data-lang="it">{wg_body_it}</div>
    <div lang="en" data-lang="en" hidden>{wg_body_en}</div>
  </div>

  <dl class="wg-facts">{facts}</dl>
{wg_secs_html}
{wg_grid_html}

  <a class="btn wg-ig" href="{esc(wg['instagram'])}" rel="noopener" target="_blank">
    <span data-lang="it">Guarda l'archivio su Instagram</span><span data-lang="en" hidden>See the archive on Instagram</span>
    <b>{esc(wg['handle'])}</b>
  </a>

  <article class="book">
    <div class="book-cov">
      <picture>
        <source srcset="img/wg/{bk['cover']}.webp" type="image/webp">
        <img src="img/wg/{bk['cover']}.jpg" alt="Copertina di {esc(bk['title'])} volume 1" loading="lazy" width="1812" height="1812">
      </picture>
    </div>
    <div class="book-tx">
      <p class="adp-k"><span data-lang="it">Il libro</span><span data-lang="en" hidden>The book</span> · {esc(bk['year'])}</p>
      <h2 class="adp-t">{esc(bk['title'])}</h2>
      <p class="book-sub">{esc(bk['subtitle'])}</p>
      <div lang="it" data-lang="it">{bk_it}</div>
      <div lang="en" data-lang="en" hidden>{bk_en}</div>
      <p class="book-next"><span data-lang="it">{esc(bk['next_it'])}</span><span data-lang="en" hidden>{esc(bk['next_en'])}</span></p>
    </div>
  </article>
</section>"""
    open(os.path.join(DIST, "weedgadget.html"), "w").write(
        page("WeedGadget — Giampiero Pagnini", wgpage, 0, active="wg", url_path="weedgadget.html",
             desc="WeedGadget: oltre dieci anni di vetro soffiato d'autore. Il primo import del vetro dei glass blower americani a Barcellona, e il libro Glass Addiction.",
             og_image=f"wg/{bk['cover']}.jpg")
    )

    # ---- musica
    mu = content["music"]
    os.makedirs(os.path.join(DIST, "img", "music"), exist_ok=True)
    for rel in mu["releases"]:
        for ext in ("jpg", "webp"):
            s = os.path.join(ROOT, "assets", "music", f'{rel["slug"]}.{ext}')
            if os.path.exists(s):
                shutil.copy2(s, os.path.join(DIST, "img", "music", f'{rel["slug"]}.{ext}'))

    def release_block(rel):
        # player Bandcamp: colori del sito, tracklist cliccabile, copertina nostra
        embed = (
            f'https://bandcamp.com/EmbeddedPlayer/v=2/album={rel["album_id"]}'
            f'/size=large/bgcol=111111/linkcol=ff9d00/artwork=none/tracklist=true/transparent=true/'
        )
        # la tracklist visibile la disegna già il player di Bandcamp (con le durate,
        # e cliccabile): qui non va ripetuta. Per i motori di ricerca resta il JSON-LD.
        return f"""
<article class="rel" id="{rel['slug']}">
  <div class="rel-cov">
    <a href="{esc(rel['url'])}" rel="noopener" target="_blank">
      <picture>
        <source srcset="img/music/{rel['slug']}.webp" type="image/webp">
        <img src="img/music/{rel['slug']}.jpg" alt="Copertina di {esc(rel['title'])}" loading="lazy" width="1200" height="1200">
      </picture>
    </a>
  </div>
  <div class="rel-tx">
    <h2 class="rel-t">{esc(rel['title'])}</h2>
    <p class="rel-d"><span data-lang="it">{esc(rel['date_it'])}</span><span data-lang="en" hidden>{esc(rel['date_en'])}</span> · {len(rel['tracks'])} <span data-lang="it">tracce</span><span data-lang="en" hidden>tracks</span></p>
    {bi(esc(rel['note_it']), esc(rel['note_en']), 'p', 'rel-n')}
    <div class="rel-play">
      <iframe src="{embed}" title="Ascolta {esc(rel['title'])} su Bandcamp" loading="lazy" seamless>
        <a href="{esc(rel['url'])}">{esc(rel['title'])} — GP THE SYNTH ROLLER</a>
      </iframe>
    </div>
    <a class="btn btn-s" href="{esc(rel['url'])}" rel="noopener" target="_blank"><span data-lang="it">Ascolta e acquista su Bandcamp</span><span data-lang="en" hidden>Listen and buy on Bandcamp</span></a>
  </div>
</article>"""

    albums_ld = json.dumps(
        [
            {
                "@context": "https://schema.org",
                "@type": "MusicAlbum",
                "name": rel["title"],
                "byArtist": {"@type": "MusicGroup", "name": mu["artist"], "url": mu["bandcamp"]},
                "datePublished": rel["year"],
                "url": rel["url"],
                "image": f"{SITE_URL}/img/music/{rel['slug']}.jpg",
                "numTracks": len(rel["tracks"]),
                "track": [
                    {"@type": "MusicRecording", "name": t, "position": i}
                    for i, t in enumerate(rel["tracks"], 1)
                ],
            }
            for rel in mu["releases"]
        ],
        ensure_ascii=False,
    )
    mu_bio_it = "".join(f"<p>{esc(t)}</p>" for t in mu["bio_it"])
    mu_bio_en = "".join(f"<p>{esc(t)}</p>" for t in mu["bio_en"])
    musica = f"""
<script type="application/ld+json">{albums_ld}</script>
<section class="sec sec-top musica">
  <p class="mu-k">{esc(mu['artist'])}</p>
  <h1 class="pg-h"><span data-lang="it">Musica</span><span data-lang="en" hidden>Music</span></h1>
  <p class="mu-sub"><span data-lang="it">{esc(mu['tagline_it'])}</span><span data-lang="en" hidden>{esc(mu['tagline_en'])}</span></p>
  <div class="mu-bio">
    <div lang="it" data-lang="it">{mu_bio_it}</div>
    <div lang="en" data-lang="en" hidden>{mu_bio_en}</div>
  </div>
  <div class="mu-links">
    <a href="{esc(mu['bandcamp'])}" rel="noopener" target="_blank">Bandcamp</a>
    <a href="{esc(mu['instagram'])}" rel="noopener" target="_blank">Instagram</a>
  </div>
  <div class="rels">{''.join(release_block(r) for r in mu['releases'])}</div>
</section>"""
    open(os.path.join(DIST, "musica.html"), "w").write(
        page("Musica — GP The Synth Roller | Giampiero Pagnini", musica, 0, active="musica",
             url_path="musica.html",
             desc="GP THE SYNTH ROLLER, il progetto musicale di Giampiero Pagnini: downtempo, trip hop ed elettronica ambient costruita su sintetizzatori modulari. Due dischi del 2025.",
             og_image=f"music/{mu['releases'][0]['slug']}.jpg")
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

    # ---- reindirizzamenti dai vecchi indirizzi Wix
    # Google ha ancora in elenco gli indirizzi del sito Wix (es. /sxpin): senza
    # queste paginette rispondono 404 e la visita si perde. GitHub Pages non fa
    # redirect veri, quindi si usa meta refresh + canonical, che Google accetta.
    manuali = {
        "home": "", "blog": "", "single-post": "",
        "about": "about.html", "exhibitions": "about.html", "contact": "contact.html",
        "photography": "opere.html#fotografia", "light": "opere.html#luce",
        "polaroid": "opere.html#polaroid", "cameras": "opere.html#camere",
        "video": "opere.html#video", "paintings": "opere.html#pittura",
        "street": "opere.html#street", "streetgall": "progetti/street-gallery.html",
        "sk8": "opere.html#street", "mugshot": "opere.html",
        "red-chair": "progetti/red-chairs.html",
        "disappering": "progetti/disappearing.html",
        "ambient-exhibition": "progetti/ambient-venezia.html",
        "dripping-city-dreams-pola": "progetti/dripping-city-dreams.html",
        "emulsion-ball-zqkgo": "progetti/emulsion-ball.html",
        "emulsion-ball-t20kw": "progetti/emulsion-ball.html",
    }
    # ATTENZIONE: alcuni vecchi indirizzi Wix hanno lo stesso nome delle pagine
    # vere (/about, /contact). Scriverci sopra una paginetta di rinvio le
    # distruggerebbe — e per giunta rinvierebbero a se stesse. GitHub Pages già
    # serve /about da about.html, quindi quei vecchi indirizzi funzionano da soli.
    RISERVATI = {"index", "opere", "art-direction", "weedgadget", "musica",
                 "about", "contact", "404", "sitemap", "robots"}
    slug_norm = {re.sub(r"[^a-z0-9]", "", p["slug"].lower()): p["slug"] for p in visible}
    esistenti = {p["slug"] for p in visible}
    old_path = os.path.join(ROOT, "scrape", "site.json")
    n_red = 0
    if os.path.exists(old_path):
        for p in json.load(open(old_path))["pages"].values():
            s = p["slug"]
            if s in RISERVATI:
                continue
            if s in manuali:
                dest = manuali[s]
            elif s in esistenti:
                dest = f"progetti/{s}.html"
            elif re.sub(r"[^a-z0-9]", "", s.lower()) in slug_norm:
                dest = f"progetti/{slug_norm[re.sub(r'[^a-z0-9]', '', s.lower())]}.html"
            else:
                dest = ""
            url = f"{SITE_URL}/{dest}"
            open(os.path.join(DIST, s + ".html"), "w").write(
                f"""<!DOCTYPE html>
<html lang="it">
<head>
<meta charset="utf-8">
<title>{esc(p['title'])} — Giampiero Pagnini</title>
<link rel="canonical" href="{url}">
<meta http-equiv="refresh" content="0; url={url}">
<meta name="robots" content="noindex, follow">
<script>location.replace({json.dumps(url)});</script>
</head>
<body style="background:#0b0b0d;color:#eee;font:16px/1.5 system-ui;padding:3rem">
<p>Questa pagina si è spostata. <a style="color:#ff9d00" href="{url}">Continua qui</a>.</p>
</body>
</html>""")
            n_red += 1

    # ---- sitemap / robots / CNAME
    urls = ["", "opere.html", "art-direction.html", "weedgadget.html", "musica.html",
            "about.html", "contact.html"] + [f"progetti/{p['slug']}.html" for p in visible]
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

    print(f"built {n_red} redirect, {len(visible)} project pages, {len(urls)} urls in sitemap, domain {DOMAIN}")


if __name__ == "__main__":
    build()
