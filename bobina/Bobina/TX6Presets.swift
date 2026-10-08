import Foundation

// MARK: - Le batterie pronte di Crea (rifatte l'8/10/2026): 20 ritmi classici
//
// Giampiero: «batterie trip hop, hip hop, elettronica, dance, non cose strane». Scritte a mano, in testo:
// una riga di 16 caratteri per traccia, «x» = colpo, «.» = niente. Le righe sono le tracce 1-4 del TX-6:
// cassa, rullante, percussione, charleston. I suoni sono i preset di suono (TX6Preset.builtIn) per nome;
// le tracce 5 e 6 (basso e melodia) non si toccano.

struct TX6DrumPreset: Identifiable {
    let name: String
    let group: String
    let bpm: Int
    /// cassa, rullante, percussione, charleston: 16 caratteri ciascuna.
    let rows: [String]
    /// Il preset di suono di ogni riga.
    let sounds: [String]
    /// Lo swing come sulle MPC (0,5 dritto, 0,66 terzina).
    var swing: Double = 0.5
    var id: String { name }

    func steps(_ row: Int) -> [Bool] { rows[row].map { $0 == "x" } }

    static let groups = ["trip hop", "hip hop", "elettronica", "dance"]

    static let all: [TX6DrumPreset] = [
        // trip hop: lenti e pesanti, rullante sul 2 e sul 4
        TX6DrumPreset(name: "Bristol", group: "trip hop", bpm: 88,
                      rows: ["x......x..x.....", "....x.......x...", "..............x.", "x.x.x.x.x.x.x.x."],
                      sounds: ["cassa sorda", "rullante pieno", "rimshot", "chiuso"]),
        TX6DrumPreset(name: "Lento", group: "trip hop", bpm: 82,
                      rows: ["x.........x.....", "....x.......x...", "......x.......x.", "x.x.x.x.x.x.x.x."],
                      sounds: ["cassa sorda", "rullante scuro", "shaker", "chiuso"]),
        TX6DrumPreset(name: "Vinile", group: "trip hop", bpm: 90,
                      rows: ["x..x......x..x..", "....x.......x...", "...x.......x....", "..x...x...x...x."],
                      sounds: ["cassa house", "rullante secco", "rimshot", "aperto"]),
        TX6DrumPreset(name: "Notte", group: "trip hop", bpm: 85,
                      rows: ["x.....x...x.....", "....x.......x...", "....x.......x...", "x.xxx.x.x.xxx.x."],
                      sounds: ["808 lunga", "rullante scuro", "battimani", "chiuso"]),
        TX6DrumPreset(name: "Polvere", group: "trip hop", bpm: 92,
                      rows: ["x......x.x......", "....x.......x..x", "......x........x", "x.x.x.x.x.x.x.x."],
                      sounds: ["cassa sorda", "rullante pieno", "rimshot", "chiuso"]),
        // hip hop: boom bap e dintorni
        TX6DrumPreset(name: "Boom bap", group: "hip hop", bpm: 90,
                      rows: ["x.......x.x.....", "....x.......x...", "................", "x.x.x.x.x.x.x.x."],
                      sounds: ["cassa corta", "rullante secco", "rimshot", "chiuso"]),
        TX6DrumPreset(name: "Old school", group: "hip hop", bpm: 95,
                      rows: ["x......x..x.....", "....x.......x...", "....x.......x...", "x.x.x.x.x.x.x.x."],
                      sounds: ["cassa house", "rullante pieno", "battimani", "chiuso"]),
        TX6DrumPreset(name: "Strada", group: "hip hop", bpm: 88,
                      rows: ["x..x......x..x..", "....x.......x...", "..........x.....", "x.x.x.xxx.x.x.xx"],
                      sounds: ["cassa sorda", "rullante secco", "rimshot", "chiuso"]),
        TX6DrumPreset(name: "Trap", group: "hip hop", bpm: 140,
                      rows: ["x......x..x.....", "........x.......", "................", "x.x.x.x.xxxx.x.x"],
                      sounds: ["808 lunga", "rullante pieno", "battimani", "chiuso"]),
        TX6DrumPreset(name: "Lo-fi", group: "hip hop", bpm: 82,
                      rows: ["x.....x...x.....", "....x.......x...", "..x.......x.....", "x.x.x.x.x.x.x.x."],
                      sounds: ["cassa sorda", "rullante scuro", "shaker", "chiuso"]),
        // elettronica
        TX6DrumPreset(name: "Electro", group: "elettronica", bpm: 120,
                      rows: ["x.....x...x.....", "....x.......x...", "................", "x.x.x.x.x.x.x.x."],
                      sounds: ["808 lunga", "battimani", "rimshot", "chiuso"]),
        TX6DrumPreset(name: "Breakbeat", group: "elettronica", bpm: 130,
                      rows: ["x.........x.....", "....x.......x...", "..x....x.....x..", "x.x.x.x.x.x.x.x."],
                      sounds: ["cassa corta", "rullante secco", "rimshot", "chiuso"]),
        TX6DrumPreset(name: "Minimal", group: "elettronica", bpm: 124,
                      rows: ["x...x...x...x...", "................", "....x.......x...", "..x...x...x...x."],
                      sounds: ["cassa techno", "rullante secco", "rimshot", "aperto"]),
        TX6DrumPreset(name: "Techno", group: "elettronica", bpm: 130,
                      rows: ["x...x...x...x...", "....x.......x...", "................", "..x...x...x...x."],
                      sounds: ["cassa techno", "battimani", "shaker", "aperto"]),
        TX6DrumPreset(name: "Dubstep", group: "elettronica", bpm: 140,
                      rows: ["x.........x.....", "........x.......", "......x.......x.", "x.x.x.x.x.x.x.x."],
                      sounds: ["808 lunga", "rullante pieno", "shaker", "chiuso"]),
        // dance: cassa dritta
        TX6DrumPreset(name: "House", group: "dance", bpm: 124,
                      rows: ["x...x...x...x...", "....x.......x...", "................", "..x...x...x...x."],
                      sounds: ["cassa house", "battimani", "rimshot", "aperto"]),
        TX6DrumPreset(name: "Deep house", group: "dance", bpm: 120,
                      rows: ["x...x...x...x...", "....x.......x...", "xxxxxxxxxxxxxxxx", "..x...x...x...x."],
                      sounds: ["cassa sorda", "battimani", "shaker", "aperto"]),
        TX6DrumPreset(name: "Disco", group: "dance", bpm: 118,
                      rows: ["x...x...x...x...", "....x.......x...", "..x...x...x...x.", "xxxxxxxxxxxxxxxx"],
                      sounds: ["cassa house", "rullante pieno", "aperto", "chiuso"]),
        TX6DrumPreset(name: "Club", group: "dance", bpm: 128,
                      rows: ["x...x...x...x...", "....x.......x...", "....x.......x...", "..x...x...x...x."],
                      sounds: ["cassa techno", "battimani", "rullante secco", "aperto"]),
        TX6DrumPreset(name: "Trance", group: "dance", bpm: 136,
                      rows: ["x...x...x...x...", "....x.......x...", "..x...x...x...x.", "xxxxxxxxxxxxxxxx"],
                      sounds: ["cassa techno", "battimani", "aperto", "chiuso"]),
    ]
}
