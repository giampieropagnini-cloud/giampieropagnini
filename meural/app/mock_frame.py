#!/usr/bin/env python3
"""Cornice Meural finta, per collaudare l'app senza la cornice vera.

Emula l'API locale su http://127.0.0.1:<porta>/remote/... e stampa cosa riceve.
Uso: python3 mock_frame.py [porta]   (default 8081)
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

STATE = {
    "sleeping": False,
    "backlight": 70,
    "orientation": "landscape",
    "gallery": 1,
    "item": 101,
    "postcards": 0,
    "last_postcard_bytes": 0,
}
GALLERIES = [
    {"id": 1, "name": "Preferite", "orientation": "landscape"},
    {"id": 2, "name": "Famiglia", "orientation": "portrait"},
]
ITEMS = {1: [{"id": 101, "name": "Alba"}, {"id": 102, "name": "Tramonto"}],
         2: [{"id": 201, "name": "Nonna"}]}


class H(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        sys.stderr.write("[cornice finta] %s\n" % (fmt % args))

    def _send(self, obj, code=200):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        p = self.path.strip("/").split("/")
        if not p or p[0] != "remote":
            return self._send({"error": "not found"}, 404)
        p = p[1:]
        try:
            if p[0] == "control_command":
                c = p[1]
                if c == "set_key":
                    STATE["item"] += 1 if p[2] == "right" else -1
                elif c == "suspend":
                    STATE["sleeping"] = True
                elif c == "resume":
                    STATE["sleeping"] = False
                elif c == "set_backlight":
                    STATE["backlight"] = int(p[2])
                elif c == "set_orientation":
                    STATE["orientation"] = p[2]
                elif c == "change_gallery":
                    STATE["gallery"] = int(p[2])
                elif c == "change_item":
                    STATE["item"] = int(p[2])
                return self._send({"status": "pass", "response": "ok"})
            if p[0] == "control_check":
                if p[1] == "sleep":
                    return self._send({"status": "pass", "response": STATE["sleeping"]})
                if p[1] == "system":
                    return self._send({"status": "pass", "response": {
                        "model": "Canvas II (finta)", "version": "2.3.2_3.0.3",
                        "storage_free": "12 GB", "wifi": "-52 dBm", "als": 180}})
            if p[0] == "get_backlight":
                return self._send({"status": "pass", "response": STATE["backlight"]})
            if p[0] == "identify":
                return self._send({"status": "pass", "response": {"name": "Cornice finta"}})
            if p[0] == "get_wifi_connections_json":
                return self._send({"status": "pass", "response": [{"ssid": "CasaWifi"}]})
            if p[0] == "get_galleries_json":
                return self._send(GALLERIES)
            if p[0] == "get_gallery_status_json":
                g = next(x for x in GALLERIES if x["id"] == STATE["gallery"])
                return self._send({"status": "pass", "response": {
                    "current_gallery": g["id"], "current_gallery_name": g["name"],
                    "current_item": STATE["item"],
                    "current_item_name": f"Opera {STATE['item']}"}})
            if p[0] == "get_frame_items_by_gallery_json":
                return self._send(ITEMS.get(int(p[1]), []))
        except (IndexError, ValueError):
            pass
        self._send({"error": "unknown"}, 404)

    def do_POST(self):
        if self.path.rstrip("/") == "/remote/postcard":
            n = int(self.headers.get("Content-Length") or 0)
            data = self.rfile.read(n)
            STATE["postcards"] += 1
            STATE["last_postcard_bytes"] = len(data)
            sys.stderr.write(f"[cornice finta] POSTCARD ricevuta: {len(data)} byte, "
                             f"multipart={'photo' in data[:500].decode('latin-1')}\n")
            return self._send({"status": "pass", "response": "postcard displayed"})
        self._send({"error": "not found"}, 404)


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8081
    print(f"Cornice finta su http://127.0.0.1:{port}  (usa frame_ip = 127.0.0.1:{port})")
    ThreadingHTTPServer(("127.0.0.1", port), H).serve_forever()
