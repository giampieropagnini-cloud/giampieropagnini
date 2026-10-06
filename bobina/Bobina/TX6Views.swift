import SwiftUI

// MARK: - scegliere la macchina

/// In alto a destra in ogni pagina: passa dalla sezione TP-7 alla sezione TX-6 e ritorno.
struct MachineSwitch: View {
    @AppStorage("bobina.macchina") private var machine = "tp7"

    private let machines = [("tp7", "TP-7"), ("tx6", "TX-6"), ("po", "Pocket Operator"), ("opz", "OP-Z"), ("m8", "M8"), ("nts1", "NTS-1")]

    var body: some View {
        // un menu con tre tasti, ognuno col suo nome: col Controllo Vocale «passa a…» e poi il nome
        Menu {
            ForEach(machines.filter { $0.0 != machine }, id: \.0) { m in
                Button(m.0 == "opz" ? "passa all'OP-Z" : m.0 == "m8" ? "passa all'M8" : m.0 == "nts1" ? "passa all'NTS-1" : "passa al \(m.1)") { machine = m.0 }
            }
        } label: {
            Text("passa a…")
        }
        .font(.system(.footnote, design: .monospaced))
        .accessibilityLabel("passa a un'altra macchina")
    }
}

/// Le cinque schermate del TX-6. Riapre l'ultima scheda usata.
struct TX6Tabs: View {
    @AppStorage("bobina.tx6.scheda") private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            TX6MixerView()
                .tabItem { Label("Mixer", systemImage: "slider.horizontal.3") }.tag(0)
            TX6EffettiView()
                .tabItem { Label("Effetti", systemImage: "sparkles") }.tag(1)
            TX6SuonaView()
                .tabItem { Label("Suona", systemImage: "pianokeys") }.tag(2)
            TX6RitmoView()
                .tabItem { Label("Ritmo", systemImage: "metronome") }.tag(3)
            TX6CollegaView()
                .tabItem { Label("Collega", systemImage: "cable.connector") }.tag(4)
        }
    }
}

// MARK: - pezzi comuni

/// Come Page, con la striscia del TX-6.
struct TX6Page<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        #if DEBUG
        let _ = Diagnostics.shared.count("pagina tx6 " + title)
        #endif
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    TX6StatusStrip()
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

struct TX6StatusStrip: View {
    @EnvironmentObject var tx: TX6Engine

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tx.connected ? Color.green : Palette.rec)
                .frame(width: 8, height: 8)
            Text(tx.connected ? "collegato a \(tx.connectedName)" : "TX-6 non collegato · vai su Collega")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
                .lineLimit(1)
            Spacer()
            if tx.pulsing {
                Text("\(Int(tx.bpm.rounded())) bpm")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.accent)
            }
            if tx.connected {
                Chip(text: "silenzio") { tx.allNotesOff() }
            }
        }
        .padding(.top, 6)
        if tx.strayClock && tx.clockMode != .follow {
            Text("Il TX-6 manda il clock ma qui non serve, e intasa il bluetooth: sul TX-6 shift + select → CLOCK → OUT off.")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.rec)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Un tasto piccolo per − e +: col Controllo Vocale è più facile di uno slider.
struct SmallKey: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(.subheadline, design: .monospaced))
                .frame(width: 34, height: 30)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color(white: 0.18)))
                .foregroundStyle(Color.white)
        }
        .buttonStyle(.plain)
    }
}

/// Nome, −, slider, +, valore. Da 0 a 127, − e + saltano di 8.
struct StepSlider: View {
    let name: String
    let value: Int
    var shown: String? = nil
    var step = 8
    let set: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
                .frame(width: 72, alignment: .leading)
            SmallKey(text: "−") { set(max(0, value - step)) }
            Slider(value: Binding(get: { Double(value) }, set: { set(Int($0.rounded())) }), in: 0...127)
            SmallKey(text: "+") { set(min(127, value + step)) }
            Text(shown ?? "\(value)")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 56, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

/// Una fila di tasti, uno solo acceso.
struct ChipRow: View {
    let items: [String]
    let selected: Int?
    let pick: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items.indices, id: \.self) { i in
                    Chip(text: items[i], on: selected == i) { pick(i) }
                }
            }
        }
    }
}

/// Scelta di una traccia sola.
struct OneTrackPicker: View {
    let selected: Int
    let pick: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text("traccia")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
            ForEach(1...6, id: \.self) { t in
                Chip(text: "\(t)", on: selected == t) { pick(t) }
            }
        }
    }
}

/// Un menu per scegliere uno dei parametri continui.
struct ParamMenu: View {
    let selected: TX6.Param
    let pick: (TX6.Param) -> Void

    var body: some View {
        Menu {
            ForEach(TX6.Param.allCases.filter { $0.continuous }) { p in
                Button("\(p.name) · cc \(p.cc)") { pick(p) }
            }
        } label: {
            HStack {
                Text("parametro: \(selected.name)")
                Image(systemName: "chevron.down")
            }
            .font(.system(.subheadline, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color(white: 0.18)))
        }
    }
}

// MARK: - Mixer

struct TX6MixerView: View {
    @EnvironmentObject var tx: TX6Engine
    /// Cosa regolano le sei righe: volume, guadagno, EQ, compressore… La scelta resta salvata.
    @AppStorage("bobina.tx6.mixer.strato") private var layerRaw = TX6.Param.volume.rawValue
    @State private var strip = 1

    static let layers: [TX6.Param] = [.volume, .gain, .comp, .eqHigh, .eqMid, .eqLow, .pan, .filter, .fx1Send, .auxSend, .aux2Send]
    static let stripParams: [TX6.Param] = [.gain, .eqHigh, .eqMid, .eqLow, .comp, .pan, .filter, .fx1Send, .auxSend, .volume]

    static func label(_ p: TX6.Param) -> String {
        switch p {
        case .eqHigh: return "EQ alti"
        case .eqMid: return "EQ medi"
        case .eqLow: return "EQ bassi"
        case .comp: return "comp"
        case .fx1Send: return "FX I"
        default: return p.name
        }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        let layer = TX6.Param(rawValue: layerRaw) ?? .volume
        TX6Page(title: "Mixer") {
            Card(title: "le sei tracce", note: "Scegli cosa regolare su tutte e sei le tracce: volume, guadagno, compressore, EQ, pan, filtro, mandate. M è il muto (Bobina manda il muto del TX-6 e porta anche il volume a zero; togliendolo torna com'era), «tr» apre tutta la traccia. Il TX-6 va messo su MIDI → CTRL IN; non dice com'è messo: qui vedi quello che gli ha mandato Bobina.") {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Self.layers) { p in
                        GridChip(text: Self.label(p), on: layer == p) { layerRaw = p.rawValue }
                    }
                }
                ForEach(1...6, id: \.self) { t in
                    TX6ChannelRow(track: t, param: layer)
                }
            }

