import Foundation

// MARK: - Le sequenze pronte di Crea (8/10/2026): 20 batterie e 20 melodie scure
//
// Scritte a mano, in testo, così si leggono e si cambiano facilmente:
// - batteria: una riga di 16 caratteri per traccia, «x» = colpo, «.» = niente;
// - melodie: un gettone per passo, separati da spazi. «.» = niente, «A2» = una nota (do centrale = C4),
//   «A3m» = un accordo (M maggiore, m minore, m7, 7, dim, dim7, aug, sus, 5, mM7, hor = seconda minore + tritono).
// Il basso dell'OP-Z è monofonico: lì vanno solo note singole.

struct OPZDrumPreset: Identifiable {
    let name: String
    let group: String
    let bpm: Int
    /// kick, snare, perc, sample: 16 caratteri ciascuna.
    let rows: [String]
    /// Il suono (1-24 del kit) di ogni riga.
    let sounds: [Int]
    var id: String { name }

    func steps(_ row: Int) -> [Bool] { rows[row].map { $0 == "x" } }
}

struct OPZMelodyPreset: Identifiable {
    let name: String
    let group: String
    let bpm: Int
    var bass = ""
    var lead = ""
    var arp = ""
    var chord = ""
    /// Durata delle note di bass, lead, arp, chord (0 = tenuta fino alla nota dopo).
    var gates = [2, 2, 0, 0]
    /// Se c'è l'arp: la figura e la velocità dell'arpeggio di Bobina.
    var arpStyle = OPZArpStyle.up
    var arpRate = 2
    var arpOctaves = 1
    var id: String { name }

    /// I passi di una traccia (5-8), già in note MIDI. Vuoto = la traccia non c'è.
    func steps(track: Int) -> [[Int]] {
        let text = [bass, lead, arp, chord][track - 5]
        return OPZNoteText.parse(text)
    }
}

/// Legge i gettoni delle melodie: note («F#3»), accordi («A3m7»), pause («.»).
enum OPZNoteText {
    private static let letters: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
    private static let chords: [String: [Int]] = [
        "M": [0, 4, 7], "m": [0, 3, 7], "m7": [0, 3, 7, 10], "7": [0, 4, 7, 10], "dim": [0, 3, 6],
        "dim7": [0, 3, 6, 9], "aug": [0, 4, 8], "sus": [0, 5, 7], "5": [0, 7], "mM7": [0, 3, 7, 11],
        "hor": [0, 1, 6],
    ]

    static func parse(_ text: String) -> [[Int]] {
        text.split(separator: " ").map { token(String($0)) }
    }

    static func token(_ t: String) -> [Int] {
        guard t != ".", let first = t.first, let base = letters[first] else { return [] }
        var rest = t.dropFirst()
        var semitone = base
        if rest.first == "#" { semitone += 1; rest = rest.dropFirst() } else if rest.first == "b" { semitone -= 1; rest = rest.dropFirst() }
        guard let o = rest.first, let octave = o.wholeNumberValue else { return [] }
        let root = 12 * (octave + 1) + semitone
        let suffix = String(rest.dropFirst())
        if suffix.isEmpty { return [root] }
        return (chords[suffix] ?? [0]).map { root + $0 }
    }
}

extension OPZDrumPreset {
    static let groups = ["trip hop", "lenti e scuri", "horror", "industriale", "spezzati"]

