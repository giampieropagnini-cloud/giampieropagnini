#!/usr/bin/env python3
"""Meural Locale: server web per controllare la cornice dalla rete di casa.

Avvio:  python3 server.py [config.json]
Poi apri http://<ip-di-questo-computer>:8080 dal telefono.

Solo libreria standard. Pillow (facoltativo) migliora l'adattamento immagini.
"""
import json
import logging
import mimetypes
import os
import sys
import threading
from email.parser import BytesParser
from email.policy import HTTP
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import images  # noqa: E402
from frame import Frame, FrameError  # noqa: E402
from slideshow import Slideshow  # noqa: E402

log = logging.getLogger("server")

DEFAULTS = {
    "frame_ip": "",
    "port": 8080,
    "folder": "immagini",
    "interval": 300,
    "shuffle": True,
    "orientation": "auto",
    "fit": "fit",
    "background": "#000000",
    "watchdog": True,
    "night_enabled": False,
    "night_from": "23:30",
    "night_to": "07:30",
}
EDITABLE = [k for k in DEFAULTS if k != "port"]


class App:
    def __init__(self, config_path):
        self.config_path = config_path
        self.config = dict(DEFAULTS)
        if os.path.exists(config_path):
            with open(config_path, encoding="utf-8") as f:
                self.config.update(json.load(f))
        self._resolve_folder()
        self.frame = Frame(self.config["frame_ip"] or "0.0.0.0")
        self.slideshow = Slideshow(self.frame, self.config, lambda: self.folder)
        self.slideshow.start()
        self.lock = threading.Lock()

    def _resolve_folder(self):
        """Cartella immagini assoluta; in config resta il valore scritto dall'utente."""
        folder = self.config.get("folder") or "immagini"
        if not os.path.isabs(folder):
            folder = os.path.join(os.path.dirname(os.path.abspath(self.config_path)), folder)
        os.makedirs(folder, exist_ok=True)
        self.folder = folder

    def save(self):
        with self.lock:
            with open(self.config_path, "w", encoding="utf-8") as f:
                json.dump(self.config, f, indent=2, ensure_ascii=False)

    def update_config(self, data):
        for k in EDITABLE:
            if k in data:
                v = data[k]
                if isinstance(DEFAULTS[k], bool):
                    v = v in (True, "true", "1", 1, "on")
                elif isinstance(DEFAULTS[k], int):
                    v = int(v)
                self.config[k] = v
        self._resolve_folder()
        self.frame.ip = self.config["frame_ip"]
        self.save()

    def state(self):
        return {
            "config": self.config,
            "frame": self.frame.status() if self.config["frame_ip"] else {"error": "IP cornice non impostato"},
            "slideshow": self.slideshow.state(),
            "images": images.list_images(self.folder),
            "pillow": images.HAVE_PIL,
        }

    def command(self, cmd, value=None):
        fr = self.frame
        table = {
            "next": fr.next, "prev": fr.prev, "up": fr.key_up, "down": fr.key_down,
            "wake": fr.wake, "als_off": fr.als_off,
            "galleries": fr.galleries, "identify": fr.identify,
        }
        if cmd in table:
            return table[cmd]()
        if cmd == "sleep":
            # spegnimento voluto: fermo lo slideshow, altrimenti il watchdog la risveglia
            self.slideshow.stop_show()
            return fr.sleep()
        if cmd == "backlight":
            return fr.set_backlight(value)
        if cmd == "gallery":
            self.slideshow.stop_show()
            return fr.change_gallery(value)
        if cmd == "item":
            return fr.change_item(value)
        if cmd == "orientation":
            return fr.set_orientation(value)
        if cmd == "slideshow_start":
            self.slideshow.start_show()
            return "ok"
        if cmd == "slideshow_stop":
            self.slideshow.stop_show()
            return "ok"
        if cmd == "slideshow_skip":
            self.slideshow.skip()
            return "ok"
        if cmd == "show_file":
            path = os.path.join(self.folder, os.path.basename(str(value)))
            if not os.path.isfile(path):
                raise FrameError("file non trovato")
            self.slideshow.show_file(path)
            return "ok"
        raise FrameError(f"comando sconosciuto: {cmd}")


