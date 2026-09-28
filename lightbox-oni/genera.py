#!/usr/bin/env python3
"""Lightbox a ombra proiettata: genera l'inserto da stampare in 3D e simula l'ombra.

Idea: in alto nella cornice c'e' un LED che guarda il fondo (inclinato un po'
verso il basso). Sotto il LED c'e' una mensola orizzontale stampata in 3D e
forata. La luce scende radente sul fondo e l'unica luce che ci arriva e' quella
che passa dai fori: la mensola e' la "diapositiva" di un proiettore, deformata
apposta perche' l'ombra, stirata dalla luce radente, ricomponga la figura giusta.

Uso:
    python3 genera.py                      # Oni, cornice 24x30 profonda 50 mm
    python3 genera.py --profondita 60      # cambia le misure
    python3 genera.py --immagine mia.png   # sagoma propria (nero = ombra)

Produce in out/:
    inserto.stl         il pezzo da stampare (mensola forata + pareti + sede LED)
    coperchio.stl       la lastrina che chiude l'inserto in alto
    sfondo_sfumato.png  (facoltativo) fondo da stampare in scala 1:1 a 300 dpi
    simulazione.png     l'ombra attesa con LED diversi
    come_appare.png     come si vede a stanza buia, con e senza sfondo sfumato
    mensola.png         il disegno deformato che finisce sulla mensola
    verifica_stl.png    l'ombra ricalcolata dall'STL vero, confrontata col disegno
    inserto_3d.png      vista 3D del pezzo
    sezione.png         schema in sezione con i raggi di luce
    sagoma.png          la sagoma di partenza nella cornice
    riepilogo.json      misure e numeri utili

Sistema di riferimento (mm): x verso destra, y verso il BASSO misurato dal
centro del LED, z dal fondo della cornice (z = 0) verso il vetro.
"""
import argparse
import json
import os

import numpy as np
from PIL import Image, ImageDraw
from shapely.geometry import Polygon, MultiPolygon, box
from shapely.geometry.polygon import orient
from shapely.ops import unary_union
from shapely import affinity, contains_xy
import mapbox_earcut as earcut
import manifold3d as mf
import trimesh

import oni_sagoma

QUI = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(QUI, "out")


# ----------------------------------------------------------------------------
# Parametri. Le misure della cornice vanno prese DENTRO la cornice.
# ----------------------------------------------------------------------------
def parametri(argv=None):
    a = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    a.add_argument("--larghezza", type=float, default=240, help="larghezza interna della cornice (mm)")
    a.add_argument("--altezza", type=float, default=300, help="altezza interna della cornice (mm)")
    a.add_argument("--profondita", type=float, default=50, help="dal fondo al vetro, misura interna (mm)")
    a.add_argument("--mensola", type=float, default=62,
                   help="quanto sta sotto il LED la mensola forata (mm). Piu' e' bassa, piu' l'ombra e' "
                        "nitida, ma la fascia nera in alto si allunga")
    a.add_argument("--inclinazione-led", type=float, default=30,
                   help="gradi di cui il LED guarda verso il basso (0 = guarda dritto il fondo). "
                        "Piu' inclinato = piu' luce in basso. Con un LED bianco usare 0")
    a.add_argument("--led-sotto-soffitto", type=float, default=9, help="centro del LED sotto il bordo interno alto (mm)")
    a.add_argument("--larghezza-striscia", type=float, default=10, help="larghezza della striscia LED (mm)")
    a.add_argument("--spessore-striscia", type=float, default=1.6,
                   help="dal retro della striscia (adesivo compreso) alla faccia del LED (mm)")
    a.add_argument("--immagine", help="PNG in bianco e nero: nero = ombra. Default: l'Oni")
    a.add_argument("--margine-lati", type=float, default=6)
    a.add_argument("--margine-basso", type=float, default=8)
    a.add_argument("--risoluzione-sim", type=float, default=0.5, help="mm per pixel nella simulazione")
    a.add_argument("--compensazione", type=float, default=0.5,
                   help="quanto lo sfondo stampato compensa il calo di luce: 0 = niente, 1 = tutto")
    a.add_argument("--uscita", default=OUT, help="cartella dove scrivere i file")
    p = a.parse_args(argv)

    p.parete = 2.0              # pareti di fondo, fianchi, parete frontale
    p.spessore_mensola = 1.6
    p.spessore_coperchio = 1.2
    p.gioco = 0.5               # gioco tra inserto e cornice, per lato
    p.margine_immagine = 5      # spazio tra il fondo dell'inserto e l'inizio dell'immagine
    p.nervatura = (1.0, 0.8)    # guide della striscia: larghezza, altezza

    p.W_ins = p.larghezza - 2 * p.gioco                 # larghezza dell'inserto
    p.D_ins = p.profondita - p.gioco                    # profondita' dell'inserto
    p.y0 = p.mensola                                    # faccia alta della mensola
    p.y1 = p.mensola + p.spessore_mensola               # faccia bassa della mensola
    p.y_soffitto = -p.led_sotto_soffitto                # bordo interno alto della cornice
    p.Ztop = p.y1 - p.y_soffitto - 0.3 - p.spessore_coperchio   # altezza delle pareti in stampa
    p.Yfr = p.D_ins - p.parete                          # faccia interna della parete frontale
    p.tau = np.radians(p.inclinazione_led)
    # Distanza della faccia del LED dal fondo. Il cuneo che regge la striscia inclinata
    # nasce dalla parete frontale: il bordo basso della striscia deve starci sopra.
    p.Lz = (p.Yfr - p.spessore_striscia * np.cos(p.tau)
            - (p.larghezza_striscia / 2 + 1.5) * np.sin(p.tau))
    # zona dell'immagine sul fondo (il "quadro" vero e proprio)
    p.Y1 = p.y1 + p.margine_immagine
    p.Y2 = p.altezza - p.led_sotto_soffitto - p.margine_basso
    p.X = p.larghezza / 2 - p.margine_lati
    return p


