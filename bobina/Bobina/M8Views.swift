import SwiftUI

// MARK: - le quattro schermate dell'M8

/// Tasti, Suona, Passi, Collega: ognuna sta in uno schermo. Riapre l'ultima scheda usata.
/// La barra in basso è viola come le frecce dell'M8.
struct M8Tabs: View {
    @AppStorage("bobina.m8.scheda") private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            M8TastiView()
                .tabItem { Label("Tasti", systemImage: "dpad.fill") }.tag(0)
            M8SuonaView()
                .tabItem { Label("Suona", systemImage: "pianokeys") }.tag(2)
            M8PassiView()
                .tabItem { Label("Passi", systemImage: "square.grid.4x3.fill") }.tag(3)
            M8CollegaView()
                .tabItem { Label("Collega", systemImage: "cable.connector") }.tag(1)
        }
        .tint(M8.color)
    }
}

/// La pagina dell'M8: la striscia del collegamento in cima, poi il contenuto, fitto.
struct M8Page<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    M8StatusStrip()
                    content()
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("M8").font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(M8.color)
                }
                ToolbarItem(placement: .topBarTrailing) { MachineSwitch() }
            }
        }
    }
}

struct M8StatusStrip: View {
    @EnvironmentObject var m8: M8Engine

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(m8.connected ? Color.green : Palette.rec)
                .frame(width: 8, height: 8)
            Text(m8.connected ? "collegato a \(m8.connectedName)" : "M8 non collegato · vai su Collega")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
                .lineLimit(1)
            Spacer()
        }
        .padding(.top, 4)
        M8MicLine(mic: m8.mic)
    }
}

/// Una riga sotto la striscia, solo se il Controllo Vocale non ti sente (l'iPhone ascolta l'M8).
struct M8MicLine: View {
    @ObservedObject var mic: M8Mic

    var body: some View {
        if mic.usbPresent && mic.onM8 {
            Text("microfono: \(mic.inputName) · il Controllo Vocale non ti sente · Collega")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.rec)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - pezzi comuni

/// Un tasto piccolo e pieno, per le schede fitte. Acceso = viola.
struct M8Chip: View {
    let text: String
    var on = false
    var color: Color = M8.color
    var height: CGFloat = 40
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(.footnote, design: .monospaced).weight(on ? .semibold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(RoundedRectangle(cornerRadius: 8).fill(on ? color : Color(white: 0.18)))
                .foregroundStyle(on ? Color.black : Color.white)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Il riquadro scuro di una parte.
struct M8Panel<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content() }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.cardEdge, lineWidth: 1))
    }
}

struct M8Label: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(text).font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.dim)
    }
}

/// Il tempo in una riga, sempre in cima: l'M8 a tempo con Bobina (start e clock) e il bpm.
struct M8TempoLine: View {
    @EnvironmentObject var m8: M8Engine

    var body: some View {
        HStack(spacing: 5) {
            M8Chip(text: m8.running ? "ferma l'M8" : "M8 a tempo", on: true, color: m8.running ? Palette.rec : Color(red: 0.40, green: 0.82, blue: 0.40), height: 44) { m8.toggleRun() }
                .accessibilityLabel(m8.running ? "ferma l'M8" : "fai partire l'M8 a tempo")
            SmallKey(text: "−5") { m8.setBPM(m8.bpm - 5) }.accessibilityLabel("tempo meno 5")
            SmallKey(text: "−1") { m8.setBPM(m8.bpm - 1) }.accessibilityLabel("tempo meno 1")
            Text("\(m8.bpm)")
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .frame(minWidth: 44)
            SmallKey(text: "+1") { m8.setBPM(m8.bpm + 1) }.accessibilityLabel("tempo più 1")
            SmallKey(text: "+5") { m8.setBPM(m8.bpm + 5) }.accessibilityLabel("tempo più 5")
        }
    }
}

/// Una manopola senza slider: nome e valore, poi − · 0 · ¼ · ½ · ¾ · max · +. − e + ritoccano di 8.
struct M8KnobRow: View {
    let name: String
    let value: Int
    let set: (Int) -> Void

