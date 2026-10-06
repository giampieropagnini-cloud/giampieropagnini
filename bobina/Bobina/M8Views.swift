import SwiftUI

// MARK: - le due schermate dell'M8

/// Tasti e Collega. Riapre l'ultima scheda usata. La barra in basso è viola come le frecce dell'M8.
struct M8Tabs: View {
    @AppStorage("bobina.m8.scheda") private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            M8TastiView()
                .tabItem { Label("Tasti", systemImage: "dpad.fill") }.tag(0)
            M8SuonaView()
                .tabItem { Label("Suona", systemImage: "pianokeys") }.tag(2)
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
        M8MicLine(mic: m8.mic)
    }
}

/// Una riga sotto la striscia: quale microfono sente l'iPhone. Rossa se è quello dell'M8.
struct M8MicLine: View {
    @ObservedObject var mic: M8Mic

    var body: some View {
        if mic.usbPresent {
            Text(mic.onM8 ? "microfono: \(mic.inputName) · il Controllo Vocale non ti sente" : "microfono: \(mic.inputName) · il Controllo Vocale ti sente")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(mic.onM8 ? Palette.rec : Palette.dim)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct M8MicCard: View {
    @ObservedObject var mic: M8Mic

    var body: some View {
        Card(title: "microfono", note: "L'M8 col cavo è anche una scheda audio, e l'iPhone prenderebbe il suo ingresso come microfono. Acceso: Bobina usa un microfono USB se c'è (es. il CM-15 sull'hub), se no quello dell'iPhone. L'M8 e i suoi ingressi non cambiano.") {
            Toggle("non usare l'M8 come microfono", isOn: $mic.enabled)
            Text("adesso: \(mic.inputName)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
            if let p = mic.problem {
                Text(p)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.rec)
            }
            Chip(text: "rimetti il microfono giusto") { mic.apply() }
        }
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

            Button { m8.liveMode() } label: {
                VStack(spacing: 2) {
                    Text("live mode")
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                    Text("shift + sinistra · dal Song")
                        .font(.system(.caption2, design: .monospaced))
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.25, green: 0.80, blue: 0.70)))
                .foregroundStyle(Color.black)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("live mode")

            M8TempoCard()

            M8TracksCard()

            Card(title: "manopola", note: "Manda il CC \(m8.knobCC) sul canale \(m8.channel). Sull'M8 assegnalo a quello che vuoi (es. cue vol) in Project > MIDI Mapping.") {
                StepSlider(name: "cue vol", value: m8.knob) { m8.setKnob($0) }
            }
        }
    }
}

/// L'M8 a tempo con Bobina: lo stesso bpm e la stessa battuta di TX-6, PO e OP-Z.
struct M8TempoCard: View {
    @EnvironmentObject var m8: M8Engine

    var body: some View {
        Card(title: "a tempo con Bobina", note: "Sull'M8: Project > MIDI > Settings > SYNC IN = CLOCK+TRANSP. Se suona già un'altra macchina, l'M8 entra alla battuta dopo.") {
            Button { m8.toggleRun() } label: {
                Text(m8.running ? "ferma l'M8" : "fai partire l'M8 a tempo")
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 10).fill(m8.running ? Palette.rec : Color(red: 0.40, green: 0.82, blue: 0.40)))
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(.plain)
            HStack(spacing: 8) {
                Text("bpm")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.dim)
                SmallKey(text: "−5") { m8.setBPM(m8.bpm - 5) }
                SmallKey(text: "−1") { m8.setBPM(m8.bpm - 1) }
                Text("\(m8.bpm)")
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .frame(minWidth: 56)
                SmallKey(text: "+1") { m8.setBPM(m8.bpm + 1) }
                SmallKey(text: "+5") { m8.setBPM(m8.bpm + 5) }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// Mute e solo delle otto tracce: due file di tasti numerati, ognuno col suo nome.
struct M8TracksCard: View {
    @EnvironmentObject var m8: M8Engine

    static let muteColor = Color(red: 0.95, green: 0.36, blue: 0.33)
    static let soloColor = Color(red: 0.38, green: 0.70, blue: 0.98)

    var body: some View {
        Card(title: "tracce", note: "Acceso = bianco col bordo. Quello che cambi a mano sull'M8 qui non si vede.") {
            row("muta", on: m8.muted, color: M8TracksCard.muteColor) { m8.toggleMute($0) }
            row("solo", on: m8.soloed, color: M8TracksCard.soloColor) { m8.toggleSolo($0) }
            Button { m8.clearTracks() } label: {
                Text("togli tutti i muta e solo")
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.18)))
                    .foregroundStyle(Color.white)
            }
            .buttonStyle(.plain)
        }
    }

