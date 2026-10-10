import SwiftUI

// MARK: - le quattro schermate dell'NTS-1

/// Suono, Suona, Passi, Banche, Collega. Riapre l'ultima scheda usata.
struct NTS1Tabs: View {
    @AppStorage("bobina.nts1.scheda") private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            NTS1SuonoView()
                .tabItem { Label("Suono", systemImage: "dial.medium") }.tag(0)
            NTS1SuonaView()
                .tabItem { Label("Suona", systemImage: "pianokeys") }.tag(1)
            NTS1PassiView()
                .tabItem { Label("Passi", systemImage: "square.grid.4x3.fill") }.tag(4)
            NTS1BancheView()
                .tabItem { Label("Banche", systemImage: "square.stack.3d.up") }.tag(2)
            NTS1CollegaView()
                .tabItem { Label("Collega", systemImage: "cable.connector") }.tag(3)
        }
        .tint(NTS1.color)
    }
}

struct NTS1Page<Content: View>: View {
    let title: String
    /// Senza la fascia col nome: per le schede che devono stare tutte in uno schermo.
    var compact = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        #if DEBUG
        let _ = Diagnostics.shared.count("pagina nts1 " + title)
        #endif
        NavigationStack {
            ScrollView {
                VStack(spacing: compact ? 10 : 12) {
                    if !compact { NTS1Banner() }
                    NTS1StatusStrip()
                    content()
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 24)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { MachineSwitch() } }
        }
    }
}

struct NTS1Banner: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("NTS-1")
                .font(.system(.title2, design: .rounded).weight(.bold))
            Text("Korg · digital kit mkII")
                .font(.system(.subheadline, design: .monospaced))
                .opacity(0.75)
            Spacer()
        }
        .foregroundStyle(Color.black)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(NTS1.color))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("NTS-1")
    }
}

struct NTS1StatusStrip: View {
    @EnvironmentObject var nts1: NTS1Engine

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(nts1.connected ? Color.green : Palette.rec)
                .frame(width: 8, height: 8)
            Text(nts1.connected ? "collegato a \(nts1.connectedName) · canale \(nts1.channel)" : "NTS-1 non collegato · vai su Collega")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
                .lineLimit(1)
            Spacer()
        }
        .padding(.top, 6)
        if let g = nts1.global, !g.shortMessages {
            Text("l'NTS-1 non ascolta le manopole · Collega → sistema le impostazioni")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.rec)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Un tasto largo e pieno, per le cose che si fanno spesso.
struct NTS1BigButton: View {
    let text: String
    var on = false
    var color: Color = NTS1.color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(RoundedRectangle(cornerRadius: 10).fill(on ? Palette.rec : color))
                .foregroundStyle(Color.black)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Suono

/// Le sezioni della scheda Suono: se ne vede una per volta, così tutto sta in uno schermo.
enum NTS1Part: String, CaseIterable, Identifiable {
    case osc, filter, eg, mod, delay, reverb, volume

    var id: String { rawValue }

    var label: String {
        switch self {
        case .osc: return "osc"
        case .filter: return "filtro"
        case .eg: return "inviluppo"
        case .mod: return "mod"
        case .delay: return "delay"
        case .reverb: return "reverb"
        case .volume: return "volume"
        }
    }

    var choice: NTS1.Choice? {
        switch self {
        case .osc: return .osc
        case .filter: return .filter
        case .eg: return .eg
        case .mod: return .mod
        case .delay: return .delay
        case .reverb: return .reverb
        case .volume: return nil
        }
    }

    var knobs: [NTS1.Knob] {
        switch self {
        case .osc: return [.oscA, .oscB, .lfoRate, .lfoDepth]
        case .filter: return [.cutoff, .resonance, .sweepDepth, .sweepRate]
        case .eg: return [.attack, .release, .tremoloDepth, .tremoloRate]
        case .mod: return [.modA, .modB]
        case .delay: return [.delayA, .delayB, .delayMix]
        case .reverb: return [.reverbA, .reverbB, .reverbMix]
        case .volume: return [.volume]
        }
    }
}

struct NTS1SuonoView: View {
    @EnvironmentObject var nts1: NTS1Engine
    @AppStorage("bobina.nts1.suono.parte") private var part = NTS1Part.filter.rawValue

