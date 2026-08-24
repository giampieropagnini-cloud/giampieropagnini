# Il "regista" del programma: tiene insieme le tre telecamere, i loro
# driver e il telecomando Bluetooth, e prepara lo stato completo che
# l'interfaccia web chiede una volta al secondo.

from typing import Any, Dict

from . import VERSIONE
from .drivers.base import ErroreTelecamera
from .drivers.demo import DriverDemo
from .drivers.ricerca_ble import RicercaBluetooth
from .drivers.sonda_ble import SondaBluetooth
from .drivers.telecomando_ble import TelecomandoVirtuale
from .registry import TELECAMERE


class Controller:

    def __init__(self):
        self.driver = {id_t: DriverDemo(spec) for id_t, spec in TELECAMERE.items()}
        self.telecomando = TelecomandoVirtuale()
        self.ricerca = RicercaBluetooth()
        self.sonda = SondaBluetooth()

    # -------------------------------------------------------------- comandi

    def azione_telecamera(self, id_telecamera: str, dati: Dict[str, Any]) -> None:
        if id_telecamera not in self.driver:
            raise ErroreTelecamera("Telecamera sconosciuta: " + id_telecamera)
        d = self.driver[id_telecamera]
        azione = dati.get("azione", "")
        if azione == "collega":
            d.collega()
        elif azione == "scollega":
            d.scollega()
        elif azione == "spegni":
            d.spegni()
        elif azione == "scatta":
            d.scatta()
        elif azione == "ferma":
            d.ferma_registrazione()
        elif azione == "annulla_autoscatto":
            d.annulla_autoscatto()
        elif azione == "modalita":
            d.imposta_modalita(str(dati.get("valore", "")))
        elif azione == "risoluzione":
            d.imposta_risoluzione(str(dati.get("valore", "")))
        elif azione == "impostazione":
            d.imposta(str(dati.get("chiave", "")), str(dati.get("valore", "")))
        elif azione == "elimina_file":
            d.elimina_file(str(dati.get("nome", "")))
        else:
            raise ErroreTelecamera("Azione sconosciuta: " + azione)

    def azione_telecomando(self, dati: Dict[str, Any]) -> None:
        azione = dati.get("azione", "")
        try:
            if azione == "accendi":
                self.telecomando.avvia()
            elif azione == "ferma":
                self.telecomando.ferma()
            elif azione == "comando":
                self.telecomando.invia(str(dati.get("comando", "")))
            else:
                raise ErroreTelecamera("Azione sconosciuta: " + azione)
        except RuntimeError as exc:
            raise ErroreTelecamera(str(exc))

    def azione_bluetooth(self, dati: Dict[str, Any]) -> None:
        azione = dati.get("azione", "")
        try:
            if azione == "cerca":
                self.ricerca.avvia()
            elif azione == "sonda":
                self.sonda.collega(str(dati.get("indirizzo", "")), str(dati.get("nome", "")))
            elif azione == "sonda_scollega":
                self.sonda.scollega()
            elif azione == "sonda_comando":
                self.sonda.prova_comando(str(dati.get("comando", "scatto")),
                                         str(dati.get("canale", "")))
            else:
                raise ErroreTelecamera("Azione sconosciuta: " + azione)
        except RuntimeError as exc:
            raise ErroreTelecamera(str(exc))

    # ---------------------------------------------------------------- stato

    def stato(self) -> Dict[str, Any]:
        telecamere = []
        for id_t, spec in TELECAMERE.items():
            d = self.driver[id_t]
            telecamere.append({
                "id": spec.id,
                "nome": spec.nome,
                "sottotitolo": spec.sottotitolo,
                "tipo": spec.tipo,
                "colore": spec.colore,
                "chips": list(spec.chips),
                "modalita_disponibili": [
                    {"id": m.id, "nome": m.nome, "tipo": m.tipo,
                     "risoluzioni": list(m.risoluzioni)}
                    for m in spec.modalita],
                "impostazioni_disponibili": [
                    {"id": i.id, "nome": i.nome, "opzioni": list(i.opzioni)}
                    for i in spec.impostazioni],
                "stato": d.stato(),
                "registro": d.registro.voci(8),
            })
        return {
            "versione": VERSIONE,
            "telecamere": telecamere,
            "telecomando": self.telecomando.stato(),
            "bluetooth": self.ricerca.stato(),
            "sonda": self.sonda.stato(),
        }
