import SwiftUI
import CoreMIDI

// MARK: - le cinque schermate dell'OP-Z

/// Suona, Crea, Live (muti ed effetti), Ritmo, Collega. Riapre l'ultima scheda usata.
struct OPZTabs: View {
    @AppStorage("bobina.opz.scheda") private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            OPZSuonaView()
                .tabItem { Label("Suona", systemImage: "play.square.stack") }.tag(0)
            OPZCreaView()
                .tabItem { Label("Crea", systemImage: "square.grid.4x3.fill") }.tag(1)
            OPZLiveView()
                .tabItem { Label("Live", systemImage: "sparkles") }.tag(2)
            OPZRitmoView()
                .tabItem { Label("Ritmo", systemImage: "metronome") }.tag(3)
            OPZCollegaView()
                .tabItem { Label("Collega", systemImage: "cable.connector") }.tag(4)
        }
        .tint(OPZ.tint)
    }
}

/// Come Page, con la fascia dell'OP-Z e la striscia del collegamento.
struct OPZPage<Content: View>: View {
    let title: String
    /// Senza la fascia col nome: per le schede che devono stare in uno schermo.
    var compact = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        #if DEBUG
        let _ = Diagnostics.shared.count("pagina opz " + title)
        #endif
        NavigationStack {
            ScrollView {
                VStack(spacing: compact ? 8 : 12) {
                    if !compact { OPZBanner() }
                    OPZStatusStrip()
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

/// In cima a ogni scheda: il nome della macchina nel suo colore.
struct OPZBanner: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("OP-Z")
                .font(.system(.title2, design: .rounded).weight(.bold))
            Text("16 tracce")
                .font(.system(.subheadline, design: .monospaced))
                .opacity(0.75)
            Spacer()
        }
        .foregroundStyle(Color.black)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(OPZ.tint))
        .accessibilityElement(children: .combine)
    }
}

struct OPZStatusStrip: View {
    @EnvironmentObject var opz: OPZEngine

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(opz.connected ? Color.green : Palette.rec)
                .frame(width: 8, height: 8)
            Text(opz.connected ? "collegato a \(opz.connectedName)" : "OP-Z non collegato · vai su Collega")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
                .lineLimit(1)
            Spacer()
            if opz.running || opz.othersRunning {
                Text("\(Int(opz.bpm.rounded())) bpm")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.accent)
            }
        }
        .padding(.top, 6)
    }
}

/// ▶ e ■ grandi, con battuta e quarto che avanzano.
struct OPZTransport: View {
    @EnvironmentObject var opz: OPZEngine

    var body: some View {
        HStack(spacing: 8) {
            Button { opz.toggleRun() } label: {
                Text(opz.running ? "■ ferma" : "▶ suona")
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(RoundedRectangle(cornerRadius: 12).fill(opz.running ? Palette.rec : OPZ.tint))
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(opz.running ? "ferma l'OP-Z" : "fai suonare l'OP-Z")
            OPZBeatReadout(live: opz.live, running: opz.running)
                .frame(width: 96)
        }
        if opz.othersRunning && !opz.running {
            Text("suona già un'altra macchina: l'OP-Z entrerà all'inizio della battuta")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
        }
    }
}

/// Guarda solo `live`: a ogni battito si ridisegnano queste quattro lucine, non la pagina.
struct OPZBeatReadout: View {
    @ObservedObject var live: OPZLive
    let running: Bool

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { q in
                    Circle()
                        .fill(running && live.quarter == q ? (q == 0 ? Palette.accent : OPZ.tint) : Color(white: 0.22))
                        .frame(width: 14, height: 14)
                }
            }
            Text(running ? "battuta \(live.bar + 1)" : "fermo")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Palette.dim)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Suona

struct OPZSuonaView: View {
    @EnvironmentObject var opz: OPZEngine

