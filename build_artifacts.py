#!/usr/bin/env python3
"""Build 3 self-contained design-proposal pages (one per theme) for Artifacts."""
import base64
import json
import os
import subprocess

ROOT = os.path.dirname(os.path.abspath(__file__))
DIST = os.path.join(ROOT, "dist")
OUT = os.path.join(ROOT, "proposte")
os.makedirs(OUT, exist_ok=True)

content = json.load(open(os.path.join(ROOT, "content.json")))
site = content["site"]
projects = {p["slug"]: p for p in content["projects"]}
scrape = json.load(open(os.path.join(ROOT, "scrape", "site.json")))
old_pages = {p["slug"]: p for p in scrape["pages"].values()}

from collections import defaultdict
occ = defaultdict(set)
for p in scrape["pages"].values():
    for im in p["images"]:
        occ[im["uri"]].add(p["slug"])
CHROME = {u for u, s in occ.items() if len(s) >= 3}


def gallery(slug, n=None):
    pr = projects[slug]
    old = old_pages.get(pr["old_slug"], {"images": []})
    out, seen = [], set()
    for im in old["images"]:
        u = im["uri"]
        if u in seen or u in CHROME or not u.startswith("39e78d_"):
            continue
        seen.add(u)
        out.append(im)
    return out[:n] if n else out


def b64(path, mime="image/jpeg"):
    return f"data:{mime};base64," + base64.b64encode(open(path, "rb").read()).decode()


def thumb64(uri):
    return b64(os.path.join(DIST, "img", "thumb", uri))


def resized64(uri, size, q="60"):
    tmp = os.path.join(OUT, f"_tmp_{size}_{uri}")
    if not os.path.exists(tmp):
        subprocess.run(
            ["sips", "-Z", str(size), "-s", "format", "jpeg", "-s", "formatOptions", q,
             os.path.join(ROOT, "assets", "img", uri), "--out", tmp],
            capture_output=True,
        )
    return b64(tmp)


FEATURED = {
    "red-chairs": "redpost 004", "cheat-your-eyes": "IMGP0679",
    "disappearing": "4pin 010", "pimp-my-camera": "pimp", "seek-deep-inside": "mm",
}


def cover(slug):
    g = gallery(slug)
    want = FEATURED.get(slug)
    if want:
        for im in g:
            if want.lower() in (im.get("title") or "").lower():
                return im["uri"]
    return g[0]["uri"] if g else None


HOME_SEL = ["red-chairs", "cheat-your-eyes", "aperitivo-stenopeico", "disappearing",
            "seats", "pimp-my-camera", "emulsion-ball", "dripping-city-dreams"]
CAM_SEL = ["pimp-my-camera", "return-cam", "66x-cam", "cheat-cam"]

base_css = open(os.path.join(DIST, "css", "base.css")).read()
theme_css = open(os.path.join(DIST, "css", "theme.css")).read()
oswald = b64(os.path.join(DIST, "fonts", "oswald.woff2"), "font/woff2")
inter = b64(os.path.join(DIST, "fonts", "inter.woff2"), "font/woff2")
theme_css = theme_css.replace("url('../fonts/oswald.woff2')", f"url('{oswald}')")
theme_css = theme_css.replace("url('../fonts/inter.woff2')", f"url('{inter}')")

hero64 = resized64(site["home_hero"], 1300, "62")
portrait64 = resized64(site["portrait"], 700, "62")
hero_vid_path = os.path.join(ROOT, "assets", "hero-small-loop.mp4")
hero_vid64 = b64(hero_vid_path, "video/mp4") if os.path.exists(hero_vid_path) else None

THEMES = [
    ("oscura", "oscura", "Camera Oscura", "B",
     "La sala buia delle tue mostre: fondo nero, grana di pellicola, le opere si accendono come lightbox."),
    ("pin", "pin", "Stenopeico", "C",
     "L'archivio pop: rosa shocking, indice cronologico delle opere, targhe-specifiche come schede tecniche."),
]

extra_css = """
.banner { position: sticky; top: 0; z-index: 60; background: var(--ac); color: var(--on-ac);
  font: 600 .8rem/1.4 var(--font-body); letter-spacing: .12em; text-transform: uppercase;
  padding: .55em 1rem; text-align: center; }
.hd { top: 2.1rem; }
.note { font-size: .85rem; opacity: .6; max-width: 40em; margin-top: 1rem; }
.cam-row { display: grid; grid-template-columns: repeat(auto-fit, minmax(9rem, 1fr)); gap: 1rem; }
.cam-row img { aspect-ratio: 1; object-fit: cover; width: 100%; border-radius: var(--im-r);
  box-shadow: var(--im-sh); border: var(--im-bd); background: #fff; }
html { scroll-behavior: smooth; }
"""

