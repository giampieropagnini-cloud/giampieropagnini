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

struct NTS1SuonoView: View {
    @EnvironmentObject var nts1: NTS1Engine

    var body: some View {
        NTS1Page(title: "Suono") {
            NTS1ProgramCard(sound: nts1.sound)
            NTS1SectionCard(sound: nts1.sound, title: "oscillatore", choice: .osc, knobs: [.oscA, .oscB, .lfoRate, .lfoDepth])
            NTS1SectionCard(sound: nts1.sound, title: "filtro", choice: .filter, knobs: [.cutoff, .resonance, .sweepDepth, .sweepRate])
            NTS1SectionCard(sound: nts1.sound, title: "inviluppo", choice: .eg, knobs: [.attack, .release, .tremoloDepth, .tremoloRate])
            NTS1SectionCard(sound: nts1.sound, title: "mod", choice: .mod, knobs: [.modA, .modB])
            NTS1SectionCard(sound: nts1.sound, title: "delay", choice: .delay, knobs: [.delayA, .delayB, .delayMix])
            NTS1SectionCard(sound: nts1.sound, title: "reverb", choice: .reverb, knobs: [.reverbA, .reverbB, .reverbMix])
            NTS1SectionCard(sound: nts1.sound, title: "volume", choice: nil, knobs: [.volume])
        }
    }
}

struct NTS1ProgramCard: View {
    @EnvironmentObject var nts1: NTS1Engine
    @ObservedObject var sound: NTS1Sound

    var body: some View {
        Card(title: "suono di adesso", note: "Quando giri una manopola sull'NTS-1, qui si muove anche il valore.") {
            Text(sound.programName.isEmpty ? "non ancora letto" : sound.programName)
                .font(.system(.title3, design: .monospaced))
            Chip(text: "rileggi il suono dall'NTS-1") { nts1.readProgram() }
        }
    }
}

/// Una sezione dell'NTS-1: i tasti del tipo e le manopole.
struct NTS1SectionCard: View {
    @EnvironmentObject var nts1: NTS1Engine
    @ObservedObject var sound: NTS1Sound
    let title: String
    let choice: NTS1.Choice?
    let knobs: [NTS1.Knob]

    var body: some View {
        Card(title: title) {
            if let c = choice {
                NTS1ChoiceGrid(choice: c, selected: sound.choices[c], name: sound.names[c]) { nts1.set(c, $0) }
            }
            ForEach(knobs) { k in
                let v = sound.value(k)
                StepSlider(name: k.label, value: v, shown: k.shown(v)) { nts1.set(k, $0) }
            }
        }
    }
}

/// I tipi in una griglia di tre colonne, ognuno col suo nome per il Controllo Vocale.
struct NTS1ChoiceGrid: View {
    let choice: NTS1.Choice
    let selected: Int?
    var name: String? = nil
    let pick: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let n = name, selected == nil {
                Text("adesso: \(n)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(NTS1.color)
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(choice.items.indices, id: \.self) { i in
                    GridChip(text: choice.items[i], on: selected == i) { pick(i) }
                        .accessibilityLabel("\(choice.title) \(choice.items[i])")
                        .accessibilityAddTraits(selected == i ? .isSelected : [])
                }
            }
        }
    }
}

// MARK: - Suona

struct NTS1SuonaView: View {
    @EnvironmentObject var nts1: NTS1Engine

    var body: some View {
        NTS1Page(title: "Suona") {
            NTS1PadsCard(player: nts1.player)
            NTS1BobinaArpCard(player: nts1.player)
            NTS1TempoCard()
            NTS1WaveCard(player: nts1.player)
            NTS1TiltCard(player: nts1.player)
            NTS1ArpCard(sound: nts1.sound)
        }
    }
}

