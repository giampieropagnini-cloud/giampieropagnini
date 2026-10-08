import SwiftUI

// MARK: - Live: le cose da suonare dal vivo, una parte per volta (8/10/2026, come Crea)

enum OPZLivePart: String, CaseIterable, Identifiable {
    case mutes, punch, knobs, patterns, scenes

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mutes: return "muti"
        case .punch: return "effetti"
        case .knobs: return "manopole"
        case .patterns: return "pattern"
        case .scenes: return "scene"
        }
    }
}

struct OPZLiveView: View {
    @EnvironmentObject var opz: OPZEngine
    @AppStorage("bobina.opz.live.parte") private var part = OPZLivePart.mutes.rawValue

    var body: some View {
        let current = OPZLivePart(rawValue: part) ?? .mutes
        OPZPage(title: "Live", compact: true) {
            OPZLiveTop()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3), spacing: 5) {
                ForEach(OPZLivePart.allCases) { p in
                    OPZChip(text: p.label, on: p == current, height: 38) { part = p.rawValue }
                        .accessibilityLabel("parte \(p.label)")
                }
                OPZSilenceKey()
            }
            switch current {
            case .mutes: OPZLiveMutes()
            case .punch: OPZLivePunch()
            case .knobs: OPZLiveKnobs()
            case .patterns: OPZLivePatterns()
            case .scenes: OPZLiveScenes()
            }
        }
    }
}

/// In cima a Live, sempre: suona/ferma l'OP-Z, il battito, il tempo e il pattern.
struct OPZLiveTop: View {
    @EnvironmentObject var opz: OPZEngine

    var body: some View {
        HStack(spacing: 6) {
            Button {
                // Live è l'OP-Z da solo: il ▶ di qui non fa suonare i passi di Crea
                if !opz.running { opz.createOn = false }
                opz.toggleRun()
            } label: {
                Text(opz.running ? "■ ferma" : "▶ suona")
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 10).fill(opz.running ? Palette.rec : OPZ.tint))
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(opz.running ? "ferma l'OP-Z" : "fai suonare l'OP-Z")
            SmallKey(text: "−5") { opz.setBPM(opz.bpm - 5) }.accessibilityLabel("tempo meno 5")
            VStack(spacing: 0) {
                Text("\(Int(opz.bpm.rounded()))")
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                Text(opz.queuedPattern.map { "pat \(opz.pattern)→\($0)" } ?? "pat \(opz.pattern)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Palette.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(minWidth: 56)
            SmallKey(text: "+5") { opz.setBPM(opz.bpm + 5) }.accessibilityLabel("tempo più 5")
        }
    }
}

// MARK: muti

struct OPZLiveMutes: View {
    @EnvironmentObject var opz: OPZEngine
    private let four = Array(repeating: GridItem(.flexible(), spacing: 5), count: 4)

    var body: some View {
        OPZPanel {
            LazyVGrid(columns: four, spacing: 5) {
                ForEach(OPZ.tracks) { t in
                    let m = opz.muted[t.number - 1]
                    Button { opz.toggleMute(t.number) } label: {
                        VStack(spacing: 1) {
                            Text(t.short)
                                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                            Text(m ? "muto" : "suona")
                                .font(.system(.caption2, design: .monospaced))
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 9).fill(m ? Color(white: 0.12) : OPZ.color(t.number)))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(OPZ.color(t.number), lineWidth: m ? 2 : 0))
                        .foregroundStyle(m ? OPZ.color(t.number) : Color.black)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(t.name)
                    .accessibilityValue(m ? "muto" : "suona")
                }
            }
            HStack(spacing: 5) {
                OPZChip(text: "tutto suona", height: 38) { opz.unmuteAll() }
                OPZChip(text: "solo batteria", height: 38) { opz.solo(1...4) }
                OPZChip(text: "solo synth", height: 38) { opz.solo(5...8) }
            }
            HStack(spacing: 5) {
                OPZChip(text: "muto vero", on: !opz.audioOnly, height: 36) { opz.audioOnly = false }
                OPZChip(text: "muto solo audio", on: opz.audioOnly, height: 36) { opz.audioOnly = true }
            }
            OPZLabel("solo audio: la traccia tace ma suona ancora negli effetti e nel nastro")
        }
    }
}