    private let four = Array(repeating: GridItem(.flexible(), spacing: 5), count: 4)

    var body: some View {
        let current = NTS1Part(rawValue: part) ?? .filter
        NTS1Page(title: "Suono", compact: true) {
            NTS1ProgramLine(sound: nts1.sound)
            // le sezioni: un tocco e si vede quella
            LazyVGrid(columns: four, spacing: 5) {
                ForEach(NTS1Part.allCases) { p in
                    NTS1SmallChip(text: p.label, on: p == current, height: 40) { part = p.rawValue }
                        .accessibilityLabel("sezione \(p.label)")
                }
            }
            NTS1PartPanel(sound: nts1.sound, part: current)
        }
    }
}

/// Il nome del suono in una riga, con «rileggi».
struct NTS1ProgramLine: View {
    @EnvironmentObject var nts1: NTS1Engine
    @ObservedObject var sound: NTS1Sound

    var body: some View {
        HStack(spacing: 8) {
            Text(sound.programName.isEmpty ? "suono non letto" : sound.programName)
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .lineLimit(1)
            Spacer()
            NTS1SmallChip(text: "rileggi") { nts1.readProgram() }
                .frame(width: 90)
                .accessibilityLabel("rileggi il suono")
        }
    }
}

/// Una sezione: i tipi in tasti piccoli e le manopole coi salti.
struct NTS1PartPanel: View {
    @EnvironmentObject var nts1: NTS1Engine
    @ObservedObject var sound: NTS1Sound
    let part: NTS1Part

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let c = part.choice {
                NTS1ChoiceGrid(choice: c, selected: sound.choices[c], name: sound.names[c], columns: 4, small: true) { nts1.set(c, $0) }
            }
            ForEach(part.knobs) { k in
                NTS1KnobRow(knob: k, value: sound.value(k)) { nts1.set(k, $0) }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.cardEdge, lineWidth: 1))
    }
}

/// Una manopola senza slider: nome e valore, poi − · 0 · ¼ · ½ · ¾ · max · +.
/// Da zero al massimo è un tocco solo; − e + ritoccano di 8.
struct NTS1KnobRow: View {
    let knob: NTS1.Knob
    let value: Int
    let set: (Int) -> Void

    static let jumps: [(Int, String, String)] = [(0, "0", "zero"), (32, "¼", "un quarto"), (64, "½", "metà"), (96, "¾", "tre quarti"), (127, "max", "massimo")]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(knob.label)
                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                Spacer()
                Text(knob.shown(value))
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(NTS1.color)
            }
            // lo slider è per il QuadStick; col Controllo Vocale servono i tasti sotto
            NTS1DragBar(value: value, set: set)
                .accessibilityLabel(knob.label)
            if knob.isGain {
                // il volume: solo − e + a passi piccoli. Un «max» capito male dal Controllo Vocale
                // può rompere casse e cuffie (regola di Giampiero, in LEGGIMI)
                HStack(spacing: 4) {
                    NTS1SmallChip(text: "− volume", height: 40) { set(max(0, value - 4)) }
                        .accessibilityLabel("volume meno")
                    NTS1SmallChip(text: "+ volume", height: 40) { set(min(127, value + 4)) }
                        .accessibilityLabel("volume più")
                }
            } else {
                HStack(spacing: 4) {
                    NTS1SmallChip(text: "−") { set(max(0, value - 8)) }
                        .accessibilityLabel("\(knob.label) meno")
                    ForEach(NTS1KnobRow.jumps, id: \.0) { j in
                        NTS1SmallChip(text: j.1, on: abs(value - j.0) <= 4) { set(j.0) }
                            .accessibilityLabel("\(knob.label) \(j.2)")
                    }
                    NTS1SmallChip(text: "+") { set(min(127, value + 8)) }
                        .accessibilityLabel("\(knob.label) più")
                }
            }
        }
    }
}

