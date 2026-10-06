import Foundation
import SwiftUI

/// I byte del Korg NTS-1 digital kit mkII, dal documento ufficiale «MIDI Implementation» v1.00 (18/3/2024).
/// Vedi NTS1-RICERCA.md. Il suono si comanda con un CC per manopola; i CC arrivano solo se sull'NTS-1
/// il parametro globale «MIDI short message» è acceso, il tempo solo se «Clock» è su Auto.
enum NTS1 {

    // MARK: manopole (CC, 0-127)

    /// Un parametro continuo: il suo CC (la metà alta, MSB) e dove sta nel suono salvato (10 bit, 0-1023).
    enum Knob: String, CaseIterable, Identifiable {
        case oscA, oscB, lfoRate, lfoDepth
        case cutoff, resonance, sweepDepth, sweepRate
        case attack, release, tremoloDepth, tremoloRate
        case modA, modB
        case delayA, delayB, delayMix
        case reverbA, reverbB, reverbMix
        case arpLength, volume

        var id: String { rawValue }

        var cc: Int {
            switch self {
            case .oscA: return 54
            case .oscB: return 55
            case .lfoRate: return 24
            case .lfoDepth: return 26
            case .cutoff: return 43
            case .resonance: return 44
            case .sweepDepth: return 45
            case .sweepRate: return 46
            case .attack: return 16
            case .release: return 19
            case .tremoloDepth: return 20
            case .tremoloRate: return 21
            case .modA: return 28
            case .modB: return 29
            case .delayA: return 30
            case .delayB: return 31
            case .delayMix: return 33
            case .reverbA: return 34
            case .reverbB: return 35
            case .reverbMix: return 36
            case .arpLength: return 119
            case .volume: return 7
            }
        }

        /// Il nome sul tasto e per il Controllo Vocale.
        var label: String {
            switch self {
            case .oscA: return "forma"
            case .oscB: return "timbro"
            case .lfoRate: return "lfo velocità"
            case .lfoDepth: return "lfo quanto"
            case .cutoff: return "taglio"
            case .resonance: return "risonanza"
            case .sweepDepth: return "sweep quanto"
            case .sweepRate: return "sweep velocità"
            case .attack: return "attacco"
            case .release: return "rilascio"
            case .tremoloDepth: return "tremolo quanto"
            case .tremoloRate: return "tremolo velocità"
            case .modA: return "mod A"
            case .modB: return "mod B"
            case .delayA: return "delay A"
            case .delayB: return "delay B"
            case .delayMix: return "delay mix"
            case .reverbA: return "reverb A"
            case .reverbB: return "reverb B"
            case .reverbMix: return "reverb mix"
            case .arpLength: return "lunghezza"
            case .volume: return "volume"
            }
        }

        /// Dove sta nel suono salvato (due byte). nil = non c'è.
        var programOffset: Int? {
            switch self {
            case .oscA: return 60
            case .oscB: return 62
            case .lfoRate: return 64
            case .lfoDepth: return 66
            case .attack: return 90
            case .release: return 92
            case .tremoloRate: return 94
            case .tremoloDepth: return 96
            case .cutoff: return 102
            case .resonance: return 104
            case .sweepRate: return 106
            case .sweepDepth: return 108
            case .modA: return 144
            case .modB: return 146
            case .delayA: return 200
            case .delayB: return 202
            case .delayMix: return 204
            case .reverbA: return 256
            case .reverbB: return 258
            case .reverbMix: return 260
            case .arpLength, .volume: return nil
            }
        }

        /// Il valore scritto accanto: la lunghezza dell'arpeggio va da 1 a 24 passi.
        func shown(_ v: Int) -> String {
            self == .arpLength ? "\(1 + v * 23 / 127) passi" : "\(v)"
        }

        static func byCC(_ cc: Int) -> Knob? { allCases.first { $0.cc == cc } }
    }

    // MARK: scelte (un CC con pochi valori)

    enum Choice: String, CaseIterable, Identifiable {
        case osc, filter, eg, mod, delay, reverb, arpPattern, arpIntervals

        var id: String { rawValue }

        var cc: Int {
            switch self {
            case .osc: return 53
            case .filter: return 42
            case .eg: return 14
            case .mod: return 88
            case .delay: return 89
            case .reverb: return 90
            case .arpPattern: return 117
            case .arpIntervals: return 118
            }
        }

        var title: String {
            switch self {
            case .osc: return "oscillatore"
            case .filter: return "filtro"
            case .eg: return "inviluppo"
            case .mod: return "mod"
            case .delay: return "delay"
            case .reverb: return "reverb"
            case .arpPattern: return "arpeggio"
            case .arpIntervals: return "accordo"
            }
        }