    static let all: [OPZDrumPreset] = [
        // trip hop
        OPZDrumPreset(name: "Bristol", group: "trip hop", bpm: 84,
                      rows: ["x.....x..x......", "....x.......x...", "x.x.x.x.x.x.x.x.", "..............x."], sounds: [1, 1, 1, 5]),
        OPZDrumPreset(name: "Massiccio", group: "trip hop", bpm: 80,
                      rows: ["x......x..x.....", "....x.......x..x", "x.xxx.x.x.xxx.x.", "................"], sounds: [2, 3, 2, 1]),
        OPZDrumPreset(name: "Vinile", group: "trip hop", bpm: 88,
                      rows: ["x..x......x.....", "....x.......x...", "..x...x...x...x.", "x.......x......."], sounds: [3, 2, 4, 7]),
        OPZDrumPreset(name: "Fumo lento", group: "trip hop", bpm: 76,
                      rows: ["x.......x.x.....", "....x.......x...", "x..x..x..x..x...", ".......x........"], sounds: [1, 5, 3, 9]),
        OPZDrumPreset(name: "Polvere", group: "trip hop", bpm: 92,
                      rows: ["x....x....x..x..", "....x.......x...", "xxxxxxxxxxxxxxxx", "........x......."], sounds: [4, 1, 6, 2]),
        OPZDrumPreset(name: "Mezzanotte", group: "trip hop", bpm: 82,
                      rows: ["x.........x.....", "....x.......x...", "x.x.x.x.x.x.x.x.", "...x.......x...."], sounds: [2, 4, 1, 11]),
        // lenti e scuri
        OPZDrumPreset(name: "Funerale", group: "lenti e scuri", bpm: 70,
                      rows: ["x.......x.......", "............x...", "x...x...x...x...", "......x.......x."], sounds: [5, 6, 8, 3]),
        OPZDrumPreset(name: "Battito", group: "lenti e scuri", bpm: 60,
                      rows: ["x.x.......x.x...", "................", "................", "........x......."], sounds: [1, 1, 1, 13]),
        OPZDrumPreset(name: "Marcia nera", group: "lenti e scuri", bpm: 90,
                      rows: ["x...x...x...x...", "....x.......x.xx", "..x...x...x...x.", "x..............."], sounds: [6, 7, 5, 4]),
        OPZDrumPreset(name: "Ultimo respiro", group: "lenti e scuri", bpm: 66,
                      rows: ["x...............", "........x.......", "x...x...x...x...", "..x.......x....."], sounds: [7, 8, 2, 15]),
        // horror
        OPZDrumPreset(name: "Passi nel buio", group: "horror", bpm: 72,
                      rows: ["x.......x.......", "..............x.", "....x.......x...", "................"], sounds: [8, 9, 10, 1]),
        OPZDrumPreset(name: "Orologio", group: "horror", bpm: 96,
                      rows: ["x...............", "........x.......", "x.x.x.x.x.x.x.x.", "....x.......x..."], sounds: [9, 2, 12, 6]),
        OPZDrumPreset(name: "Tensione", group: "horror", bpm: 110,
                      rows: ["x.x.x.x.x.x.x.x.", "................", "....x.......x...", "...............x"], sounds: [10, 1, 7, 17]),
        OPZDrumPreset(name: "Inseguimento", group: "horror", bpm: 140,
                      rows: ["x..x..x.x..x..x.", "....x.......x...", "xxxxxxxxxxxxxxxx", "x.......x......."], sounds: [11, 10, 3, 8]),
        // industriale
        OPZDrumPreset(name: "Fabbrica", group: "industriale", bpm: 120,
                      rows: ["x...x...x...x...", "....x.......x...", "..x...x...x...x.", "x.x.....x.x....."], sounds: [12, 11, 9, 10]),
        OPZDrumPreset(name: "Acciaio", group: "industriale", bpm: 128,
                      rows: ["x...x...x...x...", "........x.......", "x.xxx.xxx.xxx.xx", "....x.......x..."], sounds: [13, 12, 11, 19]),
        OPZDrumPreset(name: "Cemento", group: "industriale", bpm: 100,
                      rows: ["x.....x.x.......", "....x.......x...", "x.x.x.x.x.x.x.x.", "..x.......x....."], sounds: [14, 13, 4, 12]),
        // spezzati
        OPZDrumPreset(name: "Spezzato", group: "spezzati", bpm: 95,
                      rows: ["x..x...x..x.....", "....x..x....x.x.", "x.x..x.x.x..x.x.", ".......x......x."], sounds: [15, 14, 13, 14]),
        OPZDrumPreset(name: "Nebbia", group: "spezzati", bpm: 86,
                      rows: ["x.........x.....", "....x...........", "......x.......x.", "........x......."], sounds: [16, 15, 14, 21]),
        OPZDrumPreset(name: "Crepe", group: "spezzati", bpm: 104,
                      rows: ["x.x....x..x..x..", "....x.....x.x...", "x..x.x..x..x.x..", "...x.......x...x"], sounds: [17, 16, 15, 16]),
    ]
}

extension OPZMelodyPreset {
    static let groups = ["trip hop", "dark", "horror", "cinema"]

