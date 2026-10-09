import SwiftUI

// MARK: - le quattro schermate dei Pocket Operator

/// Le pagine comandano il PO scelto in cima (PO 1, PO 2…): qui si passa il suo motore a tutte.
struct POTabs: View {
    @EnvironmentObject var bank: POBank

    var body: some View {
        POTabsBody(po: bank.unit)
            .environmentObject(bank.unit)
    }
}

/// Tasti, Suona, Ritmo, Collega. Riapre l'ultima scheda usata. La barra in basso prende il colore del PO.
struct POTabsBody: View {
    @ObservedObject var po: POEngine
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
        .tint(po.model.color)
    }
}

/// Ogni PO ha il suo colore, lo stesso del prontuario (le versioni per lo sfondo scuro).
extension PO.Model {
    var color: Color {
        switch self {
        case .sub: return Color(red: 0.48, green: 0.59, blue: 1.0)     // blu
        case .tonic: return Color(red: 0.94, green: 0.56, blue: 0.29)  // arancio
        case .ko: return Color(red: 1.0, green: 0.44, blue: 0.40)      // rosso
        case .speak: return Color(red: 0.25, green: 0.75, blue: 0.69)  // verde acqua
        }
    }

    var tag: String {
        switch self {
        case .sub: return "basso"
        case .tonic: return "batteria"
        case .ko: return "sampler"
        case .speak: return "voce"
        }
    }
}

/// In cima a ogni scheda: quale PO stai comandando. Ognuno ha il colore del suo modello.
struct POSlotPicker: View {
    @EnvironmentObject var bank: POBank

    var body: some View {
        HStack(spacing: 6) {
            ForEach(bank.units.indices, id: \.self) { i in
                POSlotChip(unit: bank.units[i], selected: bank.current == i) { bank.current = i }
            }
        }
    }
}

struct POSlotChip: View {
    @ObservedObject var unit: POEngine
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                HStack(spacing: 4) {
                    Circle().fill(unit.connected ? Color.green : Palette.rec).frame(width: 7, height: 7)
                    Text(unit.title).font(.system(.subheadline, design: .monospaced).weight(.bold))
                    if unit.running { Text("▶").font(.caption2) }
                }
                Text(unit.model.short).font(.system(.caption2, design: .monospaced))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(RoundedRectangle(cornerRadius: 9).fill(selected ? unit.model.color : unit.model.color.opacity(0.16)))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(unit.model.color, lineWidth: selected ? 0 : 1.5))
            .foregroundStyle(selected ? Color.black : unit.model.color)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(unit.title), \(unit.model.name)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// La fascia in cima a ogni scheda: il nome del PO scelto, nel suo colore.
struct POBanner: View {
    @EnvironmentObject var po: POEngine

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(po.title)
                .font(.system(.title3, design: .monospaced).weight(.bold))
            Text(po.model.name)
                .font(.system(.title2, design: .rounded).weight(.bold))
            Text(po.model.tag)
                .font(.system(.subheadline, design: .monospaced))
                .opacity(0.75)
            Spacer()
        }
        .foregroundStyle(Color.black)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(po.model.color))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(po.title): \(po.model.name), \(po.model.tag)")
    }
}

