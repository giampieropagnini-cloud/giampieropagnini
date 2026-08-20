# Base comune dei "driver": il pezzo di programma che parla con una
# telecamera. Oggi c'è il driver Demo (simulazione completa) e il
# telecomando Bluetooth virtuale; l'interfaccia resta la stessa, così un
# domani si può aggiungere il driver Wi-Fi o quello dell'SDK ufficiale
# senza toccare il resto del programma.

import threading
import time
from datetime import datetime
from typing import Any, Dict, List


class ErroreTelecamera(Exception):
    """Errore da mostrare all'utente (in italiano)."""


class Registro:
    """Piccolo diario degli eventi, con orario."""

    def __init__(self, massimo: int = 60):
        self._voci: List[Dict[str, str]] = []
        self._massimo = massimo
        self._lock = threading.Lock()

    def scrivi(self, testo: str) -> None:
        with self._lock:
            self._voci.append({"ora": datetime.now().strftime("%H:%M:%S"), "testo": testo})
            del self._voci[:-self._massimo]

    def voci(self, quante: int = 12) -> List[Dict[str, str]]:
        with self._lock:
            return list(self._voci[-quante:])


class DriverTelecamera:
    """Interfaccia comune a tutti i driver."""

    def __init__(self, spec):
        self.spec = spec
        self.registro = Registro()

    # -- collegamento -------------------------------------------------------
    def collega(self) -> None: raise NotImplementedError
    def scollega(self) -> None: raise NotImplementedError
    def spegni(self) -> None: raise NotImplementedError

    # -- comandi ------------------------------------------------------------
    def scatta(self) -> None: raise NotImplementedError
    def ferma_registrazione(self) -> None: raise NotImplementedError
    def imposta_modalita(self, id_modalita: str) -> None: raise NotImplementedError
    def imposta_risoluzione(self, valore: str) -> None: raise NotImplementedError
    def imposta(self, id_impostazione: str, valore: str) -> None: raise NotImplementedError
    def elimina_file(self, nome: str) -> None: raise NotImplementedError
    def annulla_autoscatto(self) -> None: raise NotImplementedError

    # -- stato --------------------------------------------------------------
    def stato(self) -> Dict[str, Any]: raise NotImplementedError


def adesso() -> float:
    return time.monotonic()