/// 16 pad, ognuno diviso in due: sopra suona, sotto tiene la nota.
struct NTS1PadsCard: View {
    @ObservedObject var player: NTS1Player

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        Card(title: "pad", note: player.arpOn ? "Arpeggio di Bobina acceso: ogni pad entra o esce dall'arpeggio." : "Sopra suona, sotto «tieni».") {
            HStack(spacing: 8) {
                Button("ottava giù") { player.octave(-1) }.font(.footnote)
                Button("ottava su") { player.octave(1) }.font(.footnote)
                Spacer()
                Button("silenzio") { player.panic() }.font(.footnote)
            }
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<16, id: \.self) { i in
                    pad(player.base + (3 - i / 4) * 4 + i % 4)
                }
            }
            if !player.held.isEmpty {
                Button("lascia tutte le note") { player.releaseAll() }.font(.footnote)
            }
        }
    }

    private func pad(_ n: Int) -> some View {
        let name = NTS1Player.name(n)
        let held = player.held.contains(n)
        let picked = player.pick == n
        return VStack(spacing: 3) {
            Button { player.touch(n) } label: {
                Text(name)
                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 8).fill(NTS1.color))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(held || picked ? Color.white : Palette.cardEdge, lineWidth: held ? 3 : picked ? 2 : 1))
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("nota \(name)")
            Button { player.toggleHold(n) } label: {
                Text(held ? "lascia" : "tieni")
                    .font(.system(.caption2, design: .monospaced).weight(held ? .bold : .regular))
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(RoundedRectangle(cornerRadius: 8).fill(held ? Color.white : NTS1.color.opacity(0.4)))
                    .foregroundStyle(held ? Color.black : Color.white.opacity(0.9))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(held ? "lascia \(name)" : "tieni \(name)")
        }
    }
}

/// L'arpeggio suonato da Bobina: non serve il tasto ARP dell'NTS-1.
struct NTS1BobinaArpCard: View {
    @ObservedObject var player: NTS1Player

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        Card(title: "arpeggio di Bobina", note: "Acceso: ogni pad che tocchi entra nell'arpeggio, ritoccato esce. Suona a tempo con le altre macchine, senza il tasto ARP.") {
            NTS1BigButton(text: player.arpOn ? "spegni l'arpeggio" : "accendi l'arpeggio", on: player.arpOn) { player.toggleArp() }
            if player.arpOn {
                Text(player.held.isEmpty ? "tocca uno o più pad" : "note: " + player.held.sorted().map(NTS1Player.name).joined(separator: " · "))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(NTS1.color)
            }
            label("come sale")
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(NTS1ArpMode.allCases) { m in
                    GridChip(text: m.label, on: player.arpMode == m) { player.arpMode = m }
                        .accessibilityLabel("arpeggio \(m.label)")
                }
            }
            label("accordo")
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(NTS1ArpChord.allCases) { c in
                    GridChip(text: c.label, on: player.arpChord == c) { player.arpChord = c }
                        .accessibilityLabel("accordo \(c.label)")
                }
            }
            label("ottave")
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(1...3, id: \.self) { o in
                    GridChip(text: o == 1 ? "1 ottava" : "\(o) ottave", on: player.arpOctaves == o) { player.arpOctaves = o }
                }
            }
            label("velocità: una nota ogni…")
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(NTS1Player.arpSpeeds, id: \.0) { d in
                    GridChip(text: d.1, on: player.arpDiv == d.0) { player.arpDiv = d.0 }
                        .accessibilityLabel("velocità \(d.1)")
                }
            }
        }
    }

    private func label(_ t: String) -> some View {
        Text(t).font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.dim)
    }
}

struct NTS1ArpCard: View {
    @EnvironmentObject var nts1: NTS1Engine
    @ObservedObject var sound: NTS1Sound

    var body: some View {
        Card(title: "arpeggio dell'NTS-1", note: "Questo è quello della macchina: si accende solo col tasto ARP sull'NTS-1.") {
            NTS1ChoiceGrid(choice: .arpPattern, selected: sound.choices[.arpPattern]) { nts1.set(.arpPattern, $0) }
            NTS1ChoiceGrid(choice: .arpIntervals, selected: sound.choices[.arpIntervals]) { nts1.set(.arpIntervals, $0) }
            let v = sound.value(.arpLength)
            StepSlider(name: "lunghezza", value: v, shown: NTS1.Knob.arpLength.shown(v), step: 6) { nts1.set(.arpLength, $0) }
        }
    }
}