            Card(title: "un canale", note: "Tutte le funzioni di un canale insieme, come sulla macchina: guadagno, EQ a tre bande (±18 dB), compressore, pan, filtro, mandate e volume.") {
                OneTrackPicker(selected: strip) { strip = $0 }
                ForEach(Self.stripParams) { p in
                    StepSlider(name: Self.label(p), value: tx.value(strip, p), shown: p.shown(tx.value(strip, p))) { tx.set(strip, p, $0) }
                }
                HStack(spacing: 8) {
                    Chip(text: tx.mutes[strip - 1] ? "muta" : "muto", on: tx.mutes[strip - 1], color: Palette.rec) { tx.toggleMute(strip) }
                    Chip(text: "EQ piatto e filtro spento") { tx.flatten(strip) }
                }
            }

            Card(title: "generale", note: "Canale 7. «Manopole spente» (local control) fa ignorare al TX-6 i suoi fader e le sue manopole: comandi solo da qui.") {
                StepSlider(name: "main", value: tx.master[0]) { tx.setMaster(0, $0) }
                StepSlider(name: "aux", value: tx.master[1]) { tx.setMaster(1, $0) }
                StepSlider(name: "cue", value: tx.master[2]) { tx.setMaster(2, $0) }
                Chip(text: tx.localOff ? "riaccendi le manopole del TX-6" : "spegni le manopole del TX-6", on: tx.localOff) { tx.toggleLocal() }
            }

            Card(title: "scene del TX-6", note: "Richiama le scene a, b, c salvate sulla macchina (menu → SCENE).") {
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Chip(text: ["a", "b", "c"][i]) { tx.recallTX6Scene(i) }
                    }
                }
            }

            TX6ScenesCard()
        }
    }
}

/// Una riga del mixer: la traccia, il parametro scelto con − e +, il valore e il muto.
struct TX6ChannelRow: View {
    @EnvironmentObject var tx: TX6Engine
    let track: Int
    var param: TX6.Param = .volume

    var body: some View {
        let v = tx.value(track, param)
        HStack(spacing: 6) {
            NavigationLink {
                TX6TrackView(start: track)
            } label: {
                Text("tr \(track) ›")
                    .font(.system(.subheadline, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.18)))
            }
            .buttonStyle(.plain)
            SmallKey(text: "−") { tx.set(track, param, v - 8) }
            Slider(value: Binding(get: { Double(v) }, set: { tx.set(track, param, Int($0.rounded())) }), in: 0...127)
            SmallKey(text: "+") { tx.set(track, param, v + 8) }
            Text(param.shown(v))
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 48, alignment: .trailing)
            Chip(text: "M", on: tx.mutes[track - 1], color: Palette.rec) { tx.toggleMute(track) }
        }
    }
}

/// Tutti i parametri di una traccia.
struct TX6TrackView: View {
    @EnvironmentObject var tx: TX6Engine
    let start: Int
    @State private var track: Int?

    var body: some View {
        let t = track ?? start
        ScrollView {
            VStack(spacing: 12) {
                OneTrackPicker(selected: t) { track = $0 }
                ForEach(["mixer", "suono", "mandate"], id: \.self) { g in
                    Card(title: g) {
                        ForEach(TX6.Param.allCases.filter { $0.group == g }) { p in
                            StepSlider(name: p.name, value: tx.value(t, p), shown: p.shown(tx.value(t, p))) { tx.set(t, p, $0) }
                        }
                    }
                }
                Card(title: "synth", note: "Con il synth acceso (menu → SYNTH). L'ordine dei suoni e dei pattern sui 128 valori è ancora da misurare: il display del TX-6 dice quale ha preso.") {
                    SoundGrid(track: t)
                    ForEach([TX6.Param.freq, .length, .detune]) { p in
                        StepSlider(name: p.name, value: tx.value(t, p)) { tx.set(t, p, $0) }
                    }
                    StepSlider(name: "pattern", value: tx.value(t, .pattern), shown: TX6.patternName(tx.value(t, .pattern)), step: 5) { tx.set(t, .pattern, $0) }
                }
                HStack(spacing: 8) {
                    Chip(text: tx.mutes[t - 1] ? "muta" : "muto", on: tx.mutes[t - 1], color: Palette.rec) { tx.toggleMute(t) }
                    Chip(text: "EQ piatto e filtro spento") { tx.flatten(t) }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 24)
        }
        .navigationTitle("Traccia \(t)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Le scene di Bobina: quante ne vuoi, e il passaggio dall'una all'altra che sfuma.
struct TX6ScenesCard: View {
    @EnvironmentObject var tx: TX6Engine

    var body: some View {
        Card(title: "scene che sfumano", note: "Fotografa quello che hai mandato al TX-6 (volumi, EQ, mandate, synth, muti, generale). «Sfuma» ci arriva piano, in tante battute quante scegli, al tempo della scheda Ritmo; «di colpo» la manda tutta subito.") {
            HStack(spacing: 8) {
                Chip(text: "fotografa adesso") { tx.saveScene() }
                TX6MorphReadout(side: tx.side)
            }
            HStack(spacing: 6) {
                Text("sfuma in")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.dim)
                ForEach([1.0, 2, 4, 8, 16], id: \.self) { b in
                    Chip(text: "\(Int(b))", on: tx.morphBars == b) { tx.morphBars = b }
                }
                Text("battute")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.dim)
            }
            if tx.scenes.isEmpty {
                Text("nessuna scena ancora")
                    .font(.footnote)
                    .foregroundStyle(Palette.dim)
            }
            ForEach(tx.scenes) { s in
                HStack(spacing: 6) {
                    Text(s.name)
                        .font(.system(.subheadline, design: .monospaced))
                    Spacer()
                    Chip(text: "sfuma") { tx.recall(s, fade: true) }
                    Chip(text: "di colpo") { tx.recall(s, fade: false) }
                    Chip(text: "✕") { tx.deleteScene(s) }
                }
            }
        }
    }
}

// MARK: - Effetti

struct TX6EffettiView: View {
    @EnvironmentObject var tx: TX6Engine

    var body: some View {
        TX6Page(title: "Effetti") {
            Card(title: "FX I · in mandata", note: "Canale 8. Riverbero, chorus o delay: ogni traccia ci manda la sua parte (qui sotto), il ritorno decide quanto effetto rientra nel mix. L'ordine degli effetti sui 128 valori è ancora da misurare.") {
                Chip(text: tx.fxOn[0] ? "acceso" : "spento", on: tx.fxOn[0]) { tx.toggleFx(0) }
                ChipRow(items: TX6.fxEngines[0], selected: tx.fxEngine[0]) { tx.setFxEngine(0, $0) }
                ForEach(0..<3, id: \.self) { k in
                    StepSlider(name: "par \(k + 1)", value: tx.fxParams[0][k]) { tx.setFxParam(0, k, $0) }
                }
                StepSlider(name: "ritorno", value: tx.fxReturn) { tx.setFxReturn($0) }
                Text("mandate delle tracce")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.dim)
                ForEach(1...6, id: \.self) { t in
                    StepSlider(name: "tr \(t)", value: tx.value(t, .fx1Send)) { tx.set(t, .fx1Send, $0) }
                }
            }

            Card(title: "FX II · inserito", note: "Canale 9. Uno solo alla volta, su una traccia o su tutto il mix. Se il mix suona ovattato, di solito è il filtro di FX II rimasto acceso.") {
                Chip(text: tx.fxOn[1] ? "acceso" : "spento", on: tx.fxOn[1]) { tx.toggleFx(1) }
                ChipRow(items: TX6.fxEngines[1], selected: tx.fxEngine[1]) { tx.setFxEngine(1, $0) }
                ForEach(0..<3, id: \.self) { k in
                    StepSlider(name: "par \(k + 1)", value: tx.fxParams[1][k]) { tx.setFxParam(1, k, $0) }
                }
                Text("su quale traccia")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.dim)
                ChipRow(items: TX6.fx2Places, selected: tx.fx2Place) { tx.setFx2Place($0) }
            }

            Card(title: "aux", note: "Le mandate aux delle tracce: per un pedale o un effetto esterno. Il ritorno entra da una traccia libera, con la sua mandata aux a zero per non fischiare.") {
                ForEach(1...6, id: \.self) { t in
                    StepSlider(name: "tr \(t)", value: tx.value(t, .auxSend)) { tx.set(t, .auxSend, $0) }
                }
            }
        }
    }
}

