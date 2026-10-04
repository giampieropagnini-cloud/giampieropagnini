import SwiftUI

// MARK: - le due schermate dell'M8

/// Tasti e Collega. Riapre l'ultima scheda usata. La barra in basso è viola come le frecce dell'M8.
struct M8Tabs: View {
    @AppStorage("bobina.m8.scheda") private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            M8TastiView()
                .tabItem { Label("Tasti", systemImage: "dpad.fill") }.tag(0)
            M8CollegaView()
                .tabItem { Label("Collega", systemImage: "cable.connector") }.tag(1)
        }
        .tint(M8.color)
    }
}

/// Come Page, col nome dell'M8 nel suo colore e la striscia del collegamento.
struct M8Page<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    M8Banner()
                    M8StatusStrip()
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

struct M8Banner: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("M8")
                .font(.system(.title2, design: .rounded).weight(.bold))
            Text("Dirtywave · telecomando")
                .font(.system(.subheadline, design: .monospaced))
                .opacity(0.75)
            Spacer()
        }
        .foregroundStyle(Color.black)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(M8.color))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("M8, telecomando")
    }
}

struct M8StatusStrip: View {
    @EnvironmentObject var m8: M8Engine

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(m8.connected ? Color.green : Palette.rec)
                .frame(width: 8, height: 8)
            Text(m8.connected ? "collegato a \(m8.connectedName) · canale \(m8.channel)" : "M8 non collegato · vai su Collega")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
                .lineLimit(1)
            Spacer()
        }
        .padding(.top, 6)
    }
}

// MARK: - Tasti

struct M8TastiView: View {
    @EnvironmentObject var m8: M8Engine

    var body: some View {
        M8Page(title: "Tasti") {
            M8Face()
                .padding(.top, 4)

            if !m8.held.isEmpty {
                Button { m8.releaseAll() } label: {
                    Text("lascia tutto")
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                        .foregroundStyle(Color.black)
                }
                .buttonStyle(.plain)
            }

            Card(title: "manopola", note: "Manda il CC \(m8.knobCC) sul canale \(m8.channel). Sull'M8 assegnalo a quello che vuoi (es. cue vol) in Project > MIDI Mapping.") {
                StepSlider(name: "cue vol", value: m8.knob) { m8.setKnob($0) }
            }
        }
    }
}

/// La faccia dell'M8: quattro colonne come sulla macchina.
struct M8Face: View {
    @EnvironmentObject var m8: M8Engine

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<M8.face.count, id: \.self) { r in
                ForEach(0..<4, id: \.self) { c in
                    if let k = M8.face[r][c] {
                        M8KeyButton(key: k, held: m8.held.contains(k))
                    } else {
                        Color.clear.frame(minHeight: 90).accessibilityHidden(true)
                    }
                }
            }
        }
    }
}

/// I colori dei tasti: le frecce viola come sull'M8, gli altri ognuno il suo.
extension M8.Key {
    var rgb: (Double, Double, Double) {
        switch self {
        case .left, .right, .up, .down: return (0.62, 0.45, 0.98)  // viola
        case .option: return (0.98, 0.86, 0.22)                   // giallo
        case .shift: return (0.98, 0.62, 0.20)                    // arancio
        case .edit: return (0.62, 0.66, 0.74)                     // grigio
        case .play: return (0.40, 0.82, 0.40)                     // verde
        }
    }

    /// `dark` = la metà «tieni», più scura.
    func color(dark: Bool = false) -> Color {
        let (r, g, b) = rgb
        let k = dark ? 0.55 : 1
        return Color(red: r * k, green: g * k, blue: b * k)
    }
}

/// Un tasto diviso in due: sopra un tocco, sotto «tieni» (resta giù finché non lo ritocchi).
/// Due tasti veri, ognuno col suo nome, per il Controllo Vocale.
struct M8KeyButton: View {
    @EnvironmentObject var m8: M8Engine
    let key: M8.Key
    let held: Bool

    var body: some View {
        VStack(spacing: 3) {
            Button { m8.touch(key) } label: {
                Group {
                    if let s = key.symbol {
                        Image(systemName: s).font(.title3)
                    } else {
                        Text(key.label)
                            .font(.system(.footnote, design: .monospaced).weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(RoundedRectangle(cornerRadius: 9).fill(key.color()))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(held ? Color.white : Palette.cardEdge, lineWidth: held ? 3 : 1))
                .foregroundStyle(Color.black)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(key.spoken)

            Button { m8.toggleHold(key) } label: {
                Text(held ? "lascia" : "tieni")
                    .font(.system(.caption2, design: .monospaced).weight(held ? .bold : .regular))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(RoundedRectangle(cornerRadius: 8).fill(held ? Color.white : key.color(dark: true)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.cardEdge, lineWidth: 1))
                    .foregroundStyle(held ? Color.black : Color.white.opacity(0.9))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(held ? "lascia \(key.spoken)" : "tieni \(key.spoken)")
            .accessibilityAddTraits(held ? .isSelected : [])
        }
    }
}

// MARK: - Collega

struct M8CollegaView: View {
    @EnvironmentObject var m8: M8Engine
    @State private var showBluetooth = false

    var body: some View {
        M8Page(title: "Collega") {
            Card(title: "col cavo", note: "Dalla USB-C dell'M8 all'iPhone: l'M8 è MIDI USB di serie e compare da solo. Col TX-6 o il TP-7 sullo stesso USB-C serve un hub.") {
                EmptyView()
            }

            Card(title: "a chi parla", note: "Tocca la porta dell'M8. Bobina sceglie da sola quella che si chiama «M8».") {
                if m8.destinations.isEmpty {
                    Text("nessuna porta MIDI")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                }
                ForEach(m8.destinations) { p in
                    GridChip(text: p.name, on: m8.destinationID == p.id) { m8.destinationID = p.id }
                }
                HStack(spacing: 6) {
                    GridChip(text: "prova: freccia giù") { m8.tap(.down) }
                    GridChip(text: "aggiorna l'elenco") { m8.refreshPorts() }
                }
            }

            Card(title: "col bluetooth", note: "L'M8 non ha il bluetooth: serve un adattatore MIDI bluetooth sulla sua presa MIDI IN.") {
                Chip(text: "cerca i dispositivi bluetooth") { showBluetooth = true }
            }

            Card(title: "canali", note: "Il canale deve essere quello di CONTROL MAP CHAN sull'M8 (Project > MIDI > Settings, di serie 10).") {
                HStack(spacing: 10) {
                    Text("canale")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                        .frame(width: 80, alignment: .leading)
                    SmallKey(text: "−") { m8.channel = max(1, m8.channel - 1) }
                    Text("\(m8.channel)").font(.system(.title3, design: .monospaced)).frame(minWidth: 36)
                    SmallKey(text: "+") { m8.channel = min(16, m8.channel + 1) }
                }
                HStack(spacing: 10) {
                    Text("CC manopola")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                        .frame(width: 80, alignment: .leading)
                    SmallKey(text: "−") { m8.knobCC = max(0, m8.knobCC - 1) }
                    Text("\(m8.knobCC)").font(.system(.title3, design: .monospaced)).frame(minWidth: 36)
                    SmallKey(text: "+") { m8.knobCC = min(127, m8.knobCC + 1) }
                }
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
            .onDisappear { m8.refreshPorts() }
        }
    }
}