# ----------------------------------------------------------------------------
# Geometria della proiezione
# ----------------------------------------------------------------------------
def fondo_a_mensola(xs, ys, y, Lz):
    """Punto del fondo (xs, ys) -> punto sul piano orizzontale a quota y dove passa il
    raggio che parte dal LED in (0, 0, Lz). Restituisce (x, z)."""
    return xs * y / ys, Lz * (1 - y / ys)


def sagoma_nel_quadro(p):
    """Sagoma scura (ombra) in coordinate del fondo (mm) e rettangolo del quadro."""
    alt = p.Y2 - p.Y1
    finestra = box(-p.X, p.Y1, p.X, p.Y2)
    if not p.immagine:
        g = oni_sagoma.sagoma_oni()          # u in [-0.5, 0.5], v in [0, 1]
        g = affinity.scale(g, alt, alt, origin=(0, 0))
        return affinity.translate(g, 0, p.Y1), finestra
    # immagine propria: la tela intera del PNG va nel quadro, centrata e in alto
    g, (w, h) = sagoma_da_png(p.immagine)
    s = min(2 * p.X / w, alt / h)
    g = affinity.scale(g, s, s, origin=(0, 0))
    g = affinity.translate(g, -w * s / 2, p.Y1)
    tela = box(-w * s / 2, p.Y1, w * s / 2, p.Y1 + h * s)
    return g, tela.intersection(finestra)


def sagoma_da_png(percorso, soglia=128):
    import cv2
    img = np.array(Image.open(percorso).convert("L"))
    scuro = (img < soglia).astype(np.uint8)
    contorni, gerarchia = cv2.findContours(scuro, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_NONE)
    poligoni = []
    for i, c in enumerate(contorni):
        if gerarchia[0][i][3] != -1 or len(c) < 3:
            continue
        fori = []
        figlio = gerarchia[0][i][2]
        while figlio != -1:
            if len(contorni[figlio]) >= 3:
                fori.append(contorni[figlio][:, 0, :].astype(float))
            figlio = gerarchia[0][figlio][0]
        poligoni.append(Polygon(c[:, 0, :].astype(float), fori).buffer(0))
    return unary_union(poligoni).simplify(0.7), (img.shape[1], img.shape[0])


def zona_illuminata(ombra, quadro):
    """Cio' che nel quadro deve ricevere luce: il quadro meno l'ombra."""
    luce = quadro.difference(ombra).buffer(0)
    parti = [g for g in getattr(luce, "geoms", [luce]) if g.area > 4.0]   # via le briciole
    return MultiPolygon(parti) if len(parti) > 1 else parti[0]


def isole_staccate(luce, quadro):
    """Le parti scure del quadro devono toccarne il bordo: altrimenti nella mensola
    sarebbero pezzi staccati dal resto, e cadrebbero."""
    scuro = quadro.difference(luce).buffer(-0.01)
    bordo = quadro.exterior.buffer(0.5)
    return [g for g in getattr(scuro, "geoms", [scuro]) if not g.intersects(bordo) and g.area > 1]


def mensola_2d(p, luce, y):
    """Sezione della mensola alla quota y: parte piena e fori, in (x, z)."""
    Wi = p.W_ins / 2
    fori = []
    for g in getattr(luce, "geoms", [luce]):
        est = np.asarray(g.exterior.coords)
        interni = [np.asarray(r.coords) for r in g.interiors]
        f = lambda c: np.stack(fondo_a_mensola(c[:, 0], c[:, 1], y, p.Lz), axis=1)
        fori.append(Polygon(f(est), [f(r) for r in interni]))
    fori = unary_union(fori)
    return box(-Wi, 0, Wi, p.D_ins).difference(fori), fori


# ----------------------------------------------------------------------------
# Mesh (coordinate di stampa: mensola sul piatto, pareti verso l'alto)
# ----------------------------------------------------------------------------
def a_stampa(x, y, z, p):
    return np.stack([x, z, p.y1 - y], axis=-1)


def loft_foro(poligono, p, ya, yb):
    """Solido tra i piani y=ya e y=yb, tagliato lungo i raggi del LED che passano per
    il poligono (in coordinate del fondo). Le pareti dei fori sono inclinate come i
    raggi, cosi' lo spessore della mensola non ruba luce."""
    poligono = orient(poligono, 1.0)
    anelli = [np.asarray(poligono.exterior.coords)[:-1]]
    anelli += [np.asarray(r.coords)[:-1] for r in poligono.interiors]
    v2 = np.vstack(anelli)
    fine = np.cumsum([len(r) for r in anelli]).astype(np.uint32)
    tri = np.asarray(earcut.triangulate_float64(v2, fine), dtype=np.int64).reshape(-1, 3)
    a, b, c = v2[tri[:, 0]], v2[tri[:, 1]], v2[tri[:, 2]]
    orario = ((b[:, 0] - a[:, 0]) * (c[:, 1] - a[:, 1]) - (b[:, 1] - a[:, 1]) * (c[:, 0] - a[:, 0])) < 0
    tri[orario] = tri[orario][:, ::-1]

    n = len(v2)
    xa, za = fondo_a_mensola(v2[:, 0], v2[:, 1], ya, p.Lz)
    xb, zb = fondo_a_mensola(v2[:, 0], v2[:, 1], yb, p.Lz)
    verts = np.vstack([a_stampa(xa, np.full(n, ya), za, p), a_stampa(xb, np.full(n, yb), zb, p)])
    facce = [tri, tri[:, ::-1] + n]
    inizio = 0
    for r in anelli:
        i = np.arange(len(r)) + inizio
        j = np.roll(i, -1)
        facce += [np.stack([i + n, j + n, j], axis=1), np.stack([i + n, j, i], axis=1)]
        inizio += len(r)
    m = mf.Manifold(mf.Mesh(vert_properties=verts.astype(np.float32),
                            tri_verts=np.vstack(facce).astype(np.uint32)))
    if m.status() != mf.Error.NoError or m.volume() <= 0:
        raise RuntimeError(f"foro non valido: {m.status()}")
    return m