/// Un tasto più piccolo di GridChip, per le schede fitte.
struct NTS1SmallChip: View {
    let text: String
    var on = false
    var height: CGFloat = 34
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(RoundedRectangle(cornerRadius: 7).fill(on ? NTS1.color : Color(white: 0.18)))
                .foregroundStyle(on ? Color.black : Color.white)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// I tipi in una griglia di tre colonne, ognuno col suo nome per il Controllo Vocale.
struct NTS1ChoiceGrid: View {
    let choice: NTS1.Choice
    let selected: Int?
    var name: String? = nil
    var columns = 3
    /// Tasti piccoli, per la scheda Suono.
    var small = false
    let pick: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let n = name, selected == nil {
                Text("adesso: \(n)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(NTS1.color)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: small ? 4 : 6), count: columns), spacing: small ? 4 : 6) {
                ForEach(choice.items.indices, id: \.self) { i in
                    Group {
                        if small {
                            NTS1SmallChip(text: choice.items[i], on: selected == i) { pick(i) }
                        } else {
                            GridChip(text: choice.items[i], on: selected == i) { pick(i) }
                        }
                    }
                    .accessibilityLabel("\(choice.title) \(choice.items[i])")
                    .accessibilityAddTraits(selected == i ? .isSelected : [])
                }
            }
        }
    }
}

// MARK: - Suona

/// Le parti della scheda Suona: se ne vede una per volta.
enum NTS1PlayPart: String, CaseIterable, Identifiable {
    case pads, wave, tilt, machineArp
    var id: String { rawValue }
    var label: String {
        switch self {
        case .pads: return "pad"
        case .wave: return "onda"
        case .tilt: return "inclina"
        case .machineArp: return "arp NTS-1"
        }
    }
}

struct NTS1SuonaView: View {
    @EnvironmentObject var nts1: NTS1Engine
    @AppStorage("bobina.nts1.suona.parte") private var part = NTS1PlayPart.pads.rawValue

    private let four = Array(repeating: GridItem(.flexible(), spacing: 5), count: 4)

    var body: some View {
        let current = NTS1PlayPart(rawValue: part) ?? .pads
        NTS1Page(title: "Suona", compact: true) {
            NTS1TempoLine()
            LazyVGrid(columns: four, spacing: 5) {
                ForEach(NTS1PlayPart.allCases) { p in
                    NTS1SmallChip(text: p.label, on: p == current, height: 40) { part = p.rawValue }
                        .accessibilityLabel("parte \(p.label)")
                }
            }
            NTS1Panel {
                switch current {
                case .pads: NTS1PadsPanel(player: nts1.player)
                case .wave: NTS1WavePanel(player: nts1.player)
                case .tilt: NTS1TiltPanel(player: nts1.player)
                case .machineArp: NTS1MachineArpPanel(sound: nts1.sound)
                }
            }
        }
    }
}

/// Il riquadro scuro di una parte.
struct NTS1Panel<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content() }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.cardEdge, lineWidth: 1))
    }
}

struct NTS1Label: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(text).font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.dim)
    }
}

/// Il tempo in una riga, sempre in cima: dai il tempo all'NTS-1 (con o senza la sua sequenza) e il bpm.
struct NTS1TempoLine: View {
    @EnvironmentObject var nts1: NTS1Engine

    var body: some View {
        HStack(spacing: 5) {
            if nts1.running {
                NTS1SmallChip(text: nts1.withSequence ? "ferma l'NTS-1" : "ferma il tempo", on: true, height: 44) { nts1.stopRun() }
            } else {
                NTS1SmallChip(text: "dai il tempo", height: 44) { nts1.startClock() }
                    .accessibilityLabel("dai solo il tempo all'NTS-1")
                NTS1SmallChip(text: "+ sequenza", height: 44) { nts1.startWithSequence() }
                    .accessibilityLabel("fai partire anche la sua sequenza")
            }
            SmallKey(text: "−5") { nts1.setBPM(nts1.bpm - 5) }.accessibilityLabel("tempo meno 5")
            Text("\(nts1.bpm)")
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .frame(minWidth: 44)
            SmallKey(text: "+5") { nts1.setBPM(nts1.bpm + 5) }.accessibilityLabel("tempo più 5")
        }
    }
}

/// I pad: un tasto per pad, e il modo sopra (tocca · tieni · arpeggio). Con l'arpeggio le sue scelte stanno sotto.
struct NTS1PadsPanel: View {
    @ObservedObject var player: NTS1Player

