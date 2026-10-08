import SwiftUI

/// Mixer: le sei tracce in colonna come sul TX-6, gli effetti, il generale e le scene. Una parte alla volta,
/// ognuna in uno schermo (8/10/2026: dentro anche la vecchia scheda Effetti).
struct TX6MixerView: View {
    @EnvironmentObject var tx: TX6Engine
    @AppStorage("bobina.tx6.mixer.parte") private var part = 0
    /// Cosa regolano le sei colonne: volume, guadagno, EQ, compressore… La scelta resta salvata.
    @AppStorage("bobina.tx6.mixer.strato") private var layerRaw = TX6.Param.volume.rawValue

    static let parts = ["tracce", "FX I", "FX II", "generale", "scene"]
    static let layers: [TX6.Param] = [.volume, .gain, .comp, .eqHigh, .eqMid, .eqLow, .pan, .filter, .fx1Send, .auxSend, .aux2Send]

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

    private let six = Array(repeating: GridItem(.flexible(), spacing: 4), count: 6)

    var body: some View {
        let layer = TX6.Param(rawValue: layerRaw) ?? .volume
        TX6Screen(title: "Mixer") {
            TX6Parts(items: Self.parts, selection: $part)
            switch part {
            case 1:
                TX6FxPanel(index: 0) {
                    layerRaw = TX6.Param.fx1Send.rawValue
                    part = 0
                }
            case 2: TX6FxPanel(index: 1)
            case 3: TX6GeneralPanel()
            case 4: TX6ScenesPanel()
            default:
                TX6Box {
                    LazyVGrid(columns: six, spacing: 4) {
                        ForEach(Self.layers) { p in
                            TX6Mini(text: Self.label(p), on: layer == p, color: Color(white: 0.75)) { layerRaw = p.rawValue }
                                .accessibilityLabel("regola \(Self.label(p))")
                        }
                    }
                    HStack(alignment: .top, spacing: 4) {
                        ForEach(1...6, id: \.self) { t in
                            TX6Strip(track: t, param: layer)
                        }
                    }
                    TX6Label("M muto, S solo. In cima a ogni colonna si apre la traccia. Il TX-6 va su MIDI → CTRL IN.")
                }
                TX6Box {
                    TX6KnobRow(name: "main", value: tx.master[0]) { tx.setMaster(0, $0) }
                }
            }
        }
    }
}

/// Una colonna del mixer, come un canale del TX-6: in cima la traccia (si apre), il valore,
/// i salti da max a 0, − e +, muto e solo.
struct TX6Strip: View {
    @EnvironmentObject var tx: TX6Engine
    let track: Int
    let param: TX6.Param

    var body: some View {
        let v = tx.value(track, param)
        let name = TX6MixerView.label(param)
        VStack(spacing: 4) {
            NavigationLink {
                TX6TrackView(start: track)
            } label: {
                VStack(spacing: 0) {
                    Text("tr \(track) ›")
                        .font(.system(.footnote, design: .monospaced).weight(.semibold))
                    Text(tx.soundName(track))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color(white: 0.14)))
                .foregroundStyle(Color.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("apri la traccia \(track)")
            Text(param.shown(v))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Palette.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(height: 14)
            if param == .gain {
                // il guadagno solo un dB alla volta, mai a salti: un «max» sentito male rompe le casse
                TX6Mini(text: "+1 dB", height: 84) { tx.stepGain(track, by: 1) }
                    .accessibilityLabel("traccia \(track) guadagno più un decibel")
                TX6Mini(text: "−1 dB", height: 84) { tx.stepGain(track, by: -1) }
                    .accessibilityLabel("traccia \(track) guadagno meno un decibel")
            } else {
                ForEach(TX6Jump.of(param).reversed(), id: \.self) { j in
                    TX6Mini(text: j.label, on: abs(v - j.value) <= 4, height: 32) { tx.set(track, param, j.value) }
                        .accessibilityLabel("traccia \(track) \(name) \(j.spoken)")
                }
                HStack(spacing: 3) {
                    TX6Mini(text: "−", height: 32) { tx.set(track, param, v - 8) }
                        .accessibilityLabel("traccia \(track) \(name) meno")
                    TX6Mini(text: "+", height: 32) { tx.set(track, param, v + 8) }
                        .accessibilityLabel("traccia \(track) \(name) più")
                }
            }
            HStack(spacing: 3) {
                TX6Mini(text: "M", on: tx.mutes[track - 1], color: Palette.rec, height: 32) { tx.toggleMute(track) }
                    .accessibilityLabel("muto traccia \(track)")
                TX6Mini(text: "S", on: tx.solos.contains(track), color: Color.yellow, height: 32) { tx.toggleSolo(track) }
                    .accessibilityLabel("solo traccia \(track)")
            }
        }
    }
}

/// FX I (in mandata, canale 8) o FX II (inserito, canale 9).
struct TX6FxPanel: View {
    @EnvironmentObject var tx: TX6Engine
    let index: Int
    /// Solo FX I: porta alle colonne del mixer con le mandate FX I.
    var showSends: (() -> Void)? = nil