    private let columns4 = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        OPZPage(title: "Suona") {
            OPZTransport()

            Card(title: "pattern", note: opz.onTheBar ? "Mentre suona, il pattern nuovo parte all'inizio della battuta dopo. L'OP-Z non dice quale pattern suona: qui c'è l'ultimo scelto da Bobina." : "Il pattern cambia subito e tiene il passo a cui era arrivato.") {
                LazyVGrid(columns: columns4, spacing: 6) {
                    ForEach(1...16, id: \.self) { n in
                        Button { opz.choosePattern(n) } label: {
                            Text(opz.queuedPattern == n ? "\(n) ⏳" : "\(n)")
                                .font(.system(.title3, design: .monospaced).weight(opz.pattern == n ? .bold : .regular))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(RoundedRectangle(cornerRadius: 9).fill(opz.pattern == n ? OPZ.tint : Color(white: 0.18)))
                                .overlay(RoundedRectangle(cornerRadius: 9).stroke(opz.queuedPattern == n ? Palette.accent : Palette.cardEdge, lineWidth: opz.queuedPattern == n ? 3 : 1))
                                .foregroundStyle(opz.pattern == n ? Color.black : Color.white)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("pattern \(n)")
                        .accessibilityAddTraits(opz.pattern == n ? .isSelected : [])
                    }
                }
                HStack(spacing: 6) {
                    GridChip(text: "◀ pattern prima") { opz.stepPattern(-1) }
                    GridChip(text: "pattern dopo ▶") { opz.stepPattern(1) }
                }
                HStack(spacing: 6) {
                    GridChip(text: "alla battuta", on: opz.onTheBar) { opz.onTheBar = true }
                    GridChip(text: "subito", on: !opz.onTheBar) { opz.onTheBar = false }
                }
            }

            OPZSongCard()

            Card(title: "progetto", note: "Il pattern si sceglie dentro un progetto (1-10). Da provare: secondo la community questo numero cambia anche il progetto dell'OP-Z.") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                    ForEach(1...10, id: \.self) { n in
                        GridChip(text: "\(n)", on: opz.project == n) { opz.project = n }
                            .accessibilityLabel("progetto \(n)")
                    }
                }
            }
        }
    }
}

/// La canzone a pattern: Bobina cambia pattern da sola, ogni tot battute.
struct OPZSongCard: View {
    @EnvironmentObject var opz: OPZEngine
    @State private var pick = 1

    var body: some View {
        Card(title: "canzone a pattern", note: "Una fila di pattern: Bobina passa al seguente ogni \(opz.songBars) battute, a tempo, e ricomincia dall'inizio. Sono i pattern dell'OP-Z: per i pattern di Bobina c'è la catena in Crea.") {
            Toggle("canzone accesa", isOn: $opz.songOn)
            HStack(spacing: 6) {
                Text("ogni")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.dim)
                ForEach([1, 2, 4, 8], id: \.self) { b in
                    GridChip(text: b == 1 ? "1 battuta" : "\(b)", on: opz.songBars == b) { opz.songBars = b }
                }
            }
            OPZSongRow(live: opz.live, song: opz.song, songOn: opz.songOn)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                ForEach(1...16, id: \.self) { n in
                    GridChip(text: "\(n)", on: pick == n) { pick = n }
                        .accessibilityLabel("scegli \(n)")
                }
            }
            HStack(spacing: 6) {
                GridChip(text: "aggiungi il \(pick)") { if opz.song.count < 32 { opz.song.append(pick) } }
                GridChip(text: "togli l'ultimo") { if opz.song.count > 1 { opz.song.removeLast() } }
            }
        }
    }
}

/// La fila della canzone, con la voce che suona accesa. Guarda `live`.
struct OPZSongRow: View {
    @ObservedObject var live: OPZLive
    let song: [Int]
    let songOn: Bool

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
            ForEach(song.indices, id: \.self) { i in
                Text("\(song[i])")
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .background(RoundedRectangle(cornerRadius: 7).fill(songOn && live.songIndex == i ? Palette.accent : Color(white: 0.16)))
                    .foregroundStyle(songOn && live.songIndex == i ? Color.black : Color.white)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("canzone: " + song.map(String.init).joined(separator: ", "))
    }
}

// MARK: - Muti