js = """
document.getElementById('langBtn').addEventListener('click', function () {
  var l = (document.documentElement.getAttribute('data-lang') || 'it') === 'it' ? 'en' : 'it';
  document.documentElement.setAttribute('data-lang', l);
  document.querySelectorAll('[data-lang]').forEach(function (el) {
    if (el === document.documentElement) return;
    el.hidden = el.getAttribute('data-lang') !== l;
  });
});
"""


def bi(it, en, tag="p", cls=""):
    c = f' class="{cls}"' if cls else ""
    return (f'<{tag} data-lang="it"{c}>{it}</{tag}><{tag} data-lang="en"{c} hidden>{en}</{tag}>')


def year_key(pr):
    import re as _re
    m = _re.search(r"(19|20)\d\d", pr.get("year") or "")
    return (int(m.group(0)) if m else 9999, pr["title"])


for slug, attr, name, letter, pitch in THEMES:
    rc = projects["red-chairs"]
    rc_thumbs = "".join(
        f'<figure class="ph"><img src="{thumb64(im["uri"])}" alt="Red Chairs"></figure>'
        for im in gallery("red-chairs")[1:7]
    )
    pp = projects["pink-phanter"]
    pp_thumbs = "".join(
        f'<figure class="ph"><img src="{thumb64(im["uri"])}" alt="Pink Phanter"></figure>'
        for im in gallery("pink-phanter")[:4]
    )
    cards = "".join(
        f"""<span class="card"><span class="card-im"><img src="{thumb64(cover(s))}" alt="{projects[s]['title']}"></span>
        <span class="card-t">{projects[s]['title']} <span class="yr">{projects[s]['year']}</span></span>
        <span class="card-c">{projects[s]['_cat'] if '_cat' in projects[s] else projects[s]['category'].capitalize()}</span></span>"""
        for s in HOME_SEL
    )
    cams = "".join(f'<img src="{thumb64(cover(s))}" alt="{projects[s]["title"]}" title="{projects[s]["title"]}">' for s in CAM_SEL)
    bio = content["about"]["bio_it"]
    bio_en = content["about"]["bio_en"]

    hero_media = f'<section class="hero">\n  <img class="hero-im" src="{hero64}" alt="Studio">'
    if slug == "oscura" and hero_vid64:
        hero_media = (
            f'<section class="hero">\n  <video class="hero-im" autoplay muted loop playsinline '
            f'poster="{hero64}" aria-label="Lo studio di Giampiero Pagnini"><source src="{hero_vid64}" '
            f'type="video/mp4"></video>'
        )
    grain = '<div class="grain" aria-hidden="true"></div>' if slug == "oscura" else ""
    marq_items = "SENSIBILE ALLA LUCE ● FOTOGRAFIA ● LUCE ● POLAROID ● CAMERE ● VIDEO ● PITTURA ● STREET ● "
    marquee = (
        f'<div class="marq" aria-hidden="true"><div class="marq-t"><span>{marq_items}</span><span>{marq_items}</span></div></div>'
        if slug == "pin" else ""
    )
    archive = ""
    if slug == "pin":
        rows = []
        chrono = sorted([p for p in content["projects"] if cover(p["slug"])], key=year_key)
        for n, pr in enumerate(chrono[:10], 1):
            rows.append(f"""<span class="arch-r">
  <span class="arch-n">{n:02d}</span>
  <span class="arch-im"><img src="{resized64(cover(pr['slug']), 280, '55')}" alt=""></span>
  <span class="arch-t">{pr['title']}</span>
  <span class="arch-y">{pr['year']}</span>
  <span class="arch-c">{pr['category'].capitalize()}</span>
</span>""")
        archive = f"""<section class="sec">
  <h2 class="sec-h"><span data-lang="it">L'indice cronologico (anteprima)</span><span data-lang="en" hidden>The chronological index (preview)</span></h2>
  <p class="arch-note">Indice cronologico — 01/38</p>
  <div class="arch">{''.join(rows)}</div>
  <p class="note">Nella pagina Opere completa: tutti i 38 progetti in indice, filtrabili per percorso.</p>
</section>"""

    html = f"""<meta charset="utf-8">
<title>Proposta {letter} — {name} · giampieropagnini</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>{base_css}
{theme_css}
{extra_css}</style>
{grain}
<div class="banner">Proposta {letter} — {name} · anteprima del nuovo sito</div>
<header class="hd">
  <span class="wordmark">GIAMPIERO<b>PAGNINI</b></span>
  <nav class="nav">
    <a href="#opere"><span data-lang="it">Opere</span><span data-lang="en" hidden>Works</span></a>
    <a href="#about">About</a>
    <a href="#contatti"><span data-lang="it">Contatti</span><span data-lang="en" hidden>Contact</span></a>
    <button class="lang" id="langBtn">IT/EN</button>
  </nav>
</header>
{{HERO_MEDIA}}
  <div class="hero-tx">
    <h1 class="hero-h"><span data-lang="it">Sensibile alla luce</span><span data-lang="en" hidden>Sensitive to light</span></h1>
    {bi(site['intro_it'], site['intro_en'], 'p', 'hero-sub')}
    <a class="btn" href="#opere"><span data-lang="it">Guarda le opere</span><span data-lang="en" hidden>View works</span></a>
  </div>
</section>
{marquee}
<section class="sec" id="opere">
  <h2 class="sec-h"><span data-lang="it">Opere scelte</span><span data-lang="en" hidden>Selected works</span></h2>
  <div class="grid">{cards}</div>
  <p class="note">Nel sito completo: 38 progetti in 7 percorsi (Fotografia, Luce, Polaroid, Camere, Video, Pittura, Street), ognuno con la sua galleria e i testi in italiano e inglese.</p>
</section>
{archive}
<section class="sec">
  <div class="proj" style="padding:0">
    <div class="proj-cat">Fotografia · <span data-lang="it">esempio di pagina progetto</span><span data-lang="en" hidden>sample project page</span></div>
    <h2 class="pg-h">Red Chairs <span class="yr">2005–2007</span></h2>
    <p class="mat">{rc['materials']}</p>
    {bi(rc['text_it'], rc['text_en'])}
    <div class="gal" style="margin-top:1.5rem">{rc_thumbs}</div>
  </div>
</section>
<section class="sec">
  <div class="proj" style="padding:0">
    <div class="proj-cat">Camere · <span data-lang="it">esempio di scheda tecnica</span><span data-lang="en" hidden>sample spec sheet</span></div>
    <h2 class="pg-h">Pink Phanter</h2>
    <p class="mat">{pp['materials']}</p>
    {bi(pp['text_it'], pp['text_en'])}
    <div class="gal" style="margin-top:1.5rem">{pp_thumbs}</div>
  </div>
</section>
<section class="sec">
  <h2 class="sec-h"><span data-lang="it">Le camere autocostruite</span><span data-lang="en" hidden>The self-built cameras</span></h2>
  <div class="cam-row">{cams}</div>
</section>
<section class="sec" id="about">
  <div class="about-cols">
    <div class="about-im"><img src="{portrait64}" alt="Giampiero Pagnini"></div>
    <div class="about-tx">
      <h2 class="pg-h">About</h2>
      <div data-lang="it"><p>{bio[0]}</p><p>{bio[1]}</p><p>{bio[5]}</p></div>
      <div data-lang="en" hidden><p>{bio_en[0]}</p><p>{bio_en[1]}</p><p>{bio_en[5]}</p></div>
      <p class="note">La pagina completa include tutta la nuova biografia, il documentario «Sensibili alla luce» (2011) e l'elenco delle mostre.</p>
    </div>
  </div>
</section>
<footer class="ft" id="contatti">
  <div class="ft-name">GIAMPIERO PAGNINI</div>
  <div class="ft-links"><span>Instagram</span><span>Facebook</span><span>Flickr</span><span>{site['email']}</span></div>
  <div class="ft-note">© Giampiero Pagnini — Pescara, Italia · Proposta {letter}: {pitch}</div>
</footer>
<script>{js}</script>
"""
    html = html.replace("{HERO_MEDIA}", hero_media)
    if attr:
        html = f'<script>document.documentElement.setAttribute("data-theme","{attr}");</script>' + html
    out = os.path.join(OUT, f"proposta-{slug}.html")
    open(out, "w").write(html)
    print(out, f"{os.path.getsize(out)/1e6:.2f} MB")

for f in os.listdir(OUT):
    if f.startswith("_tmp_"):
        os.remove(os.path.join(OUT, f))
