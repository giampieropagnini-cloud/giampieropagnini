import Foundation
import CoreMIDI

/// La forma dell'onda che muove una manopola a tempo. Le stesse parole dell'NTS-1, più «a caso».
enum M8Shape: Int, CaseIterable, Identifiable, Codable {
    case sine, triangle, rampUp, rampDown, gate, pump, random

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .sine: return "onda"
        case .triangle: return "triangolo"
        case .rampUp: return "sale"
        case .rampDown: return "scende"
        case .gate: return "cancello"
        case .pump: return "pompa"
        case .random: return "a caso"
        }
    }

    /// Da 0 (in basso) a 1 (in alto). `phase` va da 0 a 1 nel giro; `turn` è il numero del giro
    /// (per «a caso», che cambia valore a ogni giro e resta lì).
    func level(_ phase: Double, turn: Int, knob: Int) -> Double {
        switch self {
        case .sine: return 0.5 - 0.5 * cos(phase * 2 * .pi)
        case .triangle: return phase < 0.5 ? phase * 2 : 2 - phase * 2
        case .rampUp: return phase
        case .rampDown: return 1 - phase
        case .gate: return phase < 0.5 ? 1 : 0
        // il sidechain: giù di colpo sul battito, poi risale
        case .pump: return 1 - pow(1 - phase, 2.5)
        case .random: return M8Shape.noise(turn, knob)
        }
    }

    /// Un numero a caso ma sempre lo stesso per lo stesso giro: così rifacendo il calcolo non salta.
    static func noise(_ n: Int, _ k: Int) -> Double {
        var x = UInt64(bitPattern: Int64(n &* 7919 &+ k &* 104_729 &+ 1))
        x ^= x >> 33
        x &*= 0xff51_afd7_ed55_8ccd
        x ^= x >> 33
        x &*= 0xc4ce_b9fe_1a85_ec53
        x ^= x >> 33
        return Double(x % 1000) / 999
    }
}

/// Come si muove una manopola da sola: ferma (a mano), con un'onda a tempo, o a passi.
enum M8Motion: Int, Codable {
    case none, wave, steps
}

/// Una manopola: un CC sul canale dei tasti (CONTROL MAP CHAN) che sull'M8 si collega a un parametro
/// qualsiasi (Project > MIDI Mapping). Il nome serve a te e al Controllo Vocale: «cutoff metà».
struct M8Knob: Codable, Equatable {
    var name: String
    var cc: Int
    var motion: M8Motion = .none
    var shape: M8Shape = .sine
    /// Quanto dura un giro dell'onda, in battiti (4 = una battuta).
    var beats: Double = 4
    /// Fin dove scende e fin dove sale l'onda.
    var low: Int = 0
    var high: Int = 127
    /// L'automazione a passi: il valore di ogni passo, nil = resta com'è.
    var steps: [Int?] = Array(repeating: nil, count: 16)

    /// Un volume o una mandata: regola di Giampiero (8/10/2026), mai a salti e mai mossa da sola,
    /// solo − e + piccoli. Un «max» capito male dal Controllo Vocale può rompere casse e cuffie.
    var isGain: Bool { M8Knobs.gainNames.contains(name) }

    init(name: String, cc: Int) {
        self.name = name
        self.cc = cc
    }

    /// Lettura tollerante: un campo che manca (salvato da una versione vecchia) prende il valore di serie,
    /// invece di far sparire tutte le manopole (la lezione dell'OP-Z).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "manopola"
        cc = try c.decodeIfPresent(Int.self, forKey: .cc) ?? 20
        motion = try c.decodeIfPresent(M8Motion.self, forKey: .motion) ?? .none
        shape = try c.decodeIfPresent(M8Shape.self, forKey: .shape) ?? .sine
        beats = try c.decodeIfPresent(Double.self, forKey: .beats) ?? 4
        low = try c.decodeIfPresent(Int.self, forKey: .low) ?? 0
        high = try c.decodeIfPresent(Int.self, forKey: .high) ?? 127
        let s = try c.decodeIfPresent([Int?].self, forKey: .steps) ?? []
        steps = s.count == 16 ? s : Array(repeating: nil, count: 16)
    }
}