/// L'NTS-1 a tempo con Bobina: lo stesso bpm e la stessa battuta delle altre macchine.
struct NTS1TempoCard: View {
    @EnvironmentObject var nts1: NTS1Engine

    var body: some View {
        Card(title: "a tempo con Bobina", note: "«solo il tempo»: delay «bpm» e arpeggio della macchina vanno al tempo di Bobina, la sequenza dell'NTS-1 resta ferma. «anche la sua sequenza»: parte pure quella. Se suona già un'altra macchina, entra alla battuta dopo.") {
            if nts1.running {
                NTS1BigButton(text: nts1.withSequence ? "ferma l'NTS-1" : "smetti di dare il tempo", on: true) { nts1.stopRun() }
                Text(nts1.withSequence ? "tempo e sequenza dell'NTS-1" : "solo il tempo: la sequenza dell'NTS-1 è ferma")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(NTS1.color)
            } else {
                NTS1BigButton(text: "dai solo il tempo all'NTS-1", color: Color(red: 0.40, green: 0.82, blue: 0.40)) { nts1.startClock() }
                NTS1BigButton(text: "fai partire anche la sua sequenza", color: Color(red: 0.40, green: 0.82, blue: 0.40).opacity(0.7)) { nts1.startWithSequence() }
            }
            HStack(spacing: 8) {
                Text("bpm")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.dim)
                SmallKey(text: "−5") { nts1.setBPM(nts1.bpm - 5) }
                SmallKey(text: "−1") { nts1.setBPM(nts1.bpm - 1) }
                Text("\(nts1.bpm)")
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .frame(minWidth: 56)
                SmallKey(text: "+1") { nts1.setBPM(nts1.bpm + 1) }
                SmallKey(text: "+5") { nts1.setBPM(nts1.bpm + 5) }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// Una manopola mossa a tempo: onda, cancello, pompa. L'NTS-1 da solo non lo fa a tempo con le altre macchine.
struct NTS1WaveCard: View {
    @ObservedObject var player: NTS1Player

    static let targets: [NTS1.Knob] = [.cutoff, .resonance, .oscA, .oscB, .volume, .modA, .delayMix, .reverbMix]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        Card(title: "onda a tempo", note: "Muove una manopola a tempo, scendendo dal suo valore. «Cancello» sul volume taglia il suono a ritmo, «pompa» lo fa respirare come un sidechain.") {
            NTS1BigButton(text: player.waveOn ? "ferma l'onda" : "fai partire l'onda", on: player.waveOn) { player.toggleWave() }
            Text("cosa muove").font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.dim)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(NTS1WaveCard.targets) { k in
                    GridChip(text: k.label, on: player.waveKnob == k) { player.waveKnob = k }
                        .accessibilityLabel("onda su \(k.label)")
                }
            }
            Text("forma").font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.dim)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(NTS1Shape.allCases) { s in
                    GridChip(text: s.label, on: player.waveShape == s) { player.waveShape = s }
                        .accessibilityLabel("forma \(s.label)")
                }
            }
            Text("un giro dura").font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.dim)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(NTS1Player.waveLengths, id: \.0) { len in
                    GridChip(text: len.1, on: player.waveBeats == len.0) { player.waveBeats = len.0 }
                        .accessibilityLabel("giro \(len.1)")
                }
            }
            StepSlider(name: "quanto", value: player.waveDepth) { player.waveDepth = $0 }
        }
    }
}

struct NTS1TiltCard: View {
    @ObservedObject var player: NTS1Player

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        Card(title: "inclinazione", note: "Inclina il telefono: muove la manopola scelta. Quando la spegni, la manopola torna dov'era.") {
            Toggle("inclinazione accesa", isOn: $player.tiltOn)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(NTS1WaveCard.targets) { k in
                    GridChip(text: k.label, on: player.tiltKnob == k) { player.tiltKnob = k }
                        .accessibilityLabel("inclina \(k.label)")
                }
            }
            if player.tiltOn { NTS1TiltBar(live: player.live) }
        }
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
