import SwiftUI

// I pezzi delle schermate del TX-6 fatte per stare in uno schermo (8/10/2026), come NTS-1, OP-Z e M8:
// niente slider, una parte alla volta, e da zero al massimo un tocco solo.

extension TX6.Param {
    /// I parametri che si possono far muovere (passi con manopola, onde, inclinazione): tutti tranne il guadagno,
    /// che va solo a mano, un dB alla volta.
    static let movable = allCases.filter { $0.continuous && $0 != .gain }
}

/// Il guadagno: solo − e + di un dB, niente salti e niente «max» (può rompere le casse, regola di Giampiero).
struct TX6GainRow: View {
    @EnvironmentObject var tx: TX6Engine
    let track: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("guadagno")
                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                Spacer()
                Text("+\(tx.gainDB(track)) dB")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Palette.accent)
            }
            ProgressView(value: Double(tx.gainDB(track)), total: 42)
                .tint(Palette.accent)
                .accessibilityHidden(true)
            HStack(spacing: 4) {
                TX6Mini(text: "−1 dB") { tx.stepGain(track, by: -1) }
                    .accessibilityLabel("guadagno meno un decibel")
                TX6Mini(text: "+1 dB") { tx.stepGain(track, by: 1) }
                    .accessibilityLabel("guadagno più un decibel")
            }
        }
    }
}

/// Un salto della manopola: il valore, la scritta sul tasto, il nome per il Controllo Vocale.
struct TX6Jump: Hashable {
    let value: Int
    let label: String
    let spoken: String

    static let plain = [TX6Jump(value: 0, label: "0", spoken: "zero"), TX6Jump(value: 32, label: "¼", spoken: "un quarto"),
                        TX6Jump(value: 64, label: "½", spoken: "metà"), TX6Jump(value: 96, label: "¾", spoken: "tre quarti"),
                        TX6Jump(value: 127, label: "max", spoken: "massimo")]
    static let pan = [TX6Jump(value: 0, label: "sx", spoken: "tutto a sinistra"), TX6Jump(value: 32, label: "½sx", spoken: "mezzo a sinistra"),
                      TX6Jump(value: 64, label: "C", spoken: "al centro"), TX6Jump(value: 96, label: "½dx", spoken: "mezzo a destra"),
                      TX6Jump(value: 127, label: "dx", spoken: "tutto a destra")]
    static let eq = [TX6Jump(value: 0, label: "−18", spoken: "meno diciotto"), TX6Jump(value: 32, label: "−9", spoken: "meno nove"),
                     TX6Jump(value: 64, label: "0", spoken: "piatto"), TX6Jump(value: 96, label: "+9", spoken: "più nove"),
                     TX6Jump(value: 127, label: "+18", spoken: "più diciotto")]
    static let filter = [TX6Jump(value: 0, label: "basso", spoken: "passa basso tutto"), TX6Jump(value: 32, label: "½b", spoken: "passa basso a metà"),
                         TX6Jump(value: 64, label: "off", spoken: "filtro spento"), TX6Jump(value: 96, label: "½a", spoken: "passa alto a metà"),
                         TX6Jump(value: 127, label: "alto", spoken: "passa alto tutto")]

    static func of(_ p: TX6.Param) -> [TX6Jump] {
        switch p {
        case .pan: return pan
        case .eqHigh, .eqMid, .eqLow: return eq
        case .filter: return filter
        default: return plain
        }
    }
}

/// Un tasto piccolo che riempie la sua colonna: per le righe fitte (come NTS1SmallChip).
struct TX6Mini: View {
    let text: String
    var on = false
    var color: Color = Palette.accent
    var height: CGFloat = 34
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(RoundedRectangle(cornerRadius: 7).fill(on ? color : Color(white: 0.18)))
                .foregroundStyle(on ? Color.black : Color.white)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Una manopola senza slider, come nelle sezioni NTS-1 e M8: nome e valore, la barra, poi − · 0 · ¼ · ½ · ¾ · max · +.
/// Da zero al massimo è un tocco solo; − e + ritoccano di 8.
struct TX6KnobRow: View {
    let name: String
    let value: Int
    var shown: String? = nil
    var jumps: [TX6Jump] = TX6Jump.plain
    var range: ClosedRange<Int> = 0...127
    let set: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(name)
                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                Spacer()
                Text(shown ?? "\(value)")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Palette.accent)
            }
            ProgressView(value: Double(value - range.lowerBound), total: Double(range.upperBound - range.lowerBound))
                .tint(Palette.accent)
                .accessibilityHidden(true)
            HStack(spacing: 4) {
                TX6Mini(text: "−") { set(max(range.lowerBound, value - 8)) }
                    .accessibilityLabel("\(name) meno")
                ForEach(jumps, id: \.self) { j in
                    TX6Mini(text: j.label, on: abs(value - j.value) <= 4) { set(j.value) }
                        .accessibilityLabel("\(name) \(j.spoken)")
                }
                TX6Mini(text: "+") { set(min(range.upperBound, value + 8)) }
                    .accessibilityLabel("\(name) più")
            }
        }
    }
}