        var items: [String] {
            switch self {
            case .osc: return ["user", "saw", "tri", "sqr", "vpm", "noise", "waves"]
            case .filter: return ["lp2", "lp4", "bp2", "bp4", "hp2", "hp4", "senza"]
            case .eg: return ["adsr", "ahr", "ar", "ar loop", "aperto"]
            case .mod: return ["spento", "chorus", "ensemble", "phaser", "flanger", "soft clip", "hard clip", "sine fold", "fuzz"]
            case .delay: return ["spento", "stereo", "mono", "ping pong", "highpass", "tape", "one",
                                 "stereo bpm", "mono bpm", "ping pong bpm", "high bpm", "tape bpm", "doubling"]
            case .reverb: return ["spento", "hall", "smooth", "arena", "plate", "room", "early", "space", "riser", "submarine", "horror"]
            case .arpPattern: return ["su", "giù", "su-giù", "giù-su", "converge", "diverge", "conv-div", "div-conv", "a caso", "stocastico"]
            case .arpIntervals: return ["ottava", "maggiore", "sospeso", "aumentato", "minore", "diminuito"]
            }
        }

        /// Il valore da mandare per ogni voce (tabella 1-1 del documento Korg).
        var sendValues: [Int] {
            switch self {
            case .osc, .filter: return [0, 18, 36, 54, 72, 90, 127]
            case .eg: return [0, 25, 50, 75, 127]
            case .mod: return [0, 14, 28, 42, 56, 70, 84, 98, 127]
            case .delay: return [0, 9, 18, 27, 36, 45, 54, 63, 72, 81, 90, 99, 127]
            case .reverb: return [0, 11, 22, 33, 44, 55, 66, 77, 88, 99, 127]
            case .arpPattern: return [0, 12, 24, 36, 48, 60, 72, 84, 96, 127]
            case .arpIntervals: return [0, 21, 42, 63, 84, 127]
            }
        }

        /// Da dove comincia ogni voce quando il valore arriva dall'NTS-1 (tabella 2-1).
        private var starts: [Int] {
            switch self {
            case .osc: return [0, 18, 36, 54, 72, 90, 107]
            case .filter: return [0, 18, 36, 54, 72, 90, 108]
            case .eg: return [0, 25, 50, 75, 100]
            case .mod: return [0, 14, 28, 42, 56, 70, 84, 98, 112]
            case .delay: return [0, 9, 18, 27, 36, 45, 54, 63, 72, 81, 90, 99, 108]
            case .reverb: return [0, 11, 22, 33, 44, 55, 66, 77, 88, 99, 110]
            case .arpPattern: return [0, 12, 24, 36, 48, 60, 72, 84, 96, 108]
            case .arpIntervals: return [0, 21, 42, 63, 84, 105]
            }
        }

        func index(of value: Int) -> Int {
            starts.lastIndex { value >= $0 } ?? 0
        }

        static func byCC(_ cc: Int) -> Choice? { allCases.first { $0.cc == cc } }
    }

    static func cc(_ number: Int, _ value: Int, channel: Int) -> [UInt8] {
        [0xB0 | UInt8((channel - 1) & 0x0F), UInt8(number & 0x7F), UInt8(max(0, min(127, value)))]
    }

    // MARK: SysEx

    /// F0 42 3g 00 01 73: g è il canale globale dell'NTS-1 (0-15).
    static func header(channel: Int) -> [UInt8] {
        [0xF0, 0x42, 0x30 | UInt8((channel - 1) & 0x0F), 0x00, 0x01, 0x73]
    }

    static func sysex(_ function: UInt8, _ data: [UInt8] = [], channel: Int) -> [UInt8] {
        header(channel: channel) + [function] + data + [0xF7]
    }

    /// «Search Device»: risponde da qualunque canale, col suo canale globale e il firmware.
    static func search(echo: UInt8) -> [UInt8] { [0xF0, 0x42, 0x50, 0x00, echo & 0x7F, 0xF7] }

    /// La risposta a «Search Device»: canale globale (1-16) e firmware «maggiore.minore».
    static func searchReply(_ b: [UInt8]) -> (channel: Int, version: String)? {
        guard b.count >= 15, b[0] == 0xF0, b[1] == 0x42, b[2] == 0x50, b[3] == 0x01, b[6] == 0x73 else { return nil }
        let minor = Int(b[10]) | Int(b[11]) << 7
        let major = Int(b[12]) | Int(b[13]) << 7
        return (Int(b[4] & 0x0F) + 1, "\(major).\(String(format: "%02d", minor))")
    }

    static let programRequest: UInt8 = 0x10
    static let globalRequest: UInt8 = 0x0E
    static let programDump: UInt8 = 0x40
    static let globalDump: UInt8 = 0x51
    static let programChanged: UInt8 = 0x7E
    static let ack: UInt8 = 0x23

