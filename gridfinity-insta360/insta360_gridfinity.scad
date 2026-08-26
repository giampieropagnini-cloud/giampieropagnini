// ================================================================
//  Contenitori Gridfinity per camere Insta360
//
//  - Insta360 GO 3S     (dentro l'Action Pod, schermo chiuso)  bin 2x2, 6 unita' (42 mm)
//  - Insta360 Ace Pro 2 (schermo chiuso, lente in su)          bin 2x2, 7 unita' (49 mm)
//  - Insta360 X6        (sdraiata, vasca di scarico per le
//                        lenti che sporgono dai due lati)      bin 3x2, 7 unita' (49 mm)
//
//  Le camere restano SOTTO il bordo del bin (mai sporgenti),
//  cosi' la valigetta Gridfinity si chiude senza toccarle.
//
//  Standard Gridfinity: griglia da 42 mm, altezze in unita' da 7 mm,
//  piede standard (si aggancia a qualsiasi baseplate), senza labbro
//  di impilamento (bordo piatto, altezza esatta = unita' x 7 mm).
//
//  Per generare gli STL da riga di comando:
//    openscad -o go3s.stl    -D 'modello="go3s"'    insta360_gridfinity.scad
//    openscad -o acepro2.stl -D 'modello="acepro2"' insta360_gridfinity.scad
//    openscad -o x6.stl      -D 'modello="x6"'      insta360_gridfinity.scad
// ================================================================

/* [Scelta del modello] */
// quale bin generare ("tutti" li mostra affiancati, per l'anteprima)
modello = "tutti"; // ["tutti", "go3s", "acepro2", "x6"]

/* [Opzioni comuni] */
// fori nel fondo per magneti 6x2 mm (standard Gridfinity); innocui se non usi i magneti
fori_magneti = true;
// gioco totale della tasca attorno alla camera, in mm (1.5 = entra ed esce senza forzare)
gioco_tasca = 1.5;
// quanto il punto piu' alto della camera resta sotto il bordo del bin (mm)
margine_sotto_il_bordo = 1.5;
// smusso d'invito sul bordo della tasca (mm)
smusso_tasca = 1.2;
// scrive il nome della camera inciso sul fondo della tasca
incidi_nomi = true;

/* [Insta360 GO 3S - Action Pod chiuso] */
// misure ufficiali Action Pod: 63.5 x 47.6 x 29.5 mm
go3s_lunghezza = 63.5;
go3s_larghezza = 47.6;
// 29.5 di Pod + 1.5 di margine per la lente della camera che sporge dal Pod
go3s_spessore = 31.0;
// altezza del bin in unita' Gridfinity (6 x 7 = 42 mm)
go3s_unita = 6;

/* [Insta360 Ace Pro 2 - schermo chiuso] */
// misure ufficiali: 71.9 x 52.15 x 38.0 mm (si ripone con la lente in su)
acepro2_lunghezza = 71.9;
acepro2_larghezza = 52.15;
acepro2_spessore = 38.0;
// altezza del bin in unita' Gridfinity (7 x 7 = 49 mm)
acepro2_unita = 7;

/* [Insta360 X6] */
// misure ufficiali del corpo: 100.0 x 50.0 x 26.4 mm (196 g)
x6_lunghezza = 100.0;
x6_larghezza = 50.0;
x6_spessore_corpo = 26.4;
// quanto OGNI lente sporge dal corpo (spessore totale con lenti ~40.6 mm)
x6_sporgenza_lente = 7.1;
// vasca di scarico nel fondo: la camera appoggia sul corpo e la lente
// resta sospesa nel vuoto, senza toccare la plastica
x6_vasca_lunghezza = 76;
x6_vasca_larghezza = 44;
// altezza del bin in unita' Gridfinity (7 x 7 = 49 mm)
x6_unita = 7;

/* [Hidden] */
$fn = 96;
passo = 42;          // griglia Gridfinity
unita_h = 7;         // una unita' di altezza Gridfinity
gioco_bin = 0.25;    // gioco del bin dentro la baseplate (per lato)
r_esterno = 3.75;    // raggio degli angoli del bin
base_h = 4.75;       // altezza del profilo del piede standard
fondo_minimo = 6.2;  // spessore minimo di plastica sotto la tasca
eps = 0.02;

// ---------------- primitive ----------------

// rettangolo arrotondato centrato
module rrect(x, y, r) {
    offset(r = r) square([x - 2 * r, y - 2 * r], center = true);
}

// piede Gridfinity standard di una cella (profilo 0.8 / 1.8 / 2.15, pieno)
module piede() {
    hull() {
        linear_extrude(eps) rrect(35.6, 35.6, 0.8);
        translate([0, 0, 0.8]) linear_extrude(eps) rrect(37.2, 37.2, 1.6);
    }
    translate([0, 0, 0.8]) linear_extrude(1.8 + eps) rrect(37.2, 37.2, 1.6);
    hull() {
        translate([0, 0, 2.6]) linear_extrude(eps) rrect(37.2, 37.2, 1.6);
        translate([0, 0, base_h - eps]) linear_extrude(eps) rrect(41.5, 41.5, r_esterno);
    }
}

