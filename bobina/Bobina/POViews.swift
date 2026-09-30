import SwiftUI

// MARK: - le quattro schermate dei Pocket Operator

/// Tasti, Suona, Ritmo, Collega. Riapre l'ultima scheda usata.
struct POTabs: View {
    @AppStorage("bobina.po.scheda") private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            POTastiView()
                .tabItem { Label("Tasti", systemImage: "square.grid.4x3.fill") }.tag(0)
            POSuonaView()
                .tabItem { Label("Suona", systemImage: "square.grid.3x3.middle.filled") }.tag(1)
            PORitmoView()
                .tabItem { Label("Ritmo", systemImage: "metronome") }.tag(2)
            POCollegaView()
                .tabItem { Label("Collega", systemImage: "cable.connector") }.tag(3)
        }
    }
}

/// Come Page, con la striscia dei PO.
struct POPage<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    POStatusStrip()
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

struct POStatusStrip: View {
    @EnvironmentObject var po: POEngine

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(po.connected ? Color.green : Palette.rec)
                .frame(width: 8, height: 8)
            Text(po.connected ? "\(po.model.short) · \(po.connectedName)" : "adattatore non collegato · vai su Collega")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
                .lineLimit(1)
            Spacer()
            if po.running || po.othersRunning {
                Text("\(Int(po.bpm.rounded())) bpm")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.accent)
            }
        }
        .padding(.top, 6)
    }
}

/// Il modello sul quale è montato l'adattatore: cambia i nomi dei tasti e degli effetti.
struct POModelPicker: View {
    @EnvironmentObject var po: POEngine

    var body: some View {
        HStack(spacing: 6) {
            ForEach(PO.Model.allCases) { m in
                GridChip(text: m.short, on: po.model == m) { po.model = m }
            }
        }
    }
}

// MARK: - Tasti

struct POTastiView: View {
    @EnvironmentObject var po: POEngine
    @State private var shortcut = PO.Shortcut.pattern
    @State private var fxLength = 600.0

    private let columns4 = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        POPage(title: "Tasti") {
            Card(title: "il PO", note: "Scegli quello su cui è montato l'adattatore: cambiano i nomi del tasto in alto e degli effetti.") {
                POModelPicker()
                Text(po.model.keysNote)
                    .font(.footnote)
                    .foregroundStyle(Palette.dim)
            }

            Card(title: "la faccia", note: "Come sulla macchina. Ogni tasto è diviso in due: sopra lo tocchi una volta, sotto («tieni») resta giù finché non lo ritocchi. Per pattern + 5: tieni pattern, tocca 5, ritocca tieni. Le manopole A e B via MIDI non si muovono.") {
                POFace(live: po.live)
                HStack {
                    Chip(text: "lascia tutto", on: !po.held.isEmpty) { po.releaseAll() }
                    Spacer()
                    Text(po.held.isEmpty ? "niente tenuto" : "tenuti: " + po.held.sorted { $0.note < $1.note }.map { $0.label(po.model) }.joined(separator: " "))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                }
            }

            Card(title: "in un tocco", note: "La combinazione la fa Bobina: tiene il tasto, preme il numero, lascia.") {
                HStack(spacing: 6) {
                    ForEach(PO.Shortcut.allCases, id: \.rawValue) { s in
                        GridChip(text: s.name, on: shortcut == s) { shortcut = s }
                    }
                }
                LazyVGrid(columns: columns4, spacing: 6) {
                    ForEach(1...16, id: \.self) { n in
                        GridChip(text: "\(shortcut.name) \(n)") { po.combo(shortcut, n) }
                    }
                }
            }

            Card(title: "un effetto per un momento", note: "fx + il tasto, tenuti per il tempo scelto. Funziona mentre il PO suona.") {
                HStack(spacing: 6) {
                    ForEach([(300.0, "corto"), (600.0, "medio"), (1500.0, "lungo")], id: \.0) { l in
                        GridChip(text: l.1, on: fxLength == l.0) { fxLength = l.0 }
                    }
                }
                LazyVGrid(columns: columns4, spacing: 6) {
                    ForEach(1...16, id: \.self) { n in
                        GridChip(text: "\(n) \(po.model.fx[n - 1])") { po.fxShot(n, length: fxLength) }
                    }
                }
            }

            Card(title: "servizio", note: "Il modo di sync si legge sul display del PO: SY0 niente, SY2 riceve il sync (quello da usare col TX-6).") {
                HStack(spacing: 6) {
                    GridChip(text: "modo di sync") { po.pair(.special, .bpm) }
                    GridChip(text: "tempo preset") { po.tap(.bpm) }
                    GridChip(text: "play") { po.tap(.play) }
                }
            }
        }
    }
}

