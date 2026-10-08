import SwiftUI
import CoreMIDI

// MARK: - Ritmo

/// Ritmo: in cima il tempo (chi lo dà, bpm, suona/ferma) e il trasporto del TX-6; sotto una parte alla volta:
/// pompa, cancello, onde, deriva, col corpo.
struct TX6RitmoView: View {
    @EnvironmentObject var tx: TX6Engine
    @AppStorage("bobina.tx6.ritmo.parte") private var part = 0

    static let parts = ["pompa", "cancello", "onde", "deriva", "corpo"]

    var body: some View {
        TX6Screen(title: "Ritmo") {
            TX6Box {
                HStack(spacing: 4) {
                    ForEach(TX6ClockMode.allCases) { m in
                        TX6Mini(text: m == .send ? "dà il tempo al TX-6" : m.rawValue, on: tx.clockMode == m, height: 38) { tx.clockMode = m }
                            .accessibilityLabel(m.rawValue)
                    }
                }
                TX6TempoTop(crea: false, tap: true)
                if tx.clockMode != .follow, let c = tx.clockBPM {
                    TX6Mini(text: String(format: "arriva un clock dal TX-6: %.1f bpm · seguilo", c)) { tx.clockMode = .follow }
                }
                HStack(spacing: 4) {
                    Text("TX-6")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                    TX6Mini(text: "▶■") { tx.startStopTX6() }
                        .accessibilityLabel("start stop del TX-6")
                    ForEach([-5, -1, 1, 5], id: \.self) { d in
                        TX6Mini(text: d > 0 ? "+\(d)" : "−\(-d)") { tx.nudgeTempo(d) }
                            .accessibilityLabel("tempo del TX-6 \(d > 0 ? "più" : "meno") \(abs(d))")
                    }
                }
            }
            TX6Parts(items: Self.parts, selection: $part)
            switch part {
            case 1: TX6GatePanel(live: tx.live)
            case 2: TX6WavesPanel()
            case 3: TX6DriftPanel()
            case 4: TX6TiltPanel()
            default: TX6PumpPanel()
            }
        }
    }
}

/// Un interruttore come tasto: «acceso»/«spento».
private struct TX6Switch: View {
    let name: String
    let on: Bool
    let toggle: () -> Void

    var body: some View {
        TX6Mini(text: "\(name) \(on ? "accesa" : "spenta")", on: on, height: 40, action: toggle)
            .accessibilityLabel(on ? "spegni \(name)" : "accendi \(name)")
    }
}

/// Il sidechain che il TX-6 non ha: a ogni quarto il volume delle tracce scelte cala e risale.
struct TX6PumpPanel: View {
    @EnvironmentObject var tx: TX6Engine

    var body: some View {
        TX6Box {
            TX6Switch(name: "pompa", on: tx.pumpOn) { tx.pumpOn.toggle() }
            TX6KnobRow(name: "quanto", value: Int(tx.pumpDepth * 127), shown: "\(Int(tx.pumpDepth * 100))%") { tx.pumpDepth = Double($0) / 127 }
            TX6KnobRow(name: "risalita", value: Int(tx.pumpRelease * 127), shown: "\(Int(tx.pumpRelease * 100))%") { tx.pumpRelease = max(0.1, Double($0) / 127) }
            TX6TrackSet(tracks: $tx.pumpTracks)
            TX6Label("A ogni quarto il volume delle tracce scelte cala e risale. Gira col tempo di sopra.")
        }
    }
}

/// A ogni passo spento le tracce scelte vanno in muto: il transformer.
struct TX6GatePanel: View {
    @EnvironmentObject var tx: TX6Engine
    @ObservedObject var live: TX6Live

