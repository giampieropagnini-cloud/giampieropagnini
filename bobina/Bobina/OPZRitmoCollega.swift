import SwiftUI
import CoreMIDI

// MARK: - Ritmo in uno schermo (8/10/2026, come Crea, Live e Suona)

struct OPZRitmoView: View {
    @EnvironmentObject var opz: OPZEngine
    private let six = Array(repeating: GridItem(.flexible(), spacing: 4), count: 6)

    var body: some View {
        OPZPage(title: "Ritmo", compact: true) {
            OPZLiveTop()
            OPZPanel {
                OPZLabel("come sta a tempo")
                HStack(spacing: 5) {
                    OPZChip(text: "Bobina dà il clock", on: opz.sync == .clock, height: 44) { opz.sync = .clock }
                    OPZChip(text: "l'OP-Z va da solo", on: opz.sync == .own, height: 44) { opz.sync = .own }
                }
                OPZLabel(opz.sync == .clock ? "stessa battuta di TX-6, PO e M8 · sull'OP-Z il tasto 4 acceso" : "il suo orologio: tempo da 40 a 127, con le altre macchine scivola")

                OPZLabel("tempo di tutta Bobina")
                HStack(spacing: 5) {
                    SmallKey(text: "−1") { opz.setBPM(opz.bpm - 1) }.accessibilityLabel("tempo meno 1")
                    Text("\(Int(opz.bpm.rounded()))")
                        .font(.system(.title2, design: .monospaced).weight(.bold))
                        .frame(minWidth: 60)
                    SmallKey(text: "+1") { opz.setBPM(opz.bpm + 1) }.accessibilityLabel("tempo più 1")
                    OPZChip(text: "tap", height: 40) { opz.tap() }
                        .accessibilityLabel("batti il tempo")
                }
                .disabled(opz.followingTX6)
                LazyVGrid(columns: six, spacing: 4) {
                    ForEach([66.0, 76.0, 84.0, 90.0, 110.0, 120.0], id: \.self) { b in
                        OPZChip(text: "\(Int(b))", on: Int(opz.bpm.rounded()) == Int(b), height: 38) { opz.setBPM(b) }
                            .accessibilityLabel("\(Int(b)) bpm")
                    }
                }
                .disabled(opz.followingTX6)
                if opz.followingTX6 {
                    OPZLabel("il tempo lo dà il TX-6 (Ritmo del TX-6: «segui il TX-6»)")
                }
                if opz.sync == .own && opz.bpm > OPZ.tempoRange.upperBound {
                    Text("da solo l'OP-Z arriva a 127: per andare più veloce «Bobina dà il clock»")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.rec)
                }

                HStack(spacing: 5) {
                    OPZLabel("swing")
                    SmallKey(text: "−") { opz.setSwing(opz.swing - 4) }.accessibilityLabel("swing meno")
                    Text("\(opz.swing)").font(.system(.body, design: .monospaced).weight(.bold)).frame(minWidth: 36)
                    SmallKey(text: "+") { opz.setSwing(opz.swing + 4) }.accessibilityLabel("swing più")
                    OPZChip(text: "niente", on: opz.swing == 64, height: 34) { opz.setSwing(64) }
                        .accessibilityLabel("niente swing")
                }
                HStack(spacing: 5) {
                    OPZLabel("anticipo")
                    SmallKey(text: "−") { opz.leadMs = max(-100, opz.leadMs - 5) }.accessibilityLabel("anticipo meno")
                    Text("\(Int(opz.leadMs)) ms").font(.system(.body, design: .monospaced).weight(.bold)).frame(minWidth: 62)
                    SmallKey(text: "+") { opz.leadMs = min(200, opz.leadMs + 5) }.accessibilityLabel("anticipo più")
                    OPZChip(text: "0", on: opz.leadMs == 0, height: 34) { opz.leadMs = 0 }
                        .accessibilityLabel("anticipo zero")
                }
                OPZLabel("anticipo: se l'OP-Z suona in ritardo rispetto alle altre macchine, alzalo")
                HStack(spacing: 5) {
                    if opz.sync == .clock {
                        OPZChip(text: opz.clockAlways ? "clock sempre: sì" : "clock sempre: no", on: opz.clockAlways, height: 38) { opz.clockAlways.toggle() }
                            .accessibilityLabel("clock sempre acceso")
                    }
                    OPZChip(text: "manda stop", height: 38) { opz.forceStop() }
                        .accessibilityLabel("manda stop all'OP-Z")
                }
            }
        }
    }
}