/// Quello che cambia molte volte al secondo quando le manopole si muovono da sole: sta a parte,
/// così si ridisegnano solo le barrette dei valori e non la pagina col menu «passa a…».
final class M8KnobLive: ObservableObject {
    @Published var values: [Int] = Array(repeating: 64, count: 8)
    /// Il passo dell'automazione che sta suonando.
    @Published var step: Int?
}

/// Le 8 manopole dell'M8: valori a mano, onde a tempo, automazione a passi.
final class M8Knobs: ObservableObject {
    weak var engine: M8Engine?
    let live = M8KnobLive()

    @Published var knobs: [M8Knob] { didSet { save(); push() } }
    /// La manopola che si sta guardando.
    @Published var selected: Int { didSet { UserDefaults.standard.set(selected, forKey: "bobina.m8.manopole.scelta") } }
    /// Il passo dove va il prossimo valore scritto in fila.
    @Published var cursor = 0

    /// I nomi da scegliere: i parametri dell'M8 che si collegano più spesso.
    static let names = ["cue vol", "forma", "size", "mult", "warp", "scan", "cutoff", "res",
                        "amp", "chorus", "delay", "reverb", "volume", "filtro DJ", "timbre", "color"]

    /// I nomi che sono un guadagno: volumi e mandate agli effetti.
    static let gainNames: Set<String> = ["cue vol", "volume", "amp", "chorus", "delay", "reverb"]
    /// Il passo di − e + su un guadagno: il più piccolo che si sente (2 su 127).
    static let gainStep = 2

    /// Quanto dura un giro dell'onda: in battiti, col nome in battute.
    static let lengths: [(Double, String)] = [(0.25, "1/16"), (0.5, "1/8"), (1, "1/4"), (2, "1/2"), (4, "1"), (8, "2"), (16, "4")]

    /// I salti di valore, come le manopole dell'NTS-1.
    static let jumps: [(Int, String, String)] = [(0, "0", "zero"), (32, "¼", "un quarto"), (64, "½", "metà"), (96, "¾", "tre quarti"), (127, "max", "massimo")]