/// Un effetto diviso in due: sopra un tocco, sotto tieni / lascia. Ognuno col suo colore.
struct OPZPunchKey: View {
    @EnvironmentObject var opz: OPZEngine
    let index: Int
    let name: String
    let held: Bool

    private var color: Color { Color(hue: Double(index) / 12, saturation: 0.55, brightness: 0.95) }
    private var dark: Color { Color(hue: Double(index) / 12, saturation: 0.6, brightness: 0.45) }

    var body: some View {
        VStack(spacing: 3) {
            Button { opz.punchTap(index) } label: {
                Text(name)
                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 8).fill(color))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(held ? Color.white : Palette.cardEdge, lineWidth: held ? 3 : 1))
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(name)

            Button { opz.punchToggle(index) } label: {
                Text(held ? "lascia" : "tieni")
                    .font(.system(.caption2, design: .monospaced).weight(held ? .bold : .regular))
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(RoundedRectangle(cornerRadius: 8).fill(held ? Color.white : dark))
                    .foregroundStyle(held ? Color.black : Color.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(held ? "lascia \(name)" : "tieni \(name)")
            .accessibilityAddTraits(held ? .isSelected : [])
        }
    }
}

// MARK: - Ritmo

struct OPZRitmoView: View {
    @EnvironmentObject var opz: OPZEngine

    var body: some View {
        OPZPage(title: "Ritmo") {
            OPZTransport()

            Card(title: "come sta a tempo", note: syncNote) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(OPZSync.allCases) { m in
                        Chip(text: m.rawValue, on: opz.sync == m) { opz.sync = m }
                    }
                }
            }

            Card(title: "tempo", note: "È il tempo di tutta Bobina: cambiarlo qui lo cambia anche per TX-6 e Pocket Operator.") {
                HStack(spacing: 10) {
                    Chip(text: "−") { opz.setBPM(opz.bpm - 1) }
                    Text("\(Int(opz.bpm.rounded()))")
                        .font(.system(size: 34, weight: .medium, design: .monospaced))
                        .frame(minWidth: 80)
                    Chip(text: "+") { opz.setBPM(opz.bpm + 1) }
                    Spacer()
                    Chip(text: "tap") { opz.tap() }
                }
                .disabled(opz.followingTX6)
                HStack(spacing: 6) {
                    ForEach([90.0, 100.0, 110.0, 120.0, 128.0], id: \.self) { b in
                        GridChip(text: "\(Int(b))", on: Int(opz.bpm.rounded()) == Int(b)) { opz.setBPM(b) }
                    }
                }
                .disabled(opz.followingTX6)
                if opz.followingTX6 {
                    Text("il tempo lo dà il TX-6 (Ritmo del TX-6: «segui il TX-6»)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.accent)
                }
                if opz.sync == .own && opz.bpm > OPZ.tempoRange.upperBound {
                    Text("Da solo l'OP-Z via MIDI arriva a 127 bpm: per andare più veloce scegli «Bobina dà il clock».")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.rec)
                }
            }

            Card(title: "swing", note: "64 = niente swing.") {
                HStack(spacing: 10) {
                    SmallKey(text: "−") { opz.setSwing(opz.swing - 4) }
                    Text("\(opz.swing)")
                        .font(.system(.title3, design: .monospaced))
                        .frame(minWidth: 60)
                    SmallKey(text: "+") { opz.setSwing(opz.swing + 4) }
                    Spacer()
                    Chip(text: "64") { opz.setSwing(64) }
                }
            }

            Card(title: "anticipo", note: "Col bluetooth l'OP-Z sente tutto qualche millisecondo dopo. Se suona in ritardo rispetto alle altre macchine alza l'anticipo.") {
                HStack(spacing: 10) {
                    SmallKey(text: "−") { opz.leadMs = max(-100, opz.leadMs - 5) }
                    Text("\(Int(opz.leadMs)) ms")
                        .font(.system(.title3, design: .monospaced))
                        .frame(minWidth: 90)
                    SmallKey(text: "+") { opz.leadMs = min(200, opz.leadMs + 5) }
                    Spacer()
                    Chip(text: "0") { opz.leadMs = 0 }
                }
            }