def scatola(x0, x1, y0, y1, z0, z1):
    return mf.Manifold.cube([x1 - x0, y1 - y0, z1 - z0]).translate([x0, y0, z0])


def scatola_orientata(centro, assi, mezze):
    """Parallelepipedo con assi qualsiasi (per le guide sulla faccia inclinata)."""
    c = np.asarray(centro, float)
    pts = [c + sx * mezze[0] * assi[0] + sy * mezze[1] * assi[1] + sz * mezze[2] * assi[2]
           for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    return mf.Manifold.hull_points(np.array(pts))


def geometria_led(p):
    """Posizione e orientamento della striscia, in coordinate di stampa."""
    t = p.tau
    n = np.array([0, -np.cos(t), -np.sin(t)])      # esce dalla faccia del LED: verso il fondo e in basso
    su = np.array([0, -np.sin(t), np.cos(t)])      # lungo la larghezza della striscia, verso l'alto
    C = np.array([0, p.Lz, p.y1])                  # centro della faccia del LED
    B = C - n * p.spessore_striscia                # centro del retro della striscia (appoggio)
    return n, su, C, B


def costruisci_inserto(p, luce):
    W = p.W_ins / 2
    Wi = W - p.parete
    corpo = scatola(-W, W, 0, p.D_ins, 0, p.spessore_mensola)                  # mensola
    corpo += scatola(-W, W, 0, p.parete, 0, p.Ztop)                             # parete di fondo
    corpo += scatola(-W, W, p.Yfr, p.D_ins, 0, p.Ztop)                          # parete frontale
    corpo += scatola(-W, -Wi, 0, p.D_ins, 0, p.Ztop)                            # fianchi
    corpo += scatola(Wi, W, 0, p.D_ins, 0, p.Ztop)

    # cuneo sulla parete frontale: la striscia ci si incolla sopra, inclinata verso il basso
    n, su, C, B = geometria_led(p)
    cuneo = scatola(-Wi, Wi, p.Yfr - 40, p.Yfr + 0.01, p.spessore_mensola, p.Ztop)
    cuneo = cuneo.trim_by_plane(list(-n), float(-n @ B))
    corpo += cuneo
    # due guide ai lati della striscia; la tacca al centro indica dove va il LED che proietta
    lw, lh = p.nervatura
    x = np.array([1.0, 0, 0])
    for s in (-1, 1):
        centro = B + su * s * (p.larghezza_striscia / 2 + 0.25 + lw / 2) + n * lh / 2
        corpo += scatola_orientata(centro, [x, su, n], [Wi - 0.01, lw / 2, lh / 2 + 0.3])
    corpo -= scatola_orientata(B + n * lh / 2, [x, su, n], [0.6, p.larghezza_striscia, lh + 0.5])
    # passaggio per i fili, sui due fianchi, all'altezza della striscia
    passaggio = mf.Manifold.cylinder(p.parete * 4, 2.5, 2.5, 32).rotate([0, 90, 0])
    for sx in (-W, W):
        corpo -= passaggio.translate([sx - p.parete * 2, B[1] - 3, B[2]])

    # i fori della mensola: le zone illuminate proiettate verso il LED
    fori = [loft_foro(g, p, p.y0 - 0.5, p.y1 + 0.5) for g in getattr(luce, "geoms", [luce])]
    corpo -= mf.Manifold.batch_boolean(fori, mf.OpType.Add)
    return corpo


def costruisci_coperchio(p):
    """Lastrina che chiude l'inserto in alto: senza, la luce che sale rimbalza sul
    soffitto della cornice e schiarisce le ombre. Si stampa cosi', bordino in su."""
    W = p.W_ins / 2
    t = p.spessore_coperchio
    c = scatola(-W, W, 0, p.D_ins, 0, t)
    g = 0.3                                    # gioco dentro le pareti
    a, b = -W + p.parete + g, W - p.parete - g
    y_fine = p.Yfr - 14                        # davanti c'e' il cuneo: il bordino si ferma prima
    anello = scatola(a, b, p.parete + g, y_fine, t, t + 1.5)
    anello -= scatola(a + 1.2, b - 1.2, p.parete + g + 1.2, y_fine + 1, t - 1, t + 3)
    return c + anello


def a_trimesh(m):
    mesh = m.to_mesh()
    return trimesh.Trimesh(vertices=np.asarray(mesh.vert_properties)[:, :3],
                           faces=np.asarray(mesh.tri_verts), process=True)


# ----------------------------------------------------------------------------
# Simulazione della luce
# ----------------------------------------------------------------------------
class Raster:
    """Poligono rasterizzato nel piano del fondo, per test punto-dentro veloci."""

    def __init__(self, geom, x0, x1, y0, y1, px=0.1):
        self.x0, self.y0, self.px = x0, y0, px
        nx, ny = int(np.ceil((x1 - x0) / px)), int(np.ceil((y1 - y0) / px))
        img = Image.new("1", (nx, ny), 0)
        d = ImageDraw.Draw(img)
        for g in sorted(getattr(geom, "geoms", [geom]), key=lambda g: -g.area):
            d.polygon([((x - x0) / px, (y - y0) / px) for x, y in g.exterior.coords], fill=1)
            for r in g.interiors:
                d.polygon([((x - x0) / px, (y - y0) / px) for x, y in r.coords], fill=0)
        self.a = np.array(img, dtype=bool)

    def dentro(self, x, y):
        i = np.floor((y - self.y0) / self.px).astype(np.int64)
        j = np.floor((x - self.x0) / self.px).astype(np.int64)
        ok = (i >= 0) & (i < self.a.shape[0]) & (j >= 0) & (j < self.a.shape[1])
        out = np.zeros(x.shape, bool)
        out[ok] = self.a[i[ok], j[ok]]
        return out


# zona che emette luce: (lato, spessore) in mm. Nei LED colorati la luce viene dal chip,
# un granello; nei LED bianchi da tutto lo strato di fosforo giallo che riempie la coppetta.
LED = {"colore": (0.35, 0.15), "bianco": (2.5, 0.5), "foro": (0.8, 0.1), "striscia": (2.5, 0.5)}


def campioni_led(tipo, p):
    """Punti che rappresentano la parte luminosa del LED (coordinate del mondo)."""
    lato, spessore = LED[tipo]
    if tipo == "striscia":
        passo = 1000 / 60                                      # 60 LED/m
        k = int((p.W_ins - 2 * p.parete - 6) / passo)
        centri = (np.arange(k) - (k - 1) // 2) * passo
        g = np.linspace(-0.5, 0.5, 3)
    else:
        centri = np.array([0.0])
        g = np.linspace(-0.5, 0.5, 5)
    t = p.tau
    normale = np.array([0.0, np.sin(t), -np.cos(t)])          # verso il fondo, inclinata in basso
    lungo = np.array([0.0, np.cos(t), np.sin(t)])
    pts = [np.array([c, 0, p.Lz]) + a * lato * np.array([1.0, 0, 0]) + b * lato * lungo + s * spessore * normale
           for c in centri for a in g for b in g for s in (-0.5, 0, 0.5)]
    return np.array(pts), normale


def sfumatura(p, tipo, ys):
    """Larghezza stimata del bordo sfumato dell'ombra (mm) all'altezza ys: (orizz., vert.)."""
    lato, spessore = LED[tipo]
    k = ys / p.y0 - 1
    dz = spessore * np.cos(p.tau) + lato * np.sin(p.tau)       # quanto e' "spesso" il LED lungo z
    return lato * k, lato * np.cos(p.tau) * k + dz * ys * (ys - p.y0) / (p.y0 * p.Lz)


def simula(p, prova_buco, sorgenti, normale, xs, ys):
    """Irradianza sul fondo E e frazione di LED visibile V (0 = ombra piena).
    prova_buco(quota, x, z) dice se in quel punto la mensola e' vuota."""
    X, Y = np.meshgrid(xs, ys)
    E = np.zeros_like(X)
    V = np.zeros_like(X)
    Wi = p.W_ins / 2 - p.parete
    for sx, sy, sz in sorgenti:
        visibile = np.ones_like(X, bool)
        for yp in (p.y0, (p.y0 + p.y1) / 2, p.y1):
            u = (yp - sy) / (Y - sy)
            xm = sx + u * (X - sx)
            zm = sz * (1 - u)
            ok = (zm < p.Lz - 1e-6) & (zm > p.parete) & (abs(xm) < Wi)
            visibile &= ok & prova_buco(yp, xm, zm)
        vx, vy, vz = X - sx, Y - sy, -sz
        r = np.sqrt(vx ** 2 + vy ** 2 + vz ** 2)
        cos_e = np.clip((vx * normale[0] + vy * normale[1] + vz * normale[2]) / r, 0, None)
        E += visibile * cos_e * (sz / r) / r ** 2
        V += visibile
    return E, V / len(sorgenti)


def buchi_dal_disegno(p, luce):
    """Mensola ideale: vuota dove il raggio dal LED nominale cade nella zona illuminata."""
    r = Raster(luce, -p.larghezza / 2 - 20, p.larghezza / 2 + 20, p.y0 - 5, p.altezza + 400)

    def prova(yp, x, z):
        k = p.Lz / np.where(z < p.Lz, p.Lz - z, 1.0)
        return r.dentro(x * k, yp * k)
    return prova


def buchi_come_stampati(p, luce, ugello=0.4):
    """Mensola come la fa una stampante FDM: le fessure e le punte piu' strette
    dell'ugello spariscono (approssimazione)."""
    r = ugello / 2
    W = p.W_ins / 2
    piani = {}
    for yp in (p.y0, (p.y0 + p.y1) / 2, p.y1):
        pieno, fori = mensola_2d(p, luce, yp)
        fori = fori.buffer(-r).buffer(r)                          # fessure sottili: si chiudono
        pieno = box(-W, 0, W, p.D_ins).difference(fori)
        pieno = pieno.buffer(-r).buffer(r)                        # punte sottili: spariscono
        fori = box(-W, 0, W, p.D_ins).difference(pieno)
        piani[yp] = Raster(fori, -W, W, 0, p.D_ins, 0.04)

    def prova(yp, x, z):
        return piani[yp].dentro(x, z)
    return prova


def verifica_da_stl(p, mesh, xs, ys):
    """Ricalcola l'ombra dalle sezioni dell'STL vero (LED puntiforme nominale)."""
    X, Y = np.meshgrid(xs, ys)
    visibile = np.ones_like(X, bool)
    for yp in (p.y0 + 0.15, (p.y0 + p.y1) / 2, p.y1 - 0.15):
        sez = mesh.section(plane_origin=[0, 0, p.y1 - yp], plane_normal=[0, 0, 1])
        planare, _ = sez.to_2D(to_2D=np.eye(4))
        pieno = unary_union(planare.polygons_full)
        u = yp / Y
        visibile &= ~contains_xy(pieno, u * X, p.Lz * (1 - u))
    return visibile


def irradianza_senza_ombre(p, X, Y):
    """Luce che arriverebbe al fondo senza la mensola (LED puntiforme lambertiano)."""
    n = np.array([0.0, np.sin(p.tau), -np.cos(p.tau)])
    r = np.sqrt(X ** 2 + Y ** 2 + p.Lz ** 2)
    cos_e = np.clip((Y * n[1] - p.Lz * n[2]) / r, 0, None)
    return cos_e * (p.Lz / r) / r ** 2


def riflettanza_compensata(p, E0, nel_quadro):
    """Grigio dello sfondo stampato: piu' scuro dove arriva piu' luce. 1 = bianco carta."""
    Emin = E0[nel_quadro].min() if nel_quadro.any() else E0.min()
    return np.clip((E0 / Emin) ** (-p.compensazione), 0, 1)


def salva_sfondo(p, percorso, dpi=300):
    """PNG in scala 1:1 da stampare e mettere come fondo della cornice."""
    mm = 25.4 / dpi
    xs = (np.arange(int(p.larghezza / mm)) + 0.5) * mm - p.larghezza / 2
    ys = (np.arange(int(p.altezza / mm)) + 0.5) * mm + p.y_soffitto
    X, Y = np.meshgrid(xs, ys)
    E0 = irradianza_senza_ombre(p, X, Y)
    nel_quadro = (np.abs(X) < p.X) & (Y > p.Y1) & (Y < p.Y2)
    R = riflettanza_compensata(p, E0, nel_quadro)
    R[Y < p.y1] = 1.0                                  # dietro l'inserto non serve
    srgb = np.where(R <= 0.0031308, 12.92 * R, 1.055 * R ** (1 / 2.4) - 0.055)
    Image.fromarray((srgb * 255).round().astype(np.uint8), "L").save(percorso, dpi=(dpi, dpi))


# ----------------------------------------------------------------------------
# Rendering 3D semplice (z-buffer), senza dipendenze grafiche
# ----------------------------------------------------------------------------
def render(mesh, direzione, alto_mondo=(0, 0, 1), larg=1400, alt=900, colore=(0.42, 0.42, 0.44), margine=0.06):
    """Proiezione ortografica: 'direzione' e' dove guarda la camera, 'alto_mondo' cio' che
    sullo schermo deve stare in alto."""
    f = np.asarray(direzione, float)
    f /= np.linalg.norm(f)
    r = np.cross(f, alto_mondo)
    r /= np.linalg.norm(r)
    u = np.cross(r, f)
    R = np.stack([r, u, -f])                      # righe: destra, alto, verso la camera
    v = (mesh.vertices - mesh.bounds.mean(0)) @ R.T
    nrm = mesh.face_normals @ R.T
    lo, hi = v[:, :2].min(0), v[:, :2].max(0)
    s = (1 - 2 * margine) * min(larg / (hi[0] - lo[0]), alt / (hi[1] - lo[1]))
    px = (v[:, 0] - (lo[0] + hi[0]) / 2) * s + larg / 2
    py = alt / 2 - (v[:, 1] - (lo[1] + hi[1]) / 2) * s
    pz = v[:, 2]
    zbuf = np.full((alt, larg), -np.inf)
    img = np.ones((alt, larg, 3))
    luci = [(np.array([-0.4, 0.5, 0.75]), 0.75), (np.array([0.6, -0.2, 0.4]), 0.25)]
    for f, nf in zip(mesh.faces, nrm):
        if nf[2] <= 0:                            # faccia girata di spalle
            continue
        x, y, z = px[f], py[f], pz[f]
        x0, x1 = int(max(0, np.floor(x.min()))), int(min(larg - 1, np.ceil(x.max())))
        y0, y1 = int(max(0, np.floor(y.min()))), int(min(alt - 1, np.ceil(y.max())))
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        d = (y[1] - y[2]) * (x[0] - x[2]) + (x[2] - x[1]) * (y[0] - y[2])
        if abs(d) < 1e-12:
            continue
        l0 = ((y[1] - y[2]) * (gx - x[2]) + (x[2] - x[1]) * (gy - y[2])) / d
        l1 = ((y[2] - y[0]) * (gx - x[2]) + (x[0] - x[2]) * (gy - y[2])) / d
        l2 = 1 - l0 - l1
        m = (l0 >= -1e-6) & (l1 >= -1e-6) & (l2 >= -1e-6)
        zz = l0 * z[0] + l1 * z[1] + l2 * z[2]
        sub = zbuf[y0:y1 + 1, x0:x1 + 1]
        m &= zz > sub
        if not m.any():
            continue
        sub[m] = zz[m]
        lum = 0.22 + sum(w * max(0.0, float(nf @ (L / np.linalg.norm(L)))) for L, w in luci)
        img[y0:y1 + 1, x0:x1 + 1][m] = np.clip(np.array(colore) * lum * 1.6, 0, 1)
    return img


# ----------------------------------------------------------------------------
# Immagini
# ----------------------------------------------------------------------------
def figure(p, ombra, quadro, luce, mesh, coperchio, info):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.colors import LinearSegmentedColormap
    from shapely.plotting import plot_polygon

    px = p.risoluzione_sim
    xs = np.arange(-p.larghezza / 2, p.larghezza / 2, px) + px / 2
    ys = np.arange(p.y1, p.altezza - p.led_sotto_soffitto, px) + px / 2
    est = [xs[0] - px / 2, xs[-1] + px / 2, ys[-1] + px / 2, ys[0] - px / 2]
    ideale = buchi_dal_disegno(p, luce)
    qx0, qy0, qx1, qy1 = quadro.bounds

    def cornice(ax, titolo):
        ax.set_title(titolo, fontsize=10)
        ax.add_patch(plt.Rectangle((qx0, qy0), qx1 - qx0, qy1 - qy0, fill=False, ec="#c33", lw=0.6, ls="--"))
        ax.set_xlim(-p.larghezza / 2, p.larghezza / 2)
        ax.set_ylim(p.altezza - p.led_sotto_soffitto, p.y_soffitto)
        ax.add_patch(plt.Rectangle((-p.larghezza / 2, p.y_soffitto), p.larghezza, p.y1 - p.y_soffitto,
                                   color="#222", zorder=5))
        ax.text(0, (p.y_soffitto + p.y1) / 2, "inserto stampato\n(LED + mensola forata)", color="#bbb",
                ha="center", va="center", fontsize=7, zorder=6)
        ax.set_aspect("equal")
        ax.set_xticks([])
        ax.set_yticks([])

    # 1) la sagoma nel quadro
    fig, ax = plt.subplots(figsize=(4.2, 5.2))
    ax.set_facecolor("#f4efe6")
    plot_polygon(ombra.intersection(box(-p.larghezza / 2, p.y1, p.larghezza / 2, p.altezza)), ax=ax,
                 add_points=False, facecolor="#111", edgecolor="none")
    cornice(ax, "Il disegno che vogliamo come ombra")
    fig.tight_layout()
    fig.savefig(os.path.join(p.uscita, "sagoma.png"), dpi=150)
    plt.close(fig)

    # 2) simulazioni con sorgenti diverse
    casi = [("stampato", "1 LED colorato, mensola come esce\nda una stampante con ugello 0,4"),
            ("colore", "1 LED colorato\n(la luce esce da un chip di ~0,4 mm)"),
            ("foro", "1 LED bianco coperto da nastro\ncon un forellino da 0,8 mm"),
            ("bianco", "1 LED bianco scoperto\n(la luce esce da ~2,5 mm di fosforo)"),
            ("striscia", "Tutta la striscia accesa\n(60 LED/m)")]
    ris = {}
    for tipo, _ in casi:
        src, nrm = campioni_led("colore" if tipo == "stampato" else tipo, p)
        buchi = buchi_come_stampati(p, luce) if tipo == "stampato" else ideale
        ris[tipo] = simula(p, buchi, src, nrm, xs, ys)
    X, Y = np.meshgrid(xs, ys)
    nel_quadro = contains_xy(quadro, X, Y)
    fascia = lambda q0, q1: nel_quadro & (Y > p.Y1 + q0 * (p.Y2 - p.Y1)) & (Y < p.Y1 + q1 * (p.Y2 - p.Y1))
    E0 = irradianza_senza_ombre(p, X, Y)
    rapporto = float(E0[fascia(0.9, 1.0)].mean() / E0[fascia(0.0, 0.1)].mean())
    info["luce: fondo del quadro / cima del quadro"] = round(rapporto, 3)
    info["bordo sfumato dell'ombra, mm (orizzontale, verticale)"] = {
        tipo: {f"a {int(q * 100)}% dell'altezza": [round(float(v), 1) for v in sfumatura(p, tipo, p.Y1 + q * (p.Y2 - p.Y1))]
               for q in (0.2, 0.5, 0.9)} for tipo in ("colore", "foro", "bianco")}

    fig, axs = plt.subplots(1, 5, figsize=(19, 5.6))
    for ax, (tipo, titolo) in zip(axs, casi):
        cornice(ax, titolo)
        ax.imshow(ris[tipo][1], extent=est, cmap="gray", vmin=0, vmax=1, interpolation="bilinear")
    fig.suptitle("Forma dell'ombra con sorgenti diverse (luminosità uniformata per confrontare la nitidezza)",
                 fontsize=11)
    fig.tight_layout()
    fig.savefig(os.path.join(p.uscita, "simulazione.png"), dpi=100)
    plt.close(fig)

    # 2b) come appare al buio, con e senza sfondo sfumato stampato
    R = riflettanza_compensata(p, E0, nel_quadro)
    salva_sfondo(p, os.path.join(p.uscita, "sfondo_sfumato.png"))
    info["sfondo sfumato: grigio piu' scuro (riflettanza %)"] = round(100 * float(R[nel_quadro].min()), 1)
    info["luce percepita con sfondo sfumato: fondo / cima"] = round(
        float((E0 * R)[fascia(0.9, 1.0)].mean() / (E0 * R)[fascia(0.0, 0.1)].mean()), 3)
    rosso = LinearSegmentedColormap.from_list("rosso", ["#030101", "#3d0605", "#c21a10", "#ffd2c0"])
    caldo = LinearSegmentedColormap.from_list("caldo", ["#050302", "#3a2415", "#c98f55", "#fff3dd"])
    src, nrm = campioni_led("foro", p)
    foro_stampato = simula(p, buchi_come_stampati(p, luce), src, nrm, xs, ys)[0]
    viste = [(ris["stampato"][0], rosso, "LED rosso, fondo bianco"),
             (ris["stampato"][0] * R, rosso, "LED rosso, fondo con sfumatura stampata"),
             (foro_stampato * R, caldo, "LED bianco con forellino,\nfondo con sfumatura stampata")]
    fig, axs = plt.subplots(1, 3, figsize=(12, 5.9))
    for ax, (E, cmap, titolo) in zip(axs, viste):
        rif = np.percentile(E[E > 0], 99.5)
        # al buio l'occhio si adatta: compressione logaritmica della luminosita'
        ax.imshow(np.clip(np.log1p(30 * E / rif) / np.log1p(30), 0, 1), extent=est, cmap=cmap,
                  vmin=0, vmax=1, interpolation="bilinear")
        cornice(ax, titolo)
    fig.suptitle("Come appare a stanza buia (mensola come esce dalla stampante)", fontsize=11)
    fig.tight_layout()
    fig.savefig(os.path.join(p.uscita, "come_appare.png"), dpi=100)
    plt.close(fig)

    # 3) verifica sull'STL vero
    vis = verifica_da_stl(p, mesh, xs, ys)
    atteso = Raster(luce, xs[0] - 1, xs[-1] + 1, ys[0] - 1, ys[-1] + 1, 0.1).dentro(X, Y)
    dentro = contains_xy(quadro.buffer(-1), X, Y)
    diff = (vis != atteso) & dentro
    info["verifica: pixel diversi tra STL e disegno (%)"] = round(100 * diff.sum() / dentro.sum(), 3)
    rgb = np.ones(vis.shape + (3,))
    rgb[~vis] = (0.1, 0.1, 0.1)
    rgb[diff] = (1.0, 0.25, 0.1)
    fig, ax = plt.subplots(figsize=(4.2, 5.2))
    cornice(ax, "Ombra ricalcolata dall'STL\n"
                f"(in rosso i pixel diversi dal disegno: {info['verifica: pixel diversi tra STL e disegno (%)']}%)")
    ax.imshow(rgb, extent=est, interpolation="nearest")
    fig.tight_layout()
    fig.savefig(os.path.join(p.uscita, "verifica_stl.png"), dpi=150)
    plt.close(fig)

    # 4) il disegno sulla mensola, com'e' davvero
    pieno, _ = mensola_2d(p, luce, p.y0)
    sottile = pieno.difference(pieno.buffer(-0.22).buffer(0.22))     # parti piene sotto ~0,45 mm
    sottile = unary_union([g for g in getattr(sottile, "geoms", [sottile]) if g.area > 0.3])
    info["mensola: punte piu' sottili di 0,45 mm, che la stampante smussa (mm2)"] = round(sottile.area, 1)
    fig, ax = plt.subplots(figsize=(11, 3.4))
    plot_polygon(pieno, ax=ax, add_points=False, facecolor="#1b1b1b", edgecolor="none")
    if sottile.area > 0.05:
        plot_polygon(sottile.buffer(0.3), ax=ax, add_points=False, facecolor="#e33", edgecolor="none")
    ax.set_xlim(-p.W_ins / 2 - 2, p.W_ins / 2 + 2)
    ax.set_ylim(p.D_ins + 7, -7)                   # lato fondo in alto: cosi' il demone e' dritto
    ax.set_aspect("equal")
    ax.set_xlabel("mm")
    ax.text(0, -1.5, "lato fondo della cornice", ha="center", va="bottom", fontsize=8, color="#555")
    ax.text(0, p.D_ins + 1.5, "lato vetro (sopra c'è il LED)", ha="center", va="top", fontsize=8, color="#555")
    ax.set_title("La mensola vista dall'alto, in scala. Il demone è schiacciato e deformato: "
                 "la luce radente lo raddrizza" + ("  (in rosso: punte che la stampante smusserà)" if sottile.area > 0.05 else ""),
                 fontsize=10)
    ax.set_yticks([])
    fig.tight_layout()
    fig.savefig(os.path.join(p.uscita, "mensola.png"), dpi=150)
    plt.close(fig)

    # 5) vista 3D dell'inserto e del coperchio
    aperto = mesh.slice_plane([0, p.parete + 0.05, 0], [0, 1, 0], cap=True)
    fig, axs = plt.subplots(1, 2, figsize=(14, 6.4), gridspec_kw=dict(width_ratios=[1.2, 1]))
    axs[0].imshow(render(aperto, (0.45, 0.75, -0.55), larg=1400, alt=950))
    axs[0].set_title("Inserto senza la parete di fondo: mensola forata e, davanti,\n"
                     "il cuneo inclinato con le due guide per la striscia LED", fontsize=10)
    axs[1].imshow(render(mesh, (0, 0, 1), alto_mondo=(0, -1, 0), larg=1200, alt=760))
    axs[1].set_title("La mensola vista da sotto (la faccia che va sul piatto)", fontsize=10)
    for ax in axs:
        ax.set_axis_off()
    fig.tight_layout(pad=2.0)
    fig.savefig(os.path.join(p.uscita, "inserto_3d.png"), dpi=110)
    plt.close(fig)

    # 6) sezione con i raggi
    sezione(p, luce, os.path.join(p.uscita, "sezione.png"))


def sezione(p, luce, percorso):
    """Schema laterale: LED, mensola, raggi che passano dai fori e cadono sul fondo."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.patches import Polygon as Poli

    H = p.altezza - p.led_sotto_soffitto
    legno, nero = "#8a6a4a", "#222"
    fig, ax = plt.subplots(figsize=(5.6, 8.6))
    ax.fill_between([-6, 0], p.y_soffitto - 6, H + 6, color=legno)
    ax.fill_between([-6, p.profondita + 8], p.y_soffitto - 6, p.y_soffitto, color=legno)
    ax.fill_between([-6, p.profondita + 8], H, H + 6, color=legno)
    ax.fill_between([p.profondita, p.profondita + 2.5], p.y_soffitto, H, color="#bfe3f0", alpha=0.8)
    # inserto: coperchio, parete di fondo, parete frontale, cuneo
    ys_ = lambda Z: p.y1 - Z
    ax.fill_between([0, p.D_ins], ys_(p.Ztop), ys_(p.Ztop + p.spessore_coperchio), color=nero)
    ax.fill_between([0, p.parete], ys_(p.Ztop), p.y0, color=nero)
    ax.fill_between([p.Yfr, p.D_ins], ys_(p.Ztop), p.y1, color=nero)
    n, su, C, B = geometria_led(p)
    Zb = p.spessore_mensola
    # profilo del cuneo in (z, y)
    tz = -n[1] / n[2] if abs(n[2]) > 1e-9 else None
    punti = [(p.Yfr, ys_(p.Ztop))]
    Ytop = B[1] + (B[2] - p.Ztop) * np.tan(p.tau)
    punti += [(Ytop, ys_(p.Ztop))]
    Zlow = B[2] - (p.Yfr - B[1]) / max(np.tan(p.tau), 1e-9) if p.tau > 1e-6 else p.Ztop
    punti += [(p.Yfr, ys_(max(Zlow, Zb)))]
    if p.tau > 1e-6:
        ax.add_patch(Poli(punti, closed=True, color=nero))
    # striscia LED
    e1, e2 = B - su * p.larghezza_striscia / 2, B + su * p.larghezza_striscia / 2
    q = [e1, e2, e2 + n * 0.6, e1 + n * 0.6]
    ax.add_patch(Poli([(v[1], ys_(v[2])) for v in q], closed=True, color="#2a7d3a"))
    ax.plot([p.Lz], [0], marker="o", ms=6, color="#ff3b2f", mec="#7a0c06", zorder=6)
    ax.annotate("LED acceso\n(uno solo)", (p.Lz, 0), (p.Lz - 42, 22), fontsize=8,
                arrowprops=dict(arrowstyle="-", color="#666"))
    # mensola lungo la sezione centrale: piena o vuota
    zz = np.linspace(0, p.D_ins, 900)
    ysf = np.where(zz < p.Lz - 0.01, p.y0 * p.Lz / np.maximum(p.Lz - zz, 1e-3), 1e9)
    foro = contains_xy(luce, np.zeros_like(zz), ysf)
    for i in range(len(zz) - 1):
        if not foro[i]:
            ax.fill_between([zz[i], zz[i + 1]], p.y0, p.y1, color=nero, lw=0)
    # raggi dal LED
    for yv in np.linspace(p.Y1 + 1, p.Y2 - 1, 80):
        zm = p.Lz * (1 - p.y0 / yv)
        if contains_xy(luce, 0.0, yv):
            ax.plot([p.Lz, 0], [0, yv], color="#ff5a3c", lw=0.5, alpha=0.8)
        else:
            ax.plot([p.Lz, zm], [0, p.y0], color="#ff5a3c", lw=0.5, alpha=0.8)
    # ombra e luce sul fondo lungo la sezione centrale
    yy = np.linspace(p.Y1, p.Y2, 1500)
    lit = contains_xy(luce, np.zeros_like(yy), yy)
    for i in range(len(yy) - 1):
        ax.plot([0.8, 0.8], [yy[i], yy[i + 1]], color="#ffcfc2" if lit[i] else "#111", lw=3.5,
                solid_capstyle="butt")
    ax.text(p.Lz / 2 + 4, p.y0 - 3, "mensola forata", fontsize=8, ha="center")
    ax.text(p.D_ins / 2, ys_(p.Ztop + p.spessore_coperchio) - 2, "coperchio", fontsize=8, ha="center")
    ax.text(-3, (p.Y1 + p.Y2) / 2, "fondo della cornice", rotation=90, fontsize=8, color="w", va="center", ha="center")
    ax.text(p.profondita + 1.2, (p.Y1 + p.Y2) / 2, "vetro", rotation=90, fontsize=8, va="center", ha="center")
    ax.text(3, (p.Y1 + p.Y2) / 2, "qui si forma l'ombra", rotation=90, fontsize=8, va="center", color="#444")
    ax.set_xlim(-10, p.profondita + 12)
    ax.set_ylim(H + 8, p.y_soffitto - 10)
    ax.set_aspect("equal")
    ax.set_xlabel("profondità (mm)")
    ax.set_ylabel("mm sotto il LED")
    ax.set_title("Sezione verticale al centro della cornice", fontsize=10)
    fig.tight_layout()
    fig.savefig(percorso, dpi=150)
    plt.close(fig)


# ----------------------------------------------------------------------------
def main(argv=None):
    p = parametri(argv)
    os.makedirs(p.uscita, exist_ok=True)

    ombra, quadro = sagoma_nel_quadro(p)
    luce = zona_illuminata(ombra, quadro)
    isole = isole_staccate(luce, quadro)
    if isole:
        print(f"ATTENZIONE: {len(isole)} parti scure non toccano il bordo del quadro: nella mensola "
              "sarebbero pezzi staccati. Collegale al bordo con un ponticello nel disegno.")

    mesh = a_trimesh(costruisci_inserto(p, luce))
    mesh.export(os.path.join(p.uscita, "inserto.stl"))
    coperchio = a_trimesh(costruisci_coperchio(p))
    coperchio.export(os.path.join(p.uscita, "coperchio.stl"))

    info = {
        "cornice, misure interne (larg, alt, prof) mm": [p.larghezza, p.altezza, p.profondita],
        "inserto (larg, prof, alt) mm": [round(float(v), 1) for v in mesh.extents],
        "coperchio (larg, prof, alt) mm": [round(float(v), 1) for v in coperchio.extents],
        "LED: distanza della faccia dal fondo, mm": round(float(p.Lz), 2),
        "LED: inclinazione verso il basso, gradi": p.inclinazione_led,
        "LED: centro sotto il bordo alto interno, mm": p.led_sotto_soffitto,
        "mensola: faccia alta sotto il LED, mm": p.y0,
        "quadro: dove comincia e finisce l'immagine, mm sotto il LED": [round(p.Y1, 1), round(p.Y2, 1)],
        "fascia nera in alto (dal bordo interno), mm": round(p.y1 - p.y_soffitto, 1),
        "STL chiuso (watertight)": bool(mesh.is_watertight and coperchio.is_watertight),
        "pezzi staccati nella mensola": len(isole),
    }
    figure(p, ombra, quadro, luce, mesh, coperchio, info)
    with open(os.path.join(p.uscita, "riepilogo.json"), "w") as f:
        json.dump(info, f, indent=2, ensure_ascii=False)
    print(json.dumps(info, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
