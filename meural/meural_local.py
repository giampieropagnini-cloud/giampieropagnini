#!/usr/bin/env python3
"""Prova dell'API locale della cornice Meural Canvas (porta 80, senza password).

Uso:
  python3 meural_local.py <ip> status
  python3 meural_local.py <ip> galleries
  python3 meural_local.py <ip> items <gallery_id>
  python3 meural_local.py <ip> next | prev | up | down
  python3 meural_local.py <ip> sleep | wake
  python3 meural_local.py <ip> backlight <0-100>
  python3 meural_local.py <ip> gallery <gallery_id>
  python3 meural_local.py <ip> item <item_id>
  python3 meural_local.py <ip> orientation portrait|landscape
  python3 meural_local.py <ip> show <file.jpg|png|gif>

Nessuna dipendenza esterna: solo la libreria standard di Python 3.
"""
import json
import mimetypes
import sys
import urllib.error
import urllib.request
import uuid

TIMEOUT = 10


def get(ip, path):
    url = f"http://{ip}/remote/{path}"
    with urllib.request.urlopen(url, timeout=TIMEOUT) as r:
        body = r.read().decode("utf-8", "replace")
    try:
        return json.loads(body)
    except ValueError:
        return body


def postcard(ip, filepath):
    """Mostra subito un'immagine sulla cornice (anteprima temporanea)."""
    ctype = mimetypes.guess_type(filepath)[0] or "application/octet-stream"
    if ctype == "image/jpg":
        ctype = "image/jpeg"
    with open(filepath, "rb") as f:
        data = f.read()
    boundary = "----meural" + uuid.uuid4().hex
    name = filepath.split("/")[-1]
    body = b"".join([
        f"--{boundary}\r\n".encode(),
        f'Content-Disposition: form-data; name="photo"; filename="{name}"\r\n'.encode(),
        f"Content-Type: {ctype}\r\n\r\n".encode(),
        data,
        f"\r\n--{boundary}--\r\n".encode(),
    ])
    req = urllib.request.Request(
        f"http://{ip}/remote/postcard",
        data=body,
        method="POST",
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    )
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        return r.read().decode("utf-8", "replace")


def show(result):
    if isinstance(result, (dict, list)):
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        print(result)


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 1
    ip, cmd, args = argv[1], argv[2], argv[3:]
    simple = {
        "next": "control_command/set_key/right/",
        "prev": "control_command/set_key/left/",
        "up": "control_command/set_key/up/",
        "down": "control_command/set_key/down/",
        "sleep": "control_command/suspend",
        "wake": "control_command/resume",
        "galleries": "get_galleries_json/",
        "identify": "identify/",
        "wifi": "get_wifi_connections_json/",
    }
    try:
        if cmd == "status":
            show({
                "system": get(ip, "control_check/system/"),
                "sleeping": get(ip, "control_check/sleep/"),
                "backlight": get(ip, "get_backlight/"),
                "now_playing": get(ip, "get_gallery_status_json/"),
            })
        elif cmd in simple:
            show(get(ip, simple[cmd]))
        elif cmd == "items":
            show(get(ip, f"get_frame_items_by_gallery_json/{args[0]}"))
        elif cmd == "backlight":
            show(get(ip, f"control_command/set_backlight/{int(args[0])}/"))
        elif cmd == "gallery":
            show(get(ip, f"control_command/change_gallery/{args[0]}"))
        elif cmd == "item":
            show(get(ip, f"control_command/change_item/{args[0]}"))
        elif cmd == "orientation":
            show(get(ip, f"control_command/set_orientation/{args[0]}"))
        elif cmd == "show":
            show(postcard(ip, args[0]))
        else:
            print(__doc__)
            return 1
    except (urllib.error.URLError, OSError) as e:
        print(f"Errore: non raggiungo la cornice su {ip}: {e}")
        print("Controlla che computer e cornice siano sulla stessa rete wifi.")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