            if opz.sync == .clock {
                Card(title: "clock sempre acceso", note: "Il clock va anche da fermi: l'OP-Z sa già il tempo quando parte. Costa 48 messaggi al secondo sul bluetooth.") {
                    Toggle("clock sempre acceso", isOn: $opz.clockAlways)
                }
            }

            Card(title: "se l'OP-Z non si ferma", note: "Per esempio se l'ha fatto partire qualcuno dalla macchina.") {
                GridChip(text: "manda stop") { opz.forceStop() }
            }
        }
    }

    private var syncNote: String {
        switch opz.sync {
        case .clock:
            return "Bobina manda il clock: l'OP-Z va al tempo di Bobina, sulla stessa battuta di TX-6 e Pocket Operator. Sull'OP-Z va acceso «midi clock in» (TEMPO + SCREEN, tasto 4). Col cavo è perfetto; col bluetooth è da provare."
        case .own:
            return "L'OP-Z va col suo orologio: Bobina gli dice il tempo (da 40 a 127) e lo fa partire a inizio battuta. Va bene da solo; con le altre macchine dopo qualche minuto si allontana."
        }
    }
}

// MARK: - Collega

struct OPZCollegaView: View {
    @EnvironmentObject var opz: OPZEngine
    @State private var showBluetooth = false

    var body: some View {
        OPZPage(title: "Collega") {
            Card(title: "col bluetooth", note: "La prima volta: Ele preme il tasto di pairing sotto l'OP-Z (finché la luce lampeggia blu), poi qui «cerca l'OP-Z» e tocca OP-Z nella lista. L'app ufficiale OP-Z va chiusa: l'OP-Z parla con un telefono per volta.") {
                Chip(text: "cerca l'OP-Z") { showBluetooth = true }
            }

            Card(title: "col cavo", note: "USB-C – USB-C. Col cavo il clock è perfetto. Per non scaricare l'iPhone: sull'OP-Z SCREEN + il tasto bianco più a destra spegne la ricarica.") {
                EmptyView()
            }

            Card(title: "porte", note: "Bobina sceglie da sola la porta che si chiama OP-Z.") {
                HStack {
                    Text("manda a")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                    Spacer()
                    Picker("manda a", selection: $opz.destinationID) {
                        Text("nessuno").tag(MIDIUniqueIDOrNil.none)
                        ForEach(opz.destinations) { p in
                            Text(p.name).tag(MIDIUniqueIDOrNil.some(p.id))
                        }
                    }
                }
                HStack {
                    Text("ascolta")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                    Spacer()
                    Picker("ascolta", selection: $opz.sourceID) {
                        Text("nessuno").tag(MIDIUniqueIDOrNil.none)
                        ForEach(opz.sources) { p in
                            Text(p.name).tag(MIDIUniqueIDOrNil.some(p.id))
                        }
                    }
                }
                GridChip(text: "aggiorna l'elenco") { opz.refreshPorts() }
            }

            Card(title: "da fare una volta sull'OP-Z (Ele)", note: "Tieni TEMPO + SCREEN e premi i tasti numerati: acceso = led acceso.") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(OPZCollegaView.settings, id: \.0) { s in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(s.0)
                                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                                .frame(width: 22)
                            Text(s.1)
                                .font(.system(.footnote, design: .monospaced))
                        }
                    }
                }
            }

            OPZMonitorLines(book: opz.logBook)
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
        ("4", "acceso · midi clock in (per «Bobina dà il clock»)"),
        ("5", "spento · midi clock out"),
        ("6", "spento · alt program change"),
        ("7", "SPENTO · midi echo"),
        ("8", "acceso · enable program change"),
    ]
}

/// Le righe del monitor: guardano solo il loro quaderno, non il motore.
struct OPZMonitorLines: View {
    @ObservedObject var book: OPZLogBook

    var body: some View {
        Card(title: "monitor", note: "→ parte da Bobina · ← arriva dall'OP-Z (le sue note e le sue manopole). Il clock non viene scritto.") {
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