/// Una barra da trascinare, fatta per il QuadStick (10/10/2026): un clic in un punto qualsiasi porta il pallino lì,
/// e tenendo premuto lo si trascina partendo da dove si vuole. Lo slider di Apple si muove solo prendendo il pallino
/// e un clic sulla barra non fa niente: col QuadStick la rotellina di tape e freeze non si muoveva.
struct TX6DragBar: View {
    let value: Double
    var range: ClosedRange<Double> = 0...127
    let set: (Double) -> Void

    private let knob: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let span = range.upperBound - range.lowerBound
            let f = CGFloat(max(0, min(1, (value - range.lowerBound) / span)))
            ZStack(alignment: .leading) {
                Capsule().fill(Color(white: 0.25)).frame(height: 10)
                Capsule().fill(Palette.accent).frame(width: knob / 2 + (w - knob) * f, height: 10)
                Circle().fill(Color.white).frame(width: knob, height: knob).offset(x: (w - knob) * f)
            }
            .frame(width: w, height: geo.size.height)
            .contentShape(Rectangle())
            // da 0 punti: il clic conta subito, e la pagina non scorre quando si parte dalla barra
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                let x = (g.location.x - knob / 2) / max(1, w - knob)
                set(range.lowerBound + Double(max(0, min(1, x))) * span)
            })
        }
        .frame(height: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityValue("\(Int(value.rounded()))")
        .accessibilityAdjustableAction { d in
            switch d {
            case .increment: set(min(range.upperBound, value + 8))
            case .decrement: set(max(range.lowerBound, value - 8))
            @unknown default: break
            }
        }
    }
}

/// Le parti di una schermata: una fila di tasti, una parte alla volta. La scelta resta salvata da chi la usa.
struct TX6Parts: View {
    let items: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, name in
                TX6Mini(text: name, on: selection == i, height: 38) { selection = i }
                    .accessibilityLabel("parte \(name)")
            }
        }
    }
}

/// Una riga di spiegazione corta, al posto dei riquadri con le note lunghe.
struct TX6Label: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Palette.dim)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Come TX6Mini, ma cancella: il primo tocco chiede conferma, il secondo (entro 4 secondi) cancella.
/// Col Controllo Vocale basta ridire lo stesso numero.
struct TX6ConfirmMini: View {
    let text: String
    let action: () -> Void
    @State private var armed = false

    var body: some View {
        TX6Mini(text: armed ? "sicuro?" : text, on: armed, color: Palette.rec) {
            if armed {
                armed = false
                action()
            } else {
                armed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { armed = false }
            }
        }
        .accessibilityLabel(armed ? "conferma \(text)" : text)
    }
}

/// Sedici passi col cursore della scrittura in fila: toccandone uno il cursore va lì.
/// Il cursore ha il bordo bianco, il passo che suona è pieno. Guarda solo `live`, come TX6StepGrid.
struct TX6CursorGrid: View {
    @ObservedObject var live: TX6Live
    let pulsing: Bool
    let cursor: Int
    let label: (Int) -> String
    let filled: (Int) -> Bool
    let select: (Int) -> Void
    /// 16 passi (una battuta) o 32 (due battute, quattro file più basse).
    var count = 16

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 8)

    var body: some View {
        let now = count > 16 ? live.bar * 16 + live.step : live.step
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(0..<count, id: \.self) { i in
                let playing = pulsing && now == i
                Button { select(i) } label: {
                    VStack(spacing: 1) {
                        Text("\(i + 1)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(playing ? Color.black : Palette.dim)
                        Text(label(i))
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .foregroundStyle(playing ? Color.black : Color.white)
                    }
                    .frame(maxWidth: .infinity, minHeight: count > 16 ? 36 : 44)
                    // la seconda battuta un filo più chiara, così si vede dove comincia
                    .background(RoundedRectangle(cornerRadius: 7).fill(playing ? Palette.accent : Color(white: (filled(i) ? 0.30 : 0.16) + (i >= 16 ? 0.05 : 0))))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(cursor == i ? Color.white : Color.clear, lineWidth: 3))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("passo \(i + 1)")
                .accessibilityValue(label(i) == "·" ? "vuoto" : label(i))
                .accessibilityAddTraits(cursor == i ? .isSelected : [])
            }
        }
    }
}