// MARK: - Suona

struct TX6SuonaView: View {
    @EnvironmentObject var tx: TX6Engine
    @State private var beatTrack = 1
    @State private var lockBrush: Int? = 127

    private let keyNames = ["do", "do#", "re", "re#", "mi", "fa", "fa#", "sol", "sol#", "la", "la#", "si", "do"]
    private let black: Set<Int> = [1, 3, 6, 8, 10]
    private let columns7 = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        TX6Page(title: "Suona") {
            TX6PatternCard()

            TX6SamplerCard()

            Card(title: "i sei strumenti", note: "Ogni traccia del TX-6 è uno strumento. Scegli la traccia, poi il suono, e regola le barre: sono le stesse cose che sulla macchina fai con le manopoline. «prova» lo fa suonare. Serve il synth acceso (menu → SYNTH → play). L'ordine dei suoni sui 128 valori è ancora da misurare: il display del TX-6 dice quale ha preso.") {
                OneTrackPicker(selected: beatTrack) { beatTrack = $0 }
                SoundGrid(track: beatTrack)
                ForEach([TX6.Param.volume, .freq, .length, .detune, .filter]) { p in
                    StepSlider(name: p.name, value: tx.value(beatTrack, p), shown: p.shown(tx.value(beatTrack, p))) { tx.set(beatTrack, p, $0) }
                }
                Chip(text: "prova la traccia \(beatTrack)") { tx.hitPad(beatTrack) }
            }

            TX6PresetCard(track: beatTrack, pickTrack: { beatTrack = $0 })

            Card(title: "tastiera", note: "Serve MIDI → NOTE on e il synth su play. Suona la traccia scelta a quella nota; con un accordo le sei tracce diventano sei voci.") {
                OneTrackPicker(selected: tx.keyTrack) { tx.keyTrack = $0 }
                HStack(spacing: 8) {
                    Chip(text: "ottava −") { tx.octave = max(0, tx.octave - 1) }
                    Text("do\(tx.octave)")
                        .font(.system(.subheadline, design: .monospaced))
                        .frame(minWidth: 44)
                    Chip(text: "ottava +") { tx.octave = min(8, tx.octave + 1) }
                }
                ChipRow(items: TX6Chord.allCases.map { $0.rawValue }, selected: TX6Chord.allCases.firstIndex(of: tx.chord)) { tx.chord = TX6Chord.allCases[$0] }
                LazyVGrid(columns: columns7, spacing: 6) {
                    ForEach(0..<13, id: \.self) { k in
                        PressPad(lit: tx.heldKeys.contains(k), onPress: { tx.keyDown(k) }, onRelease: { tx.keyUp(k) }) {
                            Text(keyNames[k])
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(black.contains(k) && !tx.heldKeys.contains(k) ? Palette.dim : Color.white)
                        }
                        .frame(height: 54)
                    }
                }
            }

            Card(title: "sei pad", note: "Ogni pad fa suonare la sua traccia alla nota dell'ottava scelta, come la tastiera. Serve NOTE on e il synth su play. Do2 (di fabbrica) dà casse giuste; per una cassa più profonda scendi a do1.") {
                TX6PadGrid(live: tx.live)
                HStack(spacing: 6) {
                    Text("ottava")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                    ForEach([24, 36, 48, 60, 72], id: \.self) { b in
                        Chip(text: "do\(b / 12 - 1)", on: tx.padBase == b) { tx.padBase = b }
                    }
                }
            }

            Card(title: "batteria a passi", note: "Sedici passi per ogni traccia: a ogni passo acceso il pad di quella traccia suona. Parte col tempo della scheda Ritmo.") {
                HStack {
                    Toggle("accesa", isOn: $tx.beatsOn)
                    Chip(text: tx.running ? "■" : "▶", on: tx.running) { tx.toggleRun() }
                }
                OneTrackPicker(selected: beatTrack) { beatTrack = $0 }
                TX6StepGrid(live: tx.live, pulsing: tx.pulsing,
                            label: { tx.beats[beatTrack - 1][$0] ? "■" : "·" },
                            filled: { tx.beats[beatTrack - 1][$0] },
                            tap: { tx.beats[beatTrack - 1][$0].toggle() })
                Text("tracce con passi: " + ((1...6).filter { tx.beats[$0 - 1].contains(true) }.map { "\($0)" }.joined(separator: " ")).ifEmpty("nessuna"))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.dim)
                HStack(spacing: 8) {
                    Chip(text: "svuota la traccia \(beatTrack)") { tx.beats[beatTrack - 1] = Array(repeating: false, count: 16) }
                    ConfirmChip(text: "svuota tutta la batteria") { tx.beats = Array(repeating: Array(repeating: false, count: 16), count: 6) }
                }
            }

