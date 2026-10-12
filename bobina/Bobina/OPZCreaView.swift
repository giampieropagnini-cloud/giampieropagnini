import SwiftUI

// MARK: - Crea: Bobina suona l'OP-Z a passi, col suo clock

/// Le parti di Crea: se ne vede una per volta, così tutto sta in uno schermo (8/10/2026, come TX-6 e NTS-1).
enum OPZCreaPart: String, CaseIterable, Identifiable {
    case drums, notes, patterns, fx, mixer, knobs, write

    var id: String { rawValue }

    var label: String {
        switch self {
        case .drums: return "batteria"
        case .notes: return "note"
        case .patterns: return "pattern"
        case .fx: return "effetti"
        case .mixer: return "mixer"
        case .knobs: return "manopole"
        case .write: return "scrivi"
        }
    }
}

struct OPZCreaView: View {
    @EnvironmentObject var opz: OPZEngine
    @AppStorage("bobina.opz.crea.parte") private var part = OPZCreaPart.drums.rawValue

    private let four = Array(repeating: GridItem(.flexible(), spacing: 5), count: 4)

    var body: some View {
        let current = OPZCreaPart(rawValue: part) ?? .drums
        OPZPage(title: "Crea", compact: true) {
            OPZCreaTop()
            LazyVGrid(columns: four, spacing: 5) {
                ForEach(OPZCreaPart.allCases) { p in
                    VetroGridChip(text: p.label, on: p == current) { part = p.rawValue }
                        .accessibilityLabel("parte \(p.label)")
                }
                OPZSilenceKey()
            }
            if opz.recordLockReminder { OPZRecordLockBanner() }
            switch current {
            case .drums: OPZDrumPanel(live: opz.live)
            case .notes: OPZNotePanel(live: opz.live)
            case .patterns: OPZPatternPanel()
            case .fx: OPZFxPanel()
            case .mixer: OPZCreaMixerCard()
            case .knobs: OPZAutomCard()
            case .write: OPZWritePanel()
            }
        }
    }
}

/// In cima a Crea, sempre: un tasto solo per suonare e fermare, il tempo, e dove sei.
struct OPZCreaTop: View {
    @EnvironmentObject var opz: OPZEngine

    var body: some View {
        HStack(spacing: 6) {
            Button {
                if !opz.running {
                    opz.createOn = true
                    opz.toggleRun()
                } else if !opz.createOn {
                    opz.createOn = true
                } else {
                    opz.toggleRun()
                }
            } label: {
                Text(!opz.running ? "▶ suona" : !opz.createOn ? "▶ anche Crea" : "■ ferma")
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .vetroKey(opz.running && opz.createOn ? .red : .on(OPZ.tint), radius: 16)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(!opz.running ? "suona" : !opz.createOn ? "fai suonare anche Crea" : "ferma tutto")
            // mentre suona tutto: spegne solo Crea, l'OP-Z continua col suo pattern (8/10/2026)
            if opz.running && opz.createOn {
                Button { opz.createOn = false } label: {
                    Text("solo\nOP-Z")
                        .font(.system(.footnote, design: .monospaced).weight(.bold))
                        .multilineTextAlignment(.center)
                        .frame(width: 64, height: 50)
                        .vetroKey(.on(OPZ.tint), radius: 16)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("spegni Crea, suona solo l'OP-Z")
            }
            VetroSmallKey(text: "−5") { opz.setBPM(opz.bpm - 5) }.accessibilityLabel("tempo meno 5")
            VStack(spacing: 0) {
                Text("\(Int(opz.bpm.rounded()))")
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                Text("P\(opz.creaProject)·\(opz.createPattern)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Palette.dim)
            }
            .frame(minWidth: 50)
            VetroSmallKey(text: "+5") { opz.setBPM(opz.bpm + 5) }.accessibilityLabel("tempo più 5")
        }
    }
}

struct OPZRecordLockBanner: View {
    @EnvironmentObject var opz: OPZEngine

    var body: some View {
        HStack(spacing: 8) {
            Text("Registrazione finita: Ele, premi REC per togliere il record lock.")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Button { opz.recordLockReminder = false } label: {
                Text("fatto")
                    .font(.system(.subheadline, design: .monospaced).weight(.bold))
                    .frame(width: 70, height: 44)
                    .vetroKey(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("fatto, record lock tolto")
        }
        .padding(10)
        .vetroKey(.red, radius: 16)
    }
}

/// Il tasto rosso «silenzio»: spegne tutte le note rimaste accese, anche quelle lunghe che non finiscono.
struct OPZSilenceKey: View {
    @EnvironmentObject var opz: OPZEngine

    var body: some View {
        Button { opz.silence() } label: {
            Text("silenzio")
                .font(.system(.footnote, design: .monospaced).weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 38)
                .vetroKey(.red)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("silenzio, spegni tutte le note")
    }
}

/// Il riquadro scuro di una parte, senza titolo.
struct OPZPanel<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) { content() }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .vetroPanel()
    }
}

struct OPZLabel: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(text).font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.dim)
    }
}

