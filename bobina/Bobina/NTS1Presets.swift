import Foundation

/// Sequenze pronte per la scheda Passi: tutte scure (minore, frigio, minore armonico, tritoni, cromatismi),
/// in quattro gruppi. Le note si scrivono come sull'NTS-1: «A2», «C#3», «Bb2»; «.» è un passo vuoto.
struct NTS1Preset: Identifiable {
    let name: String
    let group: String
    /// Il tempo per cui è pensata.
    let bpm: Int
    let steps: [Int?]
    var length: Int { steps.count <= 8 ? 8 : 16 }

    var id: String { name }

    init(_ name: String, _ group: String, _ bpm: Int, _ text: String) {
        self.name = name
        self.group = group
        self.bpm = bpm
        var s = text.split(separator: " ").map { NTS1Preset.note(String($0)) }
        while s.count < 16 { s.append(nil) }
        steps = Array(s.prefix(16))
    }

    /// «A2» → 45, «C#3» → 49, «Bb2» → 46, «.» → nil. Il do centrale è C4 = 60.
    static func note(_ t: String) -> Int? {
        let names: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        guard let first = t.first, let base = names[first] else { return nil }
        var rest = t.dropFirst()
        var n = base
        if rest.first == "#" { n += 1; rest = rest.dropFirst() } else if rest.first == "b" { n -= 1; rest = rest.dropFirst() }
        guard let octave = Int(rest) else { return nil }
        return (octave + 1) * 12 + n
    }

    static let groups = ["trip hop", "electro", "dance", "horror"]

    static let all: [NTS1Preset] = [
        // trip hop: lento, pesante, minore
        NTS1Preset("Nebbia", "trip hop", 84, "A2 . . A2 . . C3 . E3 . . D3 . C3 . G2"),
        NTS1Preset("Pioggia lenta", "trip hop", 80, "D3 . F3 . A3 . . G3 . F3 . E3 . . C#3 ."),
        NTS1Preset("Bristol", "trip hop", 88, "E2 . E2 G2 . . B2 . A2 . G2 . F#2 . . ."),
        NTS1Preset("Fumo", "trip hop", 82, "C3 . . Eb3 . . G3 . Ab3 . . G3 . Eb3 . D3"),
        NTS1Preset("Notturno", "trip hop", 76, "E2 . F2 . . . E2 . . G2 . F2 . . E2 ."),
        NTS1Preset("Vetro rotto", "trip hop", 86, "G2 . Bb2 . . D3 . . Eb3 . D3 . Bb2 . A2 ."),
        // electro: secco, meccanico, ottave
        NTS1Preset("Macchina", "electro", 122, "A2 A2 . A3 . A2 G2 . A2 A2 . C3 . A2 E3 ."),
        NTS1Preset("Circuito", "electro", 126, "E2 E3 E2 E3 F2 F3 F2 F3 E2 E3 E2 E3 D2 D3 C2 C3"),
        NTS1Preset("Segnale", "electro", 120, "D3 . . D3 . . D#3 . D3 . . A2 . . G#2 ."),
        NTS1Preset("Ferro", "electro", 124, "C2 . C3 C2 . Eb2 . C2 G2 . C2 . Bb2 . Ab2 ."),
        NTS1Preset("Neon morto", "electro", 118, "F#2 . F#3 . F#2 . E3 . F#2 . F#3 . A2 . G3 ."),
        // dance: dritta, ma scura
        NTS1Preset("Club buio", "dance", 126, ". A2 . A2 . A2 . A2 . F2 . F2 . G2 . G2"),
        NTS1Preset("Cantina", "dance", 128, "A2 . A3 . A2 . G3 . A2 . A3 . A2 C3 D3 E3"),
        NTS1Preset("Ipnosi", "dance", 124, "A2 C3 E3 A3 E3 C3 A2 C3 F2 A2 C3 F3 C3 A2 G2 B2"),
        NTS1Preset("Acido nero", "dance", 130, "A2 A3 . A2 C3 . A3 Bb2 . A2 A3 . Eb3 . D3 ."),
        NTS1Preset("Battito", "dance", 125, "E2 . . E2 . . E2 . G2 . . G2 . . F#2 ."),
        // horror e suspense: cromatismi, tritoni, carillon
        NTS1Preset("Corridoio", "horror", 90, "C3 . C#3 . C3 . C#3 . C3 . D3 . C#3 . C3 ."),
        NTS1Preset("Tritono", "horror", 72, "A2 . . . D#3 . . . A2 . . . D#3 . E3 ."),
        NTS1Preset("Carillon", "horror", 96, "E4 . G4 . B4 . A#4 . A4 . G4 . F#4 . D#4 ."),
        NTS1Preset("Lama", "horror", 110, "D4 A3 A3 D4 A3 A3 D4 A3 Eb4 A3 A3 Eb4 A3 A3 D4 A3"),
        NTS1Preset("Cuore", "horror", 70, "A2 A2 . . . . . . A2 A2 . . . . Bb2 ."),
        NTS1Preset("Diminuito", "horror", 100, "C3 Eb3 F#3 A3 C4 A3 F#3 Eb3 C3 Eb3 F#3 A3 C4 . . ."),
        NTS1Preset("Rito", "horror", 84, "D2 . D2 . D3 . C3 . Bb2 . A2 . G#2 . A2 ."),
    ]
}
