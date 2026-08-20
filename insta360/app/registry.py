# Il catalogo delle telecamere: modalità, risoluzioni e impostazioni di
# ciascun modello. I valori rispecchiano le schede tecniche reali ma servono
# alla simulazione: quando una telecamera è collegata per davvero, comanda
# sempre il firmware della telecamera.

from dataclasses import dataclass, field
from typing import Dict, List, Optional


@dataclass(frozen=True)
class Modalita:
    id: str
    nome: str
    tipo: str                      # "foto" oppure "video"
    risoluzioni: List[str]
    gb_al_minuto: float = 0.0      # per i video: spazio occupato al minuto
    peso_foto_mb: float = 0.0      # per le foto: peso di uno scatto


@dataclass(frozen=True)
class Impostazione:
    id: str
    nome: str
    opzioni: List[str]
    predefinita: str


@dataclass(frozen=True)
class Telecamera:
    id: str
    nome: str
    sottotitolo: str
    tipo: str                      # "mini", "action" oppure "360"
    colore: str                    # colore di accento nell'interfaccia
    chips: List[str]               # etichette riassuntive mostrate sulla scheda
    batteria_iniziale: int
    memoria_totale_gb: float
    modalita: List[Modalita] = field(default_factory=list)
    impostazioni: List[Impostazione] = field(default_factory=list)

    def trova_modalita(self, id_modalita: str) -> Optional[Modalita]:
        for m in self.modalita:
            if m.id == id_modalita:
                return m
        return None

    def trova_impostazione(self, id_imp: str) -> Optional[Impostazione]:
        for i in self.impostazioni:
            if i.id == id_imp:
                return i
        return None


# ---------------------------------------------------------------- impostazioni

def _ev() -> Impostazione:
    return Impostazione("ev", "Esposizione (EV)",
                        ["-2", "-1,5", "-1", "-0,5", "0", "+0,5", "+1", "+1,5", "+2"], "0")


def _iso() -> Impostazione:
    return Impostazione("iso", "ISO massimo",
                        ["Auto", "100", "200", "400", "800", "1600", "3200", "6400"], "Auto")


def _otturatore() -> Impostazione:
    return Impostazione("otturatore", "Otturatore",
                        ["Auto", "1/8000", "1/4000", "1/2000", "1/1000", "1/500",
                         "1/250", "1/120", "1/60", "1/30"], "Auto")


def _bilanciamento() -> Impostazione:
    return Impostazione("wb", "Bilanciamento del bianco",
                        ["Auto", "2700K", "4000K", "5000K", "6500K"], "Auto")


def _vento() -> Impostazione:
    return Impostazione("vento", "Riduzione del vento", ["Auto", "Attiva", "Off"], "Auto")


def _timer() -> Impostazione:
    return Impostazione("timer", "Autoscatto", ["Off", "3 s", "10 s"], "Off")


def _griglia() -> Impostazione:
    return Impostazione("griglia", "Griglia in anteprima", ["Off", "3×3"], "Off")


def _vocale() -> Impostazione:
    return Impostazione("vocale", "Controllo vocale", ["Attivo", "Off"], "Off")


# ------------------------------------------------------------------ telecamere

GO_3S = Telecamera(
    id="go3s",
    nome="Insta360 GO 3S",
    sottotitolo="La mini magnetica, con Action Pod",
    tipo="mini",
    colore="#2fd6c3",
    chips=["Video fino a 4K", "39 g", "Impermeabile 10 m"],
    batteria_iniziale=84,
    memoria_totale_gb=64,
    modalita=[
        Modalita("video", "Video", "video",
                 ["4K/30", "2.7K/50", "1080p/60"], gb_al_minuto=0.45),
        Modalita("foto", "Foto", "foto", ["4:3", "16:9", "1:1"], peso_foto_mb=6),
        Modalita("freeframe", "FreeFrame", "video", ["2.7K/30"], gb_al_minuto=0.35),
        Modalita("slowmotion", "Slow motion", "video", ["1080p/120"], gb_al_minuto=0.4),
        Modalita("timelapse", "Timelapse", "video", ["4K", "2.7K"], gb_al_minuto=0.1),
        Modalita("timeshift", "TimeShift", "video", ["4K", "2.7K"], gb_al_minuto=0.12),
        Modalita("prereg", "Pre-registrazione", "video", ["4K/30", "2.7K/50"], gb_al_minuto=0.45),
        Modalita("loop", "Registrazione in loop", "video", ["4K/30", "1080p/60"], gb_al_minuto=0.45),
        Modalita("intervallo", "Foto a intervalli", "foto", ["4:3", "16:9"], peso_foto_mb=6),
    ],
    impostazioni=[
        Impostazione("fov", "Campo visivo", ["Ultra grandangolo", "Lineare"], "Ultra grandangolo"),
        Impostazione("stab", "Stabilizzazione", ["FlowState", "Off"], "FlowState"),
        _ev(), _iso(), _otturatore(), _bilanciamento(),
        Impostazione("profilo", "Profilo colore", ["Standard", "Vivido", "Piatto"], "Standard"),
        _vento(), _timer(), _griglia(), _vocale(),
        Impostazione("led", "LED di stato", ["Acceso", "Spento"], "Acceso"),
    ],
)