    private let three = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)
    private let seven = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    /// I valori che ogni effetto ha davvero, dalle pagine degli effetti della guida ufficiale (8/10/2026):
    /// uno solo per effetto (il parametro 1), più la risonanza (parametro 2) nel filtro. Nessuno usa il 3.
    /// Che il parametro 1 sia proprio quel valore viene dalla guida, non è ancora misurato (prova 19).
    static func paramNames(_ index: Int, _ engine: Int?) -> [String] {
        if index == 0 {
            switch engine {
            case 0: return ["1 · drone · light · small · medium · large"]
            case 1: return ["1 · subtle · medium · strong"]
            case 2: return ["1 · 1/8 … 3/2 a tempo, warp, mash"]
            default: return ["1 · tipo o tempo dell'effetto"]
            }
        }
        switch engine {
        case 0: return ["1 · taglio", "2 · risonanza"]
        case 1: return ["1 · shape · bend · chip · bit"]
        case 2: return ["1 · push · drive · blow · dstroy"]
        case 3: return ["1 · quantità 0-99"]
        case 4: return ["1 · freeze − … +"]
        case 5: return ["1 · stop 1 · stop 2 · pong"]
        default: return ["1 · il valore dell'effetto", "2 · risonanza, solo nel filtro"]
        }
    }

    var body: some View {
        let name = index == 0 ? "FX I" : "FX II"
        TX6Box {
            HStack(spacing: 4) {
                TX6Mini(text: "acceso", on: tx.fxKnown[index] && tx.fxOn[index], height: 40) { tx.setFx(index, on: true) }
                    .accessibilityLabel("accendi \(name)")
                TX6Mini(text: "spento", on: tx.fxKnown[index] && !tx.fxOn[index], color: Palette.rec, height: 40) { tx.setFx(index, on: false) }
                    .accessibilityLabel("spegni \(name)")
                TX6Mini(text: "spegni FX I e II", height: 40) { tx.allFxOff() }
                    .accessibilityLabel("spegni tutti e due gli effetti")
            }
            LazyVGrid(columns: three, spacing: 4) {
                ForEach(TX6.fxEngines[index].indices, id: \.self) { i in
                    TX6Mini(text: TX6.fxEngines[index][i], on: tx.fxEngine[index] == i, color: Color(white: 0.75), height: 38) { tx.setFxEngine(index, i) }
                        .accessibilityLabel("effetto \(TX6.fxEngines[index][i])")
                }
            }
            let names = Self.paramNames(index, tx.fxEngine[index])
            ForEach(names.indices, id: \.self) { k in
                TX6KnobRow(name: names[k], value: tx.fxParams[index][k]) { tx.setFxParam(index, k, $0) }
            }
            TX6Label("Dalla guida: un valore per effetto (1); il filtro ha anche la risonanza (2). Il 3 non serve.")
            if index == 0 {
                TX6KnobRow(name: "ritorno", value: tx.fxReturn) { tx.setFxReturn($0) }
                if let show = showSends {
                    TX6Mini(text: "mandate delle tracce →", height: 38) { show() }
                }
                TX6Label("Spento, il ritorno va a zero: tace anche con le mandate alzate. Riacceso, torna dov'era.")
            } else {
                TX6Label("su quale traccia")
                LazyVGrid(columns: seven, spacing: 4) {
                    ForEach(TX6.fx2Places.indices, id: \.self) { i in
                        TX6Mini(text: TX6.fx2Places[i], on: tx.fx2Place == i) { tx.setFx2Place(i) }
                            .accessibilityLabel("FX II su \(TX6.fx2Places[i])")
                    }
                }
                TX6Label("Uno alla volta. Se il mix suona ovattato, di solito è il filtro di FX II rimasto acceso.")
            }
        }
    }
}

/// Canale 7: main, aux, cue e le manopole del TX-6.
struct TX6GeneralPanel: View {
    @EnvironmentObject var tx: TX6Engine

    var body: some View {
        TX6Box {
            TX6KnobRow(name: "main", value: tx.master[0]) { tx.setMaster(0, $0) }
            TX6KnobRow(name: "aux", value: tx.master[1]) { tx.setMaster(1, $0) }
            TX6KnobRow(name: "cue (cuffie)", value: tx.master[2]) { tx.setMaster(2, $0) }
            TX6Mini(text: tx.localOff ? "riaccendi le manopole del TX-6" : "spegni le manopole del TX-6", on: tx.localOff, height: 40) { tx.toggleLocal() }
            TX6Label("Con le manopole spente il TX-6 ignora i suoi fader e le sue manopole: comandi solo da qui.")
        }
    }
}

