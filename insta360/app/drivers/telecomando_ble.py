# Telecomando Bluetooth virtuale (SPERIMENTALE).
#
# Il computer si finge un telecomando "Insta360 GPS Remote": la telecamera
# lo cerca dal suo menù (Impostazioni → Telecomando), si abbina e da quel
# momento riceve i quattro comandi del telecomando vero: scatto, cambio
# modalità, schermo e spegnimento. Funziona con GO 3S, Ace Pro 2 e X6,
# perché tutte e tre supportano il telecomando GPS ufficiale.
#
# Il protocollo (servizio CE80, comandi FC EF FE 86 …) viene dal lavoro
# della community, in particolare dal progetto open source
# https://github.com/pchwalek/insta360_ble_esp32 (licenza MIT).
#
# Richiede il pacchetto facoltativo "bless" (vedi requirements-bluetooth.txt).
# Senza bless il programma funziona lo stesso: questo pannello risulterà
# semplicemente "non installato".

import asyncio
import threading
from typing import Any, Dict, Optional

from .base import Registro

try:
    from bless import (BlessServer, GATTAttributePermissions,
                       GATTCharacteristicProperties)
    DISPONIBILE = True
    MOTIVO_ASSENZA = ""
except Exception as exc:  # pragma: no cover - dipende dal sistema
    BlessServer = None
    DISPONIBILE = False
    MOTIVO_ASSENZA = str(exc)

NOME_TELECOMANDO = "Insta360 GPS Remote"

_BASE = "0000{}-0000-1000-8000-00805f9b34fb"
SERVIZIO_PRINCIPALE = _BASE.format("ce80")
CAR_SCRITTURA_CAMERA = _BASE.format("ce81")   # la telecamera scrive qui
CAR_COMANDI = _BASE.format("ce82")            # noi notifichiamo i comandi qui
CAR_IDENTITA = _BASE.format("ce83")           # il telecomando risponde 02 01
SERVIZIO_SECONDARIO = "0000d0ff-3c17-d293-8e48-14fe2e4da212"
CAR_SECONDARIE = [_BASE.format(s) for s in
                  ("ffd1", "ffd2", "ffd3", "ffd4", "ffd5", "ffd8", "fff1", "fff2", "ffe0")]

# I quattro pulsanti del telecomando GPS, come sequenze di byte.
COMANDI = {
    "scatto":   bytes([0xFC, 0xEF, 0xFE, 0x86, 0x00, 0x03, 0x01, 0x02, 0x00]),
    "modalita": bytes([0xFC, 0xEF, 0xFE, 0x86, 0x00, 0x03, 0x01, 0x01, 0x00]),
    "schermo":  bytes([0xFC, 0xEF, 0xFE, 0x86, 0x00, 0x03, 0x01, 0x00, 0x00]),
    "spegni":   bytes([0xFC, 0xEF, 0xFE, 0x86, 0x00, 0x03, 0x01, 0x00, 0x03]),
}

NOMI_COMANDI = {
    "scatto": "Scatto / avvia-ferma registrazione",
    "modalita": "Cambio modalità",
    "schermo": "Schermo acceso/spento",
    "spegni": "Spegnimento telecamera",
}


