import Foundation

/// Il MIDI del TX-6 (firmware 1.3.x), dalla guida ufficiale e dalle misure della community
/// (soprattutto op1-lfo-hero). Qui ci sono solo byte. Canali: 1-6 le tracce, 7 il generale, 8 FX I, 9 FX II.
enum TX6 {

    static let masterChannel = 7
    static let fxChannels = [8, 9]

    // MARK: cosa capisce una traccia (canale = traccia, con MIDI → CTRL IN)

    enum Param: Int, CaseIterable, Identifiable, Codable {
        case volume, pan, gain, filter, eqHigh, eqMid, eqLow, comp, fx1Send, auxSend, aux2Send, sound, freq, length, detune, pattern

        var id: Int { rawValue }

        var cc: UInt8 {
            switch self {
            case .volume: return 7
            case .pan: return 8
            case .gain: return 9
            case .filter: return 74
            case .eqHigh: return 85
            case .eqMid: return 86
            case .eqLow: return 87
            case .comp: return 93
            case .fx1Send: return 91
            case .auxSend: return 92
            case .aux2Send: return 94
            case .sound: return 3
            case .freq: return 89
            case .length: return 90
            case .detune: return 95
            case .pattern: return 14
            }
        }

        var name: String {
            switch self {
            case .volume: return "volume"
            case .pan: return "pan"
            case .gain: return "guadagno"
            case .filter: return "filtro"
            case .eqHigh: return "alti"
            case .eqMid: return "medi"
            case .eqLow: return "bassi"
            case .comp: return "compressore"
            case .fx1Send: return "FX I"
            case .auxSend: return "aux"
            case .aux2Send: return "aux II"
            case .sound: return "suono"
            case .freq: return "frequenza"
            case .length: return "lunghezza"
            case .detune: return "detune"
            case .pattern: return "pattern"
            }
        }

        var group: String {
            switch self {
            case .volume, .pan, .gain: return "mixer"
            case .filter, .eqHigh, .eqMid, .eqLow, .comp: return "suono"
            case .fx1Send, .auxSend, .aux2Send: return "mandate"
            case .sound, .freq, .length, .detune, .pattern: return "synth"
            }
        }

        /// Il valore da cui parte Bobina: il TX-6 non dice com'è messo, quindi è un'ipotesi.
        var initial: Int {
            switch self {
            case .volume: return 100
            case .pan, .filter, .eqHigh, .eqMid, .eqLow, .freq, .length, .detune: return 64
            default: return 0
            }
        }

        /// Adatto a onde, deriva e inclinazione: suono e pattern vanno a scatti, non si modulano.
        var continuous: Bool { self != .sound && self != .pattern }

        func shown(_ v: Int) -> String {
            switch self {
            case .pan: return v == 64 ? "centro" : v < 64 ? "sx \(64 - v)" : "dx \(v - 64)"
            case .gain: return "+\(Int((Double(v) / 127 * 42).rounded())) dB"
            case .filter: return v == 64 ? "spento" : v < 64 ? "basso \(64 - v)" : "alto \(v - 64)"
            case .eqHigh, .eqMid, .eqLow:
                let db = Int((Double(v - 64) / 64 * 18).rounded())
                return db > 0 ? "+\(db) dB" : "\(db) dB"
            case .sound: return TX6.sounds[TX6.soundIndex(v)]
            case .pattern: return TX6.patternName(v)
            default: return "\(v)"
            }
        }
    }

    static let ccMute: UInt8 = 120

    /// Suoni del synth: l'ordine e i valori (indice × 14) sono quelli del telecomando di psimyn, da misurare.
    static let sounds = ["SIN", "TRI", "SQR", "SAW", "KICK", "SNARE", "CLAP", "HIHAT", "SAMPLE", "MIDI"]
    static func soundValue(_ i: Int) -> Int { max(0, min(127, i * 14)) }
    static func soundIndex(_ v: Int) -> Int { max(0, min(sounds.count - 1, Int((Double(v) / 14).rounded()))) }

    /// 22 pattern pronti, uno a caso, sei tuoi: 30 in tutto sui 128 valori (da misurare).
    static func patternValue(_ i: Int) -> Int { Int((127 * Double(i) / 29).rounded(.down)) }
    static func patternIndex(_ v: Int) -> Int { max(0, min(29, Int((Double(v) * 29 / 127).rounded()))) }
    static func patternName(_ v: Int) -> String {
        let i = patternIndex(v)
        return i < 22 ? "P\(i + 1)" : i == 22 ? "RND" : "U\(i - 22)"
    }

    // MARK: il generale (canale 7)