/// Un tasto piccolo e pieno se acceso, alto quanto serve al Controllo Vocale.
struct OPZChip: View {
    @Environment(\.vetro) private var theme
    let text: String
    var on = false
    var color: Color = Palette.accent
    var height: CGFloat = 36
    let action: () -> Void

    var body: some View {
        let look = vetroLook(on: on, color: color, theme: theme)
        Button(action: action) {
            Text(text)
                .font(.system(.footnote, design: .monospaced).weight(on ? .bold : .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: height)
                .vetroKey(look)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - batteria: una griglia come una drum machine

struct OPZDrumPanel: View {
    @EnvironmentObject var opz: OPZEngine
    @ObservedObject var live: OPZLive
    @AppStorage("bobina.opz.crea.batteria.pagina") private var page = 0
    /// L'ultima riga di batteria scelta: tornando qui si riprende da lì (passi e durata valgono per la traccia scelta).
    @AppStorage("bobina.opz.crea.batteria.riga") private var lastRow = 1
    /// Le batterie pronte al posto della griglia.
    @AppStorage("bobina.opz.crea.batteria.pronti") private var ready = false
    /// «svuota tutta la batteria» chiede un secondo tocco entro 4 secondi.
    @State private var confirmClear = false
    @State private var help = false

    private let twelve = Array(repeating: GridItem(.flexible(), spacing: 3), count: 12)
    private let five = Array(repeating: GridItem(.flexible(), spacing: 5), count: 5)

    var body: some View {
        let lens = opz.lengths[opz.createPattern - 1]
        let maxLen = (0..<4).map { lens[$0] }.max() ?? 16
        let pages = max(1, (maxLen + 7) / 8)
        let pg = min(page, pages - 1)
        let row = (1...4).contains(opz.createTrack) ? opz.createTrack : 1
        OPZPanel {
            HStack(spacing: 4) {
                OPZChip(text: "griglia", on: !ready, height: 36) { ready = false }
                OPZChip(text: "pronte", on: ready, height: 36) { ready = true }
                    .accessibilityLabel("batterie pronte")
                if !ready && pages > 1 {
                    ForEach(0..<pages, id: \.self) { p in
                        OPZChip(text: "\(p * 8 + 1)-\(p * 8 + 8)", on: pg == p, height: 36) { page = p }
                            .accessibilityLabel("passi da \(p * 8 + 1) a \(p * 8 + 8)")
                    }
                }
            }
            if ready {
                OPZPresetList(items: OPZDrumPreset.all.map { ($0.name, "\($0.group) · \($0.bpm)") }) { i in
                    opz.loadDrums(OPZDrumPreset.all[i])
                }
            } else {
            ForEach(1...4, id: \.self) { t in
                let len = lens[t - 1]
                HStack(spacing: 4) {
                    Button { opz.createTrack = t; opz.auditionDrum(t) } label: {
                        VStack(spacing: 0) {
                            Text(OPZ.track(t).short).font(.system(.caption, design: .monospaced).weight(.bold))
                            Text("suono \(opz.drumPick[t - 1] - OPZ.keyboardF + 1)").font(.system(size: 9, design: .monospaced))
                        }
                        .frame(width: 62, height: 44)
                        .vetroKey(row == t ? .on(OPZ.color(t)) : .tinted(OPZ.color(t)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("riga \(OPZ.track(t).name)")
                    ForEach(0..<8, id: \.self) { c in
                        let i = pg * 8 + c
                        let cell = i < 32 ? opz.steps[t - 1][i] : []
                        let mine = cell.contains(opz.drumPick[t - 1])
                        let inside = i < len
                        Button { if inside { opz.toggleDrum(t, i) } } label: {
                            VetroKeyBackground(look: mine ? .glass(OPZ.color(t)) : !cell.isEmpty ? .half(OPZ.color(t)) : c % 4 == 0 ? .offBeat : .off, radius: 8)
                                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(live.step >= 0 && live.step % max(1, len) == i ? Color.white : Color.clear, lineWidth: 2))
                                .frame(height: 44)
                                .opacity(inside ? 1 : 0.25)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(OPZ.track(t).name) passo \(i + 1)")
                        .accessibilityValue(mine ? "acceso" : cell.isEmpty ? "spento" : "altro suono")
                    }
                }
            }
            OPZLabel("\(OPZ.track(row).short): riempi · suono")
            LazyVGrid(columns: five, spacing: 5) {
                OPZChip(text: "ogni 4", height: 34) { opz.fillDrum(row, every: 4) }
                OPZChip(text: "ogni 2", height: 34) { opz.fillDrum(row, every: 2) }
                OPZChip(text: "levare", height: 34) { opz.fillDrum(row, every: 4, offset: 2) }
                OPZChip(text: "tutti", height: 34) { opz.fillDrum(row, every: 1) }
                OPZChip(text: "svuota", height: 34) { opz.fillDrum(row, every: 0) }
            }
            LazyVGrid(columns: twelve, spacing: 3) {
                ForEach(0..<24, id: \.self) { k in
                    OPZChip(text: "\(k + 1)", on: opz.drumPick[row - 1] == OPZ.keyboardF + k, color: OPZ.color(row), height: 34) {
                        opz.setDrumPick(row, OPZ.keyboardF + k)
                    }
                    .accessibilityLabel("suono \(k + 1)")
                }
            }
            HStack(spacing: 5) {
                OPZLabel("passi")
                VetroSmallKey(text: "−") { opz.length -= 1 }.accessibilityLabel("un passo in meno")
                Text("\(lens[row - 1])").font(.system(.body, design: .monospaced).weight(.bold)).frame(minWidth: 28)
                VetroSmallKey(text: "+") { opz.length += 1 }.accessibilityLabel("un passo in più")
                OPZChip(text: help ? "chiudi" : "kit?", on: help, height: 34) { help.toggle() }
                    .accessibilityLabel(help ? "chiudi aiuto" : "come cambio il kit")
                OPZChip(text: confirmClear ? "sicuro?" : "svuota tutto", on: confirmClear, color: Palette.rec, height: 34) {
                    if confirmClear {
                        confirmClear = false
                        opz.clearDrums()
                    } else {
                        confirmClear = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { confirmClear = false }
                    }
                }
                .accessibilityLabel(confirmClear ? "conferma, svuota tutta la batteria" : "svuota tutta la batteria")
            }
            if help { OPZInstrumentHelpRows(track: row) }
            }
        }
        .onAppear { if opz.createTrack > 4 { opz.createTrack = max(1, min(4, lastRow)) } }
        .onChange(of: opz.createTrack) { _, t in if (1...4).contains(t) { lastRow = t } }
    }
}

// MARK: - note: un tocco = una nota (o un accordo) nel passo del cursore

struct OPZNotePanel: View {
    @EnvironmentObject var opz: OPZEngine
    @ObservedObject var live: OPZLive
    @AppStorage("bobina.opz.crea.note.pagina") private var page = 0
    /// L'ultima traccia di note scelta (5-8).
    @AppStorage("bobina.opz.crea.note.traccia") private var lastTrack = 5
    /// Le melodie pronte al posto della tastiera.
    @AppStorage("bobina.opz.crea.note.pronti") private var ready = false
    /// «svuota tutte» chiede un secondo tocco entro 4 secondi.
    @State private var confirmClear = false
    @State private var help = false

    static let names = ["do", "do#", "re", "re#", "mi", "fa", "fa#", "sol", "sol#", "la", "la#", "si"]
    private let four = Array(repeating: GridItem(.flexible(), spacing: 5), count: 4)
    private let six = Array(repeating: GridItem(.flexible(), spacing: 5), count: 6)
    private let eight = Array(repeating: GridItem(.flexible(), spacing: 4), count: 8)

    static func name(_ n: Int) -> String { names[((n % 12) + 12) % 12] + "\(n / 12 - 1)" }

    var body: some View {
        let tr = max(5, opz.createTrack)
        let len = opz.lengths[opz.createPattern - 1][tr - 1]
        let pages = max(1, (len + 15) / 16)
        let pg = min(page, pages - 1)
        OPZPanel {
            HStack(spacing: 5) {
                ForEach(5...8, id: \.self) { t in
                    OPZChip(text: OPZ.track(t).short, on: !ready && tr == t, color: OPZ.color(t), height: 38) {
                        opz.createTrack = t
                        opz.cursor = 0
                        ready = false
                    }
                    .accessibilityLabel("scrivi \(OPZ.track(t).name)")
                }
                OPZChip(text: "pronte", on: ready, height: 38) { ready.toggle() }
                    .accessibilityLabel("melodie pronte")
            }
            if ready {
                OPZPresetList(items: OPZMelodyPreset.all.map { ($0.name, "\($0.group) · \($0.bpm)") }) { i in
                    opz.loadMelody(OPZMelodyPreset.all[i])
                }
            } else {
            HStack(spacing: 5) {
                ForEach(OPZNoteMode.allCases) { m in
                    OPZChip(text: m.rawValue, on: opz.noteMode == m, height: 34) { opz.noteMode = m }
                        .accessibilityLabel("modo \(m.rawValue)")
                }
                if opz.noteMode == .hold {
                    OPZChip(text: "lascia tutte", height: 34) { opz.releaseLiveAll() }
                }
            }
            LazyVGrid(columns: four, spacing: 4) {
                ForEach(OPZChord.allCases) { c in
                    OPZChip(text: c.rawValue, on: opz.chordType == c, height: 32) { opz.chordType = c }
                        .accessibilityLabel(c == .single ? "una nota" : "accordo \(c.rawValue)")
                        .disabled(tr == 5 && c != .single)
                }
            }
            LazyVGrid(columns: six, spacing: 5) {
                ForEach(0..<12, id: \.self) { k in
                    let black = [1, 3, 6, 8, 10].contains(k)
                    let held = opz.isHeld(12 * (opz.noteOctave + 1) + k)
                    Button { opz.keyNote(k) } label: {
                        Text(OPZNotePanel.names[k])
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .vetroKey(held ? .white : black ? .half(OPZ.color(tr)) : .glass(OPZ.color(tr)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("nota \(OPZNotePanel.names[k])")
                    .accessibilityAddTraits(held ? .isSelected : [])
                }
            }
            HStack(spacing: 5) {
                OPZChip(text: "ottava −", height: 34) { opz.noteOctave = max(1, opz.noteOctave - 1) }
                Text("ott. \(opz.noteOctave)").font(.system(.footnote, design: .monospaced)).frame(minWidth: 44)
                OPZChip(text: "ottava +", height: 34) { opz.noteOctave = min(7, opz.noteOctave + 1) }
                OPZChip(text: "pausa", height: 34) { opz.writeRest() }
                OPZChip(text: "indietro", height: 34) { opz.cursorBack() }
            }
            if pages > 1 {
                HStack(spacing: 5) {
                    ForEach(0..<pages, id: \.self) { p in
                        OPZChip(text: "passi \(p * 16 + 1)-\(min(len, p * 16 + 16))", on: pg == p, height: 32) { page = p }
                    }
                }
            }
            LazyVGrid(columns: eight, spacing: 4) {
                ForEach(0..<16, id: \.self) { c in
                    let i = pg * 16 + c
                    let inside = i < len
                    let cell = i < 32 ? opz.steps[tr - 1][i] : []
                    let now = live.step >= 0 && live.step % max(1, len) == i
                    Button { if inside { opz.cursor = i } } label: {
                        VStack(spacing: 0) {
                            Text("\(i + 1)").font(.system(size: 9, design: .monospaced))
                            Text(cell.first.map { OPZNotePanel.name($0) + (cell.count > 1 ? "+" : "") } ?? "·")
                                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .vetroKey(now ? .on(Palette.accent) : !cell.isEmpty ? .glass(OPZ.color(tr)) : c % 4 == 0 ? .offBeat : .off, radius: 10)
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(opz.cursor == i ? Color.white : Color.clear, lineWidth: 3))
                        .opacity(inside ? 1 : 0.25)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("passo \(i + 1)")
                    .accessibilityValue(cell.isEmpty ? "vuoto" : cell.map { OPZNotePanel.name($0) }.joined(separator: " "))
                    .accessibilityAddTraits(opz.cursor == i ? .isSelected : [])
                }
            }
            HStack(spacing: 5) {
                OPZLabel("passi")
                VetroSmallKey(text: "−") { opz.length -= 1 }.accessibilityLabel("un passo in meno")
                Text("\(len)").font(.system(.body, design: .monospaced).weight(.bold)).frame(minWidth: 28)
                VetroSmallKey(text: "+") { opz.length += 1 }.accessibilityLabel("un passo in più")
                OPZLabel("dura")
                ForEach([(1, "1"), (2, "2"), (4, "4"), (0, "tenuta")], id: \.0) { g in
                    OPZChip(text: g.1, on: opz.gate == g.0, height: 32) { opz.gate = g.0 }
                        .accessibilityLabel(g.0 == 0 ? "nota tenuta" : "nota lunga \(g.1)")
                }
            }
            if tr == 7 { OPZArpRows() }
            HStack(spacing: 5) {
                OPZChip(text: "svuota \(OPZ.track(tr).short)", height: 34) { opz.clearTrack(); opz.cursor = 0 }
                OPZChip(text: confirmClear ? "sicuro?" : "svuota tutte", on: confirmClear, color: Palette.rec, height: 34) {
                    if confirmClear {
                        confirmClear = false
                        opz.clearMelodies()
                    } else {
                        confirmClear = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { confirmClear = false }
                    }
                }
                .accessibilityLabel(confirmClear ? "conferma, svuota tutte le melodie" : "svuota tutte le melodie")
                OPZChip(text: help ? "chiudi" : "strumento?", on: help, height: 34) { help.toggle() }
                    .accessibilityLabel(help ? "chiudi aiuto" : "come cambio lo strumento")
            }
            if help { OPZInstrumentHelpRows(track: tr) }
            }
        }
        .onAppear { if opz.createTrack < 5 { opz.createTrack = max(5, min(8, lastTrack)) } }
        .onChange(of: opz.createTrack) { _, t in if (5...8).contains(t) { lastTrack = t } }
    }
}

/// L'arpeggio di Bobina in poche righe, solo sulla traccia arp.
struct OPZArpRows: View {
    @EnvironmentObject var opz: OPZEngine
    private let four = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)

    var body: some View {
        HStack(spacing: 5) {
            OPZChip(text: opz.arpOn ? "arpeggio acceso" : "arpeggio spento", on: opz.arpOn, height: 34) { opz.arpOn.toggle() }
            ForEach([(1, "1/32"), (2, "1/16"), (4, "1/8"), (8, "1/4")], id: \.0) { r in
                OPZChip(text: r.1, on: opz.arpRate == r.0, height: 34) { opz.arpRate = r.0 }
                    .accessibilityLabel("velocità \(r.1)")
            }
        }
        if opz.arpOn {
            LazyVGrid(columns: four, spacing: 4) {
                ForEach(OPZArpStyle.allCases) { st in
                    OPZChip(text: st.name, on: opz.arpStyle == st, height: 32) { opz.arpStyle = st }
                        .accessibilityLabel("figura \(st.name)")
                }
            }
            // le ottave fuori dalla griglia delle figure: con gli stessi numeri si pesterebbero
            HStack(spacing: 4) {
                ForEach(1...3, id: \.self) { o in
                    OPZChip(text: o == 1 ? "1 ottava" : "\(o) ottave", on: opz.arpOctaves == o, height: 32) { opz.arpOctaves = o }
                }
            }
        }
    }
}

/// Le sequenze pronte in due colonne: un tocco le carica nel pattern che scrivi. Sotto: annulla e il tempo.
struct OPZPresetList: View {
    @EnvironmentObject var opz: OPZEngine
    let items: [(name: String, detail: String)]
    let load: (Int) -> Void
    private let three = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    var body: some View {
        HStack(spacing: 5) {
            OPZChip(text: opz.presetTempo ? "anche il tempo: sì" : "anche il tempo: no", on: opz.presetTempo, height: 36) { opz.presetTempo.toggle() }
            OPZChip(text: "annulla", height: 36) { opz.undoPreset() }
                .disabled(!opz.canUndoPreset)
                .accessibilityLabel("annulla la sequenza pronta")
            if let b = opz.presetBPM {
                OPZChip(text: "metti \(b) bpm", on: Int(opz.bpm.rounded()) == b, height: 36) { opz.setBPM(Double(b)) }
                    .accessibilityLabel("metti il tempo a \(b)")
            }
        }
        LazyVGrid(columns: three, spacing: 4) {
            ForEach(items.indices, id: \.self) { i in
                let on = opz.presetName == items[i].name
                Button { load(i) } label: {
                    VStack(spacing: 1) {
                        Text(items[i].name)
                            .font(.system(.footnote, design: .monospaced).weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(items[i].detail)
                            .font(.system(size: 9, design: .monospaced))
                            .opacity(0.7)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, 2)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .vetroKey(on ? .on(OPZ.tint) : .off)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(items[i].name)
            }
        }
    }
}

// MARK: - pattern, progetti e catena

struct OPZPatternPanel: View {
    @EnvironmentObject var opz: OPZEngine
    private let eight = Array(repeating: GridItem(.flexible(), spacing: 4), count: 8)
    private let four = Array(repeating: GridItem(.flexible(), spacing: 5), count: 4)

    var body: some View {
        OPZPanel {
            OPZLabel("progetto · si salva da solo")
            LazyVGrid(columns: eight, spacing: 4) {
                ForEach(1...16, id: \.self) { n in
                    OPZChip(text: opz.projectsUsed.contains(n) ? "\(n)•" : "\(n)", on: opz.creaProject == n, height: 38) { opz.openProject(n) }
                        .accessibilityLabel("progetto \(n)")
                }
            }
            OPZLabel("pattern · suona dalla battuta dopo")
            OPZCreaPatterns(live: opz.live)
            LazyVGrid(columns: four, spacing: 5) {
                OPZChip(text: "copia patt.", height: 34) { opz.copyPattern() }
                OPZChip(text: "incolla patt.", height: 34) { opz.pastePattern() }.disabled(opz.copied == nil)
                OPZChip(text: "copia prog.", height: 34) { opz.copyProject() }
                OPZChip(text: "incolla prog.", height: 34) { opz.pasteProject() }.disabled(opz.copiedProject == nil)
            }
            HStack(spacing: 5) {
                OPZChip(text: opz.chainOn ? "catena accesa" : "catena spenta", on: opz.chainOn, height: 36) { opz.chainOn.toggle() }
                OPZChip(text: opz.chainLoop ? "poi da capo" : "poi fermati", height: 36) { opz.chainLoop.toggle() }
            }
            OPZChainRow(live: opz.live, chain: opz.chain, on: opz.chainOn && opz.running)
            HStack(spacing: 4) {
                ForEach([1, 2, 4, 8], id: \.self) { v in
                    OPZChip(text: "×\(v)", on: opz.chainTimes == v, height: 34) { opz.chainTimes = v }
                        .accessibilityLabel("\(v) volte")
                }
                OPZChip(text: "+ \(opz.createPattern) ×\(opz.chainTimes)", height: 34) { opz.chainAdd(opz.createPattern) }
                    .accessibilityLabel("aggiungi il pattern \(opz.createPattern) alla catena")
            }
            HStack(spacing: 5) {
                OPZChip(text: "togli l'ultimo", height: 34) { opz.chainRemoveLast() }
                OPZChip(text: "svuota catena", height: 34) { opz.chainClear() }
            }
            OPZResetRow()
        }
    }
}

// MARK: - effetti di Bobina: dal vivo o nei passi

struct OPZFxPanel: View {
    @EnvironmentObject var opz: OPZEngine
    @AppStorage("bobina.opz.crea.effetti.modo") private var inSteps = false
    private let four = Array(repeating: GridItem(.flexible(), spacing: 5), count: 4)

    var body: some View {
        OPZPanel {
            HStack(spacing: 5) {
                OPZChip(text: "dal vivo", on: !inSteps, height: 36) { inSteps = false }
                OPZChip(text: "nei passi", on: inSteps, height: 36) { inSteps = true }
            }
            if !inSteps {
                LazyVGrid(columns: four, spacing: 6) {
                    ForEach(CreaFx.allCases) { f in
                        OPZCreaFxKey(fx: f, held: opz.fxHeld.contains(f))
                    }
                }
                HStack(spacing: 5) {
                    OPZChip(text: "su tutte", on: opz.fxAll, height: 34) { opz.fxAll = true }
                    OPZChip(text: "solo \(OPZ.track(opz.createTrack).short)", on: !opz.fxAll, height: 34) { opz.fxAll = false }
                    OPZChip(text: "lascia tutti", height: 34) { opz.creaFxReleaseAll() }
                }
            } else {
                LazyVGrid(columns: four, spacing: 4) {
                    ForEach(CreaFx.allCases) { f in
                        OPZChip(text: f.name, on: opz.fxPick == f, color: f.color, height: 34) { opz.fxPick = f }
                            .accessibilityLabel("scegli \(f.name)")
                    }
                }
                HStack(spacing: 4) {
                    OPZLabel("dura")
                    ForEach([1, 2, 4, 8, 16], id: \.self) { l in
                        OPZChip(text: "\(l)", on: opz.fxLength == l, height: 32) { opz.fxLength = l }
                            .accessibilityLabel(l == 1 ? "dura un passo" : "dura \(l) passi")
                    }
                }
                OPZFxStepCells(live: opz.live, cells: Array(opz.fxSteps[opz.createPattern - 1].prefix(opz.patternLength)), tap: { opz.toggleFxStep($0) })
                HStack(spacing: 4) {
                    OPZLabel("ogni")
                    ForEach([1, 2, 4, 8], id: \.self) { e in
                        OPZChip(text: e == 1 ? "giro" : "\(e)", on: opz.fxEvery == e, height: 32) { opz.fxEvery = e }
                            .accessibilityLabel(e == 1 ? "ogni giro" : "ogni \(e) giri")
                    }
                    OPZChip(text: "togli", height: 32) { opz.clearFxSteps() }
                        .accessibilityLabel("togli gli effetti dai passi")
                }
            }
        }
    }
}

// MARK: - scrivi sull'OP-Z

struct OPZWritePanel: View {
    @EnvironmentObject var opz: OPZEngine
    private let eight = Array(repeating: GridItem(.flexible(), spacing: 4), count: 8)

    var body: some View {
        let first = min(opz.writeFirst, 17 - opz.writeBars)
        OPZPanel {
            Text("Ele accende il record lock (tiene REC e preme PLAY). Poi un tocco qui sotto: Bobina suona Crea dentro l'OP-Z, una battuta per pattern, e alla fine ferma tutto.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Palette.dim)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 5) {
                ForEach([1, 2, 4], id: \.self) { b in
                    OPZChip(text: "\(b) battut\(b == 1 ? "a" : "e")", on: opz.writeBars == b, height: 38) { opz.writeBars = b }
                }
            }
            OPZLabel("nei pattern dell'OP-Z da \(first) a \(first + opz.writeBars - 1)")
            LazyVGrid(columns: eight, spacing: 4) {
                ForEach(1...16, id: \.self) { n in
                    OPZChip(text: "\(n)", on: opz.writeFirst == n, height: 36) { opz.writeFirst = n }
                        .accessibilityLabel("comincia dal pattern \(n) dell'OP-Z")
                }
            }
            Button { opz.writeOnce() } label: {
                Text(opz.writing ? "sto scrivendo…" : "scrivi sull'OP-Z")
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .vetroKey(opz.writing ? .red : .on(OPZ.tint), radius: 16)
            }
            .buttonStyle(.plain)
            .disabled(opz.writing)
        }
    }
}

/// Un effetto di Bobina diviso in due: sopra una battuta, sotto tieni / lascia.
struct OPZCreaFxKey: View {
    @EnvironmentObject var opz: OPZEngine
    let fx: CreaFx
    let held: Bool

    var body: some View {
        VStack(spacing: 3) {
            Button { opz.creaFxTap(fx) } label: {
                VStack(spacing: 1) {
                    Text(fx.name)
                        .font(.system(.footnote, design: .monospaced).weight(.semibold))
                    Text(fx.hint)
                        .font(.system(size: 9, design: .monospaced))
                        .opacity(0.75)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: 48)
                .vetroKey(.glass(fx.color))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(held ? Color.white : Color.clear, lineWidth: 3))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(fx.name)

            Button { opz.creaFxToggle(fx) } label: {
                Text(held ? "lascia" : "tieni")
                    .font(.system(.caption2, design: .monospaced).weight(held ? .bold : .regular))
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .vetroKey(held ? .white : .tinted(fx.color))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(held ? "lascia \(fx.name)" : "tieni \(fx.name)")
            .accessibilityAddTraits(held ? .isSelected : [])
        }
    }
}

/// I 16 passi degli effetti: in ognuno il nome corto dell'effetto, o niente. Guarda `live` per il passo che suona.
struct OPZFxStepCells: View {
    @ObservedObject var live: OPZLive
    let cells: [CreaFx?]
    let tap: (Int) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
            ForEach(0..<cells.count, id: \.self) { i in
                let f = cells[i]
                Button { tap(i) } label: {
                    VStack(spacing: 0) {
                        Text("\(i + 1)")
                            .font(.system(.caption, design: .monospaced))
                        Text(f?.name ?? "·")
                            .font(.system(size: 10, design: .monospaced).weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .vetroKey(f.map { .glass($0.color) } ?? (i % 4 == 0 ? .offBeat : .off))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(live.step >= 0 && live.step % cells.count == i ? Color.white : Color.clear, lineWidth: 3))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("effetto passo \(i + 1)")
                .accessibilityValue(f?.name ?? "vuoto")
            }
        }
    }
}

/// La fila della catena, con la voce che suona accesa. Guarda `live`.
struct OPZChainRow: View {
    @ObservedObject var live: OPZLive
    let chain: [OPZChainStep]
    let on: Bool

    var body: some View {
        if chain.isEmpty {
            Text("catena vuota")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 4) {
                ForEach(chain.indices, id: \.self) { i in
                    let lit = on && live.chainIndex == i
                    Text("\(chain[i].pattern + 1) ×\(chain[i].times)")
                        .font(.system(.footnote, design: .monospaced).weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .vetroKey(lit ? .on(Palette.accent) : .off, radius: 10)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("catena: " + chain.map { "\($0.pattern + 1) per \($0.times)" }.joined(separator: ", "))
        }
    }
}

/// Il mixer di Crea: le tracce che suonano e il loro volume. I muti dell'OP-Z (Live) toccano solo il suo
/// sequencer: qui una traccia spenta è Bobina che smette di mandarle le note.
struct OPZCreaMixerCard: View {
    @EnvironmentObject var opz: OPZEngine

    var body: some View {
        OPZPanel {
            OPZLabel("suona / muta e solo: Bobina · − + : volume sull'OP-Z")
            ForEach(OPZ.tracks.prefix(8)) { t in
                let on = opz.trackOn[t.number - 1]
                HStack(spacing: 6) {
                    Text(t.short)
                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        .foregroundStyle(OPZ.color(t.number))
                        .frame(width: 58, alignment: .leading)
                    Button { opz.trackOn[t.number - 1].toggle() } label: {
                        Text(on ? "suona" : "muta")
                            .font(.system(.footnote, design: .monospaced).weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .vetroKey(on ? .glass(OPZ.color(t.number)) : .tinted(OPZ.color(t.number)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(on ? "muta \(t.name)" : "fai suonare \(t.name)")
                    VetroGridChip(text: "solo") { opz.soloCrea(t.number) }
                        .frame(width: 54)
                        .accessibilityLabel("solo \(t.name)")
                    Button { opz.volumeNudge(t.number, up: false) } label: {
                        Text("−").font(.system(.title3, design: .monospaced))
                            .frame(width: 44, height: 40)
                            .vetroKey(.off)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("volume \(t.name) meno")
                    Button { opz.volumeNudge(t.number, up: true) } label: {
                        Text("+").font(.system(.title3, design: .monospaced))
                            .frame(width: 44, height: 40)
                            .vetroKey(.off)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("volume \(t.name) più")
                }
                .foregroundStyle(Color.white)
            }
            OPZChip(text: "tutte suonano", height: 36) { opz.trackOn = Array(repeating: true, count: 8) }
        }
    }
}

/// «ricomincia da zero» chiede conferma con un secondo tasto: cancella tutto Crea.
struct OPZResetRow: View {
    @EnvironmentObject var opz: OPZEngine
    @State private var asking = false

    var body: some View {
        if asking {
            HStack(spacing: 6) {
                Button { opz.resetCrea(); asking = false } label: {
                    Text("sì, cancella tutto")
                        .font(.system(.subheadline, design: .monospaced).weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .vetroKey(.red)
                }
                .buttonStyle(.plain)
                VetroGridChip(text: "no, lascia stare") { asking = false }
            }
        } else {
            Button { asking = true } label: {
                Text("ricomincia da zero")
                    .font(.system(.subheadline, design: .monospaced))
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .vetroKey(.tinted(Palette.rec))
            }
            .buttonStyle(.plain)
            .accessibilityHint("cancella tutti i pattern, gli effetti e la catena del progetto aperto")
        }
    }
}

/// L'automazione a passi: Bobina gira una manopola dell'OP-Z a ogni passo, a tempo. Salvata nel progetto.
struct OPZAutomCard: View {
    @EnvironmentObject var opz: OPZEngine

    private static let short = ["par 1", "par 2", "filtro", "riso", "att", "dec", "sus", "rel",
                                "lfo prof", "lfo vel", "lfo dest", "lfo forma", "fx 1", "fx 2", "pan", "vol"]

    var body: some View {
        let lane = opz.lane
        let eight = Array(repeating: GridItem(.flexible(), spacing: 4), count: 8)
        OPZPanel {
            OPZLabel("Bobina gira una manopola a ogni passo · 4 righe per pattern")
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { r in
                    let l = opz.autom[opz.createPattern - 1][r]
                    OPZChip(text: "riga \(r + 1)\(l.values.contains { $0 != nil } ? "•" : "")", on: opz.laneIndex == r, height: 34) { opz.laneIndex = r }
                        .accessibilityLabel("riga \(r + 1)")
                }
            }
            LazyVGrid(columns: eight, spacing: 4) {
                ForEach(OPZ.tracks.prefix(8)) { t in
                    OPZChip(text: t.short, on: lane.track == t.number, color: OPZ.color(t.number), height: 34) { opz.lane.track = t.number }
                        .accessibilityLabel("automazione su \(t.name)")
                }
            }
            LazyVGrid(columns: eight, spacing: 4) {
                // volume e mandate no: un guadagno non si muove a passi (regola dell'8/10/2026)
                ForEach((1...16).filter { !OPZ.gainCCs.contains($0) }, id: \.self) { cc in
                    OPZChip(text: OPZAutomCard.short[cc - 1], on: lane.cc == cc, height: 34) { opz.lane.cc = cc }
                        .accessibilityLabel("manopola \(OPZ.paramName(OPZ.params[cc - 1], track: lane.track))")
                }
            }
            OPZLabel("livello: 1 minimo · 8 massimo")
            LazyVGrid(columns: eight, spacing: 4) {
                ForEach(1...8, id: \.self) { v in
                    OPZChip(text: "\(v)", on: opz.autoLevel == v, height: 34) { opz.autoLevel = v }
                        .accessibilityLabel("livello \(v)")
                }
            }
            OPZAutoCells(live: opz.live, values: Array(lane.values.prefix(opz.patternLength)), tap: { opz.toggleAutoStep($0) })
            OPZChip(text: "svuota la riga \(opz.laneIndex + 1)", height: 34) { opz.clearLane() }
        }
    }
}

/// I passi dell'automazione: in ognuno il livello, con una barretta alta quanto il livello. Guarda `live`.
struct OPZAutoCells: View {
    @ObservedObject var live: OPZLive
    let values: [Int?]
    let tap: (Int) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
            ForEach(0..<values.count, id: \.self) { i in
                let v = values[i]
                Button { tap(i) } label: {
                    ZStack(alignment: .bottom) {
                        VetroKeyBackground(look: i % 4 == 0 ? .offBeat : .off)
                        if let v = v {
                            VetroKeyBackground(look: .on(OPZ.tint), radius: 10)
                                .frame(height: 46 * CGFloat(v) / 8)
                        }
                        VStack(spacing: 0) {
                            Text("\(i + 1)").font(.system(.caption2, design: .monospaced))
                            Text(v.map { "\($0)" } ?? "·").font(.system(.footnote, design: .monospaced).weight(.bold))
                        }
                        .frame(maxHeight: .infinity)
                        .foregroundStyle(v != nil && v! >= 5 ? Color.black : Color.white)
                    }
                    .frame(height: 50)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(live.step >= 0 && live.step % values.count == i ? Color.white : Color.clear, lineWidth: 3))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("automazione passo \(i + 1)")
                .accessibilityValue(v.map { "livello \($0)" } ?? "vuoto")
            }
        }
    }
}

/// Le stesse righe del promemoria, senza riquadro: si aprono dentro la parte batteria o note.
struct OPZInstrumentHelpRows: View {
    let track: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            OPZHelpRow(n: "1", text: "Traccia attiva: tieni TRACK e premi il tasto \(track) della fila dei numeri.")
            OPZHelpRow(n: "2", text: track <= 4 ? "Altro kit: tieni TRACK e premi i tasti della fila di SOPRA." : "Altro strumento: tieni TRACK e premi i tasti della fila di SOPRA.")
            OPZHelpRow(n: "3", text: "Altro suono dello stesso: tieni TRACK e premi i tasti ACCESI della fila di SOTTO.")
            OPZHelpRow(n: "4", text: "Suono a caso: tieni TRACK e premi REC.")
        }
    }
}

struct OPZHelpRow: View {
    let n: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(n)
                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                .foregroundStyle(OPZ.tint)
                .frame(width: 18)
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// I 16 pattern di Crea: pieno = quello che scrivi, bordo bianco = quello che suona.
struct OPZCreaPatterns: View {
    @EnvironmentObject var opz: OPZEngine
    @ObservedObject var live: OPZLive

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
            ForEach(1...16, id: \.self) { n in
                let editing = opz.createPattern == n
                let playing = opz.running && opz.createOn && live.createPlaying == n
                Button { opz.createPattern = n } label: {
                    Text(opz.hasNotes(pattern: n) ? "\(n)•" : "\(n)")
                        .font(.system(.subheadline, design: .monospaced).weight(editing ? .bold : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .vetroKey(editing ? .on(OPZ.tint) : .off)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(playing ? Color.white : Color.clear, lineWidth: 3))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("pattern di Bobina \(n)")
                .accessibilityAddTraits(editing ? .isSelected : [])
            }
        }
    }
}