/// La pulsantiera: sound, pattern, bpm e le manopole in alto; i 16 tasti in un quadrato e la colonna a destra.
struct POFace: View {
    @EnvironmentObject var po: POEngine
    @ObservedObject var live: POLive

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0..<5, id: \.self) { r in
                ForEach(0..<5, id: \.self) { c in
                    if let k = PO.face[r][c] {
                        POKeyButton(key: k, held: po.held.contains(k), flash: k.number.map { live.flash.contains($0) } ?? false)
                    } else {
                        VStack(spacing: 2) {
                            Text(c == 3 ? "A" : "B")
                                .font(.system(.subheadline, design: .monospaced))
                            Text("non via MIDI")
                                .font(.system(size: 8, design: .monospaced))
                        }
                        .foregroundStyle(Palette.dim)
                        .frame(maxWidth: .infinity, minHeight: 84)
                        .background(Circle().stroke(Palette.cardEdge, lineWidth: 1).padding(4))
                        .accessibilityHidden(true)
                    }
                }
            }
        }
    }
}

/// Un tasto del PO diviso in due: sopra un tocco, sotto «tieni» (resta giù finché non lo ritocchi).
/// Due tasti veri, ognuno col suo nome, così col Controllo Vocale si prende quello giusto.
struct POKeyButton: View {
    @EnvironmentObject var po: POEngine
    let key: PO.Key
    let held: Bool
    let flash: Bool