            TX6MelodyCard()

            Card(title: "passi con manopola", note: "A ogni passo un valore diverso per un parametro di una traccia, mandato un attimo prima del colpo: sei suoni diversi dalla stessa traccia. Scegli il pennello e tocca i passi; «vuoto» lascia il valore normale.") {
                Toggle("accesi (con la batteria)", isOn: $tx.lockOn)
                OneTrackPicker(selected: tx.lockTrack) { tx.lockTrack = $0 }
                ParamMenu(selected: tx.lockParam) { tx.lockParam = $0 }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Chip(text: "vuoto", on: lockBrush == nil) { lockBrush = nil }
                        ForEach([0, 32, 64, 96, 127], id: \.self) { v in
                            Chip(text: "\(v)", on: lockBrush == v) { lockBrush = v }
                        }
                    }
                }
                TX6StepGrid(live: tx.live, pulsing: tx.pulsing,
                            label: { tx.locks[$0].map { "\($0)" } ?? "·" },
                            filled: { tx.locks[$0] != nil },
                            tap: { tx.locks[$0] = tx.locks[$0] == lockBrush ? nil : lockBrush })
                Chip(text: "svuota i passi con manopola") { tx.locks = Array(repeating: nil, count: 16) }
            }
        }
    }
}

/// Stili pronti e pattern salvati: se il ritmo gira, il cambio arriva all'inizio della battuta.
/// I preset delle tracce: pronti per gruppo, e quelli salvati da Giampiero.
struct TX6PresetCard: View {
    @EnvironmentObject var tx: TX6Engine
    let track: Int
    let pickTrack: (Int) -> Void
    @State private var group = "cassa"

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 2)

    var body: some View {
        Card(title: "preset", note: "Tocca un preset: va sulla traccia scelta, suono e manopole insieme, e la senti subito. I preset pronti sono un punto di partenza: ritoccali con le barre qui sopra, poi salvali come tuoi.") {
            OneTrackPicker(selected: track) { pickTrack($0) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(TX6Preset.groups + ["miei"], id: \.self) { g in
                        Chip(text: g, on: group == g) { group = g }
                    }
                }
            }
            let list = group == "miei" ? tx.myPresets : TX6Preset.builtIn.filter { $0.group == group }
            if list.isEmpty {
                Text("Ancora nessun preset tuo: regola una traccia e tocca «salva il suono della traccia».")
                    .font(.footnote)
                    .foregroundStyle(Palette.dim)
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(list) { p in
                    GridChip(text: p.name) {
                        tx.apply(p, to: track)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { tx.hitPad(track) }
                    }
                }
            }
            if group == "miei" {
                ForEach(tx.myPresets) { p in
                    HStack {
                        Text(p.name).font(.system(.footnote, design: .monospaced))
                        Spacer()
                        ConfirmChip(text: "cancella \(p.name)") { tx.deletePreset(p) }
                    }
                }
            }
            Chip(text: "salva il suono della traccia \(track) come mio preset") { tx.savePreset(from: track); group = "miei" }
        }
    }
}

/// Campionatore e looper del TX-6. Registrare si fa sulla macchina (il MIDI non ha comandi per farlo);
/// da qui si mettono le tracce sul suono SAMPLE e si suonano i campioni a tempo, intonati.
struct TX6SamplerCard: View {
    @EnvironmentObject var tx: TX6Engine
    @State private var track = 1
    @State private var showSteps = false

    private let sampleIndex = 8

    var body: some View {
        Card(title: "campioni e loop", note: "Il TX-6 ha sei campioni da 5,5 secondi (uno per traccia) e un loop da 22 secondi. Registrarli si fa sulla macchina: il MIDI del TX-6 non ha un comando per farlo. Da qui metti una traccia sul suo campione e lo suoni: coi pad, con la batteria a passi, o intonato con la tastiera e la melodia. Serve il synth acceso (menu → SYNTH → play).") {
            OneTrackPicker(selected: track) { track = $0 }
            HStack(spacing: 8) {
                Chip(text: "traccia \(track) suona il suo campione", on: TX6.soundIndex(tx.value(track, .sound)) == sampleIndex) {
                    tx.set(track, .sound, TX6.soundValue(sampleIndex))
                }
                Chip(text: "prova") { tx.hitPad(track) }
            }
            Chip(text: "tutte e sei sui campioni") {
                for t in 1...6 { tx.set(t, .sound, TX6.soundValue(sampleIndex)) }
            }
            Text("Intonato: tastiera e melodia a passi suonano il campione della traccia scelta a note diverse. Lunghezza e frequenza si regolano in «i sei strumenti».")
                .font(.footnote)
                .foregroundStyle(Palette.dim)
            Chip(text: showSteps ? "nascondi come si registra" : "come si registra sul TX-6") { showSteps.toggle() }
            if showSteps {
                VStack(alignment: .leading, spacing: 6) {
                    Text("campione")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.accent)
                    Text("1. shift + select → SAMPLE.\n2. FX II: modo registrazione.\n3. Gira select: da quale traccia prendi il suono.\n4. Tieni il tasto traccia dove lo vuoi: registra finché tieni, al massimo 5,5 s.\n5. FX I: modo suono, i tasti traccia lo suonano.")
                    Text("loop")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.accent)
                    Text("1. shift + select → LOOP.\n2. Gira select: da quale traccia registra.\n3. Tieni FX II: registra finché tieni, al massimo 22 s.\n4. FX I: suona o fa ripartire il loop. FX II: lo ferma.")
                    Text("non perderli")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.accent)
                    Text("Allo spegnimento campioni e loop si cancellano. Con una chiavetta nella porta USB-C: shift + FX II salva, shift + FX I carica.")
                }
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct TX6PatternCard: View {
    @EnvironmentObject var tx: TX6Engine
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        Card(title: "pattern e stili", note: "Un pattern è tutto quello che suona: batteria, melodie, suoni delle sei tracce e tempo. Tocca uno stile o un tuo pattern: se il ritmo gira, entra all'inizio della prossima battuta. Gli stili usano le tracce così: 1 cassa, 2 rullante, 3 battimani, 4 charleston, 5 basso, 6 melodia.") {
            HStack(spacing: 8) {
                Chip(text: tx.running ? "■" : "▶", on: tx.running) { tx.toggleRun() }
                VStack(alignment: .leading, spacing: 2) {
                    Text("suona: " + (tx.currentPatternName ?? "—"))
                        .font(.system(.subheadline, design: .monospaced))
                    if let next = tx.pendingPatternName {
                        Text("poi: \(next), alla battuta")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Palette.accent)
                    }
                }
                Spacer()
                if tx.pendingPatternName != nil {
                    Chip(text: "annulla") { tx.cancelPendingPattern() }
                }
            }
            Toggle("cambia anche il tempo", isOn: $tx.patternTempo)
            Text("stili")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(TX6Pattern.styles) { st in
                    GridChip(text: st.name, on: tx.currentPatternID == st.id) { tx.play(st) }
                }
            }
            Text("i tuoi pattern")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
            if tx.patterns.isEmpty {
                Text("ancora nessuno: prepara batteria e melodia, poi «salva come pattern nuovo»")
                    .font(.footnote)
                    .foregroundStyle(Palette.dim)
            }
            ForEach(tx.patterns) { pat in
                HStack(spacing: 6) {
                    GridChip(text: pat.name, on: tx.currentPatternID == pat.id) { tx.play(pat) }
                    Chip(text: "salva qui") { tx.overwrite(pat) }
                    Chip(text: "✕") { tx.deletePattern(pat) }
                }
            }
            Chip(text: "salva come pattern nuovo") { tx.saveNewPattern() }
            ConfirmChip(text: "cancella il pattern: ricomincia da zero") { tx.clearSequence() }
            Text("Svuota batteria, melodie e passi con manopola, anche mentre suona. I suoni delle tracce, il tempo e i pattern salvati restano.")
                .font(.footnote)
                .foregroundStyle(Palette.dim)
        }
    }
}

