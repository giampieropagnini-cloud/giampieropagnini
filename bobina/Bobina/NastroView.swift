import SwiftUI

/// Il nastro: la bobina da girare col dito, il trasporto, la velocità e i suoi giochi.
struct NastroView: View {
    @EnvironmentObject var engine: Engine
    @State private var stopSeconds = 1.2

    var body: some View {
        Page(title: "Nastro") {
            Card(title: "bobina", note: "Girala col dito. Da fermo, un giro al secondo è la velocità normale; più veloce corre, al contrario torna indietro. Mentre suona si somma, come spingere il nastro col dito: ci puoi scratchare. Quando la lasci la leva torna al centro.") {
                ReelView()
                    .frame(height: 250)
                    .frame(maxWidth: .infinity)
                Text("leva \(engine.lever < 0 ? TP7.leverCenter : engine.lever)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.dim)
                    .frame(maxWidth: .infinity)
            }

            Card(title: "trasporto", note: "⏮ riavvolge e suona dall'inizio, ▶ riparte da dove sei, ■ si ferma; ■ di nuovo torna all'inizio, come sulla macchina. ● registra su un file nuovo, ■ chiude la ripresa. Tieni premuto «dito» per fermare il nastro come col dito sulla bobina. ⏪ ⏩ avvolgono velocissimi: un tocco parte, un altro si ferma.") {
                HStack(spacing: 8) {
                    Chip(text: "⏮") { engine.fromTop() }
                    Chip(text: "▶", on: engine.rolling && !engine.recording) { engine.play() }
                    Chip(text: "■") { engine.stop() }
                    Chip(text: "●", on: engine.recording, color: Palette.rec) { engine.record() }
                    PressPad(lit: engine.halted,
                             onPress: { engine.holdStill(true) },
                             onRelease: { engine.holdStill(false) },
                             label: { Text("dito").font(.system(.subheadline, design: .monospaced)) })
                        .frame(height: 36)
                }
                HStack(spacing: 8) {
                    Chip(text: "⏪", on: engine.winding < 0) { engine.wind(-1) }
                    Chip(text: "⏩", on: engine.winding > 0) { engine.wind(1) }
                }
            }

            Card(title: "trasporto in cue", note: "Col TP-7 su MIDI → cue i tasti di sopra non funzionano: usa questi. ▶ fa correre il nastro in avanti con la leva, ■ lo ferma. Un pad fa partire il nastro dal suo segno, e dopo ■ lo tiene fermo e ▶ lo lascia ripartire. ● arma soltanto: la registrazione la fai partire col ▶ della macchina, e il ■ di qui la chiude. Se il nastro l'hai fatto partire dalla macchina, fermalo dalla macchina.") {
                HStack(spacing: 8) {
                    Chip(text: "▶", on: engine.cueTape == .leverPlay || engine.cueTape == .playing) { engine.cuePlay() }
                    Chip(text: "■", on: engine.cueTape == .stopped || engine.cueTape == .frozen) { engine.cueStop() }
                    Chip(text: "●", on: engine.recording, color: Palette.rec) { engine.cueRecord() }
                    Text(cueTapeLabel)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                }
            }

            SpeedCard()

            Card(title: "tape stop", note: "Il nastro rallenta fino a fermarsi, come un registratore a cui manca la corrente; alla fine arriva lo stop. Avvio fa il contrario: parte fermo e prende velocità.") {
                ValueSlider(name: "durata", value: $stopSeconds, range: 0.2...4, shown: String(format: "%.1f s", stopSeconds))
                HStack {
                    Chip(text: "tape stop", color: Palette.rec) { engine.tapeStop(seconds: stopSeconds) }
                    Chip(text: "avvio") { engine.tapeStart(seconds: stopSeconds) }
                }
            }

            WowCard()
            MotionCard()
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
private extension NastroView {
    var cueTapeLabel: String {
        switch engine.cueTape {
        case .stopped: return "fermo"
        case .leverPlay: return "suona con la leva"
        case .playing: return "suona"
        case .frozen: return "tenuto fermo"
        }
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