class Handler(BaseHTTPRequestHandler):
    app: App = None

    def log_message(self, fmt, *args):
        log.debug(fmt, *args)

    # ---- helpers -----------------------------------------------------------

    def _json(self, obj, code=200):
        body = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _file(self, path, ctype=None):
        if not os.path.isfile(path):
            self.send_error(404)
            return
        ctype = ctype or mimetypes.guess_type(path)[0] or "application/octet-stream"
        with open(path, "rb") as f:
            data = f.read()
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(n) if n else b""

    def _multipart_files(self):
        ctype = self.headers.get("Content-Type", "")
        raw = b"Content-Type: " + ctype.encode() + b"\r\n\r\n" + self._body()
        msg = BytesParser(policy=HTTP).parsebytes(raw)
        out = []
        for part in msg.iter_parts():
            name = part.get_filename()
            if name:
                out.append((os.path.basename(name), part.get_payload(decode=True)))
        return out

    # ---- routes ------------------------------------------------------------

    def do_GET(self):
        u = urlparse(self.path)
        if u.path in ("/", "/index.html"):
            return self._file(os.path.join(HERE, "ui.html"), "text/html; charset=utf-8")
        if u.path == "/api/state":
            return self._json(self.app.state())
        if u.path == "/api/galleries":
            try:
                return self._json({"galleries": self.app.frame.galleries()})
            except FrameError as e:
                return self._json({"error": str(e)}, 502)
        if u.path.startswith("/img/"):
            name = os.path.basename(u.path[5:])
            if images.is_image(name):
                return self._file(os.path.join(self.app.folder, name))
        self.send_error(404)

    def do_POST(self):
        u = urlparse(self.path)
        try:
            if u.path == "/api/cmd":
                data = json.loads(self._body() or b"{}")
                result = self.app.command(data.get("cmd"), data.get("value"))
                return self._json({"ok": True, "result": result})
            if u.path == "/api/config":
                data = json.loads(self._body() or b"{}")
                self.app.update_config(data)
                return self._json({"ok": True, "config": self.app.config})
            if u.path == "/api/upload":
                q = parse_qs(u.query)
                show_now = q.get("show", ["0"])[0] == "1"
                saved = []
                for name, payload in self._multipart_files():
                    if not images.is_image(name) or not payload:
                        continue
                    dest = os.path.join(self.app.folder, name)
                    with open(dest, "wb") as f:
                        f.write(payload)
                    saved.append(name)
                if show_now and saved:
                    self.app.command("show_file", saved[-1])
                return self._json({"ok": True, "saved": saved})
            if u.path == "/api/delete":
                data = json.loads(self._body() or b"{}")
                name = os.path.basename(str(data.get("name", "")))
                path = os.path.join(self.app.folder, name)
                if images.is_image(name) and os.path.isfile(path):
                    os.remove(path)
                    return self._json({"ok": True})
                return self._json({"ok": False, "error": "file non trovato"}, 404)
        except FrameError as e:
            return self._json({"ok": False, "error": str(e)}, 502)
        except (ValueError, KeyError) as e:
            return self._json({"ok": False, "error": f"richiesta non valida: {e}"}, 400)
        self.send_error(404)


def main(argv):
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s: %(message)s")
    config_path = argv[1] if len(argv) > 1 else os.path.join(HERE, "config.json")
    app = App(config_path)
    Handler.app = app
    port = int(app.config.get("port", 8080))
    srv = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    log.info("Meural Locale in ascolto su http://0.0.0.0:%d  (cornice: %s, cartella: %s)",
             port, app.config["frame_ip"] or "non impostata", app.folder)
    if not images.HAVE_PIL:
        log.info("Pillow non installato: le immagini vengono inviate senza adattamento "
                 "(pip3 install pillow per attivarlo)")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main(sys.argv)
