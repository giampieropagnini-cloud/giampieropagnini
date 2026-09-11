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
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "app"))
from frame import Frame, FrameError  # noqa: E402


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
    fr = Frame(ip)
    simple = {
        "next": fr.next, "prev": fr.prev, "up": fr.key_up, "down": fr.key_down,
        "sleep": fr.sleep, "wake": fr.wake, "galleries": fr.galleries,
        "identify": fr.identify, "wifi": fr.wifi,
    }
    try:
        if cmd == "status":
            show(fr.status())
        elif cmd in simple:
            show(simple[cmd]())
        elif cmd == "items":
            show(fr.gallery_items(args[0]))
        elif cmd == "backlight":
            show(fr.set_backlight(args[0]))
        elif cmd == "gallery":
            show(fr.change_gallery(args[0]))
        elif cmd == "item":
            show(fr.change_item(args[0]))
        elif cmd == "orientation":
            show(fr.set_orientation(args[0]))
        elif cmd == "show":
            with open(args[0], "rb") as f:
                show(fr.postcard(f.read(), os.path.basename(args[0])))
        else:
            print(__doc__)
            return 1
    except FrameError as e:
        print(f"Errore: {e}")
        print("Controlla che computer e cornice siano sulla stessa rete wifi.")
        return 2
    except (IndexError, ValueError, OSError) as e:
        print(f"Errore: {e}")
        print(__doc__)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
