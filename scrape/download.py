#!/usr/bin/env python3
"""Build structured site model from scraped data and download all images."""
import json
import os
import re
import urllib.request
from concurrent.futures import ThreadPoolExecutor

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)
IMGDIR = os.path.join(ROOT, "assets", "img")
os.makedirs(IMGDIR, exist_ok=True)

manifest = json.load(open(os.path.join(BASE, "manifest.json")))
master = json.load(open(os.path.join(BASE, "json", "master.json")))
doc = master["data"]["document_data"]

# --- build menu hierarchy from CUSTOM_MAIN_MENU ---
def resolve(ref):
    return doc.get(ref.lstrip("#"), {})

def menu_item(ref):
    rec = resolve(ref)
    link = rec.get("link", "")
    page_id = ""
    if link:
        lrec = resolve(link)
        page_id = (lrec.get("pageId") or "").lstrip("#")
    return {
        "label": rec.get("label", "").strip(),
        "pageId": page_id,
        "items": [menu_item(i) for i in rec.get("items", [])],
    }

menu = []
for k, v in doc.items():
    if v.get("type") == "CustomMenu":
        menu = [menu_item(i) for i in v.get("items", [])]

site = {"menu": menu, "pages": manifest}
json.dump(site, open(os.path.join(BASE, "site.json"), "w"), indent=1, ensure_ascii=False)

# --- collect unique image uris ---
uris = {}
for pid, page in manifest.items():
    for im in page["images"]:
        u = im.get("uri")
        if u:
            uris.setdefault(u, []).append(page["slug"])
print("unique images:", len(uris))

def dl(uri):
    out = os.path.join(IMGDIR, uri)
    if os.path.exists(out) and os.path.getsize(out) > 0:
        return "skip"
    url = f"https://static.wixstatic.com/media/{uri}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=60) as r:
            data = r.read()
        open(out, "wb").write(data)
        return "ok"
    except Exception as e:
        return f"FAIL {uri}: {e}"

results = {"ok": 0, "skip": 0}
fails = []
with ThreadPoolExecutor(max_workers=12) as ex:
    for res in ex.map(dl, sorted(uris)):
        if res in results:
            results[res] += 1
        else:
            fails.append(res)
print(results, "fails:", len(fails))
for f in fails[:20]:
    print(f)
