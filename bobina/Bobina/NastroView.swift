import SwiftUI

/// Il TP-7 in uno schermo (12/10/2026, come TX-6, M8, OP-Z e NTS-1): trasporto, i 16 pad e sotto una parte alla volta.
/// Niente note lunghe, poco scorrere, da zero al massimo un tocco. Le schede Pad, Ritmo, Mixer e Collega restano per il resto.
struct NastroView: View {
    @EnvironmentObject var engine: Engine
    @AppStorage("bobina.tp7.modo") private var cueMode = true
    @AppStorage("bobina.tp7.parte") private var part = 0
    @AppStorage("bobina.tp7.durata") private var stopSeconds = 1.2

    private let pads = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        Page(title: "TP-7") {
            VStack(alignment: .leading, spacing: 8) {
                transport
                padHeader
                LazyVGrid(columns: pads, spacing: 6) {
                    ForEach(0..<16, id: \.self) { i in
                        FlashingPad(pulse: engine.pulse, index: i, onPress: { engine.padDown(i) }, onRelease: { engine.padUp(i) }, label: {
                            Text("\(i + 1)").font(.system(.title3, design: .monospaced))
                        })
                        .frame(height: 42)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.accent, lineWidth: engine.padsSet.contains(i) ? 2 : 0))
                        .accessibilityLabel("pad \(i + 1)")
                    }
                }
                TP7Parts(items: ["nastro", "ritmo", "giochi", "stanco", "bobina"], selection: $part)
                    .padding(.top, 4)
                switch part {
                case 1: rhythmPart
                case 2: playPart
                case 3: wowPart
                case 4:
                    ReelView().frame(height: 230).frame(maxWidth: .infinity)
                    LeverReadout(live: engine.live)
                default: tapePart
                }
            }
        }
    }

    // MARK: trasporto: in cue la leva, in sync start/stop

    @ViewBuilder private var transport: some View {
        HStack(spacing: 5) {
            if cueMode {
                TP7Mini(text: "▶", on: engine.cueTape == .leverPlay || engine.cueTape == .playing) { engine.cuePlay() }
                TP7Mini(text: "■", on: engine.cueTape == .stopped || engine.cueTape == .frozen) { engine.cueStop() }
                TP7Mini(text: "●", on: engine.recording, color: Palette.rec) { engine.cueRecord() }
                TP7Mini(text: "⏮ canz.") { engine.skipSong(-1) }
                    .accessibilityLabel("canzone prima")
                TP7Mini(text: "⏭ canz.") { engine.skipSong(1) }
                    .accessibilityLabel("canzone dopo")
            } else {
                TP7Mini(text: "⏮") { engine.fromTop() }
                TP7Mini(text: "▶", on: engine.rolling && !engine.recording) { engine.play() }
                TP7Mini(text: "■") { engine.stop() }
                TP7Mini(text: "●", on: engine.recording, color: Palette.rec) { engine.record() }
                TP7Mini(text: "⏪", on: engine.winding < 0) { engine.wind(-1) }
                TP7Mini(text: "⏩", on: engine.winding > 0) { engine.wind(1) }
            }
            PressPad(lit: engine.halted,
                     onPress: { engine.holdStill(true) },
                     onRelease: { engine.holdStill(false) },
                     label: { Text("dito").font(.system(.footnote, design: .monospaced)) })
                .frame(height: 38)
                .accessibilityLabel("dito")
        }
        if cueMode && engine.cueTape == .leverPlay {
            LeverPlayHint()
        }
    }

    private var padHeader: some View {
        HStack(spacing: 5) {
            TP7Mini(text: "richiama", on: !engine.markMode) { engine.markMode = false }
            TP7Mini(text: "segna", on: engine.markMode, color: Palette.rec) { engine.markMode = true }
            TP7Mini(text: "finché tieni", on: engine.padHold) { engine.padHold.toggle() }
                .accessibilityLabel("finché tieni premuto")
            // come è messo il TP-7 (MIDI → cue o sync): cambia i tasti del trasporto qui sopra
            TP7Mini(text: cueMode ? "su cue" : "su sync") { cueMode.toggle() }
                .accessibilityLabel(cueMode ? "passa a sync" : "passa a cue")
        }
    }

    // MARK: le parti

    private var tapePart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                TP7Mini(text: "tape stop", color: Palette.rec, height: 44) { engine.tapeStop(seconds: stopSeconds) }
                TP7Mini(text: "avvio", height: 44) { engine.tapeStart(seconds: stopSeconds) }
            }
            TP7BarRow(name: "durata", value: stopSeconds, range: 0.2...4, shown: String(format: "%.1f s", stopSeconds), step: 0.2,
                      jumps: [(0.5, "½ s"), (1, "1 s"), (2, "2 s"), (4, "4 s")]) { stopSeconds = $0 }
            TP7BarRow(name: "velocità", value: log2(engine.speed), range: -1...1, shown: String(format: "×%.2f", engine.speed), step: 1.0 / 12,
                      jumps: [(-1, "×½"), (log2(0.75), "×¾"), (0, "×1"), (log2(1.5), "×1½"), (1, "×2")]) { engine.speed = pow(2, $0) }
        }
    }

    private var rhythmPart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                TP7Mini(text: "−") { engine.bpm = max(40, engine.bpm - 1) }
                    .accessibilityLabel("tempo meno")
                Text("\(Int(engine.bpm))")
                    .font(.system(.title2, design: .monospaced))
                    .frame(minWidth: 60)
                TP7Mini(text: "+") { engine.bpm = min(240, engine.bpm + 1) }
                    .accessibilityLabel("tempo più")
                TP7Mini(text: "tap") { engine.tap() }
                if engine.followClock {
                    TP7Label("segue il TP-7")
                } else {
                    TP7Mini(text: engine.running ? "■ tempo" : "▶ tempo", on: engine.running) { engine.toggleRun() }
                }
            }
            HStack(spacing: 5) {
                TP7Mini(text: "sequenza", on: engine.seqOn) { engine.seqOn.toggle() }
                TP7Mini(text: "collage", on: engine.collageOn) { engine.setCollage(!engine.collageOn) }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
                ForEach(0..<16, id: \.self) { i in
                    PulseStepCell(label: engine.seq[i].map { "\($0 + 1)" } ?? "·",
                                  filled: engine.seq[i] != nil,
                                  index: i, pulse: engine.pulse, pulsing: engine.pulsing) {
                        let brush = engine.lastPad
                        engine.seq[i] = (engine.seq[i] == brush) ? nil : brush
                    }
                    .accessibilityLabel("passo \(i + 1)")
                }
            }
            TP7Label("un passo prende l'ultimo pad toccato (\(engine.lastPad.map { "pad \($0 + 1)" } ?? "nessuno")); ritoccalo per svuotarlo")
        }
    }

    private let stutterDivisions: [(Double, String)] = [(4, "1/4"), (2, "1/8"), (1, "1/16"), (0.5, "1/32")]

    private var playPart: some View {
        VStack(alignment: .leading, spacing: 8) {
            TP7Label("balbettio: tieni premuto")
            HStack(spacing: 5) {
                ForEach(stutterDivisions, id: \.0) { d in
                    PressPad(lit: engine.stutter == d.0,
                             onPress: { engine.beginStutter(d.0) },
                             onRelease: { engine.endStutter() },
                             label: { Text(d.1).font(.system(.subheadline, design: .monospaced)) })
                        .frame(height: 44)
                        .accessibilityLabel("balbettio \(d.1)")
                }
            }
            TP7Label("loop: schermata LOOP aperta sul TP-7")
            HStack(spacing: 5) {
                TP7Mini(text: "inizio", on: engine.loop != .off) { engine.loopStart() }
                    .disabled(engine.loop != .off)
                TP7Mini(text: "fine", on: engine.loop == .on) { engine.loopEnd() }
                    .disabled(engine.loop != .started)
                TP7Mini(text: "spegni") { engine.loopOff() }
                    .accessibilityLabel("spegni il loop")
            }
            HStack(spacing: 5) {
                TP7Mini(text: "½ batt.") { engine.loopInTime(bars: 0.5) }
                TP7Mini(text: "1 batt.") { engine.loopInTime(bars: 1) }
                TP7Mini(text: "2 batt.") { engine.loopInTime(bars: 2) }
            }
            TP7Label("collage: ogni quanto (quanto spesso: scheda Pad)")
            HStack(spacing: 5) {
                TP7Mini(text: "collage", on: engine.collageOn) { engine.setCollage(!engine.collageOn) }
                ForEach([(1, "1/16"), (2, "1/8"), (4, "1/4"), (16, "batt.")], id: \.0) { e in
                    TP7Mini(text: e.1, on: engine.collageEvery == e.0) { engine.collageEvery = e.0 }
                        .accessibilityLabel("collage ogni \(e.1)")
                }
            }
        }
    }

    private var wowPart: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                TP7Mini(text: "nastro stanco", on: engine.wowOn) { engine.wowOn.toggle() }
                TP7Mini(text: "inclinazione", on: engine.motionOn) { engine.motionOn.toggle() }
            }
            LeverPlayHint()
            TP7BarRow(name: "ondeggia", value: engine.wowDepth, range: 0...1, shown: "\(Int(engine.wowDepth * 100))%", step: 0.1,
                      jumps: TP7BarRow.quarters(0...1)) { engine.wowDepth = $0 }
            TP7BarRow(name: "lentezza", value: engine.wowRate, range: 0.1...4, shown: String(format: "%.1f Hz", engine.wowRate), step: 0.1,
                      jumps: [(0.1, "min"), (0.5, "½"), (1, "1"), (2, "2"), (4, "max")]) { engine.wowRate = $0 }
            TP7BarRow(name: "tremolio", value: engine.flutter, range: 0...1, shown: "\(Int(engine.flutter * 100))%", step: 0.1,
                      jumps: TP7BarRow.quarters(0...1)) { engine.flutter = $0 }
        }
    }
}

