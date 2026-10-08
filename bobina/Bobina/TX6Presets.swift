import Foundation

// MARK: - Le batterie pronte di Crea (8/10/2026): 20 ritmi scuri, come nell'OP-Z
//
// Scritte a mano, in testo, così si leggono e si cambiano facilmente: una riga di 16 caratteri per traccia,
// «x» = colpo, «.» = niente. Le righe sono le tracce 1-4 del TX-6: cassa, rullante, percussione, charleston.
// I suoni sono i preset di suono (TX6Preset.builtIn) per nome; le tracce 5 e 6 (basso e melodia) non si toccano.

struct TX6DrumPreset: Identifiable {
    let name: String
    let group: String
    let bpm: Int
    /// cassa, rullante, percussione, charleston: 16 caratteri ciascuna.
    let rows: [String]
    /// Il preset di suono di ogni riga.
    let sounds: [String]
    var id: String { name }

    func steps(_ row: Int) -> [Bool] { rows[row].map { $0 == "x" } }

    static let groups = ["trip hop", "lenti e scuri", "horror", "industriale", "spezzati"]

    static let all: [TX6DrumPreset] = [
        // trip hop
        TX6DrumPreset(name: "Bassa marea", group: "trip hop", bpm: 84,
                      rows: ["x.....x..x......", "....x.......x...", "..........x.....", "x.x.x.x.x.x.x.x."],
                      sounds: ["cassa sorda", "rullante pieno", "rimshot", "chiuso"]),
        TX6DrumPreset(name: "Fumo denso", group: "trip hop", bpm: 80,
                      rows: ["x......x..x.....", "....x.......x..x", "......x.........", "x.xxx.x.x.xxx.x."],
                      sounds: ["808 lunga", "rullante scuro", "schiocco", "chiuso"]),
        TX6DrumPreset(name: "Vecchio vinile", group: "trip hop", bpm: 88,
                      rows: ["x..x......x.....", "....x.......x...", "..x...x...x...x.", "x.......x......."],
                      sounds: ["cassa sorda", "rullante secco", "shaker", "aperto"]),
        TX6DrumPreset(name: "Pioggia lenta", group: "trip hop", bpm: 76,
                      rows: ["x.......x.x.....", "....x.......x...", "x..x..x..x..x...", ".......x........"],
                      sounds: ["cassa lontana", "rullante pieno", "legno", "aperto"]),
        TX6DrumPreset(name: "Seconda mano", group: "trip hop", bpm: 92,
                      rows: ["x....x....x..x..", "....x.......x...", "xxxxxxxxxxxxxxxx", "........x......."],
                      sounds: ["cassa corta", "rullante secco", "shaker", "piatto"]),
        TX6DrumPreset(name: "Sottopassaggio", group: "trip hop", bpm: 82,
                      rows: ["x.........x.....", "....x.......x...", "...x.......x....", "x.x.x.x.x.x.x.x."],
                      sounds: ["808 lunga", "rullante lontano", "battimani", "chiuso"]),
        // lenti e scuri
        TX6DrumPreset(name: "Corteo", group: "lenti e scuri", bpm: 70,
                      rows: ["x.......x.......", "............x...", "x...x...x...x...", "......x.......x."],
                      sounds: ["cassa lontana", "rullante scuro", "taiko", "piatto"]),
        TX6DrumPreset(name: "Cuore", group: "lenti e scuri", bpm: 60,
                      rows: ["xx......xx......", "................", "................", "........x......."],
                      sounds: ["battito", "rullante lontano", "legno", "fruscio"]),
        TX6DrumPreset(name: "Marcia", group: "lenti e scuri", bpm: 90,
                      rows: ["x...x...x...x...", "....x.......x.xx", "..x...x...x...x.", "x..............."],
                      sounds: ["cassa techno", "rullante pieno", "schiocco", "piatto"]),
        TX6DrumPreset(name: "Veglia", group: "lenti e scuri", bpm: 66,
                      rows: ["x...............", "........x.......", "x...x...x...x...", "..x.......x....."],
                      sounds: ["cassa lontana", "rullante lontano", "metallo", "chiuso"]),
        // horror
        TX6DrumPreset(name: "Scricchiolio", group: "horror", bpm: 72,
                      rows: ["x.......x.......", "..............x.", "....x.......x...", "...x......x....."],
                      sounds: ["cassa sorda", "frusta", "legno", "fruscio"]),
        TX6DrumPreset(name: "Lancette", group: "horror", bpm: 96,
                      rows: ["x...............", "........x.......", "x.x.x.x.x.x.x.x.", "....x.......x..."],
                      sounds: ["battito", "rimshot", "legno", "chiuso"]),
        TX6DrumPreset(name: "Fiato sul collo", group: "horror", bpm: 110,
                      rows: ["x.x.x.x.x.x.x.x.", "................", "....x.......x...", "...............x"],
                      sounds: ["battito", "rullante scuro", "metallo", "aperto"]),
        TX6DrumPreset(name: "Fuga", group: "horror", bpm: 140,
                      rows: ["x..x..x.x..x..x.", "....x.......x...", "xxxxxxxxxxxxxxxx", "x.......x......."],
                      sounds: ["cassa corta", "rullante secco", "shaker", "piatto"]),
        // industriale
        TX6DrumPreset(name: "Officina", group: "industriale", bpm: 120,
                      rows: ["x...x...x...x...", "....x.......x...", "..x...x...x...x.", "x.x.....x.x....."],
                      sounds: ["cassa techno", "rullante pieno", "metallo", "chiuso"]),
        TX6DrumPreset(name: "Pressa", group: "industriale", bpm: 128,
                      rows: ["x...x...x...x...", "........x.......", "x.xxx.xxx.xxx.xx", "....x.......x..."],
                      sounds: ["cassa techno", "rullante scuro", "schiocco", "aperto"]),
        TX6DrumPreset(name: "Cantiere", group: "industriale", bpm: 100,
                      rows: ["x.....x.x.......", "....x.......x...", "x.x.x.x.x.x.x.x.", "..x.......x....."],
                      sounds: ["cassa sorda", "rullante pieno", "metallo", "aperto"]),
        // spezzati
        TX6DrumPreset(name: "Vetri rotti", group: "spezzati", bpm: 95,
                      rows: ["x..x...x..x.....", "....x..x....x.x.", "x.x..x.x.x..x.x.", ".......x......x."],
                      sounds: ["cassa corta", "rullante secco", "shaker", "aperto"]),
        TX6DrumPreset(name: "Inciampo", group: "spezzati", bpm: 86,
                      rows: ["x.........x.....", "....x...........", "......x.......x.", "........x......."],
                      sounds: ["808 lunga", "rullante pieno", "taiko", "piatto"]),
        TX6DrumPreset(name: "Crepa", group: "spezzati", bpm: 104,
                      rows: ["x.x....x..x..x..", "....x.....x.x...", "x..x.x..x..x.x..", "...x.......x...x"],
                      sounds: ["cassa corta", "rimshot", "legno", "chiuso"]),
    ]
}
