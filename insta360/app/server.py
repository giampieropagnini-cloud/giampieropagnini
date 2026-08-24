# Il piccolo server web locale. Usa solo le librerie standard di Python:
# niente da installare. Ascolta soltanto sul computer stesso (127.0.0.1),
# quindi nulla è raggiungibile da fuori.

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Tuple

from .controller import Controller
from .drivers.base import ErroreTelecamera

CARTELLA_WEB = Path(__file__).parent / "web"

TIPI_FILE = {
    ".html": "text/html; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".svg": "image/svg+xml",
    ".png": "image/png",
}


class GestoreRichieste(BaseHTTPRequestHandler):
    server_version = "ControlloInsta360"
    controller: Controller = None  # assegnato da crea_server()

    # ------------------------------------------------------------- risposte

    def _json(self, dati, codice: int = 200) -> None:
        corpo = json.dumps(dati, ensure_ascii=False).encode("utf-8")
        self.send_response(codice)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(corpo)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(corpo)

    def _errore(self, messaggio: str, codice: int = 400) -> None:
        self._json({"errore": messaggio}, codice)

    def _file_statico(self, nome: str) -> None:
        percorso = (CARTELLA_WEB / nome).resolve()
        if not str(percorso).startswith(str(CARTELLA_WEB.resolve())) or not percorso.is_file():
            self._errore("Pagina non trovata.", 404)
            return
        corpo = percorso.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", TIPI_FILE.get(percorso.suffix, "application/octet-stream"))
        self.send_header("Content-Length", str(len(corpo)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(corpo)

    def _leggi_corpo(self) -> dict:
        lunghezza = int(self.headers.get("Content-Length") or 0)
        if lunghezza <= 0:
            return {}
        try:
            return json.loads(self.rfile.read(lunghezza).decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            return {}

    # -------------------------------------------------------------- richieste

    def do_GET(self) -> None:  # noqa: N802 (nome imposto dalla libreria)
        if self.path in ("/", "/index.html"):
            self._file_statico("index.html")
        elif self.path.startswith("/static/"):
            self._file_statico(self.path[len("/static/"):])
        elif self.path == "/api/stato":
            self._json(self.controller.stato())
        else:
            self._errore("Pagina non trovata.", 404)

    def do_POST(self) -> None:  # noqa: N802
        dati = self._leggi_corpo()
        try:
            if self.path.startswith("/api/telecamere/"):
                id_telecamera = self.path[len("/api/telecamere/"):].strip("/")
                self.controller.azione_telecamera(id_telecamera, dati)
                self._json({"ok": True})
            elif self.path == "/api/telecomando":
                self.controller.azione_telecomando(dati)
                self._json({"ok": True})
            elif self.path == "/api/bluetooth":
                self.controller.azione_bluetooth(dati)
                self._json({"ok": True})
            else:
                self._errore("Pagina non trovata.", 404)
        except ErroreTelecamera as exc:
            self._errore(str(exc))
        except Exception as exc:  # imprevisti: mostrali, non nasconderli
            self._errore("Errore interno: " + str(exc), 500)

    def log_message(self, formato, *argomenti) -> None:
        pass  # niente rumore nel terminale


def crea_server(porta: int = 8360) -> Tuple[ThreadingHTTPServer, int]:
    """Crea il server sulla prima porta libera a partire da quella chiesta."""
    controller = Controller()

    class _Gestore(GestoreRichieste):
        pass

    _Gestore.controller = controller

    ultimo_errore = None
    for tentativo in range(10):
        try:
            server = ThreadingHTTPServer(("127.0.0.1", porta + tentativo), _Gestore)
            server.daemon_threads = True
            return server, server.server_address[1]
        except OSError as exc:
            ultimo_errore = exc
    raise ultimo_errore