// MARK: i pezzi per stare in uno schermo (copie di quelli del TX-6: la sezione TP-7 va su main da sola)

/// Un tasto piccolo che riempie la sua colonna.
struct TP7Mini: View {
    let text: String
    var on = false
    var color: Color = Palette.accent
    var height: CGFloat = 38
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

/// Le parti della schermata: una fila di tasti, una parte alla volta.
struct TP7Parts: View {
    let items: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, name in
                TP7Mini(text: name, on: selection == i) { selection = i }
                    .accessibilityLabel("parte \(name)")
            }
        }
    }
}

/// Una riga di spiegazione corta.
struct TP7Label: View {
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

/// Barra per il QuadStick (copia di TX6DragBar): un clic porta il pallino lì, tenendo premuto si trascina.
struct TP7DragBar: View {
    let value: Double
    let range: ClosedRange<Double>
    let set: (Double) -> Void

    private let knob: CGFloat = 26

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
        .frame(height: 30)
        .accessibilityHidden(true)
    }
}

/// Nome e valore, la barra, poi − · salti · + per la voce (regola dell'11/10: la barra si aggiunge, i tasti restano).
struct TP7BarRow: View {
    let name: String
    let value: Double
    let range: ClosedRange<Double>
    let shown: String
    let step: Double
    let jumps: [(Double, String)]
    let set: (Double) -> Void

