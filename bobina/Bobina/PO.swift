import Foundation

/// I Pocket Operator con l'adattatore MIDI di Hanz Tech (firmware 3.4.3). Qui ci sono solo byte e nomi.
/// L'adattatore capisce solo Note On (tasto giù) e Note Off (tasto su), sul canale 1: le combinazioni
/// si fanno tenendo accesa una nota mentre se ne manda un'altra. Le manopole A e B non si comandano.
/// Vedi PO-RICERCA.md.
enum PO {

    // MARK: i tasti

    /// I 23 tasti. `rawValue` = la nota dell'adattatore di serie.
    enum Key: Int, CaseIterable, Identifiable, Codable {
        case k1 = 68, k2 = 69, k3 = 70, k4 = 71
        case k5 = 72, k6 = 73, k7 = 74, k8 = 75
        case k9 = 60, k10 = 61, k11 = 62, k12 = 63
        case k13 = 64, k14 = 65, k15 = 66, k16 = 67
        case sound = 76, pattern = 77, play = 78, special = 79, fx = 80, bpm = 81, write = 82

        var id: Int { rawValue }
        var note: Int { rawValue }

        /// I tasti numerati, 1-16.
        static func number(_ n: Int) -> Key { numbers[max(1, min(16, n)) - 1] }
        static let numbers: [Key] = [.k1, .k2, .k3, .k4, .k5, .k6, .k7, .k8, .k9, .k10, .k11, .k12, .k13, .k14, .k15, .k16]
        static let functions: [Key] = [.sound, .pattern, .bpm, .special, .fx, .play, .write]

        /// 1-16, o nil per i tasti funzione.
        var number: Int? { Key.numbers.firstIndex(of: self).map { $0 + 1 } }
        var isNumber: Bool { number != nil }

        /// Il nome sulla serigrafia. Il tasto in alto a destra cambia da un modello all'altro.
        func label(_ model: Model) -> String {
            if let n = number { return "\(n)" }
            switch self {
            case .sound: return "sound"
            case .pattern: return "pattern"
            case .bpm: return "bpm"
            case .special: return model.special
            case .fx: return "fx"
            case .play: return "play"
            case .write: return "write"
            default: return ""
            }
        }
    }

    /// Com'è fatta la faccia: in alto sound, pattern, bpm e le due manopole; sotto i 16 tasti in un
    /// quadrato 4×4 e a destra la colonna tasto in alto, fx, play, write. nil = una manopola.
    static let face: [[Key?]] = [
        [.sound, .pattern, .bpm, nil, nil],
        [.k1, .k2, .k3, .k4, .special],
        [.k5, .k6, .k7, .k8, .fx],
        [.k9, .k10, .k11, .k12, .play],
        [.k13, .k14, .k15, .k16, .write]
    ]

    static func key(forNote n: Int) -> Key? { Key(rawValue: n) }

    // MARK: i messaggi

    static func noteOn(_ key: Key, channel: Int) -> [UInt8] {
        [0x90 | UInt8((channel - 1) & 0x0F), UInt8(key.note), 100]
    }

    static func noteOff(_ key: Key, channel: Int) -> [UInt8] {
        [0x80 | UInt8((channel - 1) & 0x0F), UInt8(key.note), 0]
    }

    /// Le scorciatoie a CC (con `po_cc_control = 1` nel configuratore): un messaggio al posto di quattro.
    /// Il valore è 0-15 per i tasti 1-16. Sopra 15 il firmware legge fuori dalla sua tabella: mai.
    enum Shortcut: UInt8, CaseIterable {
        case sound = 10, pattern = 11, volume = 12

        var name: String {
            switch self {
            case .sound: return "suono"
            case .pattern: return "pattern"
            case .volume: return "volume"
            }
        }

        /// Il tasto che si tiene premuto mentre si preme il numero.
        var held: Key {
            switch self {
            case .sound: return .sound
            case .pattern: return .pattern
            case .volume: return .bpm
            }
        }
    }

    static func cc(_ s: Shortcut, _ number: Int, channel: Int) -> [UInt8] {
        [0xB0 | UInt8((channel - 1) & 0x0F), s.rawValue, UInt8(max(1, min(16, number)) - 1)]
    }

