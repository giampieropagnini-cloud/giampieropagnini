import Foundation

/// Il MIDI del TP-7 (firmware 1.1.11), dalla guida ufficiale e dalle misure della community
/// (soprattutto op1-lfo-hero, che l'ha misurato con gli strumenti). Qui ci sono solo byte.
enum TP7 {

    // MARK: trasporto (messaggi in tempo reale, funzionano con MIDI su off, cue e sync)

    /// Riavvolge e suona dall'inizio.
    static let start: [UInt8] = [0xFA]
    /// Suona da dove si trova. Dopo un arma (cc 14) registra.
    static let continuePlay: [UInt8] = [0xFB]
    /// Si ferma dov'è. Un secondo stop da fermo riavvolge all'inizio.
    static let stop: [UInt8] = [0xFC]

    // MARK: cosa capisce (dal telefono al TP-7)

    /// Volume della traccia: il canale 1-6 è la traccia.
    static let ccVolume: UInt8 = 7
    /// Guadagno degli ingressi: il canale 1-3 è l'ingresso, 0-127 = 0-42 dB.
    static let ccGain: UInt8 = 9
    /// Arma la registrazione (64-127 acceso).
    static let ccArm: UInt8 = 14
    /// Modo «segna cue»: acceso le note segnano, spento le richiamano.
    static let ccCueRec: UInt8 = 16
    /// Loop: 1 inizio, 2 fine, 0 spento. Sempre in quest'ordine.
    static let ccLoop: UInt8 = 17
    /// La leva finta: 64 centro. Si somma al nastro: ogni passo vale circa ×0,26.
    static let ccLever: UInt8 = 18
    /// Muto della traccia: il canale 1-6 è la traccia (64-127 muto).
    static let ccMute: UInt8 = 120

    static let leverCenter = 64
    /// A nastro fermo la leva vale come una velocità: 64 fermo, 68 avanti ×1, 60 indietro ×1
    /// (lucidyan/tp7-midi, MIDI_SPEC.md). È il ▶ che funziona anche in cue, dove start e continue vengono ignorati.
    /// Il 30/9/2026 avevamo scelto 60: suonava, ma all'indietro, e si fermava arrivato all'inizio.
    /// Durante il play (dopo ▶ o un cue) la leva cambia significato: 64 è il play normale e il fermo è 60 + pitch bend +708.
    static let leverCuePlay = 68
    /// Mentre suona, 60 più il pitch bend +708 lo tengono fermo come sotto il dito.
    static let leverHalt = 60
    static let haltBend = 708

    /// Il pitch bend va da mezza velocità a doppia: un'ottava sotto, un'ottava sopra.
    static let minSpeed = 0.5
    static let maxSpeed = 2.0

    /// I sedici pad di Bobina usano le note 36-51, come i pad controller.
    static let padBase = 36

    // MARK: cosa manda (in modalità ctrl, canale 1)

    static let ccWheel: UInt8 = 30
    static let buttonNames: [UInt8: String] = [
        20: "▲ su", 21: "▼ giù", 22: "● rec", 23: "▶ play", 24: "■ stop",
        25: "−", 26: "+", 27: "M memo", 28: "mode"
    ]

    // MARK: costruttori di messaggi

    static func cc(_ number: UInt8, _ value: Int, channel: Int = 1) -> [UInt8] {
        let status: UInt8 = 0xB0 | UInt8((channel - 1) & 0x0F)
        return [status, number & 0x7F, UInt8(max(0, min(127, value)))]
    }

    /// Pitch bend da −8192 a +8191.
    static func bend(_ value: Int) -> [UInt8] {
        let n = max(0, min(16383, value + 8192))
        return [0xE0, UInt8(n & 0x7F), UInt8((n >> 7) & 0x7F)]
    }

    static func noteOn(_ note: Int) -> [UInt8] { [0x90, UInt8(note & 0x7F), 100] }
    static func noteOff(_ note: Int) -> [UInt8] { [0x80, UInt8(note & 0x7F), 0] }

    /// Misurato: velocità ≈ 2^(bend / 8192). −8192 = ×0,5, 0 = ×1, +8191 = ×2.
    static func bendFor(speed: Double) -> Int {
        let s = max(minSpeed, min(maxSpeed, speed))
        return max(-8192, min(8191, Int((8192 * log2(s)).rounded())))
    }

    static func speedFor(bend: Int) -> Double {
        pow(2, Double(bend) / 8192)
    }

    /// La bobina in ctrl manda passi relativi in complemento a due.
    static func wheelDelta(_ value: UInt8) -> Int {
        value < 64 ? Int(value) : Int(value) - 128
    }

    // MARK: lettura per il monitor

    static func describe(_ m: [UInt8], incoming: Bool) -> String {
        guard let status = m.first else { return "" }
        let kind = status & 0xF0
        let channel = Int(status & 0x0F) + 1
        switch status {
        case 0xF0: return "sysex, \(m.count) byte"
        case 0xF8: return "clock"
        case 0xFA: return "start"
        case 0xFB: return "continue"
        case 0xFC: return "stop"
        default: break
        }
        switch kind {
        case 0xB0 where m.count >= 3:
            let n = m[1], v = Int(m[2])
            if incoming {
                if n == ccWheel { return "bobina \(wheelDelta(m[2]) > 0 ? "+" : "")\(wheelDelta(m[2]))" }
                if let name = buttonNames[n] { return "\(name) \(v > 0 ? "premuto" : "lasciato") · cc \(n)" }
                return "cc \(n) = \(v) · ch \(channel)"
            }
            switch n {
            case ccVolume: return "volume traccia \(channel) = \(v)"
            case ccMute: return "traccia \(channel) \(v >= 64 ? "muta" : "riaccesa")"
            case ccGain: return "guadagno ingresso \(channel) = \(v)"
            case ccArm: return v >= 64 ? "arma rec" : "disarma rec"
            case ccCueRec: return v >= 64 ? "cue: segna" : "cue: richiama"
            case ccLoop: return ["loop spento", "loop: inizio", "loop: fine"][min(2, v)]
            case ccLever: return "leva = \(v)"
            default: return "cc \(n) = \(v) · ch \(channel)"
            }
        case 0xE0 where m.count >= 3:
            let v = (Int(m[2]) << 7 | Int(m[1])) - 8192
            return incoming ? "leva \(v)" : String(format: "velocità ×%.2f", speedFor(bend: v))
        case 0x90 where m.count >= 3:
            return m[2] > 0 ? "nota \(m[1]) (cue)" : "nota \(m[1]) off"
        case 0x80 where m.count >= 3:
            return "nota \(m[1]) off"
        default:
            return m.map { String(format: "%02x", $0) }.joined(separator: " ")
        }
    }
}