    static let all: [OPZMelodyPreset] = [
        // trip hop
        OPZMelodyPreset(name: "Pioggia", group: "trip hop", bpm: 82,
                        bass: "A2 . . A2 . . . . E2 . . . G2 . . . F2 . . F2 . . . . C3 . . . E2 . . .",
                        lead: ". . . . . . . . E5 . . . D5 . . . . . . . . . . . C5 . . . B4 . . .",
                        chord: "A3m7 . . . . . . . . . . . . . . . F3M . . . . . . . . . . . . . . .",
                        gates: [2, 4, 0, 0]),
        OPZMelodyPreset(name: "Fumo", group: "trip hop", bpm: 78,
                        bass: "D2 . . . . . D2 . A2 . . . C3 . . . Bb2 . . . . . Bb2 . F2 . . . A2 . . .",
                        lead: ". . . . A4 . . . . . F4 . . . . . . . . . E4 . . . . . D4 . . . . .",
                        chord: "D3m7 . . . . . . . . . . . . . . . Bb2M . . . . . . . . . . . . . . .",
                        gates: [2, 2, 0, 0]),
        OPZMelodyPreset(name: "Vinile", group: "trip hop", bpm: 88,
                        bass: "E2 . . E2 . . G2 . . . E2 . D2 . . . A2 . . A2 . . C3 . . . A2 . G2 . . .",
                        arp: "E4m7 . . . . . . . . . . . . . . . A3M . . . . . . . . . . . . . . .",
                        chord: "E3m7 . . . . . . . . . . . . . . . A3M . . . . . . . . . . . . . . .",
                        gates: [2, 2, 0, 0], arpStyle: .upDown, arpRate: 2),
        OPZMelodyPreset(name: "Notte lenta", group: "trip hop", bpm: 76,
                        bass: "C2 . . . . . . . Ab2 . . . . . . . Eb2 . . . . . . . G2 . . . . . G2 .",
                        lead: ". . Eb5 . . . D5 . . . C5 . . . Ab4 . . . G4 . . . Bb4 . . . B4 . . . D5 .",
                        chord: "C3m . . . . . . . Ab2M . . . . . . . Eb3M . . . . . . . G2M . . . . . . .",
                        gates: [0, 2, 0, 0]),
        OPZMelodyPreset(name: "Specchio", group: "trip hop", bpm: 84,
                        bass: "F2 . . F2 . . Ab2 . . . C3 . . . Eb2 . Db2 . . Db2 . . F2 . . . Ab2 . . . C3 .",
                        arp: "F4m7 . . . . . . . . . . . . . . . Db4M . . . . . . . . . . . . . . .",
                        chord: "F3m7 . . . . . . . . . . . . . . . Db3M . . . . . . . . . . . . . . .",
                        gates: [2, 2, 0, 0], arpStyle: .down, arpRate: 2),
        // dark
        OPZMelodyPreset(name: "Abisso", group: "dark", bpm: 66,
                        bass: "A2 . . . . . . . . . . . . . . . Bb2 . . . . . . . . . . . . . . .",
                        lead: ". . . . E5 . . . F5 . . . E5 . . . . . . . D5 . . . C5 . . . Bb4 . . .",
                        chord: "A2m . . . . . . . . . . . . . . . Bb2M . . . . . . . . . . . . . . .",
                        gates: [0, 4, 0, 0]),
        OPZMelodyPreset(name: "Cattedrale", group: "dark", bpm: 70,
                        bass: "D2 . . . . . . . Bb2 . . . . . . . G2 . . . . . . . A2 . . . . . . .",
                        lead: "A4 . . . D5 . . . F5 . . . E5 . . . D5 . . . Bb4 . . . C#5 . . . A4 . . .",
                        chord: "D3m . . . . . . . Bb2M . . . . . . . G2m . . . . . . . A27 . . . . . . .",
                        gates: [0, 4, 0, 0]),
        OPZMelodyPreset(name: "Lutto", group: "dark", bpm: 62,
                        bass: "B2 . . . . . . . . . . . F#2 . . . G2 . . . . . . . . . . . A2 . . .",
                        arp: "B3m . . . . . . . . . . . . . . . G3M . . . . . . . . . . . . . . .",
                        chord: "B2m . . . . . . . . . . . . . . . G2M . . . . . . . . . . . . . . .",
                        gates: [0, 2, 0, 0], arpStyle: .up, arpRate: 4),
        OPZMelodyPreset(name: "Cenere", group: "dark", bpm: 72,
                        bass: "G2 . . . . . G2 . . . Bb2 . . . . . Eb2 . . . . . Eb2 . . . F2 . . . D2 .",
                        lead: ". . . . . . Bb4 A4 . . . . . . G4 . . . . . . . F4 G4 . . . . . . D4 .",
                        chord: "G2m7 . . . . . . . . . . . . . . . Eb3M . . . . . . . . . . . . . . .",
                        gates: [2, 2, 0, 0]),
        OPZMelodyPreset(name: "Gelo", group: "dark", bpm: 68,
                        bass: "E2 . . . . . . . C3 . . . . . . . A2 . . . . . . . B2 . . . . . . .",
                        arp: "E3m . . . . . . . C3M . . . . . . . A2m . . . . . . . B2M . . . . . . .",
                        gates: [0, 2, 0, 0], arpStyle: .converge, arpRate: 2, arpOctaves: 2),
        // horror
        OPZMelodyPreset(name: "La casa", group: "horror", bpm: 70,
                        bass: "C2 . . . . . . . . . . . . . . . B1 . . . . . . . . . . . . . . .",
                        lead: ". . . . . . . . F#5 . . . . . . . . . . . . . . . F5 . . . . . . .",
                        chord: "C3mM7 . . . . . . . . . . . . . . . B2mM7 . . . . . . . . . . . . . . .",
                        gates: [0, 4, 0, 0]),
        OPZMelodyPreset(name: "Carillon", group: "horror", bpm: 96,
                        bass: "A2 . . . . . . . . . . . . . . .",
                        lead: "E5 . A5 . C6 . B5 . A5 . E5 . D#5 . E5 .",
                        chord: "A3m . . . . . . . . . . . . . . .",
                        gates: [0, 1, 0, 0]),
        OPZMelodyPreset(name: "Corridoio", group: "horror", bpm: 80,
                        bass: "E2 . E2 . E2 . E2 . Bb2 . Bb2 . Bb2 . Bb2 .",
                        lead: ". . . . F5 . . . . . . . E5 . . .",
                        chord: "E3hor . . . . . . . . . . . . . . .",
                        gates: [1, 4, 0, 0]),
        OPZMelodyPreset(name: "Presenza", group: "horror", bpm: 60,
                        bass: "D2 . . . . . . . . . . . . . . .",
                        arp: "D4dim7 . . . . . . . . . . . . . . .",
                        chord: "D3dim7 . . . . . . . . . . . . . . .",
                        gates: [0, 2, 0, 0], arpStyle: .random, arpRate: 1, arpOctaves: 2),
        OPZMelodyPreset(name: "Rintocchi", group: "horror", bpm: 72,
                        bass: "A2 . . . . . . . . . . . . . . . Eb2 . . . . . . . . . . . . . . .",
                        lead: "A4 . . . . . . . Eb5 . . . . . . . A4 . . . . . . . D5 . . . . . C#5 .",
                        chord: "A2m . . . . . . . . . . . . . . . Eb3M . . . . . . . . . . . . . . .",
                        gates: [0, 4, 0, 0]),
        OPZMelodyPreset(name: "Sotto il letto", group: "horror", bpm: 90,
                        bass: "A2 Bb2 A2 . A2 Bb2 B2 . A2 Bb2 A2 . C3 B2 Bb2 .",
                        lead: ". . . . . . . . . . . . . . . Eb5",
                        chord: "A2hor . . . . . . . . . . . . . . .",
                        gates: [1, 2, 0, 0]),
        // cinema
        OPZMelodyPreset(name: "Noir", group: "cinema", bpm: 84,
                        bass: "D2 . F2 . A2 . C3 . Bb2 . A2 . G2 . F2 . E2 . G2 . Bb2 . D3 . C#3 . A2 . G2 . E2 .",
                        lead: ". . . . A4 . . . . . . . F4 . . . . . . . E4 . . . . . . . C#4 . . .",
                        chord: "D3m7 . . . . . . . . . . . . . . . Bb27 . . . . . . . . . . . . . . .",
                        gates: [2, 4, 0, 0]),
        OPZMelodyPreset(name: "Titoli di coda", group: "cinema", bpm: 75,
                        bass: "C3 . . . . . . . Ab2 . . . . . . . Bb2 . . . . . . . G2 . . . . . . .",
                        lead: "G4 . . . . . . . C5 . . . . . . . D5 . . . . . . . B4 . . . . . . .",
                        arp: "C3m . . . . . . . Ab2M . . . . . . . Bb2M . . . . . . . G2M . . . . . . .",
                        gates: [0, 0, 0, 0], arpStyle: .upOctave, arpRate: 2),
        OPZMelodyPreset(name: "Bruma", group: "cinema", bpm: 66,
                        bass: "F#2 . . . . . . . . . . . . . . . D2 . . . . . . . . . . . . . . .",
                        arp: "F#4m . . . . . . . . . . . . . . . D4M . . . . . . . . . . . . . . .",
                        chord: "F#3m . . . . . . . . . . . . . . . D3M . . . . . . . . . . . . . . .",
                        gates: [0, 2, 0, 0], arpStyle: .diverge, arpRate: 4),
        OPZMelodyPreset(name: "Ultima notte", group: "cinema", bpm: 80,
                        bass: "A2 . . A2 . . . . A2 . . . G2 . . . Bb2 . . Bb2 . . . . Bb2 . . . A2 . . .",
                        lead: ". . E5 . . . F5 . . . . . . . E5 . . . D5 . . . F5 . . . . . . . E5 .",
                        chord: "A3m . . . . . . . . . . . . . . . Bb3M . . . . . . . . . . . . . . .",
                        gates: [2, 2, 0, 0]),
    ]
}