    private let four = Array(repeating: GridItem(.flexible(), spacing: 5), count: 4)

    var body: some View {
        HStack(spacing: 5) {
            NTS1SmallChip(text: "tocca", on: player.padMode == .tap, height: 40) { player.setPadMode(.tap) }
                .accessibilityLabel("modo tocca")
            NTS1SmallChip(text: "tieni", on: player.padMode == .hold, height: 40) { player.setPadMode(.hold) }
                .accessibilityLabel("modo tieni")
            NTS1SmallChip(text: "arpeggio", on: player.padMode == .arp, height: 40) { player.setPadMode(.arp) }
                .accessibilityLabel("modo arpeggio")
        }
        LazyVGrid(columns: four, spacing: 5) {
            ForEach(0..<16, id: \.self) { i in
                let n = player.base + (3 - i / 4) * 4 + i % 4
                let lit = player.held.contains(n)
                Button { player.pad(n) } label: {
                    Text(NTS1Player.name(n))
                        .font(.system(.footnote, design: .monospaced).weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(RoundedRectangle(cornerRadius: 8).fill(lit ? Color.white : NTS1.color))
                        .foregroundStyle(Color.black)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("nota \(NTS1Player.name(n))")
                .accessibilityAddTraits(lit ? .isSelected : [])
            }
        }
        HStack(spacing: 5) {
            NTS1SmallChip(text: "ottava −") { player.octave(-1) }
            NTS1SmallChip(text: "ottava +") { player.octave(1) }
            NTS1SmallChip(text: "lascia tutto") { player.releaseAll() }
            NTS1SmallChip(text: "silenzio") { player.panic() }
        }
        if player.padMode == .arp {
            NTS1ArpChoices(player: player)
        }
    }
}

/// Le scelte dell'arpeggio di Bobina, in tasti piccoli.
struct NTS1ArpChoices: View {
    @ObservedObject var player: NTS1Player

    private let four = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)

    var body: some View {
        NTS1Label("come sale")
        LazyVGrid(columns: four, spacing: 4) {
            ForEach(NTS1ArpMode.allCases) { m in
                NTS1SmallChip(text: m.label, on: player.arpMode == m) { player.arpMode = m }
                    .accessibilityLabel("arpeggio \(m.label)")
            }
        }
        NTS1Label("accordo")
        LazyVGrid(columns: four, spacing: 4) {
            ForEach(NTS1ArpChord.allCases) { c in
                NTS1SmallChip(text: c.label, on: player.arpChord == c) { player.arpChord = c }
                    .accessibilityLabel("accordo \(c.label)")
            }
        }
        NTS1Label("ottave")
        // due griglie: 1 e 2 ottave hanno gli stessi id di «quarti» (1.0) e «ottavi» (2.0) e nella stessa griglia sparirebbero
        HStack(spacing: 4) {
            ForEach(1...3, id: \.self) { o in
                NTS1SmallChip(text: o == 1 ? "1 ottava" : "\(o) ottave", on: player.arpOctaves == o) { player.arpOctaves = o }
            }
        }
        NTS1Label("una nota ogni…")
        LazyVGrid(columns: four, spacing: 4) {
            ForEach(NTS1Player.arpSpeeds, id: \.0) { d in
                NTS1SmallChip(text: d.1, on: player.arpDiv == d.0) { player.arpDiv = d.0 }
                    .accessibilityLabel("velocità \(d.1)")
            }
        }
    }
}

/// L'onda a tempo: cosa muove, la forma, quanto dura un giro, quanto si muove.
struct NTS1WavePanel: View {
    @ObservedObject var player: NTS1Player

    /// Niente volume: onde e inclinazione non muovono mai un guadagno.
    static let targets: [NTS1.Knob] = [.cutoff, .resonance, .oscA, .oscB, .modA, .modB, .delayMix, .reverbMix]
    private let four = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)

