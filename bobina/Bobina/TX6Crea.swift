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
            Text("suona: " + (tx.currentPatternName ?? "—") + (tx.pendingPatternName.map { " · poi \($0), alla battuta" } ?? "")
                 + (tx.swing > 0.505 ? " · swing \(Int((tx.swing * 100).rounded()))%" : ""))
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
        #if DEBUG
        .onAppear {
            let prova = UserDefaults.standard.bool(forKey: "bobina.prova.crea")
            trace("Crea aperta, prova automatica: \(prova ? "sì" : "no")")
            if prova { TX6SelfTest.run(tx) }
            // per le fotografie: `-bobina.prova.melodia Velluto` o `-bobina.prova.batteria Teardrop` carica quella pronta (solo per quel lancio)
            if let name = UserDefaults.standard.string(forKey: "bobina.prova.melodia"),
               let m = TX6MelodyPreset.all.first(where: { $0.name == name }) {
                tx.applyMelody(m)
            }
            if let name = UserDefaults.standard.string(forKey: "bobina.prova.batteria"),
               let d = TX6DrumPreset.all.first(where: { $0.name == name }) {
                tx.playDrums(d)
            }
        }
        #endif
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
    private let three = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

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
                TX6Mini(text: "1-8", on: half == 0 && view == 0) { half = 0; view = 0 }
                    .accessibilityLabel("passi 1-8")
                TX6Mini(text: "9-16", on: half == 1 && view == 0) { half = 1; view = 0 }
                    .accessibilityLabel("passi 9-16")
                TX6Mini(text: "suoni", on: view == 0, color: Color(white: 0.75)) { view = 0 }
                    .accessibilityLabel("suoni della riga")
                TX6Mini(text: "preset", on: view == 1, color: Color(white: 0.75)) { view = 1 }
                    .accessibilityLabel("preset di suono della riga")
                TX6Mini(text: "pronte", on: view == 2) { view = 2 }
                    .accessibilityLabel("batterie pronte")
            }
            if view == 2 {
                HStack(spacing: 4) {
                    TX6Label("Cambiano solo le tracce 1-4 ed entrano subito, anche col ritmo che gira.")
                    // di serie il tempo resta: col TX-6 a tempo con gli altri apparecchi non cambia il bpm di tutti
                    TX6Mini(text: tx.patternTempo ? "anche il tempo: sì" : "anche il tempo: no", on: tx.patternTempo, height: 40) {
                        tx.patternTempo.toggle()
                    }
                    .frame(width: 120)
                    .accessibilityLabel(tx.patternTempo ? "le pronte cambiano anche il tempo" : "le pronte lasciano il tempo com'è")
                }
                if let cur = TX6DrumPreset.all.first(where: { $0.name == (tx.pendingPatternName ?? tx.currentPatternName) }) {
                    HStack(spacing: 4) {
                        Text("\(cur.ref) · \(cur.bpm) bpm" + (cur.swing > 0.505 ? " · swing \(Int((cur.swing * 100).rounded()))%" : ""))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Palette.accent)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        // il tempo del disco con un tocco: senza la spunta il tempo resta, ma ogni batteria suona
                        // meglio al suo (Teardrop a 120 invece di 77 suonava male, 9/10/2026)
                        if tx.clockMode != .follow && abs(tx.bpm - Double(cur.bpm)) > 0.5 {
                            TX6Mini(text: "metti \(cur.bpm) bpm", height: 40) { tx.bpm = Double(cur.bpm) }
                                .frame(width: 120)
                                .accessibilityLabel("metti il tempo del disco, \(cur.bpm) bpm")
                        }
                    }
                }
                ForEach(TX6DrumPreset.groups, id: \.self) { g in
                    TX6Label(g)
                    LazyVGrid(columns: five, spacing: 4) {
                        ForEach(TX6DrumPreset.all.filter { $0.group == g }) { d in
                            TX6Mini(text: d.name, on: tx.currentPatternName == d.name || tx.pendingPatternName == d.name, height: 40) { tx.playDrums(d) }
                                .accessibilityLabel("batteria \(d.name), \(d.bpm) bpm")
                        }
                    }
                }
            } else if view == 1 {
                // i suoni pronti della riga: senza griglia, così ci stanno tutti
                TX6TrackRow(selected: row, label: { "\($0) \(tx.soundName($0))" }) { row = $0; tx.hitPad($0) }
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
                LazyVGrid(columns: three, spacing: 4) {
                    ForEach(list) { p in
                        TX6Mini(text: p.name, height: 38) { pick(p) }
                            .accessibilityLabel("preset \(p.name) sulla riga \(row)")
                    }
                }
                TX6Label("Il suono va sulla riga \(row) e la senti subito. Alla griglia si torna con «suoni».")
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
                                .frame(width: 62, height: 36, alignment: .leading)
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
                                        .frame(height: 36)
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
                HStack(spacing: 4) {
                    TX6Mini(text: tx.beatsOn ? "batteria accesa" : "batteria spenta", on: tx.beatsOn) { tx.beatsOn.toggle() }
                        .accessibilityLabel(tx.beatsOn ? "spegni la batteria" : "accendi la batteria")
                    TX6ConfirmMini(text: "svuota tutta la batteria") { tx.clearDrums() }
                }
                LazyVGrid(columns: five, spacing: 4) {
                    ForEach(Self.soundOrder, id: \.self) { i in
                        TX6Mini(text: TX6.sounds[i], on: tx.sentSounds[row - 1].map { TX6.soundIndex($0) } == i) {
                            tx.setSound(row, i)
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

// MARK: - melodia

/// La melodia scritta in fila, come NTS-1 e M8: ogni nota toccata va nel passo del cursore e il cursore va avanti.
/// Toccando un passo il cursore va lì; «pausa» lascia un passo vuoto. Ogni traccia ha una battuta o due,
/// e la sua durata delle note («tenuta» = fino alla nota dopo, come sull'OP-Z).
struct TX6MelodyPanel: View {
    @EnvironmentObject var tx: TX6Engine
    @ObservedObject var live: TX6Live
    @AppStorage("bobina.tx6.crea.melodia.traccia") private var track = 1
    @AppStorage("bobina.tx6.crea.melodia.pronte") private var showPresets = false
    /// L'ultima melodia pronta scelta: resta accesa, e sopra si legge a cosa somiglia.
    @AppStorage("bobina.tx6.crea.melodia.scelta") private var picked = ""

    /// I tasti: l'ottava della traccia, dal do al do sopra.
    static let names = ["do", "do#", "re", "re#", "mi", "fa", "fa#", "sol", "sol#", "la", "la#", "si", "do↑"]
    private static let black: Set<Int> = [1, 3, 6, 8, 10]
    /// Le durate: in sedicesimi, 0 = tenuta fino alla nota dopo.
    static let gates: [(Int, String)] = [(1, "1/16"), (2, "1/8"), (4, "1/4"), (8, "1/2"), (0, "tenuta")]
    private let seven = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let five = Array(repeating: GridItem(.flexible(), spacing: 4), count: 5)
    /// L'ultima nota toccata: «ogni 4» la mette su un passo ogni quattro.
    @State private var lastNote = 0

    /// Il nome di una nota della melodia: nell'ottava della traccia, con ↑ sopra e ↓ sotto (14 = re↑, −3 = la↓).
    static func noteName(_ k: Int) -> String {
        let pc = ((k % 12) + 12) % 12
        let o = k >= 0 ? k / 12 : -((-k + 11) / 12)
        let base = ["do", "do#", "re", "re#", "mi", "fa", "fa#", "sol", "sol#", "la", "la#", "si"][pc]
        return base + String(repeating: o > 0 ? "↑" : "↓", count: abs(o))
    }

    var body: some View {
        let t = min(6, max(1, track))
        let mel = tx.melodies[t - 1]
        let count = max(1, mel.count)
        TX6Box {
            HStack(spacing: 4) {
                ForEach(1...6, id: \.self) { n in
                    TX6Mini(text: "\(n) \(tx.soundName(n))", on: t == n) { track = n; showPresets = false }
                        .accessibilityLabel("traccia \(n)")
                }
                TX6Mini(text: "pronte", on: showPresets, color: Color(white: 0.75)) { showPresets.toggle() }
                    .accessibilityLabel("melodie scure pronte")
            }
            if showPresets {
                TX6Label("Basso sulla traccia 5 e melodia sulla 6, due battute. Tutte in re minore: si cambiano a tempo senza stonare.")
                if let cur = TX6MelodyPreset.all.first(where: { $0.name == picked }) {
                    Text("\(cur.name): \(cur.ref)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.accent)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(TX6MelodyPreset.groups, id: \.self) { g in
                    TX6Label(g)
                    LazyVGrid(columns: five, spacing: 4) {
                        ForEach(TX6MelodyPreset.all.filter { $0.group == g }) { m in
                            TX6Mini(text: m.name, on: picked == m.name, height: 40) {
                                tx.applyMelody(m)
                                picked = m.name
                                track = 6
                                showPresets = false
                            }
                            .accessibilityLabel("melodia \(m.name)")
                        }
                    }
                }
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
                    TX6Mini(text: "indietro") { tx.melodyBack(t) }
                    TX6Mini(text: "\(Self.names[lastNote]) ogni 4") {
                        for i in stride(from: 0, to: count, by: 4) { tx.melodies[t - 1][i] = lastNote }
                        tx.melodyOn = true
                    }
                    .accessibilityLabel("nota su ogni 4")
                }
                TX6CursorGrid(live: live, pulsing: tx.pulsing, cursor: tx.melodyCursor % count,
                              label: { mel.indices.contains($0) ? (mel[$0].map { Self.noteName($0) } ?? "·") : "·" },
                              filled: { mel.indices.contains($0) && mel[$0] != nil },
                              select: { tx.selectMelodyStep(t, $0) },
                              count: count)
                HStack(spacing: 4) {
                    Text("dura")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                    ForEach(Self.gates, id: \.0) { g in
                        TX6Mini(text: g.1, on: tx.melodyGates[t - 1] == g.0) { tx.melodyGates[t - 1] = g.0 }
                            .accessibilityLabel(g.0 == 0 ? "traccia \(t), note tenute fino alla nota dopo" : "traccia \(t), ogni nota dura \(g.1)")
                    }
                }
                HStack(spacing: 4) {
                    TX6Mini(text: tx.melodyOn ? "melodia accesa" : "melodia spenta", on: tx.melodyOn) { tx.melodyOn.toggle() }
                        .accessibilityLabel(tx.melodyOn ? "spegni le melodie" : "accendi le melodie")
                    TX6Mini(text: "2 battute", on: count > 16) { tx.setMelodyBars(t, count > 16 ? 1 : 2) }
                        .accessibilityLabel(count > 16 ? "traccia \(t) torna a una battuta" : "traccia \(t) a due battute")
                    TX6ConfirmMini(text: "svuota traccia \(t)") { tx.clearMelody(t) }
                        .accessibilityLabel("svuota la melodia della traccia \(t)")
                    TX6ConfirmMini(text: "svuota tutto") { tx.clearMelodies() }
                        .accessibilityLabel("svuota tutte le melodie")
                }
                // il Playdate al posto del synth: le note di questa traccia vanno solo al Playdate, il TX-6 non le suona
                // e il suo ingresso (col Playdate dentro) passa da solo. Se il Playdate non risponde, suonano sul TX-6.
                HStack(spacing: 4) {
                    let onPlaydate = tx.toPlaydate.contains(t)
                    TX6Mini(text: onPlaydate ? "traccia \(t) al Playdate: sì" : "traccia \(t) al Playdate: no", on: onPlaydate) {
                        if onPlaydate { tx.toPlaydate.remove(t) } else { tx.toPlaydate.insert(t) }
                    }
                    .accessibilityLabel(onPlaydate ? "traccia \(t) torna al TX-6" : "traccia \(t) al Playdate")
                }
                if tx.toPlaydate.contains(t) {
                    TX6Label("Le note della traccia \(t) suonano solo sul Playdate: il synth del TX-6 tace e nel suo ingresso \(t) passa il Playdate. Se il Playdate non risponde, suonano sul TX-6.")
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
                Text("swing")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.dim)
                ForEach([(0.5, "dritto"), (0.54, "54"), (0.58, "58"), (0.62, "62"), (0.66, "66")], id: \.0) { sw in
                    TX6Mini(text: sw.1, on: abs(tx.swing - sw.0) < 0.005) { tx.swing = sw.0 }
                        .accessibilityLabel(sw.0 == 0.5 ? "swing dritto" : "swing \(sw.1) per cento")
                }
            }
            HStack(spacing: 4) {
                TX6Mini(text: tx.patternTempo ? "anche il tempo: sì" : "anche il tempo: no", on: tx.patternTempo) { tx.patternTempo.toggle() }
                    .accessibilityLabel(tx.patternTempo ? "cambiando pattern o pronta cambia anche il tempo" : "cambiando pattern o pronta il tempo resta")
                TX6ConfirmMini(text: "cancella tutto") { tx.clearSequence() }
            }
        }
    }
}
