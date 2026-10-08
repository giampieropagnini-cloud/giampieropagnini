import SwiftUI

// MARK: - Suona: i pattern dell'OP-Z, una parte per volta (8/10/2026, come Crea e Live)

enum OPZSuonaPart: String, CaseIterable, Identifiable {
    case patterns, song, project

    var id: String { rawValue }

    var label: String {
        switch self {
        case .patterns: return "pattern"
        case .song: return "canzone"
        case .project: return "progetto"
        }
    }
}

struct OPZSuonaView: View {
    @EnvironmentObject var opz: OPZEngine
    @AppStorage("bobina.opz.suona.parte") private var part = OPZSuonaPart.patterns.rawValue

    var body: some View {
        let current = OPZSuonaPart(rawValue: part) ?? .patterns
        OPZPage(title: "Suona", compact: true) {
            OPZLiveTop()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 4), spacing: 5) {
                ForEach(OPZSuonaPart.allCases) { p in
                    OPZChip(text: p.label, on: p == current, height: 40) { part = p.rawValue }
                        .accessibilityLabel("parte \(p.label)")
                }
                OPZSilenceKey()
            }
            switch current {
            case .patterns: OPZLivePatterns()
            case .song: OPZSongPanel()
            case .project: OPZProjectPanel()
            }
        }
    }
}

/// La canzone a pattern dell'OP-Z: un tocco su un numero lo mette in fila. Bobina passa al seguente
/// ogni tot battute, a tempo, e ricomincia dall'inizio.
struct OPZSongPanel: View {
    @EnvironmentObject var opz: OPZEngine
    private let eight = Array(repeating: GridItem(.flexible(), spacing: 4), count: 8)

    var body: some View {
        OPZPanel {
            HStack(spacing: 4) {
                OPZChip(text: opz.songOn ? "canzone accesa" : "canzone spenta", on: opz.songOn, height: 40) { opz.songOn.toggle() }
                    .accessibilityLabel(opz.songOn ? "spegni la canzone" : "accendi la canzone")
            }
            HStack(spacing: 4) {
                OPZLabel("ogni")
                ForEach([1, 2, 4, 8], id: \.self) { b in
                    OPZChip(text: b == 1 ? "1 battuta" : "\(b)", on: opz.songBars == b, height: 36) { opz.songBars = b }
                        .accessibilityLabel(b == 1 ? "ogni battuta" : "ogni \(b) battute")
                }
            }
            OPZLabel("la fila (\(opz.song.count)) · quella che suona è accesa")
            if opz.song.isEmpty {
                OPZLabel("vuota: tocca i numeri qui sotto")
            } else {
                OPZSongRow(live: opz.live, song: opz.song, songOn: opz.songOn && opz.running)
            }
            OPZLabel("tocca un pattern: va in fondo alla fila")
            LazyVGrid(columns: eight, spacing: 4) {
                ForEach(1...16, id: \.self) { n in
                    OPZChip(text: "\(n)", height: 40) { if opz.song.count < 32 { opz.song.append(n) } }
                        .accessibilityLabel("aggiungi il pattern \(n)")
                }
            }
            HStack(spacing: 5) {
                OPZChip(text: "togli l'ultimo", height: 38) { if !opz.song.isEmpty { opz.song.removeLast() } }
                OPZChip(text: "svuota la fila", height: 38) { opz.song = []; opz.songOn = false }
            }
            OPZLabel("sono i pattern dell'OP-Z · per quelli di Bobina c'è la catena in Crea")
        }
    }
}

/// Il progetto dell'OP-Z (1-10): è il canale con cui Bobina sceglie i pattern.
struct OPZProjectPanel: View {
    @EnvironmentObject var opz: OPZEngine
    private let five = Array(repeating: GridItem(.flexible(), spacing: 5), count: 5)

    var body: some View {
        OPZPanel {
            OPZLabel("il progetto dell'OP-Z in cui Bobina sceglie i pattern")
            LazyVGrid(columns: five, spacing: 5) {
                ForEach(1...10, id: \.self) { n in
                    OPZChip(text: "\(n)", on: opz.project == n, height: 48) { opz.project = n }
                        .accessibilityLabel("progetto \(n)")
                }
            }
            OPZLabel("da provare: secondo la community questo numero cambia anche il progetto aperto sull'OP-Z")
        }
    }
}