/// La melodia a passi: una traccia alla volta, ogni passo una nota.
struct TX6MelodyCard: View {
    @EnvironmentObject var tx: TX6Engine
    @State private var track = 1
    @State private var brush: Int? = 0

    private let names = ["do", "do#", "re", "re#", "mi", "fa", "fa#", "sol", "sol#", "la", "la#", "si", "do↑"]
    private let columns7 = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        Card(title: "melodia a passi", note: "Sedici passi per ogni traccia: in ogni passo una nota. Scegli la traccia, tocca una nota (il pennello) e poi i passi dove la vuoi: la senti subito. Ritocca un passo con la stessa nota per svuotarlo. Più tracce con la melodia suonano insieme. Serve NOTE on e il synth su play; parte col tempo della scheda Ritmo, insieme alla batteria.") {
            HStack {
                Toggle("accesa", isOn: $tx.melodyOn)
                Chip(text: tx.running ? "■" : "▶", on: tx.running) { tx.toggleRun() }
            }
            OneTrackPicker(selected: track) { track = $0 }
            HStack(spacing: 8) {
                Chip(text: "ottava −") { tx.melodyOctaves[track - 1] = max(1, tx.melodyOctaves[track - 1] - 1) }
                Text("do\(tx.melodyOctaves[track - 1])")
                    .font(.system(.subheadline, design: .monospaced))
                    .frame(minWidth: 44)
                Chip(text: "ottava +") { tx.melodyOctaves[track - 1] = min(7, tx.melodyOctaves[track - 1] + 1) }
            }
            Text("pennello")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
            LazyVGrid(columns: columns7, spacing: 6) {
                GridChip(text: "vuoto", on: brush == nil) { brush = nil }
                ForEach(0..<13, id: \.self) { k in
                    GridChip(text: names[k], on: brush == k) { brush = k }
                }
            }
            TX6StepGrid(live: tx.live, pulsing: tx.pulsing,
                        label: { tx.melodies[track - 1][$0].map { names[$0] } ?? "·" },
                        filled: { tx.melodies[track - 1][$0] != nil },
                        tap: { i in
                            let now = tx.melodies[track - 1][i] == brush ? nil : brush
                            tx.melodies[track - 1][i] = now
                            if let k = now { tx.preview(track, k) }
                        })
            HStack(spacing: 6) {
                Text("ogni nota dura")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.dim)
                ForEach([(1, "1/16"), (2, "1/8"), (4, "1/4")], id: \.0) { l in
                    Chip(text: l.1, on: tx.melodyLength == l.0) { tx.melodyLength = l.0 }
                }
            }
            HStack(spacing: 8) {
                Chip(text: "svuota la traccia \(track)") { tx.melodies[track - 1] = Array(repeating: nil, count: 16) }
                ConfirmChip(text: "svuota tutte") { tx.melodies = Array(repeating: Array(repeating: nil, count: 16), count: 6) }
                Text("con note: " + ((1...6).filter { tx.melodies[$0 - 1].contains { $0 != nil } }.map { "\($0)" }.joined(separator: " ")).ifEmpty("nessuna"))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.dim)
            }
        }
    }
}

/// Un tasto che cancella tanto: il primo tocco chiede conferma, il secondo (entro 4 secondi) cancella.
/// Col Controllo Vocale basta ridire lo stesso numero.
struct ConfirmChip: View {
    let text: String
    let action: () -> Void
    @State private var armed = false

    var body: some View {
        Chip(text: armed ? "sicuro? tocca di nuovo" : text, on: armed, color: Palette.rec) {
            if armed {
                armed = false
                action()
            } else {
                armed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { armed = false }
            }
        }
    }
}

/// Un tasto che riempie la sua colonna, per le griglie strette.
struct GridChip: View {
    let text: String
    var on = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(RoundedRectangle(cornerRadius: 8).fill(on ? Palette.accent : Color(white: 0.18)))
                .foregroundStyle(on ? Color.black : Color.white)
        }
        .buttonStyle(.plain)
    }
}

/// Sedici passi. Guarda solo `live`: quando avanza il passo si ridisegnano questi quadratini, non la pagina.
struct TX6StepGrid: View {
    @ObservedObject var live: TX6Live
    let pulsing: Bool
    let label: (Int) -> String
    let filled: (Int) -> Bool
    let tap: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 8)

    var body: some View {
        #if DEBUG
        let _ = Diagnostics.shared.count("griglia passi tx6")
        #endif
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0..<16, id: \.self) { i in
                StepCell(label: label(i), filled: filled(i), current: pulsing && live.step == i) { tap(i) }
            }
        }
    }
}

/// I sei pad: si accendono quando suonano, da te o dalla batteria a passi.
struct TX6PadGrid: View {
    @EnvironmentObject var tx: TX6Engine
    @ObservedObject var live: TX6Live

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(1...6, id: \.self) { t in
                PressPad(lit: live.flash.contains(t) || (tx.pulsing && tx.beatsOn && tx.beats[t - 1][live.step]), onPress: { tx.hitPad(t) }) {
                    VStack(spacing: 2) {
                        Text("traccia \(t)").font(.system(.subheadline, design: .monospaced))
                        Text(TX6.sounds[TX6.soundIndex(tx.value(t, .sound))]).font(.system(.caption, design: .monospaced))
                        Text("do\(tx.padBase / 12 - 1)").font(.system(.caption2, design: .monospaced))
                    }
                }
                .frame(height: 70)
            }
        }
    }
}