    var body: some View {
        TX6Box {
            HStack(spacing: 4) {
                TX6Mini(text: tx.gateOn ? "cancello acceso" : "cancello spento", on: tx.gateOn, height: 40) { tx.gateOn.toggle() }
                    .accessibilityLabel(tx.gateOn ? "spegni il cancello" : "accendi il cancello")
                TX6Mini(text: "tutti aperti", height: 40) { tx.gate = Array(repeating: true, count: 16) }
                    .accessibilityLabel("rimetti tutti i passi aperti")
            }
            TX6StepGrid(live: live, pulsing: tx.pulsing,
                        label: { tx.gate[$0] ? "■" : "·" },
                        filled: { tx.gate[$0] },
                        tap: { tx.gate[$0].toggle() })
            TX6TrackSet(tracks: $tx.gateTracks)
            TX6Label("■ suona, · tace. Gira col tempo di sopra.")
        }
    }
}

/// Le due onde: muovono un parametro intorno al valore che hai messo, a tempo (il TX-6 non ha LFO).
struct TX6WavesPanel: View {
    @EnvironmentObject var tx: TX6Engine
    @AppStorage("bobina.tx6.ritmo.onda") private var index = 0

    private let lengths: [(String, Double)] = [("1/8", 0.5), ("1/4", 1), ("1/2", 2), ("1", 4), ("2", 8), ("4", 16), ("8", 32)]
    private let five = Array(repeating: GridItem(.flexible(), spacing: 4), count: 5)

    var body: some View {
        let i = min(1, max(0, index))
        let w = tx.waves[i]
        TX6Box {
            HStack(spacing: 4) {
                TX6Mini(text: "onda 1", on: i == 0, color: Color(white: 0.75), height: 38) { index = 0 }
                TX6Mini(text: "onda 2", on: i == 1, color: Color(white: 0.75), height: 38) { index = 1 }
                TX6Switch(name: "onda \(i + 1)", on: w.on) { tx.waves[i].on.toggle() }
            }
            LazyVGrid(columns: five, spacing: 4) {
                ForEach(TX6.Param.movable) { p in
                    TX6Mini(text: p.name, on: w.param == p, color: Color(white: 0.75)) { tx.waves[i].param = p }
                        .accessibilityLabel("muove \(p.name)")
                }
            }
            HStack(spacing: 4) {
                ForEach(TX6Wave.Shape.allCases) { s in
                    TX6Mini(text: s.rawValue, on: w.shape == s) { tx.waves[i].shape = s }
                        .accessibilityLabel("forma \(s.rawValue)")
                }
            }
            HStack(spacing: 4) {
                Text("giro")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.dim)
                ForEach(lengths, id: \.0) { l in
                    TX6Mini(text: l.0, on: w.beats == l.1) { tx.waves[i].beats = l.1 }
                        .accessibilityLabel("un giro ogni \(l.0)")
                }
            }
            TX6KnobRow(name: "quanto", value: Int(w.depth * 2), shown: "±\(Int(w.depth))") { tx.waves[i].depth = min(63, max(2, Double($0) / 2)) }
            TX6TrackSet(tracks: $tx.waves[i].tracks)
        }
    }
}

/// I volumi delle tracce scelte vagano piano, ognuno per conto suo.
struct TX6DriftPanel: View {
    @EnvironmentObject var tx: TX6Engine

    var body: some View {
        TX6Box {
            HStack(spacing: 4) {
                TX6Switch(name: "deriva", on: tx.driftOn) { tx.driftOn.toggle() }
                TX6Mini(text: tx.driftPan ? "anche il pan" : "solo volumi", on: tx.driftPan, height: 40) { tx.driftPan.toggle() }
                    .accessibilityLabel(tx.driftPan ? "deriva senza pan" : "deriva anche il pan")
            }
            TX6KnobRow(name: "quanto", value: Int(tx.driftAmount * 127), shown: "\(Int(tx.driftAmount * 100))%") { tx.driftAmount = max(0.1, Double($0) / 127) }
            TX6TrackSet(tracks: $tx.driftTracks)
            TX6Label("Col pan acceso vagano anche fra destra e sinistra.")
        }
    }
}

/// Inclinando il telefono: a destra apre, a sinistra chiude.
struct TX6TiltPanel: View {
    @EnvironmentObject var tx: TX6Engine

    private let five = Array(repeating: GridItem(.flexible(), spacing: 4), count: 5)