/// Le scene del TX-6 (a, b, c) e quelle di Bobina, che sfumano.
struct TX6ScenesPanel: View {
    @EnvironmentObject var tx: TX6Engine

    var body: some View {
        TX6Box {
            TX6Label("scene salvate sul TX-6 (menu → SCENE)")
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    TX6Mini(text: "scena \(["a", "b", "c"][i])", height: 40) { tx.recallTX6Scene(i) }
                }
            }
        }
        TX6Box {
            TX6Label("scene di Bobina: fotografano quello che hai mandato al TX-6, e ci arrivano sfumando")
            HStack(spacing: 4) {
                TX6Mini(text: "fotografa adesso", height: 40) { tx.saveScene() }
                TX6MorphReadout(side: tx.side)
            }
            TX6Label("sfuma in quante battute")
            HStack(spacing: 4) {
                ForEach([1.0, 2, 4, 8, 16], id: \.self) { b in
                    TX6Mini(text: "\(Int(b))", on: tx.morphBars == b) { tx.morphBars = b }
                        .accessibilityLabel("sfuma in \(Int(b)) battute")
                }
            }
            if tx.scenes.isEmpty {
                TX6Label("nessuna scena ancora")
            }
            ForEach(tx.scenes) { s in
                HStack(spacing: 4) {
                    Text(s.name)
                        .font(.system(.footnote, design: .monospaced))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TX6Mini(text: "sfuma") { tx.recall(s, fade: true) }
                        .accessibilityLabel("sfuma su \(s.name)")
                    TX6Mini(text: "di colpo") { tx.recall(s, fade: false) }
                        .accessibilityLabel("\(s.name) di colpo")
                    TX6ConfirmMini(text: "✕") { tx.deleteScene(s) }
                        .accessibilityLabel("cancella \(s.name)")
                }
            }
        }
    }
}

/// Tutta una traccia, in uno schermo: una parte alla volta.
struct TX6TrackView: View {
    @EnvironmentObject var tx: TX6Engine
    let start: Int
    @State private var track: Int?
    @AppStorage("bobina.tx6.traccia.parte") private var part = 0

    static let parts = ["mixer", "EQ e filtro", "mandate", "synth"]
    static let groups: [[TX6.Param]] = [[.volume, .pan, .gain, .comp], [.eqHigh, .eqMid, .eqLow, .filter], [.fx1Send, .auxSend, .aux2Send], [.freq, .length, .detune]]
    private let five = Array(repeating: GridItem(.flexible(), spacing: 4), count: 5)

    var body: some View {
        let t = track ?? start
        ScrollView {
            VStack(spacing: 8) {
                TX6TrackRow(selected: t) { track = $0 }
                TX6Parts(items: Self.parts, selection: $part)
                TX6Box {
                    if part == 3 {
                        LazyVGrid(columns: five, spacing: 4) {
                            ForEach(TX6DrumPanel.soundOrder, id: \.self) { i in
                                TX6Mini(text: TX6.sounds[i], on: TX6.soundIndex(tx.value(t, .sound)) == i) { tx.set(t, .sound, TX6.soundValue(i)) }
                                    .accessibilityLabel("suono \(TX6.sounds[i])")
                            }
                        }
                    }
                    ForEach(Self.groups[min(3, max(0, part))]) { p in
                        if p == .gain {
                            TX6GainRow(track: t)
                        } else {
                            TX6KnobRow(name: p.name, value: tx.value(t, p), shown: p.shown(tx.value(t, p)), jumps: TX6Jump.of(p)) { tx.set(t, p, $0) }
                        }
                    }
                    if part == 3 {
                        HStack(spacing: 4) {
                            Text("pattern del synth")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Palette.dim)
                            Spacer()
                            SmallKey(text: "−") { tx.set(t, .pattern, tx.value(t, .pattern) - 5) }
                                .accessibilityLabel("pattern meno")
                            Text(TX6.patternName(tx.value(t, .pattern)))
                                .font(.system(.footnote, design: .monospaced))
                                .frame(minWidth: 44)
                            SmallKey(text: "+") { tx.set(t, .pattern, tx.value(t, .pattern) + 5) }
                                .accessibilityLabel("pattern più")
                        }
                        TX6Label("Con il synth acceso (menu → SYNTH). Il display del TX-6 dice quale suono ha preso.")
                    }
                }
                HStack(spacing: 4) {
                    TX6Mini(text: tx.mutes[t - 1] ? "muta" : "muto", on: tx.mutes[t - 1], color: Palette.rec, height: 40) { tx.toggleMute(t) }
                        .accessibilityLabel("muto traccia \(t)")
                    TX6Mini(text: "prova", height: 40) { tx.hitPad(t) }
                        .accessibilityLabel("prova la traccia \(t)")
                    TX6Mini(text: "EQ piatto, filtro spento", height: 40) { tx.flatten(t) }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .navigationTitle("Traccia \(t)")
        .navigationBarTitleDisplayMode(.inline)
    }
}