struct TX6MorphReadout: View {
    @ObservedObject var side: TX6Side

    var body: some View {
        if let p = side.morphProgress {
            Text("sfuma… \(Int(p * 100))%")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.accent)
        }
    }
}

struct TX6TiltReadout: View {
    @ObservedObject var side: TX6Side

    var body: some View {
        Text(String(format: "inclinazione %+.0f%%", side.tilt * 100))
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Palette.accent)
    }
}

/// I suoni del synth divisi in gruppi, tutti visibili: col Controllo Vocale ognuno ha il suo numero.
struct SoundGrid: View {
    @EnvironmentObject var tx: TX6Engine
    let track: Int

    private let groups: [(name: String, sounds: [Int])] = [("onde", [0, 1, 2, 3]), ("batteria", [4, 5, 6, 7]), ("altro: campione, o note verso un altro synth", [8, 9])]

    var body: some View {
        let current = TX6.soundIndex(tx.value(track, .sound))
        VStack(alignment: .leading, spacing: 6) {
            ForEach(groups, id: \.name) { g in
                Text(g.name)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.dim)
                HStack(spacing: 6) {
                    ForEach(g.sounds, id: \.self) { i in
                        Chip(text: TX6.sounds[i], on: current == i) { tx.set(track, .sound, TX6.soundValue(i)) }
                    }
                }
            }
        }
    }
}

private extension String {
    func ifEmpty(_ other: String) -> String { isEmpty ? other : self }
}

// MARK: - Ritmo

struct TX6RitmoView: View {
    @EnvironmentObject var tx: TX6Engine

    var body: some View {
        TX6Page(title: "Ritmo") {
            TX6TempoCard()

            Card(title: "il trasporto del TX-6", note: "Start/stop (cc 46) è un interruttore: il TX-6 non dice se sta suonando. Il tempo si sposta di uno o cinque bpm per volta: per imporne uno preciso usa «Bobina dà il tempo al TX-6».") {
                HStack(spacing: 6) {
                    Chip(text: "▶■") { tx.startStopTX6() }
                    Chip(text: "−5") { tx.nudgeTempo(-5) }
                    Chip(text: "−1") { tx.nudgeTempo(-1) }
                    Chip(text: "+1") { tx.nudgeTempo(1) }
                    Chip(text: "+5") { tx.nudgeTempo(5) }
                }
            }

            Card(title: "pompa", note: "Il sidechain che il TX-6 non ha: a ogni quarto il volume delle tracce scelte cala e risale.") {
                Toggle("accesa", isOn: $tx.pumpOn)
                ValueSlider(name: "quanto", value: $tx.pumpDepth, range: 0...1, shown: "\(Int(tx.pumpDepth * 100))%")
                ValueSlider(name: "risalita", value: $tx.pumpRelease, range: 0.1...1, shown: "\(Int(tx.pumpRelease * 100))%")
                TrackPicker(tracks: $tx.pumpTracks)
            }

            Card(title: "cancello", note: "A ogni passo spento le tracce scelte vanno in muto: il transformer.") {
                Toggle("acceso", isOn: $tx.gateOn)
                TX6StepGrid(live: tx.live, pulsing: tx.pulsing,
                            label: { tx.gate[$0] ? "■" : "·" },
                            filled: { tx.gate[$0] },
                            tap: { tx.gate[$0].toggle() })
                Chip(text: "rimetti tutti i passi aperti") { tx.gate = Array(repeating: true, count: 16) }
                TrackPicker(tracks: $tx.gateTracks)
            }

            TX6WaveCard(index: 0)
            TX6WaveCard(index: 1)

            Card(title: "deriva", note: "I volumi delle tracce scelte vagano piano, ognuno per conto suo; col pan acceso vagano anche fra destra e sinistra.") {
                Toggle("accesa", isOn: $tx.driftOn)
                Toggle("anche il pan", isOn: $tx.driftPan)
                ValueSlider(name: "quanto", value: $tx.driftAmount, range: 0.1...1, shown: "\(Int(tx.driftAmount * 100))%")
                TrackPicker(tracks: $tx.driftTracks)
            }

            Card(title: "col corpo", note: "Inclina il telefono: a destra apre, a sinistra chiude. Di fabbrica muove il filtro delle tracce scelte.") {
                Toggle("accesa", isOn: $tx.tiltOn)
                ParamMenu(selected: tx.tiltParam) { tx.tiltParam = $0 }
                TrackPicker(tracks: $tx.tiltTracks)
                if tx.tiltOn { TX6TiltReadout(side: tx.side) }
            }
        }
    }
}

struct TX6TempoCard: View {
    @EnvironmentObject var tx: TX6Engine

    var body: some View {
        Card(title: "tempo", note: "Tre modi. Bobina tiene il tempo per sé: è il più leggero, e col bluetooth e due macchine è quello da usare. Oppure lo dà al TX-6 (sul TX-6: CLOCK → SRC USB, o BLE col bluetooth): il suo sequencer e gli effetti a tempo seguono Bobina, ma partono 48 messaggi di clock al secondo. Oppure segue il TX-6 (sul TX-6: SRC INT, OUT acceso, e play sulla schermata del tempo).") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(TX6ClockMode.allCases) { m in
                    Chip(text: m.rawValue, on: tx.clockMode == m) { tx.clockMode = m }
                }
            }
            HStack(spacing: 10) {
                Chip(text: "−") { tx.bpm = max(40, tx.bpm - 1) }
                Text("\(Int(tx.bpm.rounded()))")
                    .font(.system(size: 34, weight: .medium, design: .monospaced))
                    .frame(minWidth: 80)
                Chip(text: "+") { tx.bpm = min(300, tx.bpm + 1) }
                Spacer()
                Chip(text: "tap") { tx.tap() }
            }
            Slider(value: $tx.bpm, in: 40...300, step: 1)
                .disabled(tx.clockMode == .follow)
            if tx.clockMode == .follow {
                Text(tx.clockBPM.map { String(format: "segue il TX-6: %.1f bpm", $0) } ?? "aspetto il clock: premi play sul TX-6")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.accent)
            } else {
                Chip(text: tx.running ? "■ ferma il tempo" : "▶ fai partire il tempo", on: tx.running) { tx.toggleRun() }
                if let c = tx.clockBPM {
                    Button(String(format: "arriva un clock dal TX-6: %.1f bpm", c)) { tx.clockMode = .follow }
                        .font(.footnote)
                }
            }
        }
    }
}