class TelecomandoVirtuale:
    """Gestisce il server Bluetooth in un suo thread dedicato."""

    def __init__(self):
        self.registro = Registro()
        self._lock = threading.Lock()
        self._stato = "spento"          # spento | avvio | attivo | errore
        self._errore = ""
        self._camera_viva = False       # la telecamera ha scritto qualcosa
        self._loop: Optional[asyncio.AbstractEventLoop] = None
        self._server = None
        self._thread: Optional[threading.Thread] = None

    # ------------------------------------------------------------ controllo

    def avvia(self) -> None:
        with self._lock:
            if not DISPONIBILE:
                raise RuntimeError("Componente Bluetooth non installato.")
            if self._stato in ("avvio", "attivo"):
                return
            self._stato = "avvio"
            self._errore = ""
            self._camera_viva = False
            self._thread = threading.Thread(target=self._esegui, daemon=True,
                                            name="telecomando-ble")
            self._thread.start()
        self.registro.scrivi("Avvio del telecomando virtuale…")

    def ferma(self) -> None:
        with self._lock:
            loop, server = self._loop, self._server
            if self._stato not in ("attivo", "avvio") or loop is None:
                self._stato = "spento"
                return
        try:
            asyncio.run_coroutine_threadsafe(self._spegni_server(), loop).result(timeout=8)
        except Exception:
            pass
        with self._lock:
            self._stato = "spento"
            self._camera_viva = False
        self.registro.scrivi("Telecomando virtuale fermato.")

    def invia(self, comando: str) -> None:
        if comando not in COMANDI:
            raise RuntimeError("Comando sconosciuto: " + comando)
        with self._lock:
            loop = self._loop
            if self._stato != "attivo" or loop is None:
                raise RuntimeError("Il telecomando non è attivo: premi prima «Accendi».")
        loop.call_soon_threadsafe(self._notifica, COMANDI[comando])
        self.registro.scrivi("Inviato: " + NOMI_COMANDI[comando])

    # -------------------------------------------------------------- interno

    def _esegui(self) -> None:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        with self._lock:
            self._loop = loop
        try:
            loop.run_until_complete(self._prepara_server(loop))
            with self._lock:
                self._stato = "attivo"
            self.registro.scrivi("Telecomando attivo: ora cercalo dalla telecamera "
                                 "(Impostazioni → Telecomando).")
            loop.run_forever()
        except Exception as exc:
            with self._lock:
                self._stato = "errore"
                self._errore = str(exc)
            self.registro.scrivi("Errore Bluetooth: " + str(exc))
        finally:
            try:
                loop.close()
            except Exception:
                pass
            with self._lock:
                self._loop = None
                self._server = None
                if self._stato == "attivo":
                    self._stato = "spento"

    async def _prepara_server(self, loop) -> None:
        server = BlessServer(name=NOME_TELECOMANDO, loop=loop)
        server.read_request_func = self._su_lettura
        server.write_request_func = self._su_scrittura

        scrivibile = (GATTCharacteristicProperties.write |
                      GATTCharacteristicProperties.write_without_response)
        await server.add_new_service(SERVIZIO_PRINCIPALE)
        await server.add_new_characteristic(
            SERVIZIO_PRINCIPALE, CAR_SCRITTURA_CAMERA, scrivibile,
            bytearray(b"\x00"), GATTAttributePermissions.writeable)
        await server.add_new_characteristic(
            SERVIZIO_PRINCIPALE, CAR_COMANDI,
            (GATTCharacteristicProperties.read |
             GATTCharacteristicProperties.notify |
             GATTCharacteristicProperties.indicate),
            bytearray(b"\x00"), GATTAttributePermissions.readable)
        await server.add_new_characteristic(
            SERVIZIO_PRINCIPALE, CAR_IDENTITA,
            GATTCharacteristicProperties.read,
            bytearray(b"\x02\x01"), GATTAttributePermissions.readable)

        # Servizio secondario presente sul telecomando vero: lo esponiamo
        # con valori neutri per assomigliargli il più possibile.
        await server.add_new_service(SERVIZIO_SECONDARIO)
        for uuid in CAR_SECONDARIE:
            await server.add_new_characteristic(
                SERVIZIO_SECONDARIO, uuid,
                (GATTCharacteristicProperties.read | scrivibile),
                bytearray(b"\x00"),
                (GATTAttributePermissions.readable | GATTAttributePermissions.writeable))

        await server.start()
        with self._lock:
            self._server = server

    async def _spegni_server(self) -> None:
        server = self._server
        if server is not None:
            try:
                await server.stop()
            except Exception:
                pass
        loop = asyncio.get_event_loop()
        loop.stop()

    def _notifica(self, dati: bytes) -> None:
        server = self._server
        if server is None:
            return
        try:
            car = server.get_characteristic(CAR_COMANDI)
            car.value = bytearray(dati)
            server.update_value(SERVIZIO_PRINCIPALE, CAR_COMANDI)
        except Exception as exc:
            self.registro.scrivi("Invio non riuscito: " + str(exc))

    def _su_lettura(self, characteristic, **kwargs):
        return characteristic.value

    def _su_scrittura(self, characteristic, value, **kwargs):
        characteristic.value = value
        if not self._camera_viva:
            self._camera_viva = True
            self.registro.scrivi("Una telecamera si è collegata al telecomando!")

    # ---------------------------------------------------------------- stato

    def stato(self) -> Dict[str, Any]:
        with self._lock:
            return {
                "disponibile": DISPONIBILE,
                "motivo_assenza": MOTIVO_ASSENZA,
                "stato": self._stato,
                "errore": self._errore,
                "camera_collegata": self._camera_viva,
                "nome": NOME_TELECOMANDO,
                "comandi": [{"id": c, "nome": NOMI_COMANDI[c]} for c in COMANDI],
                "registro": self.registro.voci(8),
            }