    static let jumps: [(Int, String, String)] = [(0, "0", "zero"), (32, "¼", "un quarto"), (64, "½", "metà"), (96, "¾", "tre quarti"), (127, "max", "massimo")]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name).font(.system(.footnote, design: .monospaced).weight(.semibold))
                Spacer()
                Text("\(value)").font(.system(.footnote, design: .monospaced)).foregroundStyle(M8.color)
            }
            HStack(spacing: 4) {
                M8Chip(text: "−", height: 36) { set(max(0, value - 8)) }
                    .accessibilityLabel("\(name) meno")
                ForEach(M8KnobRow.jumps, id: \.0) { j in
                    M8Chip(text: j.1, on: abs(value - j.0) <= 4, height: 36) { set(j.0) }
                        .accessibilityLabel("\(name) \(j.2)")
                }
                M8Chip(text: "+", height: 36) { set(min(127, value + 8)) }
                    .accessibilityLabel("\(name) più")
            }
        }
    }
}

// MARK: - Tasti

/// Il telecomando in uno schermo: tempo, la faccia dell'M8, live mode e silenzio, poi una parte per volta
/// (muta e solo, oppure la manopola).
struct M8TastiView: View {
    @EnvironmentObject var m8: M8Engine
    @AppStorage("bobina.m8.tasti.parte") private var part = 0