struct TX6WaveCard: View {
    @EnvironmentObject var tx: TX6Engine
    let index: Int

    private let lengths: [(String, Double)] = [("1/8", 0.5), ("1/4", 1), ("1/2", 2), ("1", 4), ("2", 8), ("4", 16), ("8", 32)]

    var body: some View {
        let w = tx.waves[index]
        Card(title: "onda \(index + 1)", note: index == 0 ? "Il TX-6 non ha LFO: l'onda muove un parametro intorno al valore che hai messo, a tempo. Il display del TX-6 salterà sulla pagina di quel parametro finché gira." : nil) {
            Toggle("accesa", isOn: $tx.waves[index].on)
            ParamMenu(selected: w.param) { tx.waves[index].param = $0 }
            ChipRow(items: TX6Wave.Shape.allCases.map { $0.rawValue }, selected: TX6Wave.Shape.allCases.firstIndex(of: w.shape)) {
                tx.waves[index].shape = TX6Wave.Shape.allCases[$0]
            }
            HStack(spacing: 6) {
                Text("un giro ogni")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.dim)
                ChipRow(items: lengths.map { $0.0 }, selected: lengths.firstIndex { $0.1 == w.beats }) {
                    tx.waves[index].beats = lengths[$0].1
                }
            }
            ValueSlider(name: "quanto", value: $tx.waves[index].depth, range: 2...63, shown: "±\(Int(w.depth))")
            TrackPicker(tracks: $tx.waves[index].tracks)
        }
    }
}

// MARK: - Collega

struct TX6CollegaView: View {
    @EnvironmentObject var tx: TX6Engine
    @State private var showBluetooth = false

    var body: some View {
        TX6Page(title: "Collega") {
            Card(title: "col cavo USB-C", note: "Collega il TX-6 acceso all'iPhone col cavo USB-C: compare da solo qui sotto. Finché resta collegato è anche la scheda audio dell'iPhone, e l'iPhone prova a caricarlo: se non vuoi, sul TX-6 menu → GND acceso.") {
                EmptyView()
            }

            Card(title: "col bluetooth", note: "Sul TX-6: shift + select → BLE → ACCEPT. Poi qui «cerca il TX-6» e sceglilo dalla lista. Il bluetooth porta solo MIDI, mai audio.") {
                Chip(text: "cerca il TX-6") { showBluetooth = true }
            }

            Card(title: "come va messo il TX-6", note: "Shift + select → MIDI. CTRL IN: ascolta Bobina (ed è l'unico modo in cui la ascolta). NOTE on: le note suonano il synth, che va acceso (menu → SYNTH → play). CTRL OUT: diventa un controller e manda qui i suoi fader, ma non ascolta più niente.") {
                EmptyView()
            }

            Card(title: "a chi parla Bobina", note: "Di solito sceglie da sola il TX-6.") {
                HStack {
                    Text("manda a")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                    Spacer()
                    Picker("manda a", selection: $tx.destinationID) {
                        Text("nessuno").tag(MIDIUniqueIDOrNil.none)
                        ForEach(tx.destinations) { p in
                            Text(p.name).tag(MIDIUniqueIDOrNil.some(p.id))
                        }
                    }
                }
                HStack {
                    Text("ascolta")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                    Spacer()
                    Picker("ascolta", selection: $tx.sourceID) {
                        Text("nessuno").tag(MIDIUniqueIDOrNil.none)
                        ForEach(tx.sources) { p in
                            Text(p.name).tag(MIDIUniqueIDOrNil.some(p.id))
                        }
                    }
                }
                Button("aggiorna l'elenco") { tx.refreshPorts() }
                    .font(.footnote)
            }

            TX6MirrorCard(side: tx.side)

            Card(title: "il TX-6 comanda il TP-7", note: "TX-6 su CTRL OUT col cavo, TP-7 collegato alla sezione TP-7 (per esempio col bluetooth). I fader diventano i volumi del TP-7, i tasti traccia i suoi muti, FX I è play e stop, FX II un tape stop, la manopola select la velocità (premuta torna a ×1).") {
                Toggle("acceso", isOn: $tx.bridgeOn)
            }

            NavigationLink {
                TabelleView(sections: TX6Tables.all, title: "Tabelle MIDI TX-6")
            } label: {
                HStack {
                    Text("tutte le tabelle MIDI del TX-6")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.card))
            }
            .buttonStyle(.plain)

            TX6MonitorCard()
        }
        #if DEBUG
        // per le prove nel simulatore: -bobina.prova.bluetooth YES apre subito la ricerca
        .onAppear { if UserDefaults.standard.bool(forKey: "bobina.prova.bluetooth") { showBluetooth = true } }
        #endif
        .sheet(isPresented: $showBluetooth) {
            VStack(spacing: 0) {
                HStack {
                    Text("MIDI bluetooth").font(.headline)
                    Spacer()
                    Button("fine") {
                        showBluetooth = false
                        tx.refreshPorts()
                    }
                }
                .padding()
                BluetoothMIDIPicker()
            }
        }
    }
}

/// In CTRL OUT il TX-6 manda fader, manopole e tasti: qui si vedono.
struct TX6MirrorCard: View {
    @EnvironmentObject var tx: TX6Engine
    @ObservedObject var side: TX6Side

    private func cell(_ v: Int?) -> some View {
        Text(v.map { "\($0)" } ?? "·")
            .font(.system(.caption, design: .monospaced))
            .frame(maxWidth: .infinity, minHeight: 24)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color(white: 0.18)))
    }

    var body: some View {
        Card(title: "specchio", note: "Con il TX-6 su CTRL OUT: i numeri che mandano manopole (blu, arancione, bianca) e fader. Serve anche a misurare: per esempio se il fader in alto manda 127 o 0.") {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 4) {
                    Text(["blu", "aran", "bian"][r])
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                        .frame(width: 30, alignment: .leading)
                    ForEach(0..<6, id: \.self) { t in cell(side.knobs[r][t]) }
                }
            }
            HStack(spacing: 4) {
                Text("fader")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Palette.dim)
                    .frame(width: 30, alignment: .leading)
                ForEach(0..<6, id: \.self) { t in cell(side.faders[t]) }
            }
            HStack(spacing: 4) {
                ForEach(["tasto traccia 1", "tasto traccia 2", "tasto traccia 3", "tasto traccia 4", "tasto traccia 5", "tasto traccia 6", "select premuto", "FX I", "FX II", "shift", "aux", "cue"], id: \.self) { name in
                    Text(name.hasPrefix("tasto") ? String(name.suffix(1)) : name == "select premuto" ? "sel" : name)
                        .font(.system(size: 10, design: .monospaced))
                        .frame(maxWidth: .infinity, minHeight: 26)
                        .background(RoundedRectangle(cornerRadius: 5).fill(side.pressed.contains(name) ? Palette.accent : Color(white: 0.18)))
                        .foregroundStyle(side.pressed.contains(name) ? Color.black : Color.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            HStack {
                Text(side.lastControl)
                Spacer()
                Text("select \(side.encoderSteps > 0 ? "+" : "")\(side.encoderSteps)")
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Palette.dim)
            if let c = tx.clockBPM {
                Text(String(format: "arriva un clock: %.1f bpm", c))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.accent)
            }
        }
    }
}