// MARK: effetti punch-in dell'OP-Z

struct OPZLivePunch: View {
    @EnvironmentObject var opz: OPZEngine
    private let four = Array(repeating: GridItem(.flexible(), spacing: 5), count: 4)

    var body: some View {
        // 8/10/2026: via MIDI la scelta della traccia (CC 102) non sposta gli effetti: «solo la traccia» resta sulla
        // traccia attiva di prima e «tutto il gruppo» resta sulla batteria. Restano le due cose che funzionano.
        OPZPanel {
            HStack(spacing: 5) {
                OPZChip(text: "su tutto il gruppo", on: opz.punchHigh, height: 40) { opz.punchHigh = true }
                    .accessibilityLabel("effetti su tutto il gruppo")
                OPZChip(text: "solo traccia attiva", on: !opz.punchHigh, height: 40) { opz.punchHigh = false }
                    .accessibilityLabel("effetti solo sulla traccia attiva dell'OP-Z")
            }
            OPZLabel("sopra: mezzo secondo · sotto: resta finché non tocchi «lascia»")
            LazyVGrid(columns: four, spacing: 6) {
                ForEach(OPZ.punchIn.indices, id: \.self) { i in
                    OPZPunchKey(index: i, name: OPZ.punchIn[i], held: opz.punchHeld.contains(i))
                }
            }
            OPZChip(text: "lascia tutti gli effetti", height: 40) { opz.punchReleaseAll() }
            OPZLabel("la traccia attiva la sceglie Ele sull'OP-Z: TRACK + il numero")
        }
    }
}

// MARK: manopole: una pagina per volta

struct OPZLiveKnobs: View {
    @EnvironmentObject var opz: OPZEngine
    @AppStorage("bobina.opz.live.pagina") private var page = 0

    private static let pages: [(String, [Int])] = [("suono", [1, 2, 3, 4]), ("inviluppo", [5, 6, 7, 8]),
                                                   ("lfo", [9, 10, 11, 12]), ("mix", [13, 14, 15, 16])]
    /// I colori delle quattro manopole dell'OP-Z: verde, blu, giallo, rosso.
    private static let knob: [Color] = [Color(red: 0.36, green: 0.8, blue: 0.45), Color(red: 0.4, green: 0.6, blue: 1.0),
                                        Color(red: 0.98, green: 0.82, blue: 0.3), Color(red: 1.0, green: 0.42, blue: 0.4)]
    private let eight = Array(repeating: GridItem(.flexible(), spacing: 4), count: 8)

    var body: some View {
        let pg = max(0, min(3, page))
        let tr = opz.soundTrack
        OPZPanel {
            LazyVGrid(columns: eight, spacing: 4) {
                ForEach(OPZ.tracks.prefix(8)) { t in
                    OPZChip(text: t.short, on: tr == t.number, color: OPZ.color(t.number), height: 38) { opz.soundTrack = t.number }
                        .accessibilityLabel("manopole di \(t.name)")
                }
            }
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { p in
                    OPZChip(text: OPZLiveKnobs.pages[p].0, on: pg == p, height: 36) { page = p }
                        .accessibilityLabel("pagina \(OPZLiveKnobs.pages[p].0)")
                }
            }
            ForEach(OPZLiveKnobs.pages[pg].1, id: \.self) { cc in
                let name = OPZ.paramName(OPZ.params[cc - 1], track: tr)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle().fill(OPZLiveKnobs.knob[(cc - 1) % 4]).frame(width: 10, height: 10)
                        Text(name).font(.system(.subheadline, design: .monospaced))
                    }
                    HStack(spacing: 4) {
                        OPZChip(text: "min", height: 40) { opz.setValue(cc, 0, track: tr) }
                            .accessibilityLabel("\(name) al minimo")
                        OPZChip(text: "−", height: 40) { opz.nudge(cc, up: false, track: tr) }
                            .accessibilityLabel("\(name) meno")
                        OPZChip(text: "metà", height: 40) { opz.setValue(cc, 64, track: tr) }
                            .accessibilityLabel("\(name) a metà")
                        OPZChip(text: "+", height: 40) { opz.nudge(cc, up: true, track: tr) }
                            .accessibilityLabel("\(name) più")
                        OPZChip(text: "max", height: 40) { opz.setValue(cc, 127, track: tr) }
                            .accessibilityLabel("\(name) al massimo")
                    }
                }
            }
        }
    }
}