    static let clock: [UInt8] = [0xF8]
    static let start: [UInt8] = [0xFA]
    static let stop: [UInt8] = [0xFC]

    /// Una riga per il monitor.
    static func describe(_ bytes: [UInt8], model: Model) -> String {
        var out: [String] = []
        var i = 0
        while i < bytes.count {
            let s = bytes[i]
            switch s & 0xF0 {
            case 0x90, 0x80:
                guard i + 2 < bytes.count else { i = bytes.count; continue }
                let on = s & 0xF0 == 0x90 && bytes[i + 2] > 0
                let name = key(forNote: Int(bytes[i + 1])).map { $0.isNumber ? "tasto \($0.label(model))" : $0.label(model) } ?? "nota \(bytes[i + 1])"
                out.append("\(name) \(on ? "giù" : "su")")
                i += 3
            case 0xB0:
                guard i + 2 < bytes.count else { i = bytes.count; continue }
                if let sc = Shortcut(rawValue: bytes[i + 1]) {
                    out.append("\(sc.name) \(Int(bytes[i + 2]) + 1)")
                } else {
                    out.append("cc \(bytes[i + 1]) = \(bytes[i + 2])")
                }
                i += 3
            default:
                switch s {
                case 0xF8: out.append("clock")
                case 0xFA: out.append("start")
                case 0xFB: out.append("continue")
                case 0xFC: out.append("stop")
                default: out.append(String(format: "%02x", s))
                }
                i += 1
            }
        }
        // il clock ripetuto non serve leggerlo dieci volte
        var compact: [String] = []
        for o in out where !(o == "clock" && compact.last == "clock") { compact.append(o) }
        return compact.joined(separator: " · ")
    }

    // MARK: i modelli

    enum Model: String, CaseIterable, Identifiable, Codable {
        case sub, tonic, ko, speak

        var id: String { rawValue }

        var name: String {
            switch self {
            case .sub: return "PO-14 sub"
            case .tonic: return "PO-32 tonic"
            case .ko: return "PO-33 K.O!"
            case .speak: return "PO-35 speak"
            }
        }

        var short: String {
            switch self {
            case .sub: return "sub"
            case .tonic: return "tonic"
            case .ko: return "K.O!"
            case .speak: return "speak"
            }
        }

        /// Il tasto in alto a destra.
        var special: String {
            switch self {
            case .sub: return "style"
            case .tonic: return "acc"
            case .ko, .speak: return "record"
            }
        }

        /// Cosa fanno i 16 tasti, in una riga.
        var keysNote: String {
            switch self {
            case .sub: return "i 16 tasti sono una tastiera su due ottave; il suono 16 è la micro batteria"
            case .tonic: return "16 suoni di batteria su quattro voci, una per colonna"
            case .ko: return "slot 1-8 melodici (tastiera), 9-16 batteria (16 fette)"
            case .speak: return "slot 1-8 melodici, 9-16 a fette; lo slot 16 è la batteria del tonic"
            }
        }

        /// I 16 effetti (fx + tasto). Sullo speak 1-8 sono gli stili di voce.
        var fx: [String] {
            switch self {
            case .sub:
                return ["low sample rate", "distortion", "bit crush", "delay", "lowpass", "lowpass sweep", "hipass", "hipass sweep",
                        "stutter 3", "stutter 8", "repeat 8", "repeat 6", "note shuffle", "feedback", "parameter lfo", "vibrato"]
            case .tonic:
                return ["half rate", "distortion", "squash", "echo fade", "pitch LFO", "EQ sweep", "mega morph", "pitch bend up",
                        "punch", "6/8 quantise", "beat-repeat", "beat-repeat faster", "FM", "granular", "reverse", "bouncing ball"]
            case .ko:
                return ["loop 16", "loop 12", "loop short", "loop shorter", "unison", "unison low", "octave up", "octave down",
                        "stutter 4", "stutter 3", "scratch", "scratch fast", "6/8 quantise", "retrigger", "reverse", "nessuno"]
            case .speak:
                return ["neutral", "autotune", "retro", "noise", "robot", "fifth", "vocoder", "synth",
                        "stutter sweep", "trance gate", "half rate", "16 bar build up", "6/8 quantise", "retrigger", "reverse", "nessuno"]
            }
        }