    var body: some View {
        NTS1SmallChip(text: player.waveOn ? "ferma l'onda" : "fai partire l'onda", on: player.waveOn, height: 44) { player.toggleWave() }
        NTS1Label("cosa muove")
        LazyVGrid(columns: four, spacing: 4) {
            ForEach(NTS1WavePanel.targets) { k in
                NTS1SmallChip(text: k.label, on: player.waveKnob == k) { player.waveKnob = k }
                    .accessibilityLabel("onda su \(k.label)")
            }
        }
        NTS1Label("forma")
        LazyVGrid(columns: four, spacing: 4) {
            ForEach(NTS1Shape.allCases) { s in
                NTS1SmallChip(text: s.label, on: player.waveShape == s) { player.waveShape = s }
                    .accessibilityLabel("forma \(s.label)")
            }
        }
        NTS1Label("un giro dura")
        LazyVGrid(columns: four, spacing: 4) {
            ForEach(NTS1Player.waveLengths, id: \.0) { len in
                NTS1SmallChip(text: len.1, on: player.waveBeats == len.0) { player.waveBeats = len.0 }
                    .accessibilityLabel("giro \(len.1)")
            }
        }
        NTS1KnobRowPlain(name: "quanto si muove", value: player.waveDepth) { player.waveDepth = $0 }
    }
}

/// Come NTS1KnobRow, per un valore di Bobina (non una manopola dell'NTS-1).
struct NTS1KnobRowPlain: View {
    let name: String
    let value: Int
    let set: (Int) -> Void

    var body: some View {
        HStack {
            NTS1Label(name)
            Spacer()
            Text("\(value)").font(.system(.footnote, design: .monospaced)).foregroundStyle(NTS1.color)
        }
        NTS1DragBar(value: value, set: set)
            .accessibilityLabel(name)
        HStack(spacing: 4) {
            NTS1SmallChip(text: "−") { set(max(0, value - 8)) }.accessibilityLabel("\(name) meno")
            ForEach(NTS1KnobRow.jumps, id: \.0) { j in
                NTS1SmallChip(text: j.1, on: abs(value - j.0) <= 4) { set(j.0) }
                    .accessibilityLabel("\(name) \(j.2)")
            }
            NTS1SmallChip(text: "+") { set(min(127, value + 8)) }.accessibilityLabel("\(name) più")
        }
    }
}

struct NTS1TiltPanel: View {
    @ObservedObject var player: NTS1Player

    private let four = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)

    var body: some View {
        NTS1SmallChip(text: player.tiltOn ? "spegni l'inclinazione" : "accendi l'inclinazione", on: player.tiltOn, height: 44) { player.tiltOn.toggle() }
        NTS1Label("cosa muove (quando la spegni torna dov'era)")
        LazyVGrid(columns: four, spacing: 4) {
            ForEach(NTS1WavePanel.targets) { k in
                NTS1SmallChip(text: k.label, on: player.tiltKnob == k) { player.tiltKnob = k }
                    .accessibilityLabel("inclina \(k.label)")
            }
        }
        if player.tiltOn { NTS1TiltBar(live: player.live) }
    }
}

struct NTS1TiltBar: View {
    @ObservedObject var live: NTS1Live

    var body: some View {
        HStack {
            ProgressView(value: Double(live.tilt), total: 127).tint(NTS1.color)
            Text("\(live.tilt)").font(.system(.caption, design: .monospaced)).frame(width: 36, alignment: .trailing)
        }
    }
}

/// L'arpeggio della macchina: si accende solo col tasto ARP sull'NTS-1.
struct NTS1MachineArpPanel: View {
    @EnvironmentObject var nts1: NTS1Engine
    @ObservedObject var sound: NTS1Sound

    var body: some View {
        NTS1Label("si accende solo col tasto ARP sull'NTS-1")
        NTS1ChoiceGrid(choice: .arpPattern, selected: sound.choices[.arpPattern], columns: 4, small: true) { nts1.set(.arpPattern, $0) }
        NTS1ChoiceGrid(choice: .arpIntervals, selected: sound.choices[.arpIntervals], columns: 4, small: true) { nts1.set(.arpIntervals, $0) }
        NTS1KnobRow(knob: .arpLength, value: sound.value(.arpLength)) { nts1.set(.arpLength, $0) }
    }
}

// MARK: - Banche

struct NTS1BancheView: View {
    @EnvironmentObject var nts1: NTS1Engine
    /// Il suono che aspetta il secondo tocco per essere cancellato.
    @State private var deleting: UUID?