    static func quarters(_ r: ClosedRange<Double>) -> [(Double, String)] {
        let s = r.upperBound - r.lowerBound
        return [(r.lowerBound, "0"), (r.lowerBound + s / 4, "¼"), (r.lowerBound + s / 2, "½"), (r.lowerBound + s * 3 / 4, "¾"), (r.upperBound, "max")]
    }

    private func clamp(_ v: Double) -> Double { min(range.upperBound, max(range.lowerBound, v)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(name).font(.system(.footnote, design: .monospaced).weight(.semibold))
                Spacer()
                Text(shown).font(.system(.footnote, design: .monospaced)).foregroundStyle(Palette.accent)
            }
            TP7DragBar(value: value, range: range) { set($0) }
            HStack(spacing: 4) {
                TP7Mini(text: "−", height: 30) { set(clamp(value - step)) }
                    .accessibilityLabel("\(name) meno")
                ForEach(Array(jumps.enumerated()), id: \.offset) { _, j in
                    TP7Mini(text: j.1, on: abs(value - j.0) < step / 2, height: 30) { set(j.0) }
                        .accessibilityLabel("\(name) \(j.1)")
                }
                TP7Mini(text: "+", height: 30) { set(clamp(value + step)) }
                    .accessibilityLabel("\(name) più")
            }
        }
    }
}

/// La bobina virtuale: la velocità del dito diventa la leva del TP-7 (cc 18).
struct ReelView: View {
    @EnvironmentObject var engine: Engine
    @State private var angle = 0.0
    @State private var lastAngle: Double?
    @State private var lastTime: Date?

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(white: 0.85), Color(white: 0.62)], startPoint: .topLeading, endPoint: .bottomTrailing))
                ForEach(1..<9, id: \.self) { k in
                    Circle()
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        .padding(CGFloat(k) * side / 20)
                }
                Circle()
                    .fill(Color(white: 0.55))
                    .frame(width: side * 0.26, height: side * 0.26)
                Circle()
                    .fill(Color.black.opacity(0.22))
                    .frame(width: side * 0.14, height: side * 0.14)
                    .offset(y: -side * 0.34)
            }
            .frame(width: side, height: side)
            .rotationEffect(.degrees(angle))
            .position(center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let a = Double(atan2(v.location.y - center.y, v.location.x - center.x)) * 180 / Double.pi
                        let now = Date()
                        if let la = lastAngle, let lt = lastTime {
                            var d = a - la
                            if d > 180 { d -= 360 }
                            if d < -180 { d += 360 }
                            angle += d
                            let dt = max(0.008, now.timeIntervalSince(lt))
                            // 360 gradi al secondo = +4 sulla leva = 68 = velocità normale
                            engine.scrub(TP7.leverCenter + Int((d / dt / 90).rounded()))
                        }
                        lastAngle = a
                        lastTime = now
                    }
                    .onEnded { _ in
                        lastAngle = nil
                        lastTime = nil
                        engine.endScrub()
                    }
            )
        }
    }
}