/// Come Page, con la striscia dei PO.
struct POPage<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        #if DEBUG
        let _ = Diagnostics.shared.count("pagina po " + title)
        #endif
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    POSlotPicker()
                    POBanner()
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
    @EnvironmentObject var bank: POBank
    @State private var showBluetooth = false

    var body: some View {
        // un tocco sulla striscia apre il pannello bluetooth: dopo ogni reinstallazione gli adattatori vanno ricollegati
        Button { showBluetooth = true } label: { strip }
            .buttonStyle(.plain)
            .accessibilityLabel(po.connected ? "\(po.title) collegato, tocca per il bluetooth" : "\(po.title) non collegato, tocca per collegare")
            .sheet(isPresented: $showBluetooth) {
                VStack(spacing: 0) {
                    HStack {
                        Text("MIDI bluetooth").font(.headline)
                        Spacer()
                        Button("fine") { showBluetooth = false }
                    }
                    .padding()
                    BluetoothMIDIPicker()
                }
                .onDisappear { for u in bank.units { u.refreshPorts() } }
            }
    }

    private var strip: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(po.connected ? Color.green : Palette.rec)
                .frame(width: 8, height: 8)
            Text(po.connected ? (po.destinations.first { $0.id == po.destinationID }.map { po.portName($0) } ?? po.connectedName) : "\(po.title): non collegato · tocca qui")
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
                Button { po.model = m } label: {
                    Text(m.short)
                        .font(.system(.footnote, design: .monospaced).weight(po.model == m ? .bold : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 8).fill(po.model == m ? m.color : m.color.opacity(0.18)))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(m.color, lineWidth: 1.5))
                        .foregroundStyle(po.model == m ? Color.black : m.color)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(m.name)
                .accessibilityAddTraits(po.model == m ? .isSelected : [])
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
                POFace(flashes: po.flashes)
                HStack {
                    Chip(text: "lascia tutto", on: !po.held.isEmpty) { po.releaseAll() }
                    Chip(text: "silenzio") { po.allUp() }
                    Spacer()
                    Text(po.held.isEmpty ? "niente tenuto" : "tenuti: " + po.held.sorted { $0.note < $1.note }.map { $0.label(po.model) }.joined(separator: " "))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                }
            }

            Card(title: "cancella il pattern", note: po.model == .sub
                 ? "Un tocco: \(po.model.special) tenuto + pattern. Cancella il pattern acceso, subito e senza ritorno. Sul sub la combinazione è da confermare: guarda il display."
                 : "Un tocco: \(po.model.special) tenuto + pattern. Cancella il pattern acceso, subito e senza ritorno.") {
                Button { po.clearPattern() } label: {
                    Text("cancella il pattern")
                        .font(.system(.headline, design: .monospaced))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Palette.rec))
                        .foregroundStyle(Color.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("cancella il pattern del \(po.title)")
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
                    GridChip(text: "modo di sync") { po.slowPair(.special, .bpm) }
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
    @ObservedObject var flashes: POFlash

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0..<5, id: \.self) { r in
                ForEach(0..<5, id: \.self) { c in
                    if let k = PO.face[r][c] {
                        POKeyButton(key: k, held: po.held.contains(k), flash: k.number.map { flashes.keys.contains($0) } ?? false)
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

/// I colori dei tasti funzione, uno per tasto; i numeri restano grigi.
extension PO.Key {
    var rgb: (Double, Double, Double)? {
        switch self {
        case .sound: return (0.38, 0.58, 0.98)    // blu
        case .pattern: return (0.68, 0.48, 0.98)  // viola
        case .bpm: return (0.22, 0.76, 0.72)      // verde acqua
        case .special: return (0.95, 0.36, 0.33)  // rosso
        case .fx: return (0.97, 0.80, 0.26)       // giallo
        case .play: return (0.40, 0.82, 0.40)     // verde
        case .write: return (0.95, 0.45, 0.70)    // rosa
        default: return nil
        }
    }

    /// Il colore del tasto; `dark` = la metà «tieni», un po' più scura.
    func color(dark: Bool = false) -> Color {
        guard let (r, g, b) = rgb else { return Color(white: dark ? 0.12 : 0.24) }
        let k = dark ? 0.55 : 1
        return Color(red: r * k, green: g * k, blue: b * k)
    }
}

/// Un tasto del PO diviso in due: sopra un tocco, sotto «tieni» (resta giù finché non lo ritocchi).
/// Due tasti veri, ognuno col suo nome, così col Controllo Vocale si prende quello giusto.
/// Tenuto: la metà «tieni» diventa bianca e il tasto prende un bordo bianco.
struct POKeyButton: View {
    @EnvironmentObject var po: POEngine
    let key: PO.Key
    let held: Bool
    let flash: Bool

    var body: some View {
        let name = key.label(po.model)
        let spoken = key.isNumber ? "tasto \(name)" : name
        let colored = key.rgb != nil
        VStack(spacing: 3) {
            Button { po.touch(key) } label: {
                Text(name)
                    .font(.system(key.isNumber ? .body : .footnote, design: .monospaced).weight(colored ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(flash ? Palette.accent : key.color())
                    )
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(held ? Color.white : Palette.cardEdge, lineWidth: held ? 3 : 1))
                    .foregroundStyle(colored || flash ? Color.black : Color.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(spoken)

            Button { po.toggleHold(key) } label: {
                Text(held ? "lascia" : "tieni")
                    .font(.system(.caption2, design: .monospaced).weight(held ? .bold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(held ? Color.white : key.color(dark: true))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.cardEdge, lineWidth: 1))
                    .foregroundStyle(held ? Color.black : Color.white.opacity(0.85))
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
    @EnvironmentObject var bank: POBank

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
                Chip(text: po.running ? "■ ferma il \(po.title)" : "▶ fai partire il \(po.title)", on: po.running) { po.toggleRun() }
                if po.sync == .live && !(po.liveOn && po.liveSteps.contains { $0.contains(true) }) {
                    Text("In «Bobina lo suona» il PO resta fermo e suona solo i passi di Suona → passi dal vivo, che adesso sono spenti o vuoti. Per far partire il pattern del PO scegli un altro modo qui sopra.")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.rec)
                }
                Chip(text: bank.anyRunning ? "■ ferma tutti i PO" : "▶ tutti i PO insieme", on: bank.anyRunning) {
                    if bank.anyRunning { bank.stopAll() } else { bank.startAll() }
                }
                Text("Ogni PO ha il suo modo di stare a tempo, i suoi passi e i suoi effetti: si scelgono dai tasti PO 1, PO 2 in cima.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.dim)
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
                    GridChip(text: "modo di sync") { po.slowPair(.special, .bpm) }
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
    @EnvironmentObject var bank: POBank
    @State private var showBluetooth = false

    var body: some View {
        POPage(title: "Collega") {
            Card(title: "col bluetooth", note: "Solo l'adattatore V3 ha il bluetooth. Accendi gli adattatori, poi «cerca gli adattatori» e collegali tutti dalla lista: si chiamano tutti «PO MIDI Adapter (BLE)». Bobina li divide da sola fra PO 1, PO 2…; qui sotto «prova» ti fa sentire quale PO risponde.") {
                Chip(text: "cerca gli adattatori") { showBluetooth = true }
            }

            Card(title: "a quale adattatore parla il \(po.title)", note: "Tocca un adattatore per darlo al \(po.title). «prova» preme l'1: senti quale PO suona.") {
                if po.destinations.filter({ $0.looksLikePO }).isEmpty {
                    Text("nessun adattatore collegato")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                }
                ForEach(po.destinations.filter { $0.looksLikePO }) { p in
                    HStack(spacing: 8) {
                        GridChip(text: po.portName(p), on: po.destinationID == p.id) { po.destinationID = p.id }
                        if let other = po.user(of: p) {
                            Text("è del \(other)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Palette.dim)
                        }
                    }
                }
                HStack(spacing: 6) {
                    GridChip(text: "prova il \(po.title)") { po.identify() }
                    GridChip(text: "aggiorna l'elenco") { for u in bank.units { u.refreshPorts() } }
                }
            }

            Card(title: "quanti PO", note: "Uno per adattatore, fino a quattro. Tutti sulla stessa battuta del TX-6.") {
                HStack(spacing: 6) {
                    GridChip(text: "aggiungi un PO") { bank.add() }
                        .disabled(bank.units.count >= POBank.maxUnits)
                    GridChip(text: "togli il PO \(bank.units.count)") { bank.removeLast() }
                        .disabled(bank.units.count <= 2)
                }
            }

            Card(title: "col cavo", note: "Dalla micro USB dell'adattatore all'iPhone, con un cavo USB-C – micro USB: compare come «Teensy MIDI» e l'iPhone lo alimenta. Col TX-6 o il TP-7 sullo stesso USB-C serve un hub.") {
                EmptyView()
            }

            Card(title: "tutte le porte", note: "Per un adattatore che non si chiama come gli altri (per esempio col cavo: «Teensy MIDI»).") {
                HStack {
                    Text("manda a")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                    Spacer()
                    Picker("manda a", selection: $po.destinationID) {
                        Text("nessuno").tag(MIDIUniqueIDOrNil.none)
                        ForEach(po.destinations) { p in
                            Text(po.portName(p)).tag(MIDIUniqueIDOrNil.some(p.id))
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
                    }
                }
                .padding()
                BluetoothMIDIPicker()
            }
            .onDisappear { for u in bank.units { u.refreshPorts() } }
        }
    }
}

struct POMonitorCard: View {
    @EnvironmentObject var po: POEngine

    var body: some View {
        POMonitorLines(book: po.logBook)
    }
}

/// Le righe del monitor: guardano solo il loro quaderno, non il motore.
struct POMonitorLines: View {
    @ObservedObject var book: POLogBook

    var body: some View {
        Card(title: "monitor", note: "→ parte da Bobina · ← torna dall'adattatore (è solo l'eco: l'adattatore non manda niente di suo). I passi a tempo non vengono scritti, per non affollare.") {
            HStack {
                Toggle("in pausa", isOn: $book.paused)
                    .font(.footnote)
                Spacer()
                Button("pulisci") { book.clear() }
                    .font(.footnote)
            }
            VStack(alignment: .leading, spacing: 3) {
                ForEach(book.lines.prefix(40)) { line in
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
                if book.lines.isEmpty {
                    Text("ancora niente")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                }
            }
        }
    }
}