    var body: some View {
        NTS1Page(title: "Banche") {
            Card(title: "salva", note: "Bobina chiede all'NTS-1 il suono di adesso e lo tiene qui, con il suo nome. Dentro c'è tutto: oscillatore, filtro, effetti, arpeggio e gli 8 passi del suo sequencer.") {
                NTS1BigButton(text: "salva il suono di adesso") { nts1.saveCurrent() }
                if let s = nts1.lastStatus {
                    Text(s)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                }
            }

            Card(title: "suoni salvati", note: nts1.saved.isEmpty ? "Ancora nessuno." : "«carica» lo manda all'NTS-1 nel suono in modifica. Per tenerlo anche sull'NTS-1, salvalo lì in un programma.") {
                ForEach(nts1.saved) { s in
                    row(s)
                }
            }
        }
    }

    private func row(_ s: NTS1Saved) -> some View {
        let loaded = nts1.loadedID == s.id
        return VStack(alignment: .leading, spacing: 6) {
            Button { nts1.load(s) } label: {
                Text(s.name)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .padding(.horizontal, 12)
                    .background(RoundedRectangle(cornerRadius: 9).fill(loaded ? NTS1.color : Color(white: 0.18)))
                    .foregroundStyle(loaded ? Color.black : Color.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("carica \(s.name)")
            HStack(spacing: 6) {
                GridChip(text: "su") { nts1.move(s, by: -1) }
                    .accessibilityLabel("sposta su \(s.name)")
                GridChip(text: "giù") { nts1.move(s, by: 1) }
                    .accessibilityLabel("sposta giù \(s.name)")
                GridChip(text: deleting == s.id ? "sicuro? cancella" : "cancella", on: deleting == s.id) {
                    if deleting == s.id {
                        deleting = nil
                        nts1.delete(s)
                    } else {
                        deleting = s.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { if deleting == s.id { deleting = nil } }
                    }
                }
                .accessibilityLabel(deleting == s.id ? "conferma cancella \(s.name)" : "cancella \(s.name)")
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Collega

struct NTS1CollegaView: View {
    @EnvironmentObject var nts1: NTS1Engine

    var body: some View {
        NTS1Page(title: "Collega") {
            Card(title: "col cavo", note: "Dalla USB-C dell'NTS-1 all'iPhone: l'iPhone lo accende anche, e Bobina lo trova da sola. Con un'altra macchina sullo stesso USB-C serve un hub. L'NTS-1 non ha il bluetooth.") {
                EmptyView()
            }

            Card(title: "a chi parla", note: "Tocca la porta dell'NTS-1. Bobina sceglie da sola quella che si chiama «NTS-1».") {
                if nts1.destinations.isEmpty {
                    Text("nessuna porta MIDI")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                }
                ForEach(nts1.destinations) { p in
                    GridChip(text: p.name, on: nts1.destinationID == p.id) { nts1.destinationID = p.id }
                }
                HStack(spacing: 6) {
                    GridChip(text: "prova: suona un do") { nts1.player.touch(60) }
                    GridChip(text: "aggiorna l'elenco") { nts1.refreshPorts() }
                }
            }

            Card(title: "l'NTS-1", note: "Bobina gli chiede chi è al collegamento: firmware, canale e impostazioni.") {
                line("firmware", nts1.firmware ?? "non ha risposto")
                line("canale", "\(nts1.channel)")
                if let g = nts1.global {
                    line("ascolta le manopole", g.shortMessages ? "sì" : "no", ok: g.shortMessages)
                    line("segue il tempo", g.clockAuto ? "sì (auto)" : "no (interno)", ok: g.clockAuto)
                    if !g.shortMessages || !g.clockAuto {
                        NTS1BigButton(text: "sistema le impostazioni") { nts1.fixGlobal() }
                        Text("Accende sull'NTS-1 «MIDI short message» e «Clock: Auto». Il resto delle sue impostazioni non cambia.")
                            .font(.footnote)
                            .foregroundStyle(Palette.dim)
                    }
                } else {
                    line("impostazioni", "non ancora lette")
                }
                Chip(text: "rileggi tutto") { nts1.readAll() }
            }
        }
    }

    private func line(_ name: String, _ value: String, ok: Bool = true) -> some View {
        HStack {
            Text(name)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(ok ? Color.white : Palette.rec)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Passi

/// Scrivere una sequenza col minimo di tocchi: tutto in uno schermo. Tocchi una nota e va nel passo
/// del cursore, che passa da solo al passo dopo. 16 note = 16 tocchi.
struct NTS1PassiView: View {
    @EnvironmentObject var nts1: NTS1Engine

    var body: some View {
        NTS1Page(title: "Passi", compact: true) {
            NTS1PassiEditor(player: nts1.player)
            NTS1PresetsCard(player: nts1.player)
        }
    }
}

struct NTS1PassiEditor: View {
    @EnvironmentObject var nts1: NTS1Engine
    @ObservedObject var player: NTS1Player
    @State private var confirmClear = false

    private static let noteNames = ["do", "do#", "re", "re#", "mi", "fa", "fa#", "sol", "sol#", "la", "la#", "si"]
    private let six = Array(repeating: GridItem(.flexible(), spacing: 5), count: 6)

    var body: some View {
        VStack(spacing: 10) {
            // suona / ferma, e il tempo
            HStack(spacing: 8) {
                Button { player.toggleSteps() } label: {
                    Text(player.stepsOn ? "ferma" : "suona")
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(RoundedRectangle(cornerRadius: 10).fill(player.stepsOn ? Palette.rec : Color(red: 0.40, green: 0.82, blue: 0.40)))
                        .foregroundStyle(Color.black)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.stepsOn ? "ferma i passi" : "suona i passi")
                SmallKey(text: "−5") { nts1.setBPM(nts1.bpm - 5) }.accessibilityLabel("tempo meno 5")
                Text("\(nts1.bpm)")
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                    .frame(minWidth: 44)
                SmallKey(text: "+5") { nts1.setBPM(nts1.bpm + 5) }.accessibilityLabel("tempo più 5")
            }

            // la tastiera: 12 note, una per tasto
            LazyVGrid(columns: six, spacing: 5) {
                ForEach(0..<12, id: \.self) { i in
                    let black = [1, 3, 6, 8, 10].contains(i)
                    Button { player.write(i) } label: {
                        Text(NTS1PassiEditor.noteNames[i])
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(RoundedRectangle(cornerRadius: 8).fill(black ? NTS1.color.opacity(0.55) : NTS1.color))
                            .foregroundStyle(Color.black)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("nota \(NTS1PassiEditor.noteNames[i])")
                }
            }

            // ottava, pausa, indietro
            HStack(spacing: 5) {
                GridChip(text: "ottava −") { player.writeOctave = max(0, player.writeOctave - 1) }
                Text("ott. \(player.writeOctave)")
                    .font(.system(.footnote, design: .monospaced))
                    .frame(minWidth: 48)
                GridChip(text: "ottava +") { player.writeOctave = min(8, player.writeOctave + 1) }
                GridChip(text: "pausa") { player.rest() }
                GridChip(text: "indietro") { player.back() }
            }

            // i passi: il cursore ha il bordo bianco, quello che suona è arancio
            NTS1CursorGrid(player: player, live: player.live)

            HStack(spacing: 5) {
                GridChip(text: "8 passi", on: player.stepLength == 8) { player.stepLength = 8 }
                GridChip(text: "16 passi", on: player.stepLength == 16) { player.stepLength = 16 }
                GridChip(text: "copia 1-8 su 9-16") { player.copyHalf() }
            }
            GridChip(text: confirmClear ? "sicuro? svuota tutti i passi" : "svuota i passi", on: confirmClear) {
                if confirmClear {
                    confirmClear = false
                    player.clearSteps()
                } else {
                    confirmClear = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) { confirmClear = false }
                }
            }
            .accessibilityLabel(confirmClear ? "conferma svuota" : "svuota i passi")
        }
    }
}

/// I 16 passi in due file da 8. Guarda `live` solo per il passo che suona.
struct NTS1CursorGrid: View {
    @ObservedObject var player: NTS1Player
    @ObservedObject var live: NTS1Live

    private let eight = Array(repeating: GridItem(.flexible(), spacing: 4), count: 8)

    var body: some View {
        LazyVGrid(columns: eight, spacing: 5) {
            ForEach(0..<16, id: \.self) { i in
                let note = player.steps[i]
                let inside = i < player.stepLength
                let now = live.step == i
                let here = player.cursor == i
                Button { player.select(i) } label: {
                    VStack(spacing: 0) {
                        Text("\(i + 1)").font(.system(.caption2, design: .monospaced))
                        Text(note.map { NTS1Player.name($0).replacingOccurrences(of: " ", with: "") } ?? "·")
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 7).fill(now ? Palette.accent : note != nil ? NTS1.color : Color(white: 0.18)))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(here ? Color.white : Color.clear, lineWidth: 3))
                    .foregroundStyle(now || note != nil ? Color.black : Color.white)
                    .opacity(inside ? 1 : 0.3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("passo \(i + 1)")
                .accessibilityAddTraits(here ? .isSelected : [])
            }
        }
    }
}

/// Le sequenze pronte, sotto i passi: un tocco le carica, «annulla» rimette quelle di prima.
struct NTS1PresetsCard: View {
    @ObservedObject var player: NTS1Player

    private let two = Array(repeating: GridItem(.flexible(), spacing: 6), count: 2)

    var body: some View {
        Card(title: "sequenze pronte", note: "Tutte scure. Un tocco la mette nei passi; poi la puoi cambiare nota per nota.") {
            HStack(spacing: 6) {
                GridChip(text: player.presetTempo ? "cambia anche il tempo: sì" : "cambia anche il tempo: no", on: player.presetTempo) {
                    player.presetTempo.toggle()
                }
                if player.undo != nil {
                    GridChip(text: "annulla") { player.undoPreset() }
                        .accessibilityLabel("annulla la sequenza pronta")
                }
            }
            if let name = player.presetName, let p = NTS1Preset.all.first(where: { $0.name == name }), !player.presetTempo {
                NTS1SmallChip(text: "metti \(p.bpm) bpm (\(p.name))", height: 40) { player.engine?.setBPM(p.bpm) }
                    .accessibilityLabel("metti \(p.bpm) bpm")
            }
            ForEach(NTS1Preset.groups, id: \.self) { g in
                Text(g)
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(NTS1.color)
                    .padding(.top, 4)
                LazyVGrid(columns: two, spacing: 6) {
                    ForEach(NTS1Preset.all.filter { $0.group == g }) { p in
                        Button { player.load(p) } label: {
                            VStack(spacing: 1) {
                                Text(p.name)
                                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Text("\(p.bpm) bpm")
                                    .font(.system(.caption2, design: .monospaced))
                                    .opacity(0.7)
                            }
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(RoundedRectangle(cornerRadius: 8).fill(player.presetName == p.name ? NTS1.color : Color(white: 0.18)))
                            .foregroundStyle(player.presetName == p.name ? Color.black : Color.white)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("sequenza \(p.name)")
                    }
                }
            }
        }
    }
}

/// Una barra da trascinare, fatta per il QuadStick (copia della TX6DragBar, 10/10/2026): un clic in un punto qualsiasi
/// porta il pallino lì, e tenendo premuto lo si trascina. Lo slider di Apple si muove solo prendendo il pallino.
struct NTS1DragBar: View {
    let value: Int
    let set: (Int) -> Void

    private let knob: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let f = CGFloat(max(0, min(127, value))) / 127
            ZStack(alignment: .leading) {
                Capsule().fill(Color(white: 0.25)).frame(height: 10)
                Capsule().fill(NTS1.color).frame(width: knob / 2 + (w - knob) * f, height: 10)
                Circle().fill(Color.white).frame(width: knob, height: knob).offset(x: (w - knob) * f)
            }
            .frame(width: w, height: geo.size.height)
            .contentShape(Rectangle())
            // da 0 punti: il clic conta subito, e la pagina non scorre quando si parte dalla barra
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                let x = max(0, min(1, (g.location.x - knob / 2) / max(1, w - knob)))
                let v = Int((Double(x) * 127).rounded())
                // solo quando il numero cambia: niente messaggi uguali all'NTS-1
                if v != value { set(v) }
            })
        }
        .frame(height: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { d in
            switch d {
            case .increment: set(min(127, value + 8))
            case .decrement: set(max(0, value - 8))
            @unknown default: break
            }
        }
    }
}