// MARK: pattern dell'OP-Z

struct OPZLivePatterns: View {
    @EnvironmentObject var opz: OPZEngine
    private let four = Array(repeating: GridItem(.flexible(), spacing: 5), count: 4)

    var body: some View {
        OPZPanel {
            LazyVGrid(columns: four, spacing: 5) {
                ForEach(1...16, id: \.self) { n in
                    Button { opz.choosePattern(n) } label: {
                        Text(opz.queuedPattern == n ? "\(n) ⏳" : "\(n)")
                            .font(.system(.title3, design: .monospaced).weight(opz.pattern == n ? .bold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(RoundedRectangle(cornerRadius: 9).fill(opz.pattern == n ? OPZ.tint : Color(white: 0.18)))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(opz.queuedPattern == n ? Palette.accent : Palette.cardEdge, lineWidth: opz.queuedPattern == n ? 3 : 1))
                            .foregroundStyle(opz.pattern == n ? Color.black : Color.white)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("pattern \(n)")
                    .accessibilityAddTraits(opz.pattern == n ? .isSelected : [])
                }
            }
            HStack(spacing: 5) {
                OPZChip(text: "◀ prima", height: 40) { opz.stepPattern(-1) }
                    .accessibilityLabel("pattern prima")
                OPZChip(text: "dopo ▶", height: 40) { opz.stepPattern(1) }
                    .accessibilityLabel("pattern dopo")
            }
            HStack(spacing: 5) {
                OPZChip(text: "alla battuta", on: opz.onTheBar, height: 36) { opz.onTheBar = true }
                OPZChip(text: "subito", on: !opz.onTheBar, height: 36) { opz.onTheBar = false }
            }
            OPZLabel("i pattern dell'OP-Z · la canzone a pattern sta in Suona")
        }
    }
}

// MARK: scene, gruppi di muti, poliritmi

struct OPZLiveScenes: View {
    @EnvironmentObject var opz: OPZEngine
    private let five = Array(repeating: GridItem(.flexible(), spacing: 5), count: 5)

    var body: some View {
        OPZPanel {
            OPZLabel("scene di Bobina: i muti di adesso, richiamati alla battuta")
            // due file separate: in una griglia sola i due ForEach con gli stessi numeri si pestano e la seconda sparisce
            HStack(spacing: 5) {
                ForEach(0..<4, id: \.self) { i in
                    OPZChip(text: opz.scenes[i] == nil ? "scena \(i + 1) ·" : "scena \(i + 1)", on: opz.scenes[i] != nil, color: OPZ.tint, height: 44) { opz.recallScene(i) }
                        .disabled(opz.scenes[i] == nil)
                        .accessibilityLabel("scena \(i + 1)")
                }
            }
            HStack(spacing: 5) {
                ForEach(0..<4, id: \.self) { i in
                    OPZChip(text: "salva \(i + 1)", height: 38) { opz.saveScene(i) }
                        .accessibilityLabel("salva la scena \(i + 1)")
                }
            }
            OPZLabel("gruppi di muti dell'OP-Z (si preparano nel suo mixer)")
            LazyVGrid(columns: five, spacing: 5) {
                ForEach(1...10, id: \.self) { n in
                    OPZChip(text: "\(n)", on: opz.muteGroup == n, height: 40) { opz.chooseMuteGroup(n) }
                        .accessibilityLabel("gruppo \(n)")
                }
            }
            OPZLabel("poliritmi: passi diversi per traccia, alla battuta")
            HStack(spacing: 5) {
                OPZChip(text: "tutte 16", height: 38) { opz.polyrhythm(Array(repeating: 16, count: 8)) }
                OPZChip(text: "16·12·7", height: 38) { opz.polyrhythm([16, 12, 7, 16, 16, 12, 7, 16]) }
                OPZChip(text: "16·15·13", height: 38) { opz.polyrhythm([16, 15, 13, 16, 16, 15, 13, 16]) }
            }
        }
    }
}
