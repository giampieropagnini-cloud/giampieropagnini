import Foundation
import SwiftUI

/// Tutto quello che l'OP-Z capisce via MIDI, dalla guida ufficiale (cap. 21) e dalle prove della community.
/// Le fonti e i dubbi sono in bobina/OPZ-RICERCA.md; quello che abbiamo misurato in bobina/PROVE-OPZ.md.
///
/// Ogni traccia ha il suo canale: di serie traccia N = canale N. Sulla macchina il tasto 1 delle impostazioni
/// MIDI («channel one to active», TEMPO + SCREEN) va spento, se no il canale 1 va alla traccia attiva e non al kick.
enum OPZ {

    // MARK: le 16 tracce

    struct Track: Identifiable, Hashable {
        let number: Int      // 1-16, uguale al canale
        let name: String
        let short: String
        var id: Int { number }
        /// Le tracce 1-8 fanno suono; le 9-16 comandano (effetti, nastro, master, perform, luci…).
        var sounds: Bool { number <= 8 }
    }

    static let tracks: [Track] = [
        Track(number: 1, name: "kick", short: "kick"),
        Track(number: 2, name: "snare", short: "snare"),
        Track(number: 3, name: "perc", short: "perc"),
        Track(number: 4, name: "sample", short: "sample"),
        Track(number: 5, name: "bass", short: "bass"),
        Track(number: 6, name: "lead", short: "lead"),
        Track(number: 7, name: "arp", short: "arp"),
        Track(number: 8, name: "chord", short: "chord"),
        Track(number: 9, name: "fx 1", short: "fx1"),
        Track(number: 10, name: "fx 2", short: "fx2"),
        Track(number: 11, name: "tape", short: "tape"),
        Track(number: 12, name: "master", short: "master"),
        Track(number: 13, name: "perform", short: "perf"),
        Track(number: 14, name: "module", short: "module"),
        Track(number: 15, name: "lights", short: "luci"),
        Track(number: 16, name: "motion", short: "motion"),
    ]

    static func track(_ n: Int) -> Track { tracks[max(1, min(16, n)) - 1] }

    /// I colori dei tasti traccia dell'OP-Z, per gruppi: batteria, synth, effetti e nastro, il resto.
    static func color(_ n: Int) -> Color {
        switch n {
        case 1...4: return Color(red: 1.0, green: 0.62, blue: 0.25)   // arancio
        case 5...8: return Color(red: 0.36, green: 0.80, blue: 0.55)  // verde
        case 9...12: return Color(red: 0.45, green: 0.66, blue: 1.0)  // azzurro
        default: return Color(red: 0.86, green: 0.55, blue: 0.95)     // viola
        }
    }

    /// Il colore della sezione OP-Z in Bobina: il grigio chiaro della macchina.
    static let tint = Color(red: 0.80, green: 0.84, blue: 0.88)

    // MARK: i parametri del suono (CC 1-18, relativi 32-49)

    struct Param: Identifiable, Hashable {
        let cc: Int
        let name: String
        var id: Int { cc }
        /// Lo stesso parametro coi CC relativi: 1 = un passo su, 127 = un passo giù.
        var relative: Int { cc + 31 }
    }

    static let params: [Param] = [
        Param(cc: 1, name: "parametro 1"),
        Param(cc: 2, name: "parametro 2"),
        Param(cc: 3, name: "filtro"),
        Param(cc: 4, name: "risonanza"),
        Param(cc: 5, name: "attacco"),
        Param(cc: 6, name: "decay"),
        Param(cc: 7, name: "sustain"),
        Param(cc: 8, name: "release"),
        Param(cc: 9, name: "lfo profondità"),
        Param(cc: 10, name: "lfo velocità"),
        Param(cc: 11, name: "lfo destinazione"),
        Param(cc: 12, name: "lfo forma"),
        Param(cc: 13, name: "mandata fx 1"),
        Param(cc: 14, name: "mandata fx 2"),
        Param(cc: 15, name: "pan"),
        Param(cc: 16, name: "volume"),
        Param(cc: 17, name: "portamento"),
        Param(cc: 18, name: "stile nota"),
    ]