    private func row(_ name: String, on: Set<Int>, color: Color, tap: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(color)
            HStack(spacing: 4) {
                ForEach(1...8, id: \.self) { t in
                    let lit = on.contains(t)
                    Button { tap(t) } label: {
                        Text("\(t)")
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(RoundedRectangle(cornerRadius: 8).fill(lit ? Color.white : color.opacity(0.85)))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(lit ? color : Palette.cardEdge, lineWidth: lit ? 3 : 1))
                            .foregroundStyle(Color.black)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(name) \(t)")
                    .accessibilityAddTraits(lit ? .isSelected : [])
                }
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

            M8MicCard(mic: m8.mic)

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

            Card(title: "firmware", note: "Bobina lo chiede all'M8 col cavo. Dal 6 in su si può avere anche lo schermo dell'M8 qui.") {
                Text(m8.firmware.map { "firmware \($0)" + (m8.model.map { " · \($0)" } ?? "") } ?? "non ancora letto")
                    .font(.system(.title3, design: .monospaced))
                Chip(text: "leggi il firmware") { m8.readFirmware() }
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

// MARK: - Suona

struct M8SuonaView: View {
    @EnvironmentObject var m8: M8Engine

    var body: some View {
        M8Page(title: "Suona") {
            M8PadsCard(player: m8.player)
            M8StepsCard(player: m8.player)
            M8TempoCard()
            M8TiltCard(player: m8.player)
        }
    }
}

/// 16 pad, ognuno diviso in due: sopra suona, sotto tiene la nota.
struct M8PadsCard: View {
    @ObservedObject var player: M8Player

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)
    static let padColor = Color(red: 0.62, green: 0.45, blue: 0.98)

    var body: some View {
        Card(title: "pad", note: "Suonano la traccia che ascolta il canale \(player.channel) (sull'M8: Project > MIDI > Settings, TRACK INPUT). L'ultimo pad toccato è la nota che si scrive nei passi.") {
            HStack(spacing: 8) {
                Text("canale").font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.dim)
                SmallKey(text: "−") { player.channel = max(1, player.channel - 1) }
                Text("\(player.channel)").font(.system(.title3, design: .monospaced)).frame(minWidth: 32)
                SmallKey(text: "+") { player.channel = min(16, player.channel + 1) }
                Spacer()
                Button("ottava giù") { player.octave(-1) }.font(.footnote)
                Button("ottava su") { player.octave(1) }.font(.footnote)
            }
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<16, id: \.self) { i in
                    let n = player.base + (3 - i / 4) * 4 + i % 4
                    pad(n)
                }
            }
            HStack {
                if !player.held.isEmpty {
                    Button("lascia tutte le note") { player.releaseAll() }.font(.footnote)
                }
                Spacer()
                Chip(text: "silenzio") { player.engine?.allNotesOff() }
            }
        }
    }

    private func pad(_ n: Int) -> some View {
        let name = M8Player.name(n)
        let held = player.held.contains(n)
        let picked = player.pick == n
        return VStack(spacing: 3) {
            Button { player.touch(n) } label: {
                Text(name)
                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 8).fill(M8PadsCard.padColor))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(held || picked ? Color.white : Palette.cardEdge, lineWidth: held ? 3 : picked ? 2 : 1))
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("nota \(name)")
            Button { player.toggleHold(n) } label: {
                Text(held ? "lascia" : "tieni")
                    .font(.system(.caption2, design: .monospaced).weight(held ? .bold : .regular))
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(RoundedRectangle(cornerRadius: 8).fill(held ? Color.white : M8PadsCard.padColor.opacity(0.45)))
                    .foregroundStyle(held ? Color.black : Color.white.opacity(0.9))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(held ? "lascia \(name)" : "tieni \(name)")
        }
    }
}

/// 16 passi a tempo con Bobina. Toccare un passo vuoto ci scrive la nota scelta, uno pieno lo svuota.
struct M8StepsCard: View {
    @ObservedObject var player: M8Player

    var body: some View {
        Card(title: "passi", note: "Nota da scrivere: \(M8Player.name(player.pick)) (tocca un pad per cambiarla). Vanno a tempo con TX-6, PO e OP-Z.") {
            Button { player.toggleSteps() } label: {
                Text(player.stepsOn ? "ferma i passi" : "fai partire i passi")
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 10).fill(player.stepsOn ? Palette.rec : Color(red: 0.40, green: 0.82, blue: 0.40)))
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(.plain)
            M8StepGrid(player: player, live: player.live)
            Button("svuota i passi") { player.clearSteps() }.font(.footnote)
        }
    }
}

/// I quadratini dei passi: guardano `live`, così a ogni sedicesimo si ridisegnano solo loro.
struct M8StepGrid: View {
    @ObservedObject var player: M8Player
    @ObservedObject var live: M8Live

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0..<16, id: \.self) { i in
                let note = player.steps[i]
                let now = live.step == i
                Button { player.toggleStep(i) } label: {
                    VStack(spacing: 1) {
                        Text("\(i + 1)").font(.system(.caption2, design: .monospaced))
                        Text(note.map(M8Player.name) ?? "—").font(.system(.footnote, design: .monospaced).weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(RoundedRectangle(cornerRadius: 7).fill(now ? Palette.accent : note != nil ? M8.color : Color(white: 0.18)))
                    .foregroundStyle(now || note != nil ? Color.black : Color.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("passo \(i + 1)")
            }
        }
    }
}

/// L'inclinazione del telefono su un CC: a sinistra 0, dritto 64, a destra 127.
struct M8TiltCard: View {
    @ObservedObject var player: M8Player

    var body: some View {
        Card(title: "inclinazione", note: "Inclina il telefono: manda il CC \(player.tiltCC). Sull'M8 assegnalo in Project > MIDI Mapping (tieni OPTION sul parametro e inclina).") {
            Toggle("inclinazione accesa", isOn: $player.tiltOn)
            HStack(spacing: 8) {
                Text("CC").font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.dim)
                SmallKey(text: "−") { player.tiltCC = max(0, player.tiltCC - 1) }
                Text("\(player.tiltCC)").font(.system(.title3, design: .monospaced)).frame(minWidth: 40)
                SmallKey(text: "+") { player.tiltCC = min(127, player.tiltCC + 1) }
            }
            if player.tiltOn { M8TiltBar(live: player.live) }
        }
    }
}

struct M8TiltBar: View {
    @ObservedObject var live: M8Live

    var body: some View {
        HStack {
            ProgressView(value: Double(live.tilt), total: 127).tint(M8.color)
            Text("\(live.tilt)").font(.system(.caption, design: .monospaced)).frame(width: 36, alignment: .trailing)
        }
    }
}
