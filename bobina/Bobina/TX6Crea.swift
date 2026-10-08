import SwiftUI

/// Crea: batteria, melodia, passi con manopola e pattern, una parte alla volta e in uno schermo.
/// In cima sempre suona/ferma e il tempo (8/10/2026: prima stava tutto in Suona e bisognava scorrere su e giù).
struct TX6CreaView: View {
    @EnvironmentObject var tx: TX6Engine
    @AppStorage("bobina.tx6.crea.parte") private var part = 0

    static let parts = ["batteria", "melodia", "manopola", "pattern"]

    var body: some View {
        TX6Screen(title: "Crea") {
            TX6TempoTop()
            Text("suona: " + (tx.currentPatternName ?? "—") + (tx.pendingPatternName.map { " · poi \($0), alla battuta" } ?? ""))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Palette.dim)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            TX6Parts(items: Self.parts, selection: $part)
            switch part {
            case 1: TX6MelodyPanel(live: tx.live)
            case 2: TX6LockPanel(live: tx.live)
            case 3: TX6PatternPanel()
            default: TX6DrumPanel(live: tx.live)
            }
        }
    }
}

// MARK: - batteria

/// Le sei tracce una sotto l'altra, otto passi alla volta. Toccando il nome la traccia suona e diventa la riga
/// su cui lavorano i riempimenti, i suoni e i preset pronti.
struct TX6DrumPanel: View {
    @EnvironmentObject var tx: TX6Engine
    @ObservedObject var live: TX6Live
    @AppStorage("bobina.tx6.crea.meta") private var half = 0
    @AppStorage("bobina.tx6.crea.riga") private var row = 1
    /// Sotto la griglia: 0 i suoni della riga, 1 i preset di suono della riga; 2 = al posto della griglia le batterie pronte.
    @AppStorage("bobina.tx6.crea.batteria.vista") private var view = 0
    @AppStorage("bobina.tx6.crea.batteria.gruppo") private var group = "cassa"