    static let ccMain: UInt8 = 7
    static let ccAux: UInt8 = 14
    static let ccCue: UInt8 = 15
    /// Un interruttore senza stato: ogni «acceso» fa partire o fermare.
    static let ccStartStop: UInt8 = 46
    /// Relativo in complemento a due: 1…63 alza, 127…65 abbassa. 64 ± n sbaglia di grosso (misurato).
    static let ccTempo: UInt8 = 47
    /// 0 = manopole e fader del TX-6 spenti, 127 = riaccesi.
    static let ccLocal: UInt8 = 122

    // MARK: gli effetti (canale 8 = FX I, 9 = FX II)

    static let ccFxOn: UInt8 = 82
    static let ccFxEngine: UInt8 = 15
    static let ccFxParams: [UInt8] = [12, 13, 14]
    /// Ritorno di FX I (solo canale 8).
    static let ccFxReturn: UInt8 = 7
    /// Dove sta FX II (solo canale 9).
    static let ccFx2Place: UInt8 = 9

    /// L'ordine degli effetti è quello del telecomando di psimyn; i 128 valori divisi in parti uguali (da misurare).
    /// Gli effetti nell'ordine della guida (CHO REV DLY · TRM FRZ TPE FLT DST CRU). Che il cc 15 li scelga in
    /// quest'ordine non è ancora misurato (prova 11): se il display del TX-6 dice un altro nome, si cambia qui.
    static let fxEngines = [["chorus", "riverbero", "delay"],
                            ["tremolo", "freeze", "tape", "filtro", "distorsione", "crush"]]

    /// I preset di un effetto, come li scrive il TX-6 (dalle pagine della guida): il parametro 1 li sceglie.
    /// nil = l'effetto ha valori continui (filtro: taglio e risonanza; tremolo 0-99; freeze − … +).
    static func fxPresets(_ fx: Int, _ engine: Int?) -> [String]? {
        guard let e = engine, fxEngines[fx].indices.contains(e) else { return nil }
        switch fxEngines[fx][e] {
        case "chorus": return ["subtle", "medium", "strong"]
        case "riverbero": return ["drone", "light", "small", "medium", "large"]
        case "delay": return ["1/8", "1/4", "1/2", "2/3", "3/4", "1", "3/2", "warp", "mash"]
        case "tape": return ["stop 1", "stop 2", "pong"]
        case "distorsione": return ["push", "drive", "blow", "dstroy"]
        case "crush": return ["shape", "bend", "chip", "bit"]
        default: return nil
        }
    }

    /// Il valore del parametro 1 per il preset i di n: il centro della sua fetta di 0-127. Così cade giusto sia se
    /// il TX-6 divide in fette uguali (v · n / 128) sia se arrotonda (v · (n − 1) / 127). Da confermare (prova 19).
    static func presetValue(_ i: Int, of n: Int) -> Int { min(127, Int((Double(i) + 0.5) * 128 / Double(n))) }
    static let fx2Places = ["tutto", "tr 1", "tr 2", "tr 3", "tr 4", "tr 5", "tr 6"]

    static func spread(_ i: Int, _ n: Int) -> Int {
        n < 2 ? 0 : Int((Double(i) * 127 / Double(n - 1)).rounded())
    }

    // MARK: le note

    /// Sul canale 7 do re mi fa sol la fanno suonare le tracce 1-6 alla loro frequenza.
    static let padSteps = [0, 2, 4, 5, 7, 9]

    // MARK: cosa manda in CTRL OUT (canale 1)

    enum Control: Equatable {
        case fader(Int)
        case knob(row: Int, track: Int)
        case trackButton(Int)
        case encoder
        case select, fx1, fx2, shift, aux, cue

        var name: String {
            switch self {
            case .fader(let t): return "fader \(t)"
            case .knob(let r, let t): return "manopola \(["blu", "arancione", "bianca"][r - 1]) \(t)"
            case .trackButton(let t): return "tasto traccia \(t)"
            case .encoder: return "select girato"
            case .select: return "select premuto"
            case .fx1: return "FX I"
            case .fx2: return "FX II"
            case .shift: return "shift"
            case .aux: return "aux"
            case .cue: return "cue"
            }
        }
    }

    static func control(_ cc: UInt8) -> Control? {
        switch cc {
        case 1...6: return .fader(Int(cc))
        case 7...24: return .knob(row: (Int(cc) - 7) / 6 + 1, track: (Int(cc) - 7) % 6 + 1)
        case 25...30: return .trackButton(Int(cc) - 24)
        case 31: return .encoder
        case 32: return .select
        case 33: return .fx1
        case 34: return .fx2
        case 35: return .shift
        case 36: return .aux
        case 37: return .cue
        default: return nil
        }
    }

    /// La manopola select in OUT manda passi relativi in complemento a due.
    static func relative(_ v: UInt8) -> Int { v < 64 ? Int(v) : Int(v) - 128 }

