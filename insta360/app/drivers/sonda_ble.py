# Sonda Bluetooth: il programma si collega LUI alla telecamera (come fa il
# telecomando GPS vero), ne fotografa tutti i "canali" Bluetooth e prova a
# inviare il comando di scatto documentato dalla community su OGNI canale
# scrivibile, registrando cosa succede. È soprattutto uno strumento
# DIAGNOSTICO: il suo scopo è mostrarci come sono fatte davvero queste
# telecamere, così i comandi si possono tarare sul campo.
#
# Fonti del protocollo Bluetooth:
#   - https://github.com/pchwalek/insta360_ble_esp32  (servizio ce80,
#     canali ce81/ce82/ce83; comando scatto FC EF FE 86 00 03 01 02 00)
#   - esempio ESPHome di btittelbach (stessi comandi)
# Richiede il pacchetto facoltativo "bleak".

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
CAR_RISPOSTE = _BASE.format("ce82")     # canale delle notifiche (dal remoto)
CAR_RISPOSTE_ALT = _BASE.format("be82")

# I quattro comandi del telecomando GPS, nel formato Bluetooth vero.
COMANDI = {
    "scatto":   bytes([0xFC, 0xEF, 0xFE, 0x86, 0x00, 0x03, 0x01, 0x02, 0x00]),
    "modalita": bytes([0xFC, 0xEF, 0xFE, 0x86, 0x00, 0x03, 0x01, 0x01, 0x00]),
    "schermo":  bytes([0xFC, 0xEF, 0xFE, 0x86, 0x00, 0x03, 0x01, 0x00, 0x00]),
    "spegni":   bytes([0xFC, 0xEF, 0xFE, 0x86, 0x00, 0x03, 0x01, 0x00, 0x03]),
}

_MASSIMO_DETTAGLI = 80


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
        self._scrivibili: List[str] = []       # UUID dei canali su cui si può scrivere
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
            self._scrivibili = []
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

    def prova_comando(self, comando: str) -> None:
        if comando not in COMANDI:
            raise RuntimeError("Comando sconosciuto: " + comando)
        with self._lock:
            loop = self._loop
            if self._stato != "collegata" or loop is None:
                raise RuntimeError("Prima collegati a una telecamera.")
            if not self._scrivibili:
                raise RuntimeError("Questa telecamera non espone canali scrivibili: "
                                   "mandami la diagnostica con «Copia per Claude».")
        asyncio.run_coroutine_threadsafe(self._invia_su_tutti(comando), loop)
        self.registro.scrivi("Provo «%s» su tutti i canali scrivibili: guarda la telecamera!"
                             % comando)

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
            loop.run_forever()
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

        self._annota("Telecamera: %s  [%s]" % (self._nome, self._indirizzo))
        scrivibili: List[str] = []
        canali_notifica: List[str] = []
        for servizio in client.services:
            self._annota("Servizio " + str(servizio.uuid).lower())
            for car in servizio.characteristics:
                uuid_c = str(car.uuid).lower()
                proprieta = ",".join(car.properties)
                self._annota("   canale %s  (%s)" % (uuid_c, proprieta))
                if "write" in car.properties or "write-without-response" in car.properties:
                    scrivibili.append(uuid_c)
                if "notify" in car.properties or "indicate" in car.properties:
                    canali_notifica.append(uuid_c)

        with self._lock:
            self._scrivibili = scrivibili

        # mettiamoci in ascolto su tutti i canali che sanno notificare
        for uuid_c in canali_notifica:
            def su_notifica(_car, dati: bytearray, _u=uuid_c):
                self._annota("Risposta da %s: %s" % (_u, bytes(dati).hex(" ")))
                self.registro.scrivi("La telecamera ha risposto su %s (%d byte)!"
                                     % (_u, len(dati)))
            try:
                await client.start_notify(uuid_c, su_notifica)
            except Exception:
                pass
        if canali_notifica:
            self._annota("· in ascolto su: " + ", ".join(canali_notifica))

        self._annota("· canali scrivibili trovati: " +
                     (", ".join(scrivibili) if scrivibili else "NESSUNO"))

        with self._lock:
            self._stato = "collegata"
        if scrivibili:
            self.registro.scrivi("Collegata! %d canali scrivibili: puoi provare i comandi."
                                 % len(scrivibili))
        else:
            self.registro.scrivi("Collegata, ma nessun canale scrivibile: "
                                 "mandami la diagnostica con «Copia per Claude».")

    async def _invia_su_tutti(self, comando: str) -> None:
        client = self._client
        if client is None:
            return
        dati = COMANDI[comando]
        with self._lock:
            canali = list(self._scrivibili)
        for uuid_c in canali:
            car = client.services.get_characteristic(uuid_c)
            if car is None:
                continue
            senza_risposta = ("write-without-response" in car.properties
                              and "write" not in car.properties)
            try:
                await client.write_gatt_char(uuid_c, dati, response=not senza_risposta)
                self._annota("→ inviato «%s» su %s: %s" % (comando, uuid_c, dati.hex(" ")))
            except Exception as exc:
                self._annota("→ %s ha rifiutato: %s" % (uuid_c, str(exc)))
            await asyncio.sleep(0.6)
        self.registro.scrivi("Comando «%s» inviato su tutti i canali. Reazioni nella diagnostica."
                             % comando)

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

    def _testo_diagnostica(self) -> str:
        # va chiamata col lucchetto già preso
        righe = ["=== Diagnostica Insta360 — Controllo Telecamere ===",
                 "Telecamera: %s" % (self._nome or "?"),
                 "Stato: %s" % self._stato]
        if self._errore:
            righe.append("Errore: " + self._errore)
        righe.append("")
        righe.extend(self._dettagli)
        return "\n".join(righe)

    def stato(self) -> Dict[str, Any]:
        with self._lock:
            return {
                "disponibile": DISPONIBILE,
                "stato": self._stato,
                "errore": self._errore,
                "nome": self._nome,
                "scrivibili": list(self._scrivibili),
                "dettagli": list(self._dettagli),
                "diagnostica": self._testo_diagnostica(),
                "registro": self.registro.voci(6),
            }
