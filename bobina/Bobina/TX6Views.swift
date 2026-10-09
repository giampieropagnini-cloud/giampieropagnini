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

/// Le cinque schede del TX-6, ognuna in uno schermo (8/10/2026). Riapre l'ultima scheda usata.
/// I numeri delle schede non si cambiano: la 1 era Effetti, ora dentro il Mixer; Crea è la 5.
struct TX6Tabs: View {
    @AppStorage("bobina.tx6.scheda") private var tab = 0
    @AppStorage("bobina.tx6.mixer.parte") private var mixerPart = 0

    var body: some View {
        TabView(selection: $tab) {
            TX6MixerView()
                .tabItem { Label("Mixer", systemImage: "slider.vertical.3") }.tag(0)
            TX6CreaView()
                .tabItem { Label("Crea", systemImage: "square.grid.3x3.fill") }.tag(5)
            TX6SuonaView()
                .tabItem { Label("Suona", systemImage: "pianokeys") }.tag(2)
            TX6RitmoView()
                .tabItem { Label("Ritmo", systemImage: "metronome") }.tag(3)
            TX6CollegaView()
                .tabItem { Label("Collega", systemImage: "cable.connector") }.tag(4)
        }
        .onAppear {
            // chi aveva lasciato aperta la vecchia scheda Effetti ritrova gli effetti nel Mixer
            if tab == 1 {
                tab = 0
                mixerPart = 1
            }
        }
    }
}

// MARK: - pezzi comuni

struct TX6StatusStrip: View {
    @EnvironmentObject var tx: TX6Engine

    var body: some View {
        // non collegato: un tocco qui cerca il TX-6 col bluetooth e lo collega, senza menu (9/10/2026)
        Button {
            if !tx.connected { tx.reconnectBluetooth() }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(tx.connected ? Color.green : Palette.rec)
                    .frame(width: 8, height: 8)
                Text(tx.connected ? "collegato a \(tx.connectedName)" : (tx.bluetoothState ?? "TX-6 non collegato · tocca qui per il bluetooth"))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(tx.connected ? Palette.dim : Color.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
                if tx.pulsing {
                    Text("\(Int(tx.bpm.rounded())) bpm")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.accent)
                }
            }
            .padding(.vertical, tx.connected ? 0 : 6)
            .padding(.horizontal, tx.connected ? 0 : 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(tx.connected ? Color.clear : Color(white: 0.16)))
        }
        .buttonStyle(.plain)
        .disabled(tx.connected)
        .accessibilityLabel(tx.connected ? "collegato a \(tx.connectedName)" : "collega il TX-6 col bluetooth")
        .padding(.top, 6)
        if tx.strayClock && tx.clockMode != .follow {
            Text("Il TX-6 manda il suo tempo (32 messaggi al secondo) e intasa il bluetooth: i comandi di Bobina si perdono. Sul TX-6: shift + select → CLOCK → OUT off.")
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

/// Un tasto piccolo che resta acceso (muto, solo): stretto come − e +, per lasciare spazio allo slider.
struct ToggleKey: View {
    let text: String
    let on: Bool
    var color: Color = Palette.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(.subheadline, design: .monospaced))
                .frame(width: 34, height: 30)
                .background(RoundedRectangle(cornerRadius: 7).fill(on ? color : Color(white: 0.18)))
                .foregroundStyle(on ? Color.black : Color.white)
        }
        .buttonStyle(.plain)
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