struct TX6MonitorCard: View {
    @EnvironmentObject var tx: TX6Engine

    var body: some View {
        Card(title: "monitor", note: "← arriva dal TX-6 · → parte da Bobina. Onde, pompa e deriva non vengono scritte, per non affollare.") {
            HStack {
                Toggle("in pausa", isOn: $tx.logPaused)
                    .font(.footnote)
                Spacer()
                Button("pulisci") { tx.clearLog() }
                    .font(.footnote)
            }
            VStack(alignment: .leading, spacing: 3) {
                ForEach(tx.log.prefix(40)) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(line.incoming ? "←" : "→")
                            .foregroundStyle(Palette.accent)
                        Text(line.text)
                        Spacer(minLength: 4)
                        Text(line.raw)
                            .foregroundStyle(Palette.dim)
                            .lineLimit(1)
                    }
                    .font(.system(size: 11, design: .monospaced))
                }
                if tx.log.isEmpty {
                    Text("ancora niente")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                }
            }
        }
    }
}

// MARK: - tabelle

/// Tutte le tabelle MIDI del TX-6 (firmware 1.3.x). «community» = misurato da chi l'ha provato.
enum TX6Tables {
    static let all: [TableSection] = [
        TableSection(
            title: "le modalità · shift + select → MIDI",
            intro: "Due voci: CTRL (off, IN, OUT) e NOTE (off, on). Mai IN e OUT insieme.",
            rows: [
                TableRow(key: "CTRL IN", what: "ascolta cc e program change sui canali 1-9", more: "Non manda niente. Di fabbrica il TX-6 ignora i cc finché non lo metti su IN.", community: true),
                TableRow(key: "CTRL OUT", what: "manda fader, manopole e tasti (cc 1-37, canale 1)", more: "Non ascolta niente. Le manopole continuano a fare il loro lavoro."),
                TableRow(key: "NOTE on", what: "le note suonano il synth"),
                TableRow(key: "CTRL off", what: "mandano solo le manopole messe su «cc» in POTS (dal 1.3.0)")
            ]
        ),
        TableSection(
            title: "le tracce · canali 1-6",
            intro: "Il canale è la traccia. Tutto da 0 a 127; «acceso» = 64-127.",
            rows: TX6.Param.allCases.map { TableRow(key: "cc \($0.cc)", what: $0.name) } + [
                TableRow(key: "cc 120", what: "muto o solo", more: "127 acceso, 0 spento. Per il resto del mondo è «panico»: un tasto panico di un'altra app mette i muti.", community: true)
            ]
        ),
        TableSection(
            title: "il generale · canale 7",
            rows: [
                TableRow(key: "cc 7", what: "volume main"),
                TableRow(key: "cc 14", what: "volume aux"),
                TableRow(key: "cc 15", what: "volume cue (cuffie)"),
                TableRow(key: "cc 46", what: "start / stop", more: "Un interruttore: ogni «acceso» cambia stato. Dal 1.2.15.", community: true),
                TableRow(key: "cc 47", what: "tempo relativo", more: "1…63 alza, 127…65 abbassa. 64 ± n sbaglia di grosso.", community: true),
                TableRow(key: "cc 122", what: "local control", more: "0 = manopole e fader del TX-6 spenti, 127 = riaccesi."),
                TableRow(key: "program 1 · 2 · 3", what: "scena a · b · c", more: "Sul filo probabilmente 00, 01, 02: da misurare.")
            ]
        ),
        TableSection(
            title: "gli effetti · canale 8 = FX I, 9 = FX II",
            rows: [
                TableRow(key: "cc 82", what: "acceso / spento", more: "Per tutto l'effetto; la quantità per traccia è la mandata cc 91.", community: true),
                TableRow(key: "cc 15", what: "quale effetto", more: "FX I: riverbero, chorus, delay · FX II: filtro, crush, distorsione, tremolo, freeze, tape. Divisione dei valori da misurare."),
                TableRow(key: "cc 12 · 13 · 14", what: "parametri 1 · 2 · 3"),
                TableRow(key: "cc 7 · canale 8", what: "ritorno di FX I"),
                TableRow(key: "cc 9 · canale 9", what: "su quale traccia sta FX II")
            ]
        ),
        TableSection(
            title: "le note",
            intro: "Con NOTE on e il synth su play.",
            rows: [
                TableRow(key: "canali 1-6", what: "da do0 a si8: la traccia a quella nota"),
                TableRow(key: "canale 7", what: "do re mi fa sol la = tracce 1-6 alla loro frequenza", more: "Quale ottava: da misurare. La batteria non ha velocity.")
            ]
        ),
        TableSection(
            title: "cosa manda · CTRL OUT, canale 1",
            intro: "I tasti mandano 127 premuti e 0 lasciati.",
            rows: [
                TableRow(key: "cc 1-6", what: "fader 1-6", more: "Se in alto è 127 o 0: da misurare."),
                TableRow(key: "cc 7-12 · 13-18 · 19-24", what: "manopole blu · arancioni · bianche"),
                TableRow(key: "cc 25-30", what: "tasti traccia 1-6"),
                TableRow(key: "cc 31", what: "select girato, relativo: 1, 2, 3 in un verso, 127, 126, 125 nell'altro", community: true),
                TableRow(key: "cc 32-37", what: "select premuto, FX I, FX II, shift, aux, cue")
            ]
        ),
        TableSection(
            title: "il clock",
            rows: [
                TableRow(key: "SRC INT + OUT", what: "il TX-6 dà il tempo: 24 impulsi per quarto", community: true),
                TableRow(key: "SRC USB / BLE", what: "il TX-6 segue il clock, start e stop che arrivano"),
                TableRow(key: "SRC TR1-6", what: "il TX-6 ricava il tempo dal suono di una traccia (beat tracking)")
            ]
        )
    ]
}
