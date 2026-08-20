# Driver Demo: una simulazione completa e credibile della telecamera.
# Batteria che si scarica, memoria che si riempie, file che compaiono dopo
# ogni scatto o registrazione. Serve a usare e provare tutto il programma
# anche senza la telecamera in mano.

import random
import threading
from datetime import datetime
from typing import Any, Dict, List, Optional

from ..registry import Telecamera
from .base import DriverTelecamera, ErroreTelecamera, adesso

# Consumo di batteria, in percentuale al minuto.
_CONSUMO_ACCESA = 0.15
_CONSUMO_IN_REGISTRAZIONE = 0.75


class DriverDemo(DriverTelecamera):

    def __init__(self, spec: Telecamera):
        super().__init__(spec)
        self._lock = threading.RLock()
        self._collegata = False
        self._batteria = float(spec.batteria_iniziale)
        self._memoria_usata_gb = 0.0
        self._modalita = spec.modalita[0].id
        self._risoluzioni = {m.id: m.risoluzioni[0] for m in spec.modalita}
        self._valori = {i.id: i.predefinita for i in spec.impostazioni}
        self._file: List[Dict[str, Any]] = []
        self._contatore_file = 0
        self._inizio_registrazione: Optional[float] = None
        self._ultimo_tic: Optional[float] = None
        self._autoscatto: Optional[threading.Timer] = None
        self._autoscatto_scade: Optional[float] = None
        self._semina_file()

    # ------------------------------------------------------------- interno

    def _semina_file(self) -> None:
        """Qualche file d'esempio, come su una telecamera già usata."""
        est_video = ".insv" if self.spec.tipo == "360" else ".mp4"
        est_foto = ".insp" if self.spec.tipo == "360" else ".jpg"
        base = datetime.now().strftime("%Y%m%d")
        esempi = [
            ("VID_{}_{:06d}{}".format(base, 101502, est_video), "video", 812.0, 95),
            ("IMG_{}_{:06d}{}".format(base, 103244, est_foto), "foto",
             self._peso_foto(), 0),
            ("VID_{}_{:06d}{}".format(base, 114820, est_video), "video", 1620.0, 210),
        ]
        for nome, tipo, mb, durata in esempi:
            self._file.append({"nome": nome, "tipo": tipo, "dimensione_mb": round(mb, 1),
                               "durata_s": durata,
                               "quando": datetime.now().strftime("%d/%m %H:%M")})
            self._memoria_usata_gb += mb / 1024.0
        self._contatore_file = 3

    def _modalita_attuale(self):
        m = self.spec.trova_modalita(self._modalita)
        assert m is not None
        return m

    def _peso_foto(self) -> float:
        for m in self.spec.modalita:
            if m.peso_foto_mb:
                return m.peso_foto_mb
        return 8.0

    def _tic(self) -> None:
        """Aggiorna batteria e memoria in base al tempo passato."""
        ora = adesso()
        if self._ultimo_tic is None or not self._collegata:
            self._ultimo_tic = ora
            return
        minuti = (ora - self._ultimo_tic) / 60.0
        self._ultimo_tic = ora
        consumo = _CONSUMO_IN_REGISTRAZIONE if self._inizio_registrazione else _CONSUMO_ACCESA
        self._batteria = max(0.0, self._batteria - minuti * consumo)
        if self._inizio_registrazione is not None:
            m = self._modalita_attuale()
            self._memoria_usata_gb += minuti * m.gb_al_minuto
            if self._memoria_libera_gb() <= 0:
                self._chiudi_registrazione(motivo="memoria esaurita")
            elif self._batteria <= 0.5:
                self._chiudi_registrazione(motivo="batteria scarica")

    def _memoria_libera_gb(self) -> float:
        return max(0.0, self.spec.memoria_totale_gb - self._memoria_usata_gb)

    def _controlla_collegata(self) -> None:
        if not self._collegata:
            raise ErroreTelecamera("La telecamera non è collegata: premi prima «Collega».")

    def _nuovo_file(self, tipo: str, mb: float, durata_s: int) -> Dict[str, Any]:
        self._contatore_file += 1
        if tipo == "foto":
            est = ".insp" if self.spec.tipo == "360" else ".jpg"
            nome = "IMG_{}_{:04d}{}".format(datetime.now().strftime("%Y%m%d"), self._contatore_file, est)
        else:
            est = ".insv" if self.spec.tipo == "360" else ".mp4"
            nome = "VID_{}_{:04d}{}".format(datetime.now().strftime("%Y%m%d"), self._contatore_file, est)
        voce = {"nome": nome, "tipo": tipo, "dimensione_mb": round(mb, 1),
                "durata_s": durata_s, "quando": datetime.now().strftime("%d/%m %H:%M")}
        self._file.insert(0, voce)
        self._memoria_usata_gb += mb / 1024.0
        return voce

    def _scatta_foto_adesso(self) -> None:
        m = self._modalita_attuale()
        quante = 15 if m.id == "burst" else 1
        mb = (m.peso_foto_mb or self._peso_foto()) * quante
        voce = self._nuovo_file("foto", mb, 0)
        self._autoscatto = None
        self._autoscatto_scade = None
        if quante > 1:
            self.registro.scrivi("Raffica scattata: %s (%d foto)" % (voce["nome"], quante))
        else:
            self.registro.scrivi("Foto scattata: " + voce["nome"])

    def _chiudi_registrazione(self, motivo: str = "") -> None:
        if self._inizio_registrazione is None:
            return
        durata = adesso() - self._inizio_registrazione
        self._inizio_registrazione = None
        m = self._modalita_attuale()
        mb = max(m.gb_al_minuto * 1024.0 * durata / 60.0, 4.0)
        voce = self._nuovo_file("video", mb, int(round(durata)))
        testo = "Registrazione salvata: %s (%d s)" % (voce["nome"], int(round(durata)))
        if motivo:
            testo += " — fermata: " + motivo
        self.registro.scrivi(testo)

    # ---------------------------------------------------------- collegamento

    def collega(self) -> None:
        with self._lock:
            if self._collegata:
                return
            self._collegata = True
            self._ultimo_tic = adesso()
            if self._batteria < 5:
                self._batteria = float(random.randint(60, 95))  # "l'hai ricaricata"
            self.registro.scrivi("Telecamera collegata (modalità demo).")

    def scollega(self) -> None:
        with self._lock:
            self._annulla_timer()
            self._chiudi_registrazione(motivo="telecamera scollegata")
            self._collegata = False
            self.registro.scrivi("Telecamera scollegata.")

    def spegni(self) -> None:
        with self._lock:
            self._controlla_collegata()
            self._annulla_timer()
            self._chiudi_registrazione(motivo="spegnimento")
            self._collegata = False
            self.registro.scrivi("Telecamera spenta.")

    # -------------------------------------------------------------- comandi

    def scatta(self) -> None:
        with self._lock:
            self._controlla_collegata()
            self._tic()
            m = self._modalita_attuale()
            if m.tipo == "foto":
                if self._autoscatto is not None:
                    raise ErroreTelecamera("C'è già un autoscatto in corso.")
                if self._memoria_libera_gb() <= 0.1:
                    raise ErroreTelecamera("Memoria piena: elimina qualche file.")
                secondi = {"3 s": 3, "10 s": 10}.get(self._valori.get("timer", "Off"), 0)
                if secondi:
                    self._autoscatto_scade = adesso() + secondi
                    self._autoscatto = threading.Timer(secondi, self._autoscatto_fine)
                    self._autoscatto.daemon = True
                    self._autoscatto.start()
                    self.registro.scrivi("Autoscatto avviato: %d secondi…" % secondi)
                else:
                    self._scatta_foto_adesso()
            else:
                if self._inizio_registrazione is not None:
                    self._chiudi_registrazione()
                else:
                    if self._memoria_libera_gb() <= 0.1:
                        raise ErroreTelecamera("Memoria piena: elimina qualche file.")
                    self._inizio_registrazione = adesso()
                    self.registro.scrivi("Registrazione avviata (%s, %s)."
                                         % (m.nome, self._risoluzioni[m.id]))

    def _autoscatto_fine(self) -> None:
        with self._lock:
            if self._autoscatto is None or not self._collegata:
                return
            self._scatta_foto_adesso()

    def annulla_autoscatto(self) -> None:
        with self._lock:
            if self._autoscatto is not None:
                self._annulla_timer()
                self.registro.scrivi("Autoscatto annullato.")

    def _annulla_timer(self) -> None:
        if self._autoscatto is not None:
            self._autoscatto.cancel()
            self._autoscatto = None
            self._autoscatto_scade = None

    def ferma_registrazione(self) -> None:
        with self._lock:
            self._controlla_collegata()
            if self._inizio_registrazione is None:
                raise ErroreTelecamera("Non c'è nessuna registrazione in corso.")
            self._tic()
            self._chiudi_registrazione()

    def imposta_modalita(self, id_modalita: str) -> None:
        with self._lock:
            self._controlla_collegata()
            m = self.spec.trova_modalita(id_modalita)
            if m is None:
                raise ErroreTelecamera("Modalità sconosciuta: " + id_modalita)
            if self._inizio_registrazione is not None:
                raise ErroreTelecamera("Ferma la registrazione prima di cambiare modalità.")
            self._annulla_timer()
            self._modalita = id_modalita
            self.registro.scrivi("Modalità: " + m.nome)

    def imposta_risoluzione(self, valore: str) -> None:
        with self._lock:
            self._controlla_collegata()
            m = self._modalita_attuale()
            if valore not in m.risoluzioni:
                raise ErroreTelecamera("Risoluzione non disponibile in questa modalità.")
            self._risoluzioni[m.id] = valore
            self.registro.scrivi("Risoluzione %s: %s" % (m.nome, valore))

    def imposta(self, id_impostazione: str, valore: str) -> None:
        with self._lock:
            self._controlla_collegata()
            imp = self.spec.trova_impostazione(id_impostazione)
            if imp is None:
                raise ErroreTelecamera("Impostazione sconosciuta: " + id_impostazione)
            if valore not in imp.opzioni:
                raise ErroreTelecamera("Valore non valido per «%s»." % imp.nome)
            self._valori[id_impostazione] = valore
            self.registro.scrivi("%s → %s" % (imp.nome, valore))

    def elimina_file(self, nome: str) -> None:
        with self._lock:
            self._controlla_collegata()
            for voce in self._file:
                if voce["nome"] == nome:
                    self._file.remove(voce)
                    self._memoria_usata_gb = max(
                        0.0, self._memoria_usata_gb - voce["dimensione_mb"] / 1024.0)
                    self.registro.scrivi("File eliminato: " + nome)
                    return
            raise ErroreTelecamera("File non trovato: " + nome)

    # ---------------------------------------------------------------- stato

    def stato(self) -> Dict[str, Any]:
        with self._lock:
            self._tic()
            durata = None
            if self._inizio_registrazione is not None:
                durata = adesso() - self._inizio_registrazione
            autoscatto_fra = None
            if self._autoscatto_scade is not None:
                autoscatto_fra = max(0.0, self._autoscatto_scade - adesso())
            m = self._modalita_attuale()
            return {
                "collegata": self._collegata,
                "metodo": "demo",
                "batteria": int(round(self._batteria)),
                "memoria_libera_gb": round(self._memoria_libera_gb(), 3),
                "memoria_totale_gb": self.spec.memoria_totale_gb,
                "modalita": self._modalita,
                "tipo_modalita": m.tipo,
                "risoluzione": self._risoluzioni[self._modalita],
                "in_registrazione": self._inizio_registrazione is not None,
                "durata_registrazione": durata,
                "autoscatto_fra": autoscatto_fra,
                "valori": dict(self._valori),
                "file": [dict(v) for v in self._file],
            }