struct SpeedCard: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        Card(title: "velocità", note: "Da metà al doppio, col pitch bend: un'ottava sotto e una sopra, come un nastro. Vale solo mentre il TP-7 suona, si somma alla SPD della macchina e il suo display non la mostra.") {
            let octave = Binding<Double>(
                get: { log2(engine.speed) },
                set: { engine.speed = pow(2, $0) }
            )
            LeverPlayHint()
            ValueSlider(name: "velocità", value: octave, range: -1...1, shown: String(format: "×%.2f", engine.speed))
            HStack(spacing: 6) {
                ForEach([0.5, 0.75, 1.0, 1.5, 2.0], id: \.self) { s in
                    Chip(text: s == 1 ? "×1" : String(format: "×%g", s), on: abs(engine.speed - s) < 0.001) {
                        engine.speed = s
                    }
                }
            }
        }
    }
}

struct WowCard: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        Card(title: "nastro stanco", note: "Wow e flutter: la velocità ondeggia piano e trema veloce, come una cassetta vecchia. Si somma alla velocità scelta sopra.") {
            Toggle("acceso", isOn: $engine.wowOn)
            LeverPlayHint()
            ValueSlider(name: "ondeggia", value: $engine.wowDepth, range: 0...1, shown: "\(Int(engine.wowDepth * 100))%")
            ValueSlider(name: "lentezza", value: $engine.wowRate, range: 0.1...4, shown: String(format: "%.1f Hz", engine.wowRate))
            ValueSlider(name: "tremolio", value: $engine.flutter, range: 0...1, shown: "\(Int(engine.flutter * 100))%")
        }
    }
}

struct MotionCard: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        Card(title: "col corpo", note: "Inclina il telefono a destra per accelerare, a sinistra per rallentare: 45° = doppio o metà. Scuotilo per l'azione che scegli.") {
            Toggle("inclinazione", isOn: $engine.motionOn)
            if engine.motionOn { LeverPlayHint() }
            if engine.motionOn {
                MotionReadout(pulse: engine.pulse)
            }
            Picker("scuoti", selection: $engine.shakeAction) {
                ForEach(Engine.ShakeAction.allCases) { a in
                    Text(a.rawValue).tag(a)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

/// La velocità dell'inclinazione, aggiornata 30 volte al secondo: guarda Pulse e si ridisegna da sola.
/// ▶ ■ ● e ⏮ ⏭ canzone per il TP-7 su cue: stanno in Nastro e, sotto i pad, in Pad.
struct CueTransportControls: View {
    @EnvironmentObject var engine: Engine

    private var label: String {
        switch engine.cueTape {
        case .stopped: return "fermo"
        case .leverPlay: return "suona con la leva"
        case .playing: return "suona"
        case .frozen: return "tenuto fermo"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Chip(text: "▶", on: engine.cueTape == .leverPlay || engine.cueTape == .playing) { engine.cuePlay() }
            Chip(text: "■", on: engine.cueTape == .stopped || engine.cueTape == .frozen) { engine.cueStop() }
            Chip(text: "●", on: engine.recording, color: Palette.rec) { engine.cueRecord() }
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
        }
        HStack(spacing: 8) {
            Chip(text: "⏮ canzone") { engine.skipSong(-1) }
            Chip(text: "⏭ canzone") { engine.skipSong(1) }
            Text(engine.lastPad.map { "canzone \($0 + 1)" } ?? "")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
        }
    }
}

/// Velocità, nastro stanco e inclinazione usano il pitch bend, che il TP-7 sente solo nel play vero.
struct LeverPlayHint: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        if engine.cueTape == .leverPlay {
            Text("adesso il nastro lo spinge la leva (▶ in cue) e questo non si sente: serve il play vero, ▶ della macchina o TP-7 su sync")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.rec)
        }
    }
}

/// «leva 64» sotto la bobina: guarda Live, così lo scratch ridisegna solo questa scritta.
struct LeverReadout: View {
    @ObservedObject var live: Live

    var body: some View {
        Text("leva \(live.lever)")
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Palette.dim)
            .frame(maxWidth: .infinity)
    }
}

struct MotionReadout: View {
    @ObservedObject var pulse: Pulse

    var body: some View {
        Text(String(format: "adesso ×%.2f", pulse.motionSpeed))
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Palette.accent)
    }
}