// corpo pieno del bin: piedi + blocco arrotondato (le tasche vengono scavate dopo)
module corpo(nx, ny, h_tot) {
    for (ix = [0 : nx - 1], iy = [0 : ny - 1])
        translate([(ix - (nx - 1) / 2) * passo, (iy - (ny - 1) / 2) * passo, 0])
            piede();
    translate([0, 0, base_h - eps])
        linear_extrude(h_tot - base_h + eps)
            rrect(nx * passo - 2 * gioco_bin, ny * passo - 2 * gioco_bin, r_esterno);
}

// 4 fori per magneti 6x2 in ogni cella (diametro 6.5, profondita' 2.4, interasse 26)
module scavo_magneti(nx, ny) {
    for (ix = [0 : nx - 1], iy = [0 : ny - 1], sx = [-1, 1], sy = [-1, 1])
        translate([(ix - (nx - 1) / 2) * passo + sx * 13,
                   (iy - (ny - 1) / 2) * passo + sy * 13,
                   -eps])
            cylinder(d = 6.5, h = 2.4 + eps);
}

// tasca della camera: vano + smusso d'invito + due prese per le dita
// prese_sui_lati = true -> prese sui lati lunghi; false -> sulle due estremita'
module scavo_tasca(tl, tp, r, z_fondo, h_tot, presa_d, prese_sui_lati, presa_z) {
    // vano principale
    translate([0, 0, z_fondo]) linear_extrude(h_tot) rrect(tl, tp, r);
    // smusso d'invito sul bordo superiore
    hull() {
        translate([0, 0, h_tot - smusso_tasca]) linear_extrude(eps) rrect(tl, tp, r);
        translate([0, 0, h_tot])
            linear_extrude(eps)
                rrect(tl + 2 * smusso_tasca, tp + 2 * smusso_tasca, r + smusso_tasca);
    }
    // prese per le dita (mezzelune verticali scavate nelle pareti)
    for (s = [-1, 1])
        translate(prese_sui_lati ? [0, s * tp / 2, presa_z] : [s * tl / 2, 0, presa_z])
            cylinder(d = presa_d, h = h_tot);
}

// nome inciso 0.6 mm nel fondo
module incisione(testo, z) {
    if (incidi_nomi)
        translate([0, 0, z - 0.6])
            linear_extrude(1)
                text(testo, size = 8, font = "Liberation Sans:style=Bold",
                     halign = "center", valign = "center");
}

// ---------------- i tre bin ----------------

module bin_go3s() {
    h_tot = go3s_unita * unita_h;                       // 42 mm
    tl = go3s_lunghezza + gioco_tasca;
    tp = go3s_larghezza + gioco_tasca;
    z_fondo = max(fondo_minimo, h_tot - go3s_spessore - margine_sotto_il_bordo);
    assert(z_fondo + go3s_spessore <= h_tot, "GO 3S: aumentare go3s_unita");
    difference() {
        corpo(2, 2, h_tot);
        scavo_tasca(tl, tp, 8, z_fondo, h_tot, 22, true, z_fondo + 5);
        incisione("GO 3S", z_fondo);
        if (fori_magneti) scavo_magneti(2, 2);
    }
}

module bin_acepro2() {
    h_tot = acepro2_unita * unita_h;                    // 49 mm
    tl = acepro2_lunghezza + gioco_tasca;
    tp = acepro2_larghezza + gioco_tasca;
    z_fondo = max(fondo_minimo, h_tot - acepro2_spessore - margine_sotto_il_bordo);
    assert(z_fondo + acepro2_spessore <= h_tot, "Ace Pro 2: aumentare acepro2_unita");
    difference() {
        corpo(2, 2, h_tot);
        scavo_tasca(tl, tp, 8, z_fondo, h_tot, 22, true, z_fondo + 5);
        incisione("ACE PRO 2", z_fondo);
        if (fori_magneti) scavo_magneti(2, 2);
    }
}

module bin_x6() {
    h_tot = x6_unita * unita_h;                         // 49 mm
    tl = x6_lunghezza + gioco_tasca;
    tp = x6_larghezza + gioco_tasca;
    prof_vasca = x6_sporgenza_lente + 1.0;              // lente sospesa con 1 mm d'aria
    z_fondo = max(fondo_minimo + prof_vasca,
                  h_tot - (x6_spessore_corpo + x6_sporgenza_lente) - margine_sotto_il_bordo);
    assert(z_fondo + x6_spessore_corpo + x6_sporgenza_lente <= h_tot - 0.5,
           "X6: aumentare x6_unita");
    difference() {
        corpo(3, 2, h_tot);
        scavo_tasca(tl, tp, 8, z_fondo, h_tot, 18, false, z_fondo);
        // vasca di scarico per le lenti (vale per entrambi i versi di inserimento)
        translate([0, 0, z_fondo - prof_vasca])
            linear_extrude(prof_vasca + 1)
                rrect(x6_vasca_lunghezza, x6_vasca_larghezza,
                      min(x6_vasca_lunghezza, x6_vasca_larghezza) / 2 - 0.05);
        incisione("X6", z_fondo - prof_vasca);
        if (fori_magneti) scavo_magneti(3, 2);
    }
}

// ---------------- selezione ----------------

if (modello == "go3s") bin_go3s();
else if (modello == "acepro2") bin_acepro2();
else if (modello == "x6") bin_x6();
else {
    // anteprima con i tre bin affiancati
    translate([-114, 0, 0]) bin_go3s();
    bin_acepro2();
    translate([135, 0, 0]) bin_x6();
}