    var body: some View {
        TX6Box {
            HStack(spacing: 4) {
                TX6Switch(name: "col corpo", on: tx.tiltOn) { tx.tiltOn.toggle() }
                if tx.tiltOn { TX6TiltReadout(side: tx.side) }
            }
            LazyVGrid(columns: five, spacing: 4) {
                ForEach(TX6.Param.movable) { p in
                    TX6Mini(text: p.name, on: tx.tiltParam == p, color: Color(white: 0.75)) { tx.tiltParam = p }
                        .accessibilityLabel("muove \(p.name)")
                }
            }
            TX6TrackSet(tracks: $tx.tiltTracks)
            TX6Label("Inclina il telefono: a destra apre, a sinistra chiude.")
        }
    }
}

// MARK: - Collega

/// Collega: collegare il TX-6, lo specchio di quello che manda, il monitor e la prova dei comandi.
struct TX6CollegaView: View {
    @EnvironmentObject var tx: TX6Engine
    @AppStorage("bobina.tx6.collega.parte") private var part = 0
    @State private var showBluetooth = false

    static let parts = ["collega", "specchio", "monitor", "prova"]

    var body: some View {
        TX6Screen(title: "Collega") {
            TX6Parts(items: Self.parts, selection: $part)
            switch part {
            case 1: TX6MirrorPanel(side: tx.side)
            case 2: TX6MonitorPanel()
            case 3: TX6ProbePanel()
            default: TX6ConnectPanel(showBluetooth: $showBluetooth)
            }
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

struct TX6ConnectPanel: View {
    @EnvironmentObject var tx: TX6Engine
    @Binding var showBluetooth: Bool

    private let two = Array(repeating: GridItem(.flexible(), spacing: 4), count: 2)

    var body: some View {
        TX6Box {
            TX6Mini(text: "cerca il TX-6 col bluetooth", height: 46) { showBluetooth = true }
            TX6Label("Col cavo USB-C compare da solo. Col bluetooth: sul TX-6 shift + select → BLE → ACCEPT, poi «cerca».")
            TX6Label("manda a")
            LazyVGrid(columns: two, spacing: 4) {
                TX6Mini(text: "nessuno", on: tx.destinationID == nil) { tx.destinationID = nil }
                    .accessibilityLabel("non mandare a nessuno")
                ForEach(tx.destinations) { p in
                    TX6Mini(text: p.name, on: tx.destinationID == p.id) { tx.destinationID = p.id }
                        .accessibilityLabel("manda a \(p.name)")
                }
            }
            TX6Label("ascolta")
            LazyVGrid(columns: two, spacing: 4) {
                TX6Mini(text: "nessuno", on: tx.sourceID == nil) { tx.sourceID = nil }
                    .accessibilityLabel("non ascoltare nessuno")
                ForEach(tx.sources) { p in
                    TX6Mini(text: p.name, on: tx.sourceID == p.id) { tx.sourceID = p.id }
                        .accessibilityLabel("ascolta \(p.name)")
                }
            }
            TX6Mini(text: "aggiorna l'elenco") { tx.refreshPorts() }
        }
        TX6Box(title: "come va messo il TX-6 (shift + select)") {
            Text("MIDI → CTRL IN e NOTE on · SYNTH → play · CLOCK → OUT off, se Bobina non deve seguirlo · GND acceso se non vuoi che l'iPhone lo carichi")
                .font(.system(.caption, design: .monospaced))
                .fixedSize(horizontal: false, vertical: true)
        }
        TX6Box {
            TX6Mini(text: tx.bridgeOn ? "il TX-6 comanda il TP-7: acceso" : "il TX-6 comanda il TP-7: spento", on: tx.bridgeOn, height: 40) { tx.bridgeOn.toggle() }
            TX6Label("TX-6 su CTRL OUT col cavo: fader = volumi del TP-7, tasti traccia = muti, FX I = play/stop.")
            NavigationLink {
                TabelleView(sections: TX6Tables.all, title: "Tabelle MIDI TX-6")
            } label: {
                Text("tutte le tabelle MIDI del TX-6 ›")
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color(white: 0.18)))
                    .foregroundStyle(Color.white)
            }
            .buttonStyle(.plain)
        }
    }
}

/// In CTRL OUT il TX-6 manda fader, manopole e tasti: qui si vedono.
struct TX6MirrorPanel: View {
    @EnvironmentObject var tx: TX6Engine
    @ObservedObject var side: TX6Side

