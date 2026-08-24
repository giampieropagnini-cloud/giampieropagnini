# Prova d'insieme: si accende il server vero e gli si parla via HTTP,
# come farebbe il browser.

import http.client
import json
import pathlib
import sys
import threading
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from app.server import crea_server  # noqa: E402


class ProveServer(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.server, cls.porta = crea_server(porta=0)  # porta libera a caso
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def _chiedi(self, metodo, percorso, corpo=None):
        connessione = http.client.HTTPConnection("127.0.0.1", self.porta, timeout=5)
        dati = json.dumps(corpo).encode() if corpo is not None else None
        intestazioni = {"Content-Type": "application/json"} if dati else {}
        connessione.request(metodo, percorso, body=dati, headers=intestazioni)
        risposta = connessione.getresponse()
        contenuto = risposta.read()
        connessione.close()
        return risposta.status, contenuto

    def test_pagina_principale(self):
        codice, contenuto = self._chiedi("GET", "/")
        self.assertEqual(codice, 200)
        self.assertIn("Controllo Telecamere", contenuto.decode("utf-8"))

    def test_file_statici_e_percorsi_furbi(self):
        codice, _ = self._chiedi("GET", "/static/style.css")
        self.assertEqual(codice, 200)
        codice, _ = self._chiedi("GET", "/static/../server.py")
        self.assertEqual(codice, 404)

    def test_stato_ha_le_tre_telecamere(self):
        codice, contenuto = self._chiedi("GET", "/api/stato")
        self.assertEqual(codice, 200)
        stato = json.loads(contenuto)
        self.assertEqual(len(stato["telecamere"]), 3)
        self.assertIn("telecomando", stato)

    def test_collega_scatta_e_ritrova_il_file(self):
        codice, _ = self._chiedi("POST", "/api/telecamere/x6", {"azione": "collega"})
        self.assertEqual(codice, 200)
        codice, _ = self._chiedi("POST", "/api/telecamere/x6",
                                 {"azione": "modalita", "valore": "foto360"})
        self.assertEqual(codice, 200)

        _, contenuto = self._chiedi("GET", "/api/stato")
        prima = json.loads(contenuto)
        x6 = next(t for t in prima["telecamere"] if t["id"] == "x6")
        file_prima = len(x6["stato"]["file"])

        codice, _ = self._chiedi("POST", "/api/telecamere/x6", {"azione": "scatta"})
        self.assertEqual(codice, 200)

        _, contenuto = self._chiedi("GET", "/api/stato")
        dopo = json.loads(contenuto)
        x6 = next(t for t in dopo["telecamere"] if t["id"] == "x6")
        self.assertEqual(len(x6["stato"]["file"]), file_prima + 1)

    def test_errori_parlanti(self):
        codice, contenuto = self._chiedi("POST", "/api/telecamere/go3s", {"azione": "scatta"})
        self.assertEqual(codice, 400)
        self.assertIn("errore", json.loads(contenuto))

        codice, _ = self._chiedi("POST", "/api/telecamere/ignota", {"azione": "collega"})
        self.assertEqual(codice, 400)

        codice, _ = self._chiedi("GET", "/api/inesistente")
        self.assertEqual(codice, 404)

    def test_telecomando_risponde(self):
        codice, contenuto = self._chiedi("GET", "/api/stato")
        self.assertEqual(codice, 200)
        telecomando = json.loads(contenuto)["telecomando"]
        self.assertIn("disponibile", telecomando)
        self.assertEqual(len(telecomando["comandi"]), 4)

    def test_ricerca_bluetooth_risponde_con_garbo(self):
        _, contenuto = self._chiedi("GET", "/api/stato")
        bluetooth = json.loads(contenuto)["bluetooth"]
        self.assertIn("disponibile", bluetooth)
        self.assertIn("risultati", bluetooth)

        codice, corpo = self._chiedi("POST", "/api/bluetooth", {"azione": "cerca"})
        if bluetooth["disponibile"]:
            self.assertEqual(codice, 200)
        else:
            # senza il componente installato deve spiegarsi, non rompersi
            self.assertEqual(codice, 400)
            self.assertIn("errore", json.loads(corpo))

        codice, _ = self._chiedi("POST", "/api/bluetooth", {"azione": "boh"})
        self.assertEqual(codice, 400)

    def test_sonda_risponde_con_garbo(self):
        _, contenuto = self._chiedi("GET", "/api/stato")
        stato = json.loads(contenuto)
        self.assertIn("sonda", stato)
        self.assertIn("stato", stato["sonda"])

        # senza collegamento attivo la prova di scatto deve spiegarsi
        codice, corpo = self._chiedi("POST", "/api/bluetooth", {"azione": "sonda_scatto"})
        self.assertEqual(codice, 400)
        self.assertIn("errore", json.loads(corpo))

        # scollegare quando non c'è nulla non deve dare errore
        codice, _ = self._chiedi("POST", "/api/bluetooth", {"azione": "sonda_scollega"})
        self.assertEqual(codice, 200)


if __name__ == "__main__":
    unittest.main()