    // MARK: costruttori

    static func cc(_ number: UInt8, _ value: Int, channel: Int) -> [UInt8] {
        [0xB0 | UInt8((channel - 1) & 0x0F), number & 0x7F, UInt8(max(0, min(127, value)))]
    }

    static func noteOn(_ note: Int, channel: Int, velocity: Int = 100) -> [UInt8] {
        [0x90 | UInt8((channel - 1) & 0x0F), UInt8(max(0, min(127, note))), UInt8(max(1, min(127, velocity)))]
    }

    static func noteOff(_ note: Int, channel: Int) -> [UInt8] {
        [0x80 | UInt8((channel - 1) & 0x0F), UInt8(max(0, min(127, note))), 0]
    }

    /// Scena a, b, c = program 1, 2, 3 sul canale 7; sul filo 0, 1, 2 (da misurare).
    static func scene(_ i: Int) -> [UInt8] { [0xC6, UInt8(max(0, min(2, i)))] }

    /// Tempo relativo: +1 = 1, −1 = 127.
    static func tempoStep(_ delta: Int) -> [UInt8] {
        let d = max(-63, min(63, delta))
        return cc(ccTempo, d >= 0 ? d : 128 + d, channel: masterChannel)
    }

    static let start: [UInt8] = [0xFA]
    static let stop: [UInt8] = [0xFC]
    static let clock: [UInt8] = [0xF8]

    // MARK: lettura per il monitor

    static func noteName(_ n: Int) -> String {
        let names = ["do", "do#", "re", "re#", "mi", "fa", "fa#", "sol", "sol#", "la", "la#", "si"]
        return names[((n % 12) + 12) % 12] + "\(n / 12 - 1)"
    }

    static func describe(_ m: [UInt8], incoming: Bool) -> String {
        guard let status = m.first else { return "" }
        switch status {
        case 0xF0: return "sysex, \(m.count) byte"
        case 0xF8: return "clock"
        case 0xFA: return "start"
        case 0xFB: return "continue"
        case 0xFC: return "stop"
        default: break
        }
        let ch = Int(status & 0x0F) + 1
        switch status & 0xF0 {
        case 0xB0 where m.count >= 3:
            let n = m[1], v = Int(m[2])
            if incoming {
                if ch == 1, let c = control(n) {
                    if c == .encoder { let d = relative(m[2]); return "select girato \(d > 0 ? "+" : "")\(d)" }
                    if case .fader = c { return "\(c.name) = \(v)" }
                    if case .knob = c { return "\(c.name) = \(v)" }
                    return "\(c.name) \(v > 0 ? "premuto" : "lasciato")"
                }
                return "cc \(n) = \(v) · ch \(ch)"
            }
            if ch <= 6 {
                if n == ccMute { return "traccia \(ch) \(v >= 64 ? "muta" : "riaccesa")" }
                if let p = Param.allCases.first(where: { $0.cc == n }) { return "\(p.name) traccia \(ch) = \(p.shown(v))" }
            } else if ch == masterChannel {
                switch n {
                case ccMain: return "volume main = \(v)"
                case ccAux: return "volume aux = \(v)"
                case ccCue: return "volume cue = \(v)"
                case ccStartStop: return "start/stop"
                case ccTempo: return "tempo \(relative(m[2]) > 0 ? "+" : "")\(relative(m[2]))"
                case ccLocal: return v >= 64 ? "manopole del TX-6 accese" : "manopole del TX-6 spente"
                default: break
                }
            } else if ch == 8 || ch == 9 {
                let fx = ch == 8 ? "FX I" : "FX II"
                switch n {
                case ccFxOn: return "\(fx) \(v >= 64 ? "acceso" : "spento")"
                case ccFxEngine: return "\(fx) effetto = \(v)"
                case 12, 13, 14: return "\(fx) parametro \(Int(n) - 11) = \(v)"
                case ccFxReturn where ch == 8: return "FX I ritorno = \(v)"
                case ccFx2Place where ch == 9: return "FX II su \(v)"
                default: break
                }
            }
            return "cc \(n) = \(v) · ch \(ch)"
        case 0x90 where m.count >= 3:
            let what = ch == masterChannel ? "pad" : "traccia \(ch)"
            return m[2] > 0 ? "nota \(noteName(Int(m[1]))) · \(what)" : "nota off \(noteName(Int(m[1])))"
        case 0x80 where m.count >= 3:
            return "nota off \(noteName(Int(m[1])))"
        case 0xC0 where m.count >= 2:
            return ch == masterChannel ? "scena \(["a", "b", "c"][min(2, Int(m[1]))])" : "program \(m[1]) · ch \(ch)"
        default:
            return m.map { String(format: "%02x", $0) }.joined(separator: " ")
        }
    }
}