    private func cell(_ v: Int?) -> some View {
        Text(v.map { "\($0)" } ?? "·")
            .font(.system(.caption, design: .monospaced))
            .frame(maxWidth: .infinity, minHeight: 28)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color(white: 0.18)))
    }

    var body: some View {
        TX6Box {
            TX6Label("Con il TX-6 su CTRL OUT: i numeri che mandano manopole e fader.")
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 4) {
                    Text(["blu", "aran", "bian"][r])
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                        .frame(width: 34, alignment: .leading)
                    ForEach(0..<6, id: \.self) { t in cell(side.knobs[r][t]) }
                }
            }
            HStack(spacing: 4) {
                Text("fader")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Palette.dim)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(width: 34, alignment: .leading)
                ForEach(0..<6, id: \.self) { t in cell(side.faders[t]) }
            }
            HStack(spacing: 4) {
                ForEach(["tasto traccia 1", "tasto traccia 2", "tasto traccia 3", "tasto traccia 4", "tasto traccia 5", "tasto traccia 6", "select premuto", "FX I", "FX II", "shift", "aux", "cue"], id: \.self) { name in
                    Text(name.hasPrefix("tasto") ? String(name.suffix(1)) : name == "select premuto" ? "sel" : name)
                        .font(.system(size: 10, design: .monospaced))
                        .frame(maxWidth: .infinity, minHeight: 28)
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
        .accessibilityElement(children: .combine)
    }
}

struct TX6MonitorPanel: View {
    @EnvironmentObject var tx: TX6Engine

    var body: some View {
        TX6Box {
            HStack(spacing: 4) {
                TX6Mini(text: tx.logPaused ? "in pausa" : "pausa", on: tx.logPaused) { tx.logPaused.toggle() }
                    .accessibilityLabel(tx.logPaused ? "riprendi il monitor" : "metti in pausa il monitor")
                TX6Mini(text: "pulisci") { tx.clearLog() }
            }
            TX6Label("← arriva dal TX-6 · → parte da Bobina. Onde, pompa e deriva non vengono scritte.")
            VStack(alignment: .leading, spacing: 3) {
                ForEach(tx.log.prefix(26)) { line in
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
            .accessibilityElement(children: .combine)
        }
    }
}

/// Prova dei comandi: ogni tasto manda un solo numero (cc) alla traccia 1, e il display del TX-6 salta
/// sulla pagina di quello che ha capito. Serve a controllare la tabella ufficiale sulla macchina vera.
struct TX6ProbePanel: View {
    @EnvironmentObject var tx: TX6Engine

    static let probes: [(name: String, cc: UInt8, value: Int)] = [
        ("volume", 7, 32), ("pan", 8, 32), ("guadagno", 9, 32), ("filtro", 74, 32),
        ("EQ alti", 85, 32), ("EQ medi", 86, 32), ("EQ bassi", 87, 32), ("compressore", 93, 32),
        ("FX I", 91, 32), ("aux", 92, 32), ("aux II", 94, 32), ("muto", 120, 127), ("togli muto", 120, 0)
    ]
    private let two = Array(repeating: GridItem(.flexible(), spacing: 4), count: 2)

    var body: some View {
        TX6Box {
            TX6Label("Un comando alla volta sulla traccia 1: il display del TX-6 salta sulla pagina che ha capito. Il filtro è da provare.")
            LazyVGrid(columns: two, spacing: 4) {
                ForEach(Array(Self.probes.enumerated()), id: \.offset) { i, p in
                    // il guadagno si prova col valore che ha già: la prova non deve alzarlo
                    TX6Mini(text: "\(i + 1) · \(p.name) · cc \(p.cc)", height: 38) { tx.probe(p.cc, p.cc == 9 ? tx.value(1, .gain) : p.value) }
                }
            }
            TX6Mini(text: "rimetti a posto la traccia 1", height: 40) { tx.restoreTrack1() }
        }
    }
}
