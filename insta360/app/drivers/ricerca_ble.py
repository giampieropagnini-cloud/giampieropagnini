# Ricerca Bluetooth: guarda quali apparecchi Bluetooth LE ci sono intorno
# al computer e segnala quelli che sembrano telecamere Insta360. Serve come
# prova del nove: se la tua telecamera accesa compare qui, il Bluetooth del
# Mac la sente e si può passare al telecomando virtuale.
#
# Richiede il pacchetto facoltativo "bleak" (installato insieme a "bless"
# dal componente Bluetooth). Senza, il pannello risulta "non installato".

import asyncio
import threading
from datetime import datetime
from typing import Any, Dict, List

from .base import Registro, spiega_errore_bluetooth

try:
    from bleak import BleakScanner
    DISPONIBILE = True
    MOTIVO_ASSENZA = ""
except Exception as exc:  # pragma: no cover - dipende dal sistema
    BleakScanner = None
    DISPONIBILE = False
    MOTIVO_ASSENZA = str(exc)

# Parole che fanno pensare a una Insta360 nel nome Bluetooth.
_PAROLE_INSTA = ("insta", "osc", "x6", "x5", "x4", "x3", "ace", "go 3", "go3", "one r")

DURATA_RICERCA = 6  # secondi


class RicercaBluetooth:

    def __init__(self):
        self.registro = Registro()
        self._lock = threading.Lock()
        self._in_corso = False
        self._errore = ""
        self._risultati: List[Dict[str, Any]] = []
        self._quando = ""

    def avvia(self) -> None:
        if not DISPONIBILE:
            raise RuntimeError("Componente Bluetooth non installato.")
        with self._lock:
            if self._in_corso:
                return
            self._in_corso = True
            self._errore = ""
        thread = threading.Thread(target=self._esegui, daemon=True, name="ricerca-ble")
        thread.start()
        self.registro.scrivi("Ricerca avviata (%d secondi)…" % DURATA_RICERCA)

    # -------------------------------------------------------------- interno

    def _esegui(self) -> None:
        try:
            trovati = asyncio.run(self._scansiona())
            with self._lock:
                self._risultati = trovati
                self._quando = datetime.now().strftime("%H:%M:%S")
            insta = sum(1 for d in trovati if d["insta"])
            if insta:
                self.registro.scrivi("Trovati %d apparecchi, di cui %d sembrano Insta360!"
                                     % (len(trovati), insta))
            else:
                self.registro.scrivi("Trovati %d apparecchi Bluetooth, nessuna Insta360 "
                                     "riconosciuta dal nome." % len(trovati))
        except Exception as exc:
            with self._lock:
                self._errore = spiega_errore_bluetooth(str(exc))
            self.registro.scrivi("Ricerca non riuscita: " + self._errore)
        finally:
            with self._lock:
                self._in_corso = False

    async def _scansiona(self) -> List[Dict[str, Any]]:
        dispositivi = await BleakScanner.discover(timeout=DURATA_RICERCA, return_adv=True)
        trovati = []
        for indirizzo, (device, annuncio) in dispositivi.items():
            nome = device.name or annuncio.local_name or ""
            rssi = getattr(annuncio, "rssi", None)
            trovati.append({
                "nome": nome or "(senza nome)",
                "indirizzo": str(indirizzo),
                "segnale": rssi,
                "insta": any(p in nome.lower() for p in _PAROLE_INSTA) if nome else False,
            })
        # prima le Insta360, poi per forza del segnale
        trovati.sort(key=lambda d: (not d["insta"], -(d["segnale"] or -999)))
        return trovati[:25]

    # ---------------------------------------------------------------- stato

    def stato(self) -> Dict[str, Any]:
        with self._lock:
            return {
                "disponibile": DISPONIBILE,
                "motivo_assenza": MOTIVO_ASSENZA,
                "in_corso": self._in_corso,
                "errore": self._errore,
                "quando": self._quando,
                "risultati": [dict(d) for d in self._risultati],
                "registro": self.registro.voci(4),
            }