ACE_PRO_2 = Telecamera(
    id="acepro2",
    nome="Insta360 Ace Pro 2",
    sottotitolo="L'action cam co-progettata con Leica",
    tipo="action",
    colore="#f5b942",
    chips=["Video fino a 8K", "Foto 50 MP", "Sensore 1/1,3\"", "Schermo ribaltabile"],
    batteria_iniziale=67,
    memoria_totale_gb=256,
    modalita=[
        Modalita("video", "Video", "video",
                 ["8K/30", "4K/120", "4K/60", "1080p/240"], gb_al_minuto=1.3),
        Modalita("purevideo", "PureVideo (notturno)", "video", ["4K/30"], gb_al_minuto=0.9),
        Modalita("foto", "Foto", "foto", ["50 MP", "12 MP"], peso_foto_mb=25),
        Modalita("burst", "Raffica", "foto", ["12 MP ×15", "12 MP ×30"], peso_foto_mb=12),
        Modalita("slowmotion", "Slow motion", "video", ["4K/120", "1080p/240"], gb_al_minuto=1.1),
        Modalita("timelapse", "Timelapse", "video", ["8K", "4K"], gb_al_minuto=0.15),
        Modalita("timeshift", "TimeShift", "video", ["4K"], gb_al_minuto=0.15),
        Modalita("starlapse", "Starlapse (cielo stellato)", "video", ["4K"], gb_al_minuto=0.1),
        Modalita("prereg", "Pre-registrazione", "video", ["4K/60"], gb_al_minuto=0.9),
        Modalita("loop", "Registrazione in loop", "video", ["4K/60", "1080p/60"], gb_al_minuto=0.9),
    ],
    impostazioni=[
        Impostazione("fov", "Campo visivo",
                     ["Ultra grandangolo", "ActionView", "Lineare", "Stretto"], "Ultra grandangolo"),
        Impostazione("stab", "Stabilizzazione", ["FlowState", "Off"], "FlowState"),
        _ev(), _iso(), _otturatore(), _bilanciamento(),
        Impostazione("profilo", "Profilo colore",
                     ["Leica Naturale", "Leica Vivido", "Standard", "Piatto"], "Leica Naturale"),
        _vento(), _timer(), _griglia(), _vocale(),
        Impostazione("led", "LED di stato", ["Acceso", "Spento"], "Acceso"),
    ],
)

X6 = Telecamera(
    id="x6",
    nome="Insta360 X6",
    sottotitolo="La 360 di punta: 8K e Dolby Vision",
    tipo="360",
    colore="#a78bfa",
    chips=["Video 360 fino a 8K/50", "Doppio sensore 1/1,1\"", "Dolby Vision", "Batteria 140 min"],
    batteria_iniziale=91,
    memoria_totale_gb=512,
    modalita=[
        Modalita("video360", "Video 360", "video",
                 ["8K/50", "8K/30", "5.7K/60", "4K/100"], gb_al_minuto=1.3),
        Modalita("singolo", "Obiettivo singolo", "video",
                 ["4K/60 MaxView", "4K/30 Lineare"], gb_al_minuto=0.7),
        Modalita("instaframe", "InstaFrame (360 + inquadratura pronta)", "video",
                 ["8K/30 + 1080p"], gb_al_minuto=1.4),
        Modalita("foto360", "Foto 360", "foto", ["Standard", "HDR"], peso_foto_mb=40),
        Modalita("timelapse", "Timelapse 360", "video", ["8K", "5.7K"], gb_al_minuto=0.2),
        Modalita("timeshift", "TimeShift 360", "video", ["8K", "5.7K"], gb_al_minuto=0.2),
        Modalita("bullettime", "Bullet Time", "video", ["5.7K/120", "3K/240"], gb_al_minuto=1.0),
        Modalita("prereg", "Pre-registrazione", "video", ["8K/30", "5.7K/60"], gb_al_minuto=1.3),
        Modalita("loop", "Registrazione in loop", "video", ["5.7K/60"], gb_al_minuto=1.0),
    ],
    impostazioni=[
        Impostazione("colore360", "Modalità colore",
                     ["Standard", "Active HDR", "Dolby Vision"], "Standard"),
        _ev(), _iso(), _otturatore(), _bilanciamento(),
        Impostazione("profilo", "Profilo colore", ["Standard", "Vivido", "Piatto"], "Standard"),
        _vento(), _timer(), _griglia(), _vocale(),
        Impostazione("prospettiva", "Anteprima 360", ["Sfera", "Piccolo pianeta"], "Sfera"),
    ],
)

TELECAMERE: Dict[str, Telecamera] = {t.id: t for t in (GO_3S, ACE_PRO_2, X6)}