    private static let fills: [(name: String, steps: [Int])] = [
        ("ogni 4", [0, 4, 8, 12]), ("ogni 2", Array(stride(from: 0, to: 16, by: 2))),
        ("contro", [2, 6, 10, 14]), ("tutti", Array(0..<16)), ("svuota", [])
    ]
    /// Prima la batteria, poi le onde.
    static let soundOrder = [4, 5, 6, 7, 8, 0, 1, 2, 3, 9]
    private let five = Array(repeating: GridItem(.flexible(), spacing: 4), count: 5)
    private let four = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)

    private func pick(_ p: TX6Preset) {
        tx.apply(p, to: row)
        let r = row
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { tx.hitPad(r) }
    }

    var body: some View {
        #if DEBUG
        let _ = Diagnostics.shared.count("batteria tx6")
        #endif
        TX6Box {
            HStack(spacing: 4) {
                TX6Mini(text: "1-8", on: half == 0 && view != 2) { half = 0; if view == 2 { view = 0 } }
                    .accessibilityLabel("passi 1-8")
                TX6Mini(text: "9-16", on: half == 1 && view != 2) { half = 1; if view == 2 { view = 0 } }
                    .accessibilityLabel("passi 9-16")
                TX6Mini(text: "suoni", on: view == 0, color: Color(white: 0.75)) { view = 0 }
                    .accessibilityLabel("suoni della riga")
                TX6Mini(text: "preset", on: view == 1, color: Color(white: 0.75)) { view = 1 }
                    .accessibilityLabel("preset di suono della riga")
                TX6Mini(text: "pronte", on: view == 2) { view = 2 }
                    .accessibilityLabel("batterie pronte")
            }
            if view == 2 {
                TX6Label("Cambiano solo le tracce 1-4: melodie e tracce 5-6 restano. Col ritmo che gira entrano alla battuta.")
                ForEach(TX6DrumPreset.groups, id: \.self) { g in
                    TX6Label(g)
                    LazyVGrid(columns: four, spacing: 4) {
                        ForEach(TX6DrumPreset.all.filter { $0.group == g }) { d in
                            TX6Mini(text: d.name, on: tx.currentPatternName == d.name || tx.pendingPatternName == d.name, height: 40) { tx.playDrums(d) }
                                .accessibilityLabel("batteria \(d.name), \(d.bpm) bpm")
                        }
                    }
                }
            } else {
                VStack(spacing: 4) {
                    ForEach(1...6, id: \.self) { t in
                        HStack(spacing: 4) {
                            Button {
                                row = t
                                tx.hitPad(t)
                            } label: {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("\(t)")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(row == t ? Color.black : Palette.dim)
                                    Text(tx.soundName(t))
                                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                }
                                .padding(.leading, 6)
                                .frame(width: 62, height: 40, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 7).fill(row == t ? Palette.accent : Color(white: 0.14)))
                                .foregroundStyle(row == t ? Color.black : Color.white)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("riga \(t), \(tx.soundName(t))")
                            ForEach(0..<8, id: \.self) { c in
                                let i = half * 8 + c
                                let on = tx.beats[t - 1][i]
                                Button {
                                    tx.beats[t - 1][i].toggle()
                                    tx.beatsOn = true
                                    row = t
                                } label: {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(on ? Palette.accent : Color(white: c % 4 == 0 ? 0.26 : 0.18))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(tx.pulsing && live.step == i ? Color.white : Color.clear, lineWidth: 2))
                                        .frame(height: 40)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("traccia \(t), passo \(i + 1)")
                                .accessibilityValue(on ? "acceso" : "spento")
                            }
                        }
                    }
                }
                HStack(spacing: 4) {
                    Text("riga \(row)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                        .frame(width: 50, alignment: .leading)
                    ForEach(Self.fills, id: \.name) { f in
                        TX6Mini(text: f.name) {
                            tx.beats[row - 1] = (0..<16).map { f.steps.contains($0) }
                            if !f.steps.isEmpty { tx.beatsOn = true }
                        }
                        .accessibilityLabel("riga \(row) \(f.name)")
                    }
                }
                if view == 1 {
                    LazyVGrid(columns: five, spacing: 4) {
                        ForEach(TX6Preset.groups + ["miei"], id: \.self) { g in
                            TX6Mini(text: g, on: group == g, color: Color(white: 0.75)) { group = g }
                                .accessibilityLabel("gruppo \(g)")
                        }
                    }
                    let list = group == "miei" ? tx.myPresets : TX6Preset.builtIn.filter { $0.group == group }
                    if list.isEmpty {
                        TX6Label("Ancora nessun preset tuo: si salvano da Suona → strumenti.")
                    }
                    LazyVGrid(columns: four, spacing: 4) {
                        ForEach(list) { p in
                            TX6Mini(text: p.name) { pick(p) }
                                .accessibilityLabel("preset \(p.name) sulla riga \(row)")
                        }
                    }
                } else {
                    LazyVGrid(columns: five, spacing: 4) {
                        ForEach(Self.soundOrder, id: \.self) { i in
                            TX6Mini(text: TX6.sounds[i], on: tx.sentSounds[row - 1].map { TX6.soundIndex($0) } == i) {
                                tx.set(row, .sound, TX6.soundValue(i))
                                let r = row
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { tx.hitPad(r) }
                            }
                            .accessibilityLabel("riga \(row) suono \(TX6.sounds[i])")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - melodia

/// La melodia scritta in fila, come NTS-1 e M8: ogni nota toccata va nel passo del cursore e il cursore va avanti.
/// Toccando un passo il cursore va lì; «pausa» lascia un passo vuoto.
struct TX6MelodyPanel: View {
    @EnvironmentObject var tx: TX6Engine
    @ObservedObject var live: TX6Live
    @AppStorage("bobina.tx6.crea.melodia.traccia") private var track = 1
    @AppStorage("bobina.tx6.crea.melodia.pronte") private var showPresets = false

    static let names = ["do", "do#", "re", "re#", "mi", "fa", "fa#", "sol", "sol#", "la", "la#", "si", "do↑"]
    private static let black: Set<Int> = [1, 3, 6, 8, 10]
    private let seven = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    /// L'ultima nota toccata: «ogni 4» la mette sui passi 1, 5, 9, 13.
    @State private var lastNote = 0
    /// L'ultima melodia pronta scelta, per vederla accesa.
    @State private var picked: String?
    private let three = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    var body: some View {
        let t = min(6, max(1, track))
        TX6Box {
            HStack(spacing: 4) {
                ForEach(1...6, id: \.self) { n in
                    TX6Mini(text: "\(n) \(tx.soundName(n))", on: t == n) { track = n }
                        .accessibilityLabel("traccia \(n)")
                }
                TX6Mini(text: "pronte", on: showPresets, color: Color(white: 0.75)) { showPresets.toggle() }
                    .accessibilityLabel("melodie scure pronte")
            }
            if showPresets {
                TX6Label("linee, sulla traccia \(t)")
                LazyVGrid(columns: three, spacing: 4) {
                    ForEach(TX6MelodyPreset.dark.filter { !$0.chord }) { m in
                        TX6Mini(text: m.name, on: picked == m.name, height: 40) { tx.applyMelody(m, from: t); picked = m.name }
                            .accessibilityLabel("melodia \(m.name)")
                    }
                }
                TX6Label(t <= 4 ? "accordi, sulle tracce \(t)-\(t + 2)" : "accordi: scegli una traccia fino alla 4")
                LazyVGrid(columns: three, spacing: 4) {
                    ForEach(TX6MelodyPreset.dark.filter { $0.chord }) { m in
                        TX6Mini(text: m.name, on: picked == m.name, height: 40) { tx.applyMelody(m, from: t); picked = m.name }
                            .disabled(t > 4)
                            .opacity(t > 4 ? 0.4 : 1)
                            .accessibilityLabel("accordi \(m.name)")
                    }
                }
                TX6Label("Tocca «pronte» per tornare a scrivere.")
            } else {
                LazyVGrid(columns: seven, spacing: 4) {
                    ForEach(0..<13, id: \.self) { k in
                        Button {
                            tx.writeNote(t, k)
                            lastNote = k
                        } label: {
                            Text(Self.names[k])
                                .font(.system(.body, design: .monospaced).weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: Self.black.contains(k) ? 0.10 : 0.24)))
                                .foregroundStyle(Self.black.contains(k) ? Palette.dim : Color.white)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(k == 12 ? "nota do sopra" : "nota \(Self.names[k])")
                    }
                    TX6Mini(text: "pausa", height: 46) { tx.writeNote(t, nil) }
                        .accessibilityLabel("pausa")
                }
                HStack(spacing: 4) {
                    TX6Mini(text: "ott −") { tx.melodyOctaves[t - 1] = max(1, tx.melodyOctaves[t - 1] - 1) }
                        .accessibilityLabel("ottava meno")
                    Text("ott. \(tx.melodyOctaves[t - 1])")
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minWidth: 48)
                    TX6Mini(text: "ott +") { tx.melodyOctaves[t - 1] = min(7, tx.melodyOctaves[t - 1] + 1) }
                        .accessibilityLabel("ottava più")
                    TX6Mini(text: "indietro") { tx.melodyBack() }
                    TX6Mini(text: "\(Self.names[lastNote]) ogni 4") {
                        for i in stride(from: 0, to: 16, by: 4) { tx.melodies[t - 1][i] = lastNote }
                        tx.melodyOn = true
                    }
                    .accessibilityLabel("nota su ogni 4")
                }
            }
            if !showPresets {
            TX6CursorGrid(live: live, pulsing: tx.pulsing, cursor: tx.melodyCursor,
                          label: { tx.melodies[t - 1][$0].map { Self.names[$0] } ?? "·" },
                          filled: { tx.melodies[t - 1][$0] != nil },
                          select: { tx.selectMelodyStep(t, $0) })
            HStack(spacing: 4) {
                Text("dura")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.dim)
                ForEach([(1, "1/16"), (2, "1/8"), (4, "1/4")], id: \.0) { l in
                    TX6Mini(text: l.1, on: tx.melodyLength == l.0) { tx.melodyLength = l.0 }
                        .accessibilityLabel("ogni nota dura \(l.1)")
                }
                TX6ConfirmMini(text: "svuota") {
                    tx.melodies[t - 1] = Array(repeating: nil, count: 16)
                    tx.melodyCursor = 0
                }
                .accessibilityLabel("svuota la traccia \(t)")
                TX6ConfirmMini(text: "tutte") {
                    tx.melodies = Array(repeating: Array(repeating: nil, count: 16), count: 6)
                    tx.melodyCursor = 0
                }
                .accessibilityLabel("svuota tutte le melodie")
            }
            }
        }
    }
}

// MARK: - passi con manopola

/// Un valore diverso a ogni passo per un parametro di una traccia: sei suoni diversi dalla stessa traccia.
/// Si scrive in fila come la melodia: ogni valore toccato va nel passo del cursore.
struct TX6LockPanel: View {
    @EnvironmentObject var tx: TX6Engine
    @ObservedObject var live: TX6Live

    private let five = Array(repeating: GridItem(.flexible(), spacing: 4), count: 5)

    var body: some View {
        TX6Box {
            HStack(spacing: 4) {
                TX6Mini(text: tx.lockOn ? "accesi" : "spenti", on: tx.lockOn) { tx.lockOn.toggle() }
                    .accessibilityLabel(tx.lockOn ? "spegni i passi con manopola" : "accendi i passi con manopola")
                ForEach(1...6, id: \.self) { n in
                    TX6Mini(text: "tr \(n)", on: tx.lockTrack == n) { tx.lockTrack = n }
                        .accessibilityLabel("traccia \(n)")
                }
            }
            LazyVGrid(columns: five, spacing: 4) {
                ForEach(TX6.Param.movable) { p in
                    TX6Mini(text: p.name, on: tx.lockParam == p, color: Color(white: 0.75)) { tx.lockParam = p }
                        .accessibilityLabel("parametro \(p.name)")
                }
            }
            HStack(spacing: 4) {
                TX6Mini(text: "vuoto") { tx.writeLock(nil) }
                    .accessibilityLabel("passo vuoto")
                ForEach(TX6Jump.of(tx.lockParam), id: \.self) { j in
                    TX6Mini(text: j.label) { tx.writeLock(j.value) }
                        .accessibilityLabel("valore \(j.spoken)")
                }
                TX6Mini(text: "←") { tx.lockBack() }
                    .accessibilityLabel("indietro")
            }
            TX6CursorGrid(live: live, pulsing: tx.pulsing, cursor: tx.lockCursor,
                          label: { tx.locks[$0].map { "\($0)" } ?? "·" },
                          filled: { tx.locks[$0] != nil },
                          select: { tx.lockCursor = $0 })
            HStack(spacing: 4) {
                TX6Label("\(tx.lockParam.name) della traccia \(tx.lockTrack), con la batteria")
                TX6ConfirmMini(text: "svuota") {
                    tx.locks = Array(repeating: nil, count: 16)
                    tx.lockCursor = 0
                }
                .frame(width: 90)
            }
        }
    }
}

// MARK: - pattern

/// Stili pronti e pattern salvati. Se il ritmo gira, il cambio arriva all'inizio della battuta.
struct TX6PatternPanel: View {
    @EnvironmentObject var tx: TX6Engine

    private let three = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    var body: some View {
        let mine = tx.patterns.first { $0.id == tx.currentPatternID }
        TX6Box {
            TX6Label("stili pronti")
            LazyVGrid(columns: three, spacing: 4) {
                ForEach(TX6Pattern.styles) { st in
                    TX6Mini(text: st.name, on: tx.currentPatternID == st.id, height: 40) { tx.play(st) }
                        .accessibilityLabel("stile \(st.name)")
                }
            }
            TX6Label(tx.patterns.isEmpty ? "i miei: ancora nessuno. Prepara batteria e melodia, poi «salva nuovo»." : "i miei")
            LazyVGrid(columns: three, spacing: 4) {
                ForEach(tx.patterns) { p in
                    TX6Mini(text: p.name, on: tx.currentPatternID == p.id, height: 40) { tx.play(p) }
                        .accessibilityLabel("pattern \(p.name)")
                }
            }
            HStack(spacing: 4) {
                TX6Mini(text: "salva nuovo") { tx.saveNewPattern() }
                if let m = mine {
                    TX6Mini(text: "salva su \(m.name)") { tx.overwrite(m) }
                    TX6ConfirmMini(text: "togli \(m.name)") { tx.deletePattern(m) }
                }
            }
            HStack(spacing: 4) {
                TX6Mini(text: tx.patternTempo ? "cambia anche il tempo" : "il tempo resta", on: tx.patternTempo) { tx.patternTempo.toggle() }
                    .accessibilityLabel(tx.patternTempo ? "cambiando pattern cambia anche il tempo" : "cambiando pattern il tempo resta")
                TX6ConfirmMini(text: "cancella tutto") { tx.clearSequence() }
            }
        }
    }
}
