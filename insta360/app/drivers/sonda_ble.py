# Sonda Bluetooth: il programma si collega LUI alla telecamera, come fa il
# telecomando GPS ufficiale (è il telecomando che cerca la telecamera, non
# il contrario). Una volta collegata:
#   - fotografa l'elenco dei "canali" Bluetooth della telecamera (diagnostica),
#   - si mette in ascolto sul canale delle risposte (be82),
#   - può tentare uno scatto sperimentale sul canale dei comandi (be81).
#
# Il formato dei comandi viene dal lavoro della community:
#   - https://github.com/RigacciOrg/insta360-wifi-api (codici comando e
#     intestazioni dei messaggi, protocollo Wi-Fi della ONE RS)
#   - il progetto "Insta360 X3 BLE remote control with ESP32" su hackaday.io
#     (stesso servizio be80/be81/be82 via Bluetooth, messaggi spezzati in
#     blocchi da 20 byte)
# Sui modelli nuovi non è garantito: per questo è una SONDA — ogni risposta
# della telecamera finisce nel registro, così si può aggiustare il tiro.

import asyncio
import threading
from typing import Any, Dict, List, Optional

from .base import Registro, spiega_errore_bluetooth

try:
    from bleak import BleakClient
    DISPONIBILE = True
    MOTIVO_ASSENZA = ""
except Exception as exc:  # pragma: no cover - dipende dal sistema
    BleakClient = None
    DISPONIBILE = False
    MOTIVO_ASSENZA = str(exc)

_BASE = "0000{}-0000-1000-8000-00805f9b34fb"
CAR_COMANDI = _BASE.format("be81")     # noi scriviamo qui
CAR_RISPOSTE = _BASE.format("be82")    # la telecamera risponde qui

# Codici comando del protocollo Insta360 (dal progetto insta360-wifi-api).
CODICE_SCATTA_FOTO = 3
CODICE_AVVIA_VIDEO = 4
CODICE_FERMA_VIDEO = 5
CODICE_STATO_ATTUALE = 15

_MASSIMO_DETTAGLI = 40


def _frame(codice: int, seq: int = 1) -> bytes:
    """Messaggio nel formato documentato: prefisso di lunghezza (4 byte)
    + intestazione da 12 byte. Per questi comandi il corpo può restare vuoto."""
    testata = (b"\x04\x00\x00"
               + codice.to_bytes(2, "little")
               + b"\x02"
               + seq.to_bytes(3, "little")
               + b"\x80\x00\x00")
    return len(testata).to_bytes(4, "little") + testata


def _in_blocchi(dati: bytes, dimensione: int = 20) -> List[bytes]:
    return [dati[i:i + dimensione] for i in range(0, len(dati), dimensione)]


