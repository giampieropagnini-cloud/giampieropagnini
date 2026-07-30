#!/usr/bin/env python3
"""Scrape the classic-Wix site giamps1982.wixsite.com/giampiero-pagnini.

Downloads every page's data JSON from static.wixstatic.com, extracts texts,
images (with title/description), video embeds, and writes a manifest.
"""
import json
import os
import re
import urllib.request

BASE = os.path.dirname(os.path.abspath(__file__))
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"}


def fetch(url, binary=False):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=30) as r:
        data = r.read()
    return data if binary else data.decode("utf-8", "replace")


def balanced(html, key):
    m = re.search(r'"%s":\{' % key, html)
    if not m:
        return None
    start = m.end() - 1
    depth = 0
    for i in range(start, len(html)):
        if html[i] == "{":
            depth += 1
        elif html[i] == "}":
            depth -= 1
            if depth == 0:
                return json.loads(html[start : i + 1])
    return None


html = open(os.path.join(BASE, "sensibili.html")).read()
pages_map = balanced(html, "pagesMap")
print("pages in map:", len(pages_map))

mm = re.search(r'"masterPage(?:JsonFileName)?":"(39e78d_[a-f0-9_]+)"', html)
master_file = mm.group(1) if mm else None
print("masterPage json:", master_file)

os.makedirs(os.path.join(BASE, "json"), exist_ok=True)
manifest = {}

STRIP = re.compile(r"<[^>]+>")


def clean_html_text(s):
    s = s.replace("&nbsp;", " ").replace("&amp;", "&").replace("&quot;", '"')
    s = s.replace("&#39;", "'").replace("&lt;", "<").replace("&gt;", ">")
    return s


def harvest(doc):
    """Pull texts, images, videos out of a page's document_data."""
    texts, images, videos, links = [], [], [], []
    for rec_id, rec in doc.items():
        t = rec.get("type", "")
        if t in ("StyledText", "Text", "MediaRichText"):
            raw = rec.get("text", "")
            txt = clean_html_text(STRIP.sub(" ", raw))
            txt = re.sub(r"\s+", " ", txt).strip()
            if txt:
                texts.append({"id": rec_id, "html": raw, "text": txt})
        elif t == "Image":
            images.append(
                {
                    "id": rec_id,
                    "uri": rec.get("uri", ""),
                    "title": rec.get("title", ""),
                    "description": rec.get("description", ""),
                    "alt": rec.get("alt", ""),
                    "width": rec.get("width"),
                    "height": rec.get("height"),
                }
            )
        elif t == "Video":
            videos.append(
                {
                    "id": rec_id,
                    "videoId": rec.get("videoId", ""),
                    "videoType": rec.get("videoType", ""),
                }
            )
        elif t in ("ExternalLink", "PageLink"):
            links.append({k: rec.get(k) for k in ("url", "pageId") if k in rec})
    return texts, images, videos, links


todo = dict(pages_map)
if master_file:
    todo["masterPage"] = {
        "pageId": "masterPage",
        "title": "MASTER",
        "pageUriSEO": "master",
        "pageJsonFileName": master_file,
    }

for pid, info in todo.items():
    fn = info["pageJsonFileName"]
    out = os.path.join(BASE, "json", fn + ".json")
    if not os.path.exists(out):
        try:
            data = fetch(f"https://static.wixstatic.com/sites/{fn}.json.z?v=3")
            open(out, "w").write(data)
        except Exception as e:
            print("FAIL", info.get("pageUriSEO"), e)
            continue
    page = json.load(open(out))
    doc = page.get("data", {}).get("document_data", {})
    texts, images, videos, links = harvest(doc)
    manifest[pid] = {
        "title": info.get("title", ""),
        "slug": info.get("pageUriSEO", ""),
        "file": fn,
        "texts": texts,
        "images": images,
        "videos": videos,
        "links": links,
        "n_images": len(images),
    }
    print(f"{info.get('pageUriSEO', pid):32s} imgs={len(images):3d} texts={len(texts):3d} videos={len(videos)}")

json.dump(manifest, open(os.path.join(BASE, "manifest.json"), "w"), indent=1, ensure_ascii=False)
total = sum(m["n_images"] for m in manifest.values())
print("TOTAL images:", total)
