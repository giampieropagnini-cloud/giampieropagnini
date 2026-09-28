"""Sagoma dell'Oni (demone giapponese) disegnata con primitive geometriche.

Sistema di coordinate: u orizzontale (0 = centro), v verso il basso.
v = 0 e' il bordo alto della zona immagine, v = 1 il bordo basso.
Le corna escono oltre il bordo alto e le spalle oltre quello basso: e' voluto,
cosi' la sagoma e' attaccata al resto della maschera e il pezzo stampato
resta tutto in un corpo unico.

Restituisce un poligono shapely: la parte "piena" e' l'ombra, i buchi
(occhi, narici, bocca) sono le zone dove la luce passa.
"""
import numpy as np
from shapely.geometry import Polygon, Point
from shapely.ops import unary_union
from shapely import affinity


def bezier(p0, p1, p2, p3, n=48):
    t = np.linspace(0, 1, n)[:, None]
    p0, p1, p2, p3 = map(np.asarray, (p0, p1, p2, p3))
    return (1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * p1 + 3 * (1 - t) * t ** 2 * p2 + t ** 3 * p3


def catmull_rom_chiusa(punti, n=24):
    """Curva chiusa e morbida che passa per tutti i punti dati."""
    p = np.asarray(punti, float)
    out = []
    k = len(p)
    for i in range(k):
        p0, p1, p2, p3 = p[i - 1], p[i], p[(i + 1) % k], p[(i + 2) % k]
        t = np.linspace(0, 1, n, endpoint=False)[:, None]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t ** 2
                          + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    return Polygon(np.vstack(out)).buffer(0)


def tratto_affusolato(linea, w0, w1):
    """Poligono lungo una linea centrale, largo w0 all'inizio e w1 alla fine."""
    c = np.asarray(linea, float)
    d = np.gradient(c, axis=0)
    d /= np.linalg.norm(d, axis=1, keepdims=True)
    nrm = np.stack([-d[:, 1], d[:, 0]], axis=1)
    w = np.linspace(w0, w1, len(c))[:, None] / 2
    return Polygon(np.vstack([c + nrm * w, (c - nrm * w)[::-1]])).buffer(0)


def fiamma(base, punta, larghezza, curva=0.0):
    """Ciocca/aculeo curvo: triangolo con i lati leggermente incurvati."""
    b = np.asarray(base, float)
    p = np.asarray(punta, float)
    asse = p - b
    lung = np.linalg.norm(asse)
    n = np.array([-asse[1], asse[0]]) / lung
    c1 = b + asse * 0.5 + n * curva * lung
    lato_a = bezier(b + n * larghezza / 2, c1 + n * larghezza * 0.25, c1 + n * larghezza * 0.1, p, 20)
    lato_b = bezier(p, c1 - n * larghezza * 0.1, c1 - n * larghezza * 0.25, b - n * larghezza / 2, 20)
    return Polygon(np.vstack([lato_a, lato_b])).buffer(0)


def specchia(g):
    return affinity.scale(g, xfact=-1, yfact=1, origin=(0, 0))


def coppia(g):
    return unary_union([g, specchia(g)])


def sagoma_oni():
    pezzi = []

    # --- testa: fronte larga, zigomi, mascella quadrata
    testa = catmull_rom_chiusa([
        (0.00, 0.17), (0.17, 0.19), (0.27, 0.27), (0.30, 0.40), (0.31, 0.52),
        (0.27, 0.66), (0.20, 0.80), (0.09, 0.88), (0.00, 0.89),
        (-0.09, 0.88), (-0.20, 0.80), (-0.27, 0.66), (-0.31, 0.52),
        (-0.30, 0.40), (-0.27, 0.27), (-0.17, 0.19),
    ])
    pezzi.append(testa)

    # --- corna: grosse, curve verso l'esterno, tagliate dal bordo alto.
    #     Sono anche i "ponti" che tengono la sagoma attaccata alla maschera.
    linea_corno = bezier((0.13, 0.27), (0.17, 0.12), (0.30, 0.10), (0.36, -0.10), 60)
    corno = tratto_affusolato(linea_corno, 0.15, 0.055)
    # anelli sul corno: piccole tacche sul bordo esterno
    for t in (0.35, 0.55, 0.75):
        i = int(t * (len(linea_corno) - 1))
        c = linea_corno[i]
        d = linea_corno[min(i + 1, len(linea_corno) - 1)] - linea_corno[i - 1]
        n = np.array([d[1], -d[0]]) / np.linalg.norm(d)
        larg = 0.15 + (0.055 - 0.15) * t
        tacca = Point(*(c + n * larg * 0.62)).buffer(0.018)
        corno = corno.difference(tacca)
    pezzi.append(coppia(corno))

    # --- capelli selvaggi: corona di ciocche a fiamma sopra la fronte
    for (bx, by, px, py, w, cv) in [
        (0.00, 0.20, 0.00, 0.03, 0.08, 0.00),
        (0.07, 0.20, 0.10, 0.05, 0.07, -0.10),
        (0.25, 0.24, 0.40, 0.14, 0.09, 0.12),
        (0.28, 0.33, 0.45, 0.28, 0.09, 0.10),
        (0.29, 0.42, 0.47, 0.44, 0.09, 0.08),
        (0.29, 0.50, 0.44, 0.58, 0.08, 0.06),
    ]:
        pezzi.append(coppia(fiamma((bx, by), (px, py), w, cv)))

    # --- orecchie a punta che spuntano tra i capelli
    orecchio = Polygon([(0.28, 0.43), (0.40, 0.36), (0.33, 0.50), (0.28, 0.52)])
    pezzi.append(coppia(orecchio))

    # --- barba a punte sotto il mento
    for (bx, px, py, w, cv) in [
        (0.05, 0.05, 1.00, 0.09, 0.00),
        (0.13, 0.17, 0.99, 0.09, -0.05),
        (0.20, 0.28, 0.95, 0.08, -0.10),
    ]:
        pezzi.append(coppia(fiamma((bx, 0.82), (px, py), w, cv)))

    # --- collo e spalle: escono dal bordo basso
    busto = catmull_rom_chiusa([
        (0.00, 0.86), (0.075, 0.87), (0.12, 0.97), (0.46, 1.03), (0.60, 1.20),
        (0.00, 1.25), (-0.60, 1.20), (-0.46, 1.03), (-0.12, 0.97), (-0.075, 0.87),
    ])
    pezzi.append(busto)

    oni = unary_union(pezzi)

    # --- occhi: mandorle arrabbiate (luce), con pupilla verticale da demone.
    #     Sulla mensola tutto cio' che e' orizzontale viene schiacciato di circa 9 volte:
    #     gli occhi devono essere alti almeno ~0,08 e le pupille strette ma verticali.
    occhio = Polygon(np.vstack([
        [(0.255, 0.325)],
        bezier((0.255, 0.325), (0.25, 0.43), (0.12, 0.48), (0.045, 0.415), 28),
        [(0.045, 0.415)],
    ])).buffer(0)
    # il bordo superiore e' dritto e inclinato verso il naso: sguardo cattivo
    pupilla = Polygon([(0.138, 0.33), (0.172, 0.33), (0.165, 0.43), (0.155, 0.455), (0.145, 0.43)])
    occhio = occhio.difference(pupilla)
    luce = [coppia(occhio)]

    # --- narici svasate
    narice = affinity.rotate(affinity.scale(Point(0.055, 0.55).buffer(0.03), 1.15, 0.95), -25)
    luce.append(coppia(narice))

    # --- bocca spalancata con zanne
    bocca = catmull_rom_chiusa([
        (0.00, 0.625), (0.12, 0.605), (0.22, 0.585), (0.255, 0.62), (0.20, 0.72),
        (0.10, 0.775), (0.00, 0.785), (-0.10, 0.775), (-0.20, 0.72), (-0.255, 0.62),
        (-0.22, 0.585), (-0.12, 0.605),
    ])
    denti = []
    # zanne superiori, lunghe
    denti.append(coppia(Polygon([(0.11, 0.58), (0.19, 0.57), (0.15, 0.70)])))
    # zanne inferiori, che salgono
    denti.append(coppia(Polygon([(0.03, 0.80), (0.12, 0.79), (0.075, 0.66)])))
    # dentini superiori
    denti.append(coppia(Polygon([(0.00, 0.60), (0.07, 0.60), (0.035, 0.665)])))
    bocca = bocca.difference(unary_union(denti))
    luce.append(bocca)

    oni = oni.difference(unary_union(luce))
    return oni.buffer(0)


if __name__ == "__main__":
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from shapely.plotting import plot_polygon

    s = sagoma_oni()
    fig, ax = plt.subplots(figsize=(6, 6))
    plot_polygon(s, ax=ax, add_points=False, facecolor="black", edgecolor="none")
    ax.add_patch(plt.Rectangle((-0.5, 0), 1, 1, fill=False, ec="red", lw=1))
    ax.set_xlim(-0.6, 0.6)
    ax.set_ylim(1.15, -0.15)
    ax.set_aspect("equal")
    fig.savefig("out/_prova_sagoma.png", dpi=110)
    print(s.geom_type, s.area)