class SondaBluetooth:
    """Collegamento diretto Mac → telecamera, in un thread dedicato."""

    def __init__(self):
        self.registro = Registro()
        self._lock = threading.Lock()
        self._stato = "inattiva"      # inattiva | connessione | collegata | errore
        self._errore = ""
        self._nome = ""
        self._indirizzo = ""
        self._dettagli: List[str] = []
        self._ha_canale_comandi = False
        self._sequenza = 0
        self._loop: Optional[asyncio.AbstractEventLoop] = None
        self._client = None

    # ------------------------------------------------------------- comandi

    def collega(self, indirizzo: str, nome: str) -> None:
        if not DISPONIBILE:
            raise RuntimeError("Componente Bluetooth non installato.")
        if not indirizzo:
            raise RuntimeError("Manca l'indirizzo della telecamera: prima fai una ricerca.")
        with self._lock:
            if self._stato in ("connessione", "collegata"):
                raise RuntimeError("C'è già un collegamento in corso: scollega prima.")
            self._stato = "connessione"
            self._errore = ""
            self._nome = nome or indirizzo
            self._indirizzo = indirizzo
            self._dettagli = []
            self._ha_canale_comandi = False
        thread = threading.Thread(target=self._esegui, daemon=True, name="sonda-ble")
        thread.start()
        self.registro.scrivi("Mi collego a «%s»…" % self._nome)

    def scollega(self) -> None:
        with self._lock:
            loop = self._loop
        if loop is not None:
            try:
                asyncio.run_coroutine_threadsafe(self._chiudi(), loop).result(timeout=10)
            except Exception:
                pass
        with self._lock:
            if self._stato != "errore":
                self._stato = "inattiva"

    def prova_scatto(self) -> None:
        with self._lock:
            loop = self._loop
            if self._stato != "collegata" or loop is None:
                raise RuntimeError("Prima collegati a una telecamera.")
            if not self._ha_canale_comandi:
                raise RuntimeError("Questa telecamera non mostra il canale comandi (be81): "
                                   "mandami il contenuto della diagnostica.")
        asyncio.run_coroutine_threadsafe(self._invia_scatto(), loop)
        self.registro.scrivi("Prova di scatto inviata: guarda la telecamera!")

    # -------------------------------------------------------------- interno

    def _annota(self, testo: str) -> None:
        with self._lock:
            self._dettagli.append(testo)
            del self._dettagli[:-_MASSIMO_DETTAGLI]

    def _esegui(self) -> None:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        with self._lock:
            self._loop = loop
        try:
            loop.run_until_complete(self._collega_davvero())
            loop.run_forever()   # resta in ascolto finché non si scollega
        except Exception as exc:
            spiegazione = spiega_errore_bluetooth(str(exc) or repr(exc))
            with self._lock:
                self._stato = "errore"
                self._errore = spiegazione
            self.registro.scrivi("Collegamento non riuscito: " + spiegazione)
        finally:
            try:
                loop.close()
            except Exception:
                pass
            with self._lock:
                self._loop = None
                self._client = None
                if self._stato == "collegata":
                    self._stato = "inattiva"

    async def _collega_davvero(self) -> None:
        def su_disconnessione(_client):
            self.registro.scrivi("La telecamera si è scollegata.")
            self._annota("· collegamento chiuso dalla telecamera")
            with self._lock:
                if self._stato == "collegata":
                    self._stato = "inattiva"
                loop = self._loop
            if loop is not None:
                loop.call_soon_threadsafe(loop.stop)

        client = BleakClient(self._indirizzo, timeout=20,
                             disconnected_callback=su_disconnessione)
        await client.connect()
        with self._lock:
            self._client = client

        self._annota("Collegata a: " + self._nome)
        trovato_be82 = False
        for servizio in client.services:
            uuid_s = str(servizio.uuid).lower()
            self._annota("Servizio " + uuid_s)
            for car in servizio.characteristics:
                uuid_c = str(car.uuid).lower()
                proprieta = ",".join(car.properties)
                self._annota("   canale %s (%s)" % (uuid_c, proprieta))
                if uuid_c == CAR_COMANDI:
                    with self._lock:
                        self._ha_canale_comandi = True
                if uuid_c == CAR_RISPOSTE:
                    trovato_be82 = True

        if trovato_be82:
            def su_risposta(_car, dati: bytearray):
                self._annota("Risposta della telecamera: " + bytes(dati).hex(" "))
                self.registro.scrivi("La telecamera ha risposto! (%d byte)" % len(dati))
            try:
                await client.start_notify(CAR_RISPOSTE, su_risposta)
                self._annota("· in ascolto sul canale risposte (be82)")
            except Exception as exc:
                self._annota("· ascolto su be82 non riuscito: " + str(exc))

        with self._lock:
            ok = self._ha_canale_comandi
            self._stato = "collegata"
        if ok:
            self.registro.scrivi("Collegata! Canale comandi trovato: puoi provare lo scatto.")
        else:
            self.registro.scrivi("Collegata, ma senza il canale comandi noto: "
                                 "mandami la diagnostica in chat.")

    async def _invia_scatto(self) -> None:
        client = self._client
        if client is None:
            return
        try:
            car = client.services.get_characteristic(CAR_COMANDI)
            senza_risposta = car is not None and "write-without-response" in car.properties \
                and "write" not in car.properties
            with self._lock:
                self._sequenza += 1
                seq = self._sequenza
            grezzo = _frame(CODICE_SCATTA_FOTO, seq)
            # Variante A: messaggio così com'è. Variante B: con davanti un byte
            # di lunghezza totale (le due forme viste nei progetti community).
            for etichetta, messaggio in (("A", grezzo),
                                         ("B", bytes([len(grezzo) + 1]) + grezzo)):
                for blocco in _in_blocchi(messaggio):
                    await client.write_gatt_char(CAR_COMANDI, blocco,
                                                 response=not senza_risposta)
                self._annota("Inviato scatto variante %s: %s" % (etichetta, messaggio.hex(" ")))
                await asyncio.sleep(1.2)
        except Exception as exc:
            self._annota("Invio non riuscito: " + str(exc))
            self.registro.scrivi("Invio non riuscito: " + str(exc))

    async def _chiudi(self) -> None:
        client = self._client
        if client is not None:
            try:
                await client.disconnect()
            except Exception:
                pass
        loop = asyncio.get_event_loop()
        loop.stop()

    # ---------------------------------------------------------------- stato

    def stato(self) -> Dict[str, Any]:
        with self._lock:
            return {
                "disponibile": DISPONIBILE,
                "stato": self._stato,
                "errore": self._errore,
                "nome": self._nome,
                "canale_comandi": self._ha_canale_comandi,
                "dettagli": list(self._dettagli),
                "registro": self.registro.voci(6),
            }