    var body: some View {
        let name = key.label(po.model)
        let spoken = key.isNumber ? "tasto \(name)" : name
        VStack(spacing: 3) {
            Button { po.touch(key) } label: {
                Text(name)
                    .font(.system(key.isNumber ? .body : .footnote, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(held || flash ? Palette.accent : key.isNumber ? Color(white: 0.24) : Color(white: 0.17))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.cardEdge, lineWidth: 1))
                    .foregroundStyle(held || flash ? Color.black : Color.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(spoken)

            Button { po.toggleHold(key) } label: {
                Text(held ? "lascia" : "tieni")
                    .font(.system(.caption2, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(held ? Palette.accent.opacity(0.55) : Color(white: 0.09))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.cardEdge, lineWidth: 1))
                    .foregroundStyle(held ? Color.black : Palette.dim)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(held ? "lascia \(spoken)" : "tieni \(spoken)")
            .accessibilityAddTraits(held ? .isSelected : [])
        }
    }
}

// MARK: - Suona

struct POSuonaView: View {
    @EnvironmentObject var po: POEngine

    private let columns4 = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        POPage(title: "Suona") {
            Card(title: "passi dal vivo", note: "Il PO resta fermo e Bobina gli preme i tasti a tempo: il PO diventa uno strumento del sequencer di Bobina, sulla stessa battuta del TX-6. Scegli un tasto, poi i passi dove lo vuoi. Mentre un effetto è tenuto questi passi tacciono: sul PO i numeri sceglierebbero l'effetto.") {
                HStack {
                    Toggle("accesi", isOn: $po.liveOn)
                    Chip(text: po.running ? "■" : "▶", on: po.running) { po.toggleRun() }
                }
                Text("tasto")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.dim)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                    ForEach(1...16, id: \.self) { n in
                        GridChip(text: po.liveSteps[n - 1].contains(true) ? "\(n)•" : "\(n)", on: po.liveKey == n) { po.liveKey = n }
                    }
                }
                POStepGrid(live: po.live, pulsing: po.running,
                           label: { po.liveSteps[po.liveKey - 1][$0] ? "\(po.liveKey)" : "·" },
                           filled: { po.liveSteps[po.liveKey - 1][$0] },
                           tap: { po.liveSteps[po.liveKey - 1][$0].toggle() })
                HStack(spacing: 6) {
                    Text("premuto")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                    ForEach([(0, "tocco"), (1, "1 passo"), (2, "2 passi")], id: \.0) { l in
                        GridChip(text: l.1, on: po.holdSteps == l.0) { po.holdSteps = l.0 }
                    }
                }
                HStack(spacing: 6) {
                    Chip(text: "svuota il tasto \(po.liveKey)") { po.liveSteps[po.liveKey - 1] = Array(repeating: false, count: 16) }
                    Chip(text: "svuota tutto") { po.liveSteps = Array(repeating: Array(repeating: false, count: 16), count: 16) }
                }
            }

            Card(title: "effetti a tempo", note: "In ogni passo un effetto (fx + tasto) o niente: un effetto scritto su più passi di fila resta tenuto. Col PO che suona il suo pattern o coi passi dal vivo. «ogni 4» li fa suonare solo nell'ultima di ogni quattro battute: il riempimento.") {
                HStack {
                    Toggle("accesi", isOn: $po.fxOn)
                    Chip(text: po.running ? "■" : "▶", on: po.running) { po.toggleRun() }
                }
                LazyVGrid(columns: columns4, spacing: 6) {
                    ForEach(1...16, id: \.self) { n in
                        GridChip(text: "\(n) \(po.model.fx[n - 1])", on: po.fxPick == n) { po.fxPick = n }
                    }
                }
                POStepGrid(live: po.live, pulsing: po.running,
                           label: { po.fxSteps[$0].map { "\($0)" } ?? "·" },
                           filled: { po.fxSteps[$0] != nil },
                           tap: { i in po.fxSteps[i] = po.fxSteps[i] == po.fxPick ? nil : po.fxPick })
                HStack(spacing: 6) {
                    Text("ogni")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                    ForEach([1, 2, 4, 8], id: \.self) { e in
                        Chip(text: e == 1 ? "battuta" : "\(e)", on: po.fxEvery == e) { po.fxEvery = e }
                    }
                }
                Chip(text: "svuota") { po.fxSteps = Array(repeating: nil, count: 16) }
            }

            Card(title: "pattern a tempo", note: "Quando il PO suona il suo pattern (Ritmo: cavo dal TX-6, sync out o senza cavo). Una casella per battuta: sull'ultimo sedicesimo Bobina chiede il pattern della battuta dopo, e il giro ricomincia.") {
                Toggle("acceso", isOn: $po.songOn)
                ForEach(po.song.indices, id: \.self) { i in
                    HStack(spacing: 8) {
                        Text("battuta \(i + 1)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Palette.dim)
                            .frame(width: 80, alignment: .leading)
                        SmallKey(text: "−") { po.song[i] = max(1, po.song[i] - 1) }
                        Text("pattern \(po.song[i])")
                            .font(.system(.subheadline, design: .monospaced))
                            .frame(minWidth: 90)
                        SmallKey(text: "+") { po.song[i] = min(16, po.song[i] + 1) }
                    }
                }
                HStack(spacing: 6) {
                    Chip(text: "una battuta in più") { if po.song.count < 16 { po.song.append(po.song.last ?? 1) } }
                    Chip(text: "una in meno") { if po.song.count > 1 { po.song.removeLast() } }
                }
            }

            Card(title: "cancello", note: po.model.gateByMute
                 ? "A ogni passo spento il tonic tace: Bobina tiene i tasti 1-4, che sul tonic mutano le quattro colonne. Col PO che suona il suo pattern; coi passi dal vivo i passi spenti tacciono e basta."
                 : "A ogni passo spento il volume scende (bpm + tasto), a ogni passo acceso risale. Non è un muto vero: il volume più basso del PO si sente ancora. Coi passi dal vivo i passi spenti tacciono e basta.") {
                HStack {
                    Toggle("acceso", isOn: $po.gateOn)
                    Chip(text: po.running ? "■" : "▶", on: po.running) { po.toggleRun() }
                }
                POStepGrid(live: po.live, pulsing: po.running,
                           label: { po.gate[$0] ? "■" : "·" },
                           filled: { po.gate[$0] },
                           tap: { po.gate[$0].toggle() })
                if !po.model.gateByMute {
                    HStack(spacing: 8) {
                        Text("spento")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Palette.dim)
                        SmallKey(text: "−") { po.gateLow = max(1, po.gateLow - 1) }
                        Text("\(po.gateLow)").font(.system(.subheadline, design: .monospaced)).frame(minWidth: 28)
                        SmallKey(text: "+") { po.gateLow = min(16, po.gateLow + 1) }
                        Text("acceso")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Palette.dim)
                        SmallKey(text: "−") { po.gateHigh = max(1, po.gateHigh - 1) }
                        Text("\(po.gateHigh)").font(.system(.subheadline, design: .monospaced)).frame(minWidth: 28)
                        SmallKey(text: "+") { po.gateHigh = min(16, po.gateHigh + 1) }
                    }
                }
            }

            Card(title: "col corpo", note: "Inclina il telefono: dritto niente, a sinistra poco e tanto, a destra poco e tanto sono quattro effetti. Col ritmo acceso l'effetto entra al sedicesimo dopo.") {
                Toggle("acceso", isOn: $po.tiltOn)
                ForEach(0..<4, id: \.self) { z in
                    HStack(spacing: 8) {
                        Text(["sinistra tanto", "sinistra poco", "destra poco", "destra tanto"][z])
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Palette.dim)
                            .frame(width: 104, alignment: .leading)
                        SmallKey(text: "−") { po.tiltSet[z] = max(1, po.tiltSet[z] - 1) }
                        Text("\(po.tiltSet[z]) \(po.model.fx[po.tiltSet[z] - 1])")
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(minWidth: 110)
                        SmallKey(text: "+") { po.tiltSet[z] = min(16, po.tiltSet[z] + 1) }
                    }
                }
                if po.tiltOn { POTiltReadout(live: po.live) }
            }
        }
    }
}