    init() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: "bobina.m8.manopole"), let k = try? JSONDecoder().decode([M8Knob].self, from: data), k.count == 8 {
            knobs = k
        } else {
            // la prima manopola è la «cue vol» di prima, col suo CC: se era già collegata sull'M8 resta collegata
            let old = d.object(forKey: "bobina.m8.cc") as? Int ?? 1
            knobs = [M8Knob(name: "cue vol", cc: old), M8Knob(name: "cutoff", cc: 21), M8Knob(name: "res", cc: 22),
                     M8Knob(name: "forma", cc: 23), M8Knob(name: "delay", cc: 24), M8Knob(name: "reverb", cc: 25),
                     M8Knob(name: "amp", cc: 26), M8Knob(name: "volume", cc: 27)]
        }
        selected = max(0, min(7, d.integer(forKey: "bobina.m8.manopole.scelta")))
        for i in knobs.indices where knobs[i].isGain && knobs[i].motion != .none { knobs[i].motion = .none }
        if let v = d.array(forKey: "bobina.m8.manopole.valori") as? [Int], v.count == 8 {
            live.values = v
        } else {
            // un guadagno mai toccato da Bobina parte da 0: il primo + alza di poco, non salta a metà
            live.values = knobs.map { $0.isGain ? 0 : 64 }
        }
        // una volta sola, con la regola dei guadagni (8/10/2026): la versione di prima aveva salvato 64 per tutte,
        // anche per i volumi mai toccati; da 64 il primo + salterebbe a metà. Si riparte da 0, verso il silenzio.
        if !d.bool(forKey: "bobina.m8.manopole.guadagni") {
            for i in knobs.indices where knobs[i].isGain { live.values[i] = 0 }
            d.set(true, forKey: "bobina.m8.manopole.guadagni")
            d.set(live.values, forKey: "bobina.m8.manopole.valori")
        }
    }

    func attach(_ e: M8Engine) {
        engine = e
        e.sequencer.onKnobs = { [weak self] values, step in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.live.values != values { self.live.values = values }
                if self.live.step != step { self.live.step = step }
            }
        }
        push()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(knobs) { UserDefaults.standard.set(data, forKey: "bobina.m8.manopole") }
    }

    private func saveValues() {
        UserDefaults.standard.set(live.values, forKey: "bobina.m8.manopole.valori")
    }

    /// Passa le manopole al sequencer; se almeno una si muove da sola, il sequencer gira.
    func push() {
        guard let e = engine else { return }
        e.sequencer.updateKnobs(knobs, channel: e.channel, values: live.values)
        e.sequencer.setKnobsActive(knobs.contains { $0.motion != .none })
        if !knobs.contains(where: { $0.motion != .none }) {
            live.step = nil
            saveValues()
        }
    }

    var knob: M8Knob { knobs[selected] }

    // MARK: a mano

    /// Un valore a mano: se la manopola si muoveva da sola, si ferma.
    func set(_ i: Int, _ v: Int) {
        guard let e = engine else { return }
        let v = max(0, min(127, v))
        // se si muoveva, il sequencer ha già consegnato a CoreMIDI fino a 150 ms di onda: il valore a mano
        // parte dopo quelli, se no arriverebbe prima e verrebbe coperto (la lezione dell'OP-Z)
        let wasMoving = knobs[i].motion != .none
        if wasMoving { knobs[i].motion = .none }
        live.values[i] = v
        saveValues()
        e.io.send(M8.cc(knobs[i].cc, v, channel: e.channel), at: wasMoving ? e.io.now() + e.io.ticks(ms: 170) : 0)
        trace("→ M8 cc \(knobs[i].cc) = \(v) (\(knobs[i].name))")
    }

    /// Accende o spegne un modo di muoversi (onda o passi) per la manopola scelta.
    func toggle(_ m: M8Motion) {
        if knobs[selected].isGain && knobs[selected].motion == .none { return }
        knobs[selected].motion = knobs[selected].motion == m ? .none : m
    }

    /// Il nome nuovo; se diventa un guadagno, smette di muoversi da solo.
    func rename(_ i: Int, _ name: String) {
        knobs[i].name = name
        if knobs[i].isGain && knobs[i].motion != .none { knobs[i].motion = .none }
    }

    // MARK: collegare all'M8

    /// Il gesto del MIDI Mapping fatto da Bobina: tiene OPTION, muove il CC avanti e indietro, lascia OPTION.
    /// Prima, sull'M8, il cursore va messo sul parametro da collegare.
    func learn() {
        guard let e = engine, e.connected else { return }
        let k = knobs[selected]
        let v = live.values[selected]
        let other = v < 127 ? v + 1 : v - 1
        let ch = e.channel
        let pressed = !e.held.contains(.option)
        let now = e.io.now()
        if pressed { e.io.send(M8.noteOn(.option, channel: ch)) }
        e.io.send(M8.cc(k.cc, v, channel: ch), at: now + e.io.ticks(ms: 80))
        e.io.send(M8.cc(k.cc, other, channel: ch), at: now + e.io.ticks(ms: 140))
        e.io.send(M8.cc(k.cc, v, channel: ch), at: now + e.io.ticks(ms: 200))
        if pressed { e.io.send(M8.noteOff(.option, channel: ch), at: now + e.io.ticks(ms: 450)) }
        trace("M8: collego il cc \(k.cc) (\(k.name)) al parametro sotto il cursore")
    }

    // MARK: automazione a passi

    /// Scrittura in fila: il valore va nel passo del cursore (e si sente), il cursore va avanti.
    func writeStep(_ v: Int?, length: Int) {
        knobs[selected].steps[cursor] = v
        if let v = v, let e = engine {
            live.values[selected] = v
            e.io.send(M8.cc(knobs[selected].cc, v, channel: e.channel))
        }
        cursor = (cursor + 1) % max(1, length)
    }

    func backStep(length: Int) {
        cursor = (cursor - 1 + max(1, length)) % max(1, length)
    }

    func clearSteps() {
        knobs[selected].steps = Array(repeating: nil, count: 16)
        cursor = 0
    }
}