    /// Il corpo di un SysEx Korg dell'NTS-1 (la funzione e i dati, senza F7), se lo è.
    static func body(_ bytes: [UInt8]) -> (function: UInt8, data: [UInt8])? {
        guard bytes.count >= 8, bytes[0] == 0xF0, bytes[1] == 0x42, bytes[2] & 0xF0 == 0x30,
              bytes[3] == 0x00, bytes[4] == 0x01, bytes[5] == 0x73, bytes.last == 0xF7 else { return nil }
        return (bytes[6], Array(bytes[7..<(bytes.count - 1)]))
    }

    /// 7 bit → 8 bit (NOTE 1): ogni gruppo di 8 byte comincia con i bit alti dei 7 che seguono.
    static func unpack(_ packed: [UInt8]) -> [UInt8] {
        var out: [UInt8] = []
        var i = 0
        while i < packed.count {
            let msbs = packed[i]
            for j in 0..<7 where i + 1 + j < packed.count {
                out.append(packed[i + 1 + j] | (((msbs >> j) & 1) << 7))
            }
            i += 8
        }
        return out
    }

    /// 8 bit → 7 bit, il contrario di `unpack`.
    static func pack(_ data: [UInt8]) -> [UInt8] {
        var out: [UInt8] = []
        var i = 0
        while i < data.count {
            let group = Array(data[i..<min(i + 7, data.count)])
            var msbs: UInt8 = 0
            for (j, b) in group.enumerated() { msbs |= ((b >> 7) & 1) << j }
            out.append(msbs)
            out.append(contentsOf: group.map { $0 & 0x7F })
            i += 7
        }
        return out
    }

    // MARK: il suono (tabella 2, 505 byte)

    struct Program {
        var name = ""
        var oscName = ""
        var modName = ""
        var delayName = ""
        var reverbName = ""
        /// Le manopole, già portate a 0-127.
        var knobs: [Knob: Int] = [:]
        /// Le scelte che il suono dice con un numero (inviluppo, filtro, arpeggio).
        var choices: [Choice: Int] = [:]

        init?(_ d: [UInt8]) {
            guard d.count >= 328, String(bytes: d[0..<4], encoding: .ascii) == "PROG" else { return nil }
            name = Program.text(d, 12, 16)
            oscName = Program.text(d, 40, 20)
            modName = Program.text(d, 124, 20)
            delayName = Program.text(d, 180, 20)
            reverbName = Program.text(d, 236, 20)
            for k in Knob.allCases {
                if let o = k.programOffset, let v = Program.word(d, o, max: 1023) { knobs[k] = v >> 3 }
            }
            if d[88] <= 4 { choices[.eg] = Int(d[88]) }
            if d[100] <= 6 { choices[.filter] = Int(d[100]) }
            if let v = Program.word(d, 322, max: 9) { choices[.arpPattern] = v }
            if let v = Program.word(d, 324, max: 5) { choices[.arpIntervals] = v }
            if let v = Program.word(d, 326, max: 24), v >= 1 { knobs[.arpLength] = (v - 1) * 127 / 23 }
        }

        static func text(_ d: [UInt8], _ at: Int, _ count: Int) -> String {
            let bytes = d[at..<(at + count)].prefix { $0 != 0 }.filter { $0 >= 32 && $0 < 127 }
            return String(bytes: bytes, encoding: .ascii)?.trimmingCharacters(in: .whitespaces) ?? ""
        }

        /// Due byte: il documento dice «alto, basso». Se così non torna, si prova al contrario.
        static func word(_ d: [UInt8], _ at: Int, max: Int) -> Int? {
            let hiLo = Int(d[at]) << 8 | Int(d[at + 1])
            if hiLo <= max { return hiLo }
            let loHi = Int(d[at + 1]) << 8 | Int(d[at])
            return loHi <= max ? loHi : nil
        }
    }

    // MARK: le impostazioni globali (tabella 1)

    struct Global {
        var bytes: [UInt8]

        init?(_ d: [UInt8]) {
            guard d.count >= 16, String(bytes: d[0..<4], encoding: .ascii) == "GLOB" else { return nil }
            bytes = d
        }

        var clockAuto: Bool { bytes[11] == 1 }
        var shortMessages: Bool { bytes[12] == 1 }
        var channel: Int { Int(bytes[15] & 0x0F) + 1 }

        /// Le stesse impostazioni con i messaggi brevi accesi e il clock su Auto: quello che serve a Bobina.
        func readyForBobina() -> Global {
            var g = self
            g.bytes[11] = 1
            g.bytes[12] = 1
            return g
        }
    }

    /// Il colore dell'NTS-1 in Bobina: il verde acqua del suo schermo.
    static let color = Color(red: 0.32, green: 0.84, blue: 0.78)
}

extension MIDIPort {
    var looksLikeNTS1: Bool {
        let n = name.lowercased()
        return n.contains("nts-1") || n.contains("nts1") || n.contains("nts–1")
    }
}