/// Sedici passi. Guarda solo `live`: quando avanza il passo si ridisegnano questi quadratini.
struct POStepGrid: View {
    @ObservedObject var live: POLive
    let pulsing: Bool
    let label: (Int) -> String
    let filled: (Int) -> Bool
    let tap: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 8)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0..<16, id: \.self) { i in
                StepCell(label: label(i), filled: filled(i), current: pulsing && live.step == i) { tap(i) }
                    .accessibilityLabel("passo \(i + 1)")
            }
        }
    }
}

struct POTiltReadout: View {
    @EnvironmentObject var po: POEngine
    @ObservedObject var live: POLive

    var body: some View {
        Text(live.tiltFx.map { "effetto \($0): \(po.model.fx[$0 - 1])" } ?? "dritto: nessun effetto")
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(live.tiltFx == nil ? Palette.dim : Palette.accent)
    }
}

// MARK: - Ritmo

struct PORitmoView: View {
    @EnvironmentObject var po: POEngine

    var body: some View {
        POPage(title: "Ritmo") {
            Card(title: "come sta a tempo", note: syncNote(po.sync)) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(POSync.allCases) { m in
                        Chip(text: m.rawValue, on: po.sync == m) { po.sync = m }
                    }
                }
            }

            Card(title: "tempo", note: "È lo stesso tempo del TX-6: cambiarlo qui lo cambia anche là. Se il TX-6 suona già, il PO entra all'inizio della battuta dopo.") {
                HStack(spacing: 10) {
                    Chip(text: "−") { po.bpm = max(40, po.bpm - 1) }
                    Text("\(Int(po.bpm.rounded()))")
                        .font(.system(size: 34, weight: .medium, design: .monospaced))
                        .frame(minWidth: 80)
                    Chip(text: "+") { po.bpm = min(300, po.bpm + 1) }
                    Spacer()
                    Chip(text: "tap") { po.tap() }
                }
                .disabled(po.followingTX6)
                if po.followingTX6 {
                    Text("il tempo lo dà il TX-6 (Ritmo del TX-6: «segui il TX-6»)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.accent)
                }
                if po.sync == .ear {
                    HStack(spacing: 6) {
                        ForEach([80.0, 120.0, 140.0], id: \.self) { b in
                            Chip(text: "\(Int(b))", on: po.bpm == b) { po.bpm = b }
                        }
                    }
                }
                Chip(text: po.running ? "■ ferma il PO" : "▶ fai partire il PO", on: po.running) { po.toggleRun() }
                if po.othersRunning && !po.running {
                    Text("suona già il TX-6: il PO entrerà all'inizio della battuta")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                }
            }

            Card(title: "anticipo", note: "Col bluetooth il PO sente tutto qualche millisecondo dopo. Se suona in ritardo rispetto al TX-6 alza l'anticipo; se è in anticipo abbassalo.") {
                HStack(spacing: 10) {
                    SmallKey(text: "−") { po.leadMs = max(-100, po.leadMs - 5) }
                    Text("\(Int(po.leadMs)) ms")
                        .font(.system(.title3, design: .monospaced))
                        .frame(minWidth: 90)
                    SmallKey(text: "+") { po.leadMs = min(200, po.leadMs + 5) }
                    Spacer()
                    Chip(text: "0") { po.leadMs = 0 }
                }
            }

            if po.sync == .adapter {
                Card(title: "il clock all'adattatore", note: "Serve disable_transport = 0 nel configuratore dell'adattatore e il cavo dal suo sync out all'ingresso del PO (PO su SY2). Col clock sempre acceso l'adattatore sa il tempo prima dello start: la prima battuta non va lenta. Costa 48 messaggi al secondo sul bluetooth.") {
                    Toggle("clock sempre acceso", isOn: $po.clockAlways)
                    Text("tempi senza scivolamento: 60 · 75 · 80 · 100 · 120 · 125 · 150 · 200")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                }
            }

            Card(title: "sul PO", note: "Il PO non dice mai com'è messo: il modo di sync e il play si guardano sul display.") {
                HStack(spacing: 6) {
                    GridChip(text: "modo di sync") { po.pair(.special, .bpm) }
                    GridChip(text: "play") { po.tap(.play) }
                    GridChip(text: "tempo preset") { po.tap(.bpm) }
                }
            }
        }
    }

    private func syncNote(_ s: POSync) -> String {
        switch s {
        case .live:
            return "Il PO resta fermo e Bobina gli preme i tasti a tempo (Suona → passi dal vivo). Basta il bluetooth, vale qualunque tempo, ed è sulla stessa griglia del TX-6."
        case .tx6:
            return "Il PO suona il suo pattern. Cavo stereo dall'aux del TX-6 all'ingresso del PO. Sul TX-6: aux, shift + gira select → sync 8. Sul PO: tasto in alto + bpm fino a SY2 (non SY4 o SY5: mescolerebbe l'audio del TX-6). Bobina preme play in battere; il tempo lo dà il TX-6, cioè Bobina."
        case .adapter:
            return "Il PO suona il suo pattern. Bobina manda clock e start all'adattatore, che li trasforma in impulsi dal suo sync out. Cavo dal sync out all'ingresso del PO, PO su SY2. Ai tempi non tondi scivola piano piano."
        case .ear:
            return "Il PO suona il suo pattern col suo tempo: via MIDI solo 80, 120 o 140 (tasto bpm). Metti lo stesso tempo qui e Bobina preme play in battere. Nessun cavo, ma col passare dei minuti si allontana un poco."
        }
    }
}