    /// Sull'arp le quattro manopole dell'lfo comandano l'arpeggio.
    static func paramName(_ p: Param, track: Int) -> String {
        guard track == 7 else { return p.name }
        switch p.cc {
        case 9: return "arp velocità"
        case 10: return "arp pattern"
        case 11: return "arp stile"
        case 12: return "arp estensione"
        default: return p.name
        }
    }

    // MARK: gli effetti punch-in (traccia perform, canale 13)

    /// I dodici tasti della tastiera, da fa a mi. L'ottava bassa agisce sulla traccia, quella alta su tutte (da provare).
    static let punchIn: [String] = ["duck", "filter sweep", "loop 1", "stereo", "loop 2", "pitch",
                                    "follow / echo", "ramp up", "short", "ramp down", "long", "random"]

    /// Il fa della tastiera di serie dell'OP-Z: 53 (misurato il 4/10/2026: i primi tre tasti della fila di sotto = 53 55 57).
    static let keyboardF = 53
    /// Gli effetti punch-in (SHIFT + tastiera) escono come note molto basse sul canale 13: misurate 9 e 11 il 4/10/2026,
    /// quindi il fa è 5. Ottava bassa = la traccia attiva, quella sopra (17-28) = il gruppo.
    static let punchF = 5

    // MARK: messaggi

    static let clock: [UInt8] = [0xF8]
    static let start: [UInt8] = [0xFA]
    static let `continue`: [UInt8] = [0xFB]
    static let stop: [UInt8] = [0xFC]

    static func cc(_ number: Int, _ value: Int, channel: Int) -> [UInt8] {
        [0xB0 | UInt8((max(1, min(16, channel)) - 1) & 0x0F), UInt8(number & 0x7F), UInt8(max(0, min(127, value)))]
    }

    static func noteOn(_ note: Int, velocity: Int = 100, channel: Int) -> [UInt8] {
        [0x90 | UInt8((max(1, min(16, channel)) - 1) & 0x0F), UInt8(max(0, min(127, note))), UInt8(max(1, min(127, velocity)))]
    }

    static func noteOff(_ note: Int, channel: Int) -> [UInt8] {
        [0x80 | UInt8((max(1, min(16, channel)) - 1) & 0x0F), UInt8(max(0, min(127, note))), 0]
    }

    /// Pattern 1-16 (CC 103). Il canale è il progetto (1-10): così dice la community, da provare.
    static func pattern(_ n: Int, project: Int) -> [UInt8] { cc(103, n - 1, channel: project) }
    static func nextPattern() -> [UInt8] { cc(103, 16, channel: 1) }
    static func previousPattern() -> [UInt8] { cc(103, 17, channel: 1) }

    /// Muto (CC 53) o muto solo dell'audio (CC 54): la traccia è il canale.
    static func mute(_ track: Int, _ on: Bool, audioOnly: Bool = false) -> [UInt8] {
        cc(audioOnly ? 54 : 53, on ? 127 : 0, channel: track)
    }

    /// Gruppo di muti 1-10 (CC 55, valori 0-9).
    static func muteGroup(_ n: Int) -> [UInt8] { cc(55, n - 1, channel: 1) }

    /// Tempo (CC 56): il valore è il bpm, da 40 a 127 (oltre non si va: per tempi più alti serve il clock).
    static func tempo(_ bpm: Double) -> [UInt8] { cc(56, Int(bpm.rounded()), channel: 1) }
    static let tempoRange: ClosedRange<Double> = 40...127

    static func swing(_ value: Int) -> [UInt8] { cc(57, value, channel: 1) }

    /// «Tutte le note giù» (CC 123) sulle tracce che suonano: 1-8 e perform (13).
    static func allNotesOff() -> [UInt8] { (Array(1...8) + [13]).flatMap { cc(123, 0, channel: $0) } }

    // MARK: per il monitor