        /// Come si fa il cancello quando il PO suona il suo pattern: sul tonic tenendo i tasti (muto per colonna),
        /// sugli altri abbassando il volume (bpm + 1), che non è un muto vero.
        var gateByMute: Bool { self == .tonic }
    }
}

extension MIDIPort {
    /// L'adattatore di Hanz: col cavo «Teensy MIDI», col bluetooth «PO_MIDI_ADAPTER(BLE)» (da misurare).
    var looksLikePO: Bool {
        let n = name.lowercased()
        return n.contains("po_midi") || n.contains("po-ma") || n.contains("poma") || n.contains("po midi") || n.contains("teensy")
    }
}

/// Le tabelle MIDI dell'adattatore, da tenere in tasca. «community» = da misurare.
enum POTables {
    static let all: [TableSection] = [
        TableSection(
            title: "i tasti · canale 1",
            intro: "Note On = tasto giù, Note Off = tasto su. La velocity non conta. Queste sono le note di serie: dal configuratore web si cambiano.",
            rows: [
                TableRow(key: "68 69 70 71", what: "tasti 1 2 3 4"),
                TableRow(key: "72 73 74 75", what: "tasti 5 6 7 8"),
                TableRow(key: "60 61 62 63", what: "tasti 9 10 11 12"),
                TableRow(key: "64 65 66 67", what: "tasti 13 14 15 16"),
                TableRow(key: "76", what: "sound"),
                TableRow(key: "77", what: "pattern"),
                TableRow(key: "78", what: "play"),
                TableRow(key: "79", what: "il tasto in alto a destra", more: "record sul K.O! e sullo speak, acc sul tonic, style sul sub."),
                TableRow(key: "80", what: "fx"),
                TableRow(key: "81", what: "bpm"),
                TableRow(key: "82", what: "write"),
                TableRow(key: "A · B", what: "non si comandano", more: "Niente tempo fine, swing, parameter lock, nota di uno step.")
            ]
        ),
        TableSection(
            title: "le combinazioni",
            intro: "Si tiene accesa una nota e se ne manda un'altra. Il firmware stesso usa 20 ms fra un passo e l'altro.",
            rows: [
                TableRow(key: "77 on · 72 on · 72 off · 77 off", what: "pattern + 5"),
                TableRow(key: "81 on · 68-67 · 81 off", what: "volume 1-16 (bpm + tasto)"),
                TableRow(key: "79 on · 81 on/off · 79 off", what: "cambia modo di sync (SY0-SY5)"),
                TableRow(key: "81 da solo", what: "i tre tempi: 80 · 120 · 140", more: "Via MIDI il tempo del PO è solo questo, a meno che non arrivi il sync.")
            ]
        ),
        TableSection(
            title: "le scorciatoie a CC · spente di serie",
            intro: "Si accendono dal configuratore web (po_cc_control = 1). Un messaggio invece di quattro: col bluetooth conta.",
            rows: [
                TableRow(key: "cc 10 · 0-15", what: "sound + tasto 1-16"),
                TableRow(key: "cc 11 · 0-15", what: "pattern + tasto 1-16"),
                TableRow(key: "cc 12 · 0-15", what: "volume 1-16"),
                TableRow(key: "sopra 15", what: "mai", more: "Il firmware legge fuori dalla sua tabella.")
            ]
        ),
        TableSection(
            title: "trasporto e sync out",
            rows: [
                TableRow(key: "start · stop", what: "di serie passano e basta", more: "Con disable_transport = 0 premono play."),
                TableRow(key: "clock", what: "diventa il sync out: 2 impulsi per quarto", more: "Solo con disable_transport = 0. L'adattatore misura il bpm e poi va da solo: ai tempi non tondi il PO scivola piano piano.", community: true),
                TableRow(key: "tempi senza scivolamento", what: "60 · 75 · 80 · 100 · 120 · 125 · 150 · 200", community: true)
            ]
        ),
        TableSection(
            title: "cosa manda indietro",
            rows: [
                TableRow(key: "niente di suo", what: "non sa cosa c'è sul display né se il PO suona"),
                TableRow(key: "eco", what: "note, cc, start e stop tornano indietro sul bluetooth", more: "Il clock no.")
            ]
        )
    ]
}