// MARK: - Collega

struct POCollegaView: View {
    @EnvironmentObject var po: POEngine
    @State private var showBluetooth = false

    var body: some View {
        POPage(title: "Collega") {
            Card(title: "col bluetooth", note: "Solo l'adattatore V3 ha il bluetooth (sulla scheda: «POMA V3.x»), e va acceso nel configuratore (ble_midi_enabled = 1). Accendi l'adattatore, poi qui «cerca l'adattatore»: dovrebbe chiamarsi PO_MIDI_ADAPTER.") {
                Chip(text: "cerca l'adattatore") { showBluetooth = true }
            }

            Card(title: "col cavo", note: "Dalla micro USB dell'adattatore all'iPhone, con un cavo USB-C – micro USB: compare come «Teensy MIDI» e l'iPhone lo alimenta. Col TX-6 o il TP-7 sullo stesso USB-C serve un hub.") {
                EmptyView()
            }

            Card(title: "a chi parla Bobina", note: "Di solito sceglie da sola l'adattatore.") {
                HStack {
                    Text("manda a")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                    Spacer()
                    Picker("manda a", selection: $po.destinationID) {
                        Text("nessuno").tag(MIDIUniqueIDOrNil.none)
                        ForEach(po.destinations) { p in
                            Text(p.name).tag(MIDIUniqueIDOrNil.some(p.id))
                        }
                    }
                }
                HStack {
                    Text("ascolta")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                    Spacer()
                    Picker("ascolta", selection: $po.sourceID) {
                        Text("nessuno").tag(MIDIUniqueIDOrNil.none)
                        ForEach(po.sources) { p in
                            Text(p.name).tag(MIDIUniqueIDOrNil.some(p.id))
                        }
                    }
                }
                Button("aggiorna l'elenco") { po.refreshPorts() }
                    .font(.footnote)
            }

            Card(title: "l'adattatore", note: "Il canale è quello del configuratore (di serie 1). Le scorciatoie a CC vanno accese anche là (po_cc_control = 1): poi pattern, suono e volume partono con un messaggio solo.") {
                HStack(spacing: 10) {
                    Text("canale")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                    SmallKey(text: "−") { po.channel = max(1, po.channel - 1) }
                    Text("\(po.channel)").font(.system(.title3, design: .monospaced)).frame(minWidth: 36)
                    SmallKey(text: "+") { po.channel = min(16, po.channel + 1) }
                }
                Toggle("scorciatoie a CC", isOn: $po.useCC)
            }

            NavigationLink {
                TabelleView(sections: POTables.all, title: "Tabelle MIDI PO")
            } label: {
                HStack {
                    Text("tutte le tabelle MIDI dell'adattatore")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.card))
            }
            .buttonStyle(.plain)

            POMonitorCard()
        }
        .sheet(isPresented: $showBluetooth) {
            VStack(spacing: 0) {
                HStack {
                    Text("MIDI bluetooth").font(.headline)
                    Spacer()
                    Button("fine") {
                        showBluetooth = false
                        po.refreshPorts()
                    }
                }
                .padding()
                BluetoothMIDIPicker()
            }
        }
    }
}

struct POMonitorCard: View {
    @EnvironmentObject var po: POEngine

    var body: some View {
        Card(title: "monitor", note: "→ parte da Bobina · ← torna dall'adattatore (è solo l'eco: l'adattatore non manda niente di suo). I passi a tempo non vengono scritti, per non affollare.") {
            HStack {
                Toggle("in pausa", isOn: $po.logPaused)
                    .font(.footnote)
                Spacer()
                Button("pulisci") { po.clearLog() }
                    .font(.footnote)
            }
            VStack(alignment: .leading, spacing: 3) {
                ForEach(po.log.prefix(40)) { line in
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
                if po.log.isEmpty {
                    Text("ancora niente")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                }
            }
        }
    }
}
