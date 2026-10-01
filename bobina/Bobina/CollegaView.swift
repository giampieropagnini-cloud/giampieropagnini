import SwiftUI
import CoreAudioKit

/// Col cavo o col bluetooth, lo specchio dei tasti del TP-7 e il monitor dei messaggi.
struct CollegaView: View {
    @EnvironmentObject var engine: Engine
    @State private var showBluetooth = false
    @State private var showAdvertise = false

    var body: some View {
        Page(title: "Collega") {
            Card(title: "col cavo USB-C", note: "Collega il TP-7 acceso all'iPhone col cavo USB-C: compare da solo qui sotto. Finché resta collegato il TP-7 diventa anche la scheda audio dell'iPhone, e l'iPhone potrebbe provare a caricarlo: tieni d'occhio la batteria.") {
                EmptyView()
            }

            Card(title: "col bluetooth", note: "Sul TP-7: tieni mode → BLE → accept. Poi qui tocca «cerca il TP-7» e sceglilo dalla lista. Oppure al contrario: TP-7 su scan e qui «fatti trovare». Il bluetooth porta solo MIDI, mai audio, e iOS lo stacca se resta zitto per qualche minuto.") {
                HStack {
                    Chip(text: "cerca il TP-7") { showBluetooth = true }
                    Chip(text: "fatti trovare") { showAdvertise = true }
                }
            }

            Card(title: "a chi parla Bobina", note: "Di solito sceglie da sola il TP-7. Se hai altro collegato, scegli qui.") {
                // il menu mostra solo il nome scelto: l'etichetta va scritta accanto, se no i due «TP-7» sembrano uguali
                HStack {
                    Text("manda a").foregroundStyle(Palette.dim)
                    Spacer()
                    Picker("manda a", selection: $engine.destinationID) {
                        Text("nessuno").tag(MIDIUniqueIDOrNil.none)
                        ForEach(engine.destinations) { p in
                            Text(p.name).tag(MIDIUniqueIDOrNil.some(p.id))
                        }
                    }
                    .labelsHidden()
                }
                HStack {
                    Text("ascolta").foregroundStyle(Palette.dim)
                    Spacer()
                    Picker("ascolta", selection: $engine.sourceID) {
                        Text("nessuno").tag(MIDIUniqueIDOrNil.none)
                        ForEach(engine.sources) { p in
                            Text(p.name).tag(MIDIUniqueIDOrNil.some(p.id))
                        }
                    }
                    .labelsHidden()
                }
                Button("aggiorna l'elenco") { engine.refreshPorts() }
                    .font(.footnote)
            }

            Card(title: "come va messo il TP-7", note: "Tieni mode → MIDI. cue serve per i pad: lì play e stop si fanno con «trasporto in cue» nella scheda Nastro. sync fa andare il trasporto normale e manda il suo tempo, che Bobina segue solo col cavo; i pad non vanno. ctrl lo trasforma in controller: qui vedi i suoi tasti, ma non ascolta più niente, e resta così anche scollegato.") {
                EmptyView()
            }

            MirrorCard(live: engine.live)

            NavigationLink {
                TabelleView()
            } label: {
                HStack {
                    Text("tutte le tabelle MIDI del TP-7")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.card))
            }
            .buttonStyle(.plain)

            MonitorCard(book: engine.logBook)
        }
        .sheet(isPresented: $showBluetooth) {
            VStack(spacing: 0) {
                HStack {
                    Text("MIDI bluetooth").font(.headline)
                    Spacer()
                    Button("fine") {
                        showBluetooth = false
                        engine.refreshPorts()
                    }
                }
                .padding()
                BluetoothMIDIPicker()
            }
        }
        .sheet(isPresented: $showAdvertise) {
            VStack(spacing: 0) {
                HStack {
                    Text("fatti trovare").font(.headline)
                    Spacer()
                    Button("fine") {
                        showAdvertise = false
                        engine.refreshPorts()
                    }
                }
                .padding()
                BluetoothMIDIAdvertiser()
            }
        }
    }
}

typealias MIDIUniqueIDOrNil = Optional<Int32>

/// Il pannello di sistema di iOS che cerca e collega i dispositivi MIDI bluetooth.
struct BluetoothMIDIPicker: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController {
        UINavigationController(rootViewController: CABTMIDICentralViewController())
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}
}

/// Il pannello di sistema che fa comparire l'iPhone come dispositivo MIDI bluetooth (per il TP-7 su scan).
struct BluetoothMIDIAdvertiser: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController {
        UINavigationController(rootViewController: CABTMIDILocalPeripheralViewController())
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}
}

/// In modalità ctrl il TP-7 manda i suoi tasti: qui si accendono.
struct MirrorCard: View {
    @EnvironmentObject var engine: Engine
    @ObservedObject var live: Live

    private let order: [UInt8] = [22, 23, 24, 25, 26, 27, 20, 21, 28]

    var body: some View {
        Card(title: "specchio", note: "Con il TP-7 su MIDI → ctrl, i suoi tasti si accendono qui e la bobina conta i passi.") {
            HStack(spacing: 5) {
                ForEach(order, id: \.self) { cc in
                    Text(TP7.buttonNames[cc].map { String($0.prefix(2)).trimmingCharacters(in: .whitespaces) } ?? "?")
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(RoundedRectangle(cornerRadius: 6).fill(live.pressed.contains(cc) ? Palette.accent : Color(white: 0.18)))
                        .foregroundStyle(live.pressed.contains(cc) ? Color.black : Color.white)
                }
            }
            HStack {
                Text("bobina \(live.wheelSteps > 0 ? "+" : "")\(live.wheelSteps)")
                Spacer()
                Text("leva \(live.rocker)")
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Palette.dim)
            if let c = engine.clockBPM {
                Text(String(format: "arriva un clock: %.1f bpm", c))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.accent)
            }
        }
    }
}

struct MonitorCard: View {
    @EnvironmentObject var engine: Engine
    @ObservedObject var book: LogBook

    var body: some View {
        Card(title: "monitor", note: "← arriva dal TP-7 · → parte da Bobina. Gli effetti continui non vengono scritti, per non affollare.") {
            HStack {
                Toggle("in pausa", isOn: $engine.logPaused)
                    .font(.footnote)
                Spacer()
                Button("pulisci") { engine.clearLog() }
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