    static func describe(_ m: [UInt8]) -> String {
        guard let s = m.first else { return "" }
        switch s {
        case 0xF8: return "clock"
        case 0xFA: return "start"
        case 0xFB: return "continue"
        case 0xFC: return "stop"
        case 0xF0: return "sysex \(m.count) byte"
        default: break
        }
        let ch = Int(s & 0x0F) + 1
        let t = track(ch).name
        guard m.count >= 2 else { return "?" }
        switch s & 0xF0 {
        case 0x90 where m.count >= 3 && m[2] > 0: return "\(t) · nota \(m[1]) giù"
        case 0x80, 0x90: return "\(t) · nota \(m[1]) su"
        case 0xC0: return "program change \(m[1]) · canale \(ch)"
        case 0xE0: return "\(t) · pitch bend"
        case 0xB0 where m.count >= 3:
            let n = Int(m[1]), v = Int(m[2])
            switch n {
            case 1...18: return "\(t) · \(paramName(params[n - 1], track: ch)) \(v)"
            case 32...49: return "\(t) · \(params[n - 32].name) \(v == 1 ? "+" : "−")"
            case 50: return "\(t) · guadagno \(v)"
            case 52: return "guadagni a posto"
            case 53: return "\(t) · \(v > 0 ? "muto" : "suona")"
            case 54: return "\(t) · audio \(v > 0 ? "muto" : "acceso")"
            case 55: return "gruppo di muti \(v + 1)"
            case 56: return "tempo \(v)"
            case 57: return "swing \(v)"
            case 60: return "\(t) · \(v) passi"
            case 61: return "\(t) · lunghezza passo \(v)"
            case 62: return "\(t) · quantizza \(v)"
            case 63: return "\(t) · lunghezza nota \(v)"
            case 102: return "traccia/pagina \(v) · canale \(ch)"
            case 103: return v == 16 ? "pattern dopo" : v == 17 ? "pattern prima" : "pattern \(v + 1) · progetto \(ch)"
            case 123: return "\(t) · tutte le note su"
            default: return "\(t) · cc \(n) = \(v)"
            }
        default: return m.map { String(format: "%02x", $0) }.joined(separator: " ")
        }
    }
}

extension MIDIPort {
    var looksLikeOPZ: Bool {
        let n = name.lowercased()
        return n.contains("op-z") || n.contains("opz") || n.contains("op z")
    }
}

/// Come l'OP-Z sta a tempo con Bobina.
enum OPZSync: String, CaseIterable, Identifiable, Codable {
    /// Bobina manda il clock: l'OP-Z segue la griglia di Bobina, insieme a TX-6 e PO.
    /// Sull'OP-Z va acceso il tasto 4 delle impostazioni MIDI (midi clock in).
    case clock = "Bobina dà il clock"
    /// L'OP-Z va col suo tempo: Bobina manda start, stop e il tempo (CC 56, da 40 a 127).
    case own = "l'OP-Z va da solo"

    var id: String { rawValue }
}

/// Gli effetti di Bobina per Crea: lavorano sulle note che manda Bobina, non sul sequencer dell'OP-Z
/// (gli effetti punch-in dell'OP-Z toccano solo i suoi passi).
enum CreaFx: Int, CaseIterable, Identifiable, Codable {
    case loop1, loop2, rampUp, rampDown, pitch, random, short, long, echo, sweep, duck

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .loop1: return "loop 1"
        case .loop2: return "loop 2"
        case .rampUp: return "ramp up"
        case .rampDown: return "ramp down"
        case .pitch: return "pitch"
        case .random: return "random"
        case .short: return "short"
        case .long: return "long"
        case .echo: return "echo"
        case .sweep: return "filter sweep"
        case .duck: return "duck"
        }
    }

    /// Una riga per chi non se lo ricorda.
    var hint: String {
        switch self {
        case .loop1: return "ripete l'ultimo quarto"
        case .loop2: return "ripete gli ultimi due quarti"
        case .rampUp: return "rullata che accelera"
        case .rampDown: return "rullata che rallenta"
        case .pitch: return "synth un'ottava su"
        case .random: return "passi rimescolati"
        case .short: return "note cortissime"
        case .long: return "note tenute"
        case .echo: return "ogni nota ripetuta più piano"
        case .sweep: return "il filtro scende e risale"
        case .duck: return "il volume pompa a ogni battito"
        }
    }

    var color: Color { Color(hue: Double(rawValue) / 11, saturation: 0.55, brightness: 0.95) }
    var dark: Color { Color(hue: Double(rawValue) / 11, saturation: 0.6, brightness: 0.45) }
}