/// In cima a Crea e Ritmo: suona/ferma grande e il tempo, −5 −1 bpm +1 +5.
/// `crea`: il ▶ fa partire anche batteria e melodia (in Ritmo parte solo il tempo, per pompa e onde).
struct TX6TempoTop: View {
    @EnvironmentObject var tx: TX6Engine
    var crea = true
    var tap = false

    private func setBPM(_ v: Double) { tx.bpm = min(300, max(40, v)) }

    var body: some View {
        HStack(spacing: 5) {
            if tx.clockMode == .follow {
                Text(tx.clockBPM.map { String(format: "segue il TX-6\n%.1f bpm", $0) } ?? "aspetto il clock:\npremi play sul TX-6")
                    .font(.system(.footnote, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.accent)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.18)))
            } else {
                Button {
                    if crea && !tx.running {
                        tx.beatsOn = true
                        tx.melodyOn = true
                    }
                    tx.toggleRun()
                } label: {
                    Text(tx.running ? "■ ferma" : "▶ suona")
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 10).fill(tx.running ? Palette.rec : Palette.accent))
                        .foregroundStyle(Color.black)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tx.running ? "ferma" : "suona")
                SmallKey(text: "−5") { setBPM(tx.bpm - 5) }
                    .accessibilityLabel("tempo meno 5")
                SmallKey(text: "−1") { setBPM(tx.bpm - 1) }
                    .accessibilityLabel("tempo meno 1")
            }
            VStack(spacing: 0) {
                Text("\(Int(tx.bpm.rounded()))")
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                Text("bpm")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Palette.dim)
            }
            .frame(minWidth: 46)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(Int(tx.bpm.rounded())) bpm")
            if tx.clockMode != .follow {
                SmallKey(text: "+1") { setBPM(tx.bpm + 1) }
                    .accessibilityLabel("tempo più 1")
                SmallKey(text: "+5") { setBPM(tx.bpm + 5) }
                    .accessibilityLabel("tempo più 5")
                if tap {
                    SmallKey(text: "tap") { tx.tap() }
                        .accessibilityLabel("batti il tempo")
                }
            }
        }
    }
}

/// Una schermata del TX-6: la striscia del collegamento, poi il contenuto, senza spiegazioni lunghe.
/// Scorre solo se un telefono più piccolo non ce la fa: sull'iPhone 18 Pro ogni parte sta in uno schermo.
struct TX6Screen<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        #if DEBUG
        let _ = Diagnostics.shared.count("pagina tx6 " + title)
        #endif
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    TX6StatusStrip()
                    content()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { MachineSwitch() } }
        }
    }
}

/// Un riquadro senza titolo grande: per tenere insieme le cose di una parte.
struct TX6Box<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = title {
                Text(title)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.dim)
            }
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.cardEdge, lineWidth: 1))
    }
}

/// Le sei tracce in fila, una sola accesa: tasti che riempiono la riga.
struct TX6TrackRow: View {
    let selected: Int
    var label: (Int) -> String = { "tr \($0)" }
    let pick: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...6, id: \.self) { t in
                TX6Mini(text: label(t), on: selected == t) { pick(t) }
                    .accessibilityLabel("traccia \(t)")
            }
        }
    }
}

/// Le sei tracce in fila, quante se ne vuole accese (pompa, cancello, onde…).
struct TX6TrackSet: View {
    @Binding var tracks: Set<Int>

    var body: some View {
        HStack(spacing: 4) {
            Text("tracce")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
            ForEach(1...6, id: \.self) { t in
                TX6Mini(text: "\(t)", on: tracks.contains(t)) {
                    if tracks.contains(t) { tracks.remove(t) } else { tracks.insert(t) }
                }
                .accessibilityLabel("traccia \(t)")
            }
        }
    }
}