    var body: some View {
        M8Page(title: "Tasti") {
            M8TempoLine()
            M8Face()
            HStack(spacing: 6) {
                M8Chip(text: "live mode", on: true, color: Color(red: 0.25, green: 0.80, blue: 0.70), height: 44) { m8.liveMode() }
                    .accessibilityLabel("live mode")
                M8Chip(text: "silenzio", height: 44) { m8.allNotesOff() }
                if !m8.held.isEmpty {
                    M8Chip(text: "lascia tutto", on: true, color: .white, height: 44) { m8.releaseAll() }
                }
            }
            HStack(spacing: 6) {
                M8Chip(text: "muta e solo", on: part == 0, height: 36) { part = 0 }
                    .accessibilityLabel("parte muta e solo")
                M8Chip(text: "manopola", on: part == 1, height: 36) { part = 1 }
                    .accessibilityLabel("parte manopola")
            }
            M8Panel {
                if part == 1 {
                    M8KnobRow(name: "cue vol · CC \(m8.knobCC)", value: m8.knob) { m8.setKnob($0) }
                    M8Label("Sull'M8: Project > MIDI Mapping, tieni OPTION sul parametro e tocca qui.")
                } else {
                    M8TracksRows()
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
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0..<M8.face.count, id: \.self) { r in
                ForEach(0..<4, id: \.self) { c in
                    if let k = M8.face[r][c] {
                        M8KeyButton(key: k, held: m8.held.contains(k))
                    } else {
                        Color.clear.frame(minHeight: 80).accessibilityHidden(true)
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
                .frame(maxWidth: .infinity, minHeight: 46)
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
                    .frame(maxWidth: .infinity, minHeight: 32)
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

/// Mute e solo delle otto tracce: due file di tasti numerati, ognuno col suo nome.
struct M8TracksRows: View {
    @EnvironmentObject var m8: M8Engine

    static let muteColor = Color(red: 0.95, green: 0.36, blue: 0.33)
    static let soloColor = Color(red: 0.38, green: 0.70, blue: 0.98)

    var body: some View {
        row("muta", on: m8.muted, color: M8TracksRows.muteColor) { m8.toggleMute($0) }
        row("solo", on: m8.soloed, color: M8TracksRows.soloColor) { m8.toggleSolo($0) }
        M8Chip(text: "togli tutti i muta e solo", height: 36) { m8.clearTracks() }
    }

    private func row(_ name: String, on: Set<Int>, color: Color, tap: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 34, alignment: .leading)
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

// MARK: - Suona

/// I pad in uno schermo: tempo in cima, poi una parte per volta (pad o inclinazione).
struct M8SuonaView: View {
    @EnvironmentObject var m8: M8Engine
    @AppStorage("bobina.m8.suona.parte") private var part = 0

    var body: some View {
        M8Page(title: "Suona") {
            M8TempoLine()
            HStack(spacing: 6) {
                M8Chip(text: "pad", on: part == 0, height: 36) { part = 0 }
                    .accessibilityLabel("parte pad")
                M8Chip(text: "inclinazione", on: part == 1, height: 36) { part = 1 }
                    .accessibilityLabel("parte inclinazione")
            }
            M8Panel {
                if part == 1 {
                    M8TiltPanel(player: m8.player)
                } else {
                    M8PadsPanel(player: m8.player)
                }
            }
        }
    }
}

/// Quale traccia dell'M8 suonano pad e passi: un tasto per traccia.
/// Sull'M8 la traccia N deve ascoltare il canale N (TRACK INPUT, CHAN).
struct M8TrackPicker: View {
    @ObservedObject var player: M8Player

    var body: some View {
        HStack(spacing: 4) {
            Text("traccia")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
                .fixedSize()
            ForEach(1...8, id: \.self) { t in
                M8Chip(text: "\(t)", on: player.channel == t, height: 40) { player.setTrack(t) }
                    .accessibilityLabel("traccia \(t)")
            }
        }
    }
}

/// 16 pad, un tasto per pad. Il modo sopra: «tocca» suona un attimo, «tieni» lascia la nota accesa.
struct M8PadsPanel: View {
    @ObservedObject var player: M8Player

    private let four = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        M8TrackPicker(player: player)
        HStack(spacing: 6) {
            M8Chip(text: "tocca", on: !player.holdMode) { player.holdMode = false }
                .accessibilityLabel("modo tocca")
            M8Chip(text: "tieni", on: player.holdMode) { player.holdMode = true }
                .accessibilityLabel("modo tieni")
        }
        LazyVGrid(columns: four, spacing: 6) {
            ForEach(0..<16, id: \.self) { i in
                let n = player.base + (3 - i / 4) * 4 + i % 4
                let lit = player.held.contains(n)
                Button { player.pad(n) } label: {
                    Text(M8Player.name(n))
                        .font(.system(.footnote, design: .monospaced).weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(RoundedRectangle(cornerRadius: 8).fill(lit ? Color.white : M8.color))
                        .foregroundStyle(Color.black)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("nota \(M8Player.name(n))")
                .accessibilityAddTraits(lit ? .isSelected : [])
            }
        }
        HStack(spacing: 6) {
            M8Chip(text: "ottava −") { player.octave(-1) }
            M8Chip(text: "ottava +") { player.octave(1) }
            M8Chip(text: "lascia tutto") { player.releaseAll() }
            M8Chip(text: "silenzio") { player.engine?.allNotesOff() }
        }
        M8Label("Sull'M8, Project > MIDI > Settings, TRACK INPUT: la traccia N con CHAN N, e INST# lo strumento che suona.")
    }
}

/// L'inclinazione del telefono su un CC: a sinistra 0, dritto 64, a destra 127.
struct M8TiltPanel: View {
    @ObservedObject var player: M8Player

    var body: some View {
        M8Chip(text: player.tiltOn ? "inclinazione accesa" : "inclinazione spenta", on: player.tiltOn, height: 48) { player.tiltOn.toggle() }
            .accessibilityLabel(player.tiltOn ? "spegni l'inclinazione" : "accendi l'inclinazione")
        if player.tiltOn { M8TiltBar(live: player.live) }
        HStack(spacing: 8) {
            M8Label("CC")
            SmallKey(text: "−") { player.tiltCC = max(0, player.tiltCC - 1) }.accessibilityLabel("CC inclinazione meno")
            Text("\(player.tiltCC)").font(.system(.title3, design: .monospaced)).frame(minWidth: 40)
            SmallKey(text: "+") { player.tiltCC = min(127, player.tiltCC + 1) }.accessibilityLabel("CC inclinazione più")
        }
        M8Label("Sull'M8: Project > MIDI Mapping, tieni OPTION sul parametro e inclina il telefono.")
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

// MARK: - Passi

/// Scrivere una sequenza col minimo di tocchi: tocchi una nota e va nel passo del cursore,
/// che passa da solo al passo dopo. 16 note = 16 tocchi.
struct M8PassiView: View {
    @EnvironmentObject var m8: M8Engine

    var body: some View {
        M8Page(title: "Passi") {
            M8PassiEditor(player: m8.player)
        }
    }
}

struct M8PassiEditor: View {
    @EnvironmentObject var m8: M8Engine
    @ObservedObject var player: M8Player
    @State private var confirmClear = false

    private static let noteNames = ["do", "do#", "re", "re#", "mi", "fa", "fa#", "sol", "sol#", "la", "la#", "si"]
    private let six = Array(repeating: GridItem(.flexible(), spacing: 5), count: 6)

    var body: some View {
        VStack(spacing: 8) {
            // suona / ferma, e il tempo
            HStack(spacing: 6) {
                Button { player.toggleSteps() } label: {
                    Text(player.stepsOn ? "ferma" : "suona")
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 10).fill(player.stepsOn ? Palette.rec : Color(red: 0.40, green: 0.82, blue: 0.40)))
                        .foregroundStyle(Color.black)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.stepsOn ? "ferma i passi" : "suona i passi")
                SmallKey(text: "−5") { m8.setBPM(m8.bpm - 5) }.accessibilityLabel("tempo meno 5")
                Text("\(m8.bpm)")
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                    .frame(minWidth: 44)
                SmallKey(text: "+5") { m8.setBPM(m8.bpm + 5) }.accessibilityLabel("tempo più 5")
            }

            // la traccia dell'M8 che suona i passi
            M8TrackPicker(player: player)

            // la tastiera: 12 note, una per tasto
            LazyVGrid(columns: six, spacing: 5) {
                ForEach(0..<12, id: \.self) { i in
                    let black = [1, 3, 6, 8, 10].contains(i)
                    Button { player.write(i) } label: {
                        Text(M8PassiEditor.noteNames[i])
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(RoundedRectangle(cornerRadius: 8).fill(black ? M8.color.opacity(0.55) : M8.color))
                            .foregroundStyle(Color.black)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("nota \(M8PassiEditor.noteNames[i])")
                }
            }

            // ottava, pausa, indietro
            HStack(spacing: 5) {
                M8Chip(text: "ottava −") { player.writeOctave = max(0, player.writeOctave - 1) }
                Text("ott. \(player.writeOctave)")
                    .font(.system(.footnote, design: .monospaced))
                    .frame(minWidth: 48)
                M8Chip(text: "ottava +") { player.writeOctave = min(8, player.writeOctave + 1) }
                M8Chip(text: "pausa") { player.rest() }
                M8Chip(text: "indietro") { player.back() }
            }

            // i passi: il cursore ha il bordo bianco, quello che suona è arancio
            M8CursorGrid(player: player, live: player.live)

            HStack(spacing: 5) {
                M8Chip(text: "8 passi", on: player.stepLength == 8) { player.stepLength = 8 }
                M8Chip(text: "16 passi", on: player.stepLength == 16) { player.stepLength = 16 }
                M8Chip(text: "copia 1-8 su 9-16") { player.copyHalf() }
            }
            M8Chip(text: confirmClear ? "sicuro? svuota tutti i passi" : "svuota i passi", on: confirmClear, color: Palette.rec) {
                if confirmClear {
                    confirmClear = false
                    player.clearSteps()
                } else {
                    confirmClear = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) { confirmClear = false }
                }
            }
            .accessibilityLabel(confirmClear ? "conferma svuota" : "svuota i passi")
        }
    }
}

/// I 16 passi in due file da 8. Guarda `live` solo per il passo che suona.
struct M8CursorGrid: View {
    @ObservedObject var player: M8Player
    @ObservedObject var live: M8Live

    private let eight = Array(repeating: GridItem(.flexible(), spacing: 4), count: 8)

    var body: some View {
        LazyVGrid(columns: eight, spacing: 5) {
            ForEach(0..<16, id: \.self) { i in
                let note = player.steps[i]
                let inside = i < player.stepLength
                let now = live.step == i
                let here = player.cursor == i
                Button { player.select(i) } label: {
                    VStack(spacing: 0) {
                        Text("\(i + 1)").font(.system(.caption2, design: .monospaced))
                        Text(note.map(M8Player.name) ?? "·")
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 7).fill(now ? Palette.accent : note != nil ? M8.color : Color(white: 0.18)))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(here ? Color.white : Color.clear, lineWidth: 3))
                    .foregroundStyle(now || note != nil ? Color.black : Color.white)
                    .opacity(inside ? 1 : 0.3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("passo \(i + 1)")
                .accessibilityAddTraits(here ? .isSelected : [])
            }
        }
    }
}

// MARK: - Collega

/// Tutto in uno schermo: porta, microfono, firmware, canali.
struct M8CollegaView: View {
    @EnvironmentObject var m8: M8Engine

    var body: some View {
        M8Page(title: "Collega") {
            M8Panel {
                M8Label("porta · col cavo USB-C (l'M8 non ha il bluetooth)")
                if m8.destinations.isEmpty {
                    Text("nessuna porta MIDI").font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.dim)
                }
                ForEach(m8.destinations) { p in
                    M8Chip(text: p.name, on: m8.destinationID == p.id, height: 38) { m8.destinationID = p.id }
                }
                HStack(spacing: 6) {
                    M8Chip(text: "prova: freccia giù") { m8.tap(.down) }
                    M8Chip(text: "aggiorna l'elenco") { m8.refreshPorts() }
                }
            }
            M8MicPanel(mic: m8.mic)
            M8Panel {
                HStack {
                    M8Label("firmware")
                    Text(m8.firmware.map { $0 + (m8.model.map { " · \($0)" } ?? "") } ?? "non ancora letto")
                        .font(.system(.footnote, design: .monospaced).weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                }
                M8Chip(text: "leggi il firmware", height: 36) { m8.readFirmware() }
            }
            M8Panel {
                M8Label("canali · sull'M8: Project > MIDI > Settings")
                M8NumberRow(name: "tasti", hint: "CONTROL MAP CHAN", value: m8.channel, range: 1...16) { m8.channel = $0 }
                M8PadChannelRow(player: m8.player)
                M8NumberRow(name: "CC manopola", hint: "MIDI Mapping", value: m8.knobCC, range: 0...127) { m8.knobCC = $0 }
                M8Label("Per «M8 a tempo»: SYNC IN = CLOCK+TRANSP.")
            }
        }
    }
}

/// Il canale dei pad e dei passi: guarda il player, che è un oggetto a parte.
struct M8PadChannelRow: View {
    @ObservedObject var player: M8Player

    var body: some View {
        M8NumberRow(name: "pad e passi", hint: "canale = traccia", value: player.channel, range: 1...16) { player.channel = $0 }
    }
}

/// Nome, −, numero, +, e il nome dell'impostazione sull'M8.
struct M8NumberRow: View {
    let name: String
    let hint: String
    let value: Int
    let range: ClosedRange<Int>
    let set: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(name).font(.system(.footnote, design: .monospaced).weight(.semibold))
                Text(hint).font(.system(.caption2, design: .monospaced)).foregroundStyle(Palette.dim)
            }
            .frame(width: 130, alignment: .leading)
            SmallKey(text: "−") { set(max(range.lowerBound, value - 1)) }.accessibilityLabel("\(name) meno")
            Text("\(value)").font(.system(.title3, design: .monospaced)).frame(minWidth: 40)
            SmallKey(text: "+") { set(min(range.upperBound, value + 1)) }.accessibilityLabel("\(name) più")
            Spacer()
        }
    }
}

/// Il microfono: con l'M8 col cavo l'iPhone prenderebbe il suo ingresso come microfono.
struct M8MicPanel: View {
    @ObservedObject var mic: M8Mic

    var body: some View {
        M8Panel {
            HStack {
                M8Label("microfono")
                Text(mic.inputName.isEmpty ? "—" : mic.inputName)
                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                    .foregroundStyle(mic.onM8 ? Palette.rec : Color.white)
                Spacer()
            }
            HStack(spacing: 6) {
                M8Chip(text: mic.enabled ? "non usare l'M8 come microfono" : "Bobina non sceglie il microfono", on: mic.enabled, height: 38) { mic.enabled.toggle() }
                M8Chip(text: "rimetti", height: 38) { mic.apply() }
                    .frame(maxWidth: 90)
                    .accessibilityLabel("rimetti il microfono giusto")
            }
            if let p = mic.problem {
                Text(p).font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.rec)
            }
        }
    }
}