// MARK: - Collega in uno schermo: collega · impostazioni · monitor

enum OPZCollegaPart: String, CaseIterable, Identifiable {
    case connect, settings, monitor

    var id: String { rawValue }

    var label: String {
        switch self {
        case .connect: return "collega"
        case .settings: return "impostazioni"
        case .monitor: return "monitor"
        }
    }
}

struct OPZCollegaView: View {
    @EnvironmentObject var opz: OPZEngine
    @AppStorage("bobina.opz.collega.parte") private var part = OPZCollegaPart.connect.rawValue
    @State private var showBluetooth = false

    var body: some View {
        let current = OPZCollegaPart(rawValue: part) ?? .connect
        OPZPage(title: "Collega", compact: true) {
            HStack(spacing: 5) {
                ForEach(OPZCollegaPart.allCases) { p in
                    OPZChip(text: p.label, on: p == current, height: 40) { part = p.rawValue }
                        .accessibilityLabel("parte \(p.label)")
                }
            }
            switch current {
            case .connect:
                OPZPanel {
                    Button { showBluetooth = true } label: {
                        Text("cerca l'OP-Z (bluetooth)")
                            .font(.system(.title3, design: .monospaced).weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(RoundedRectangle(cornerRadius: 10).fill(OPZ.tint))
                            .foregroundStyle(Color.black)
                    }
                    .buttonStyle(.plain)
                    OPZLabel("la prima volta: Ele tiene il tasto di pairing sotto l'OP-Z finché la luce lampeggia blu · l'app ufficiale OP-Z va chiusa")
                    HStack {
                        OPZLabel("manda a")
                        Spacer()
                        Picker("manda a", selection: $opz.destinationID) {
                            Text("nessuno").tag(MIDIUniqueIDOrNil.none)
                            ForEach(opz.destinations) { p in
                                Text(p.name).tag(MIDIUniqueIDOrNil.some(p.id))
                            }
                        }
                    }
                    HStack {
                        OPZLabel("ascolta")
                        Spacer()
                        Picker("ascolta", selection: $opz.sourceID) {
                            Text("nessuno").tag(MIDIUniqueIDOrNil.none)
                            ForEach(opz.sources) { p in
                                Text(p.name).tag(MIDIUniqueIDOrNil.some(p.id))
                            }
                        }
                    }
                    OPZChip(text: "aggiorna l'elenco", height: 40) { opz.refreshPorts() }
                    OPZLabel("col cavo USB-C il clock è perfetto · SCREEN + il tasto bianco più a destra spegne la ricarica dall'iPhone")
                }
            case .settings:
                OPZPanel {
                    OPZLabel("una volta sola, sull'OP-Z: tieni TEMPO + SCREEN e premi i tasti 1-8 (acceso = luce accesa)")
                    ForEach(OPZCollegaView.settings, id: \.0) { s in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(s.0)
                                .font(.system(.body, design: .monospaced).weight(.bold))
                                .foregroundStyle(OPZ.tint)
                                .frame(width: 22)
                            Text(s.1)
                                .font(.system(.footnote, design: .monospaced))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    OPZLabel("metronomo: tieni TEMPO e gira la manopola rossa tutta a sinistra · tempo che non cambia: TEMPO + SHIFT lo sblocca · dopo «scrivi»: REC toglie il record lock")
                }
            case .monitor:
                OPZMonitorLines(book: opz.logBook)
            }
        }
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
            .onDisappear { opz.refreshPorts() }
        }
    }

    static let settings: [(String, String)] = [
        ("1", "SPENTO · channel one to active"),
        ("2", "acceso · incoming midi"),
        ("3", "acceso · outgoing midi"),
        ("4", "ACCESO · midi clock in: senza, va a un altro tempo"),
        ("5", "spento · midi clock out"),
        ("6", "spento · alt program change"),
        ("7", "SPENTO · midi echo"),
        ("8", "acceso · enable program change"),
    ]
}
