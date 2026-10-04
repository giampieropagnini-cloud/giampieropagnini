import Foundation
import CoreMIDI
import SwiftUI

/// Il Dirtywave M8 comandato come un telecomando: gli otto tasti arrivano come note sul canale
/// «CONTROL MAP CHAN» (Project > MIDI > Settings, di serie 10). Note On = tasto giù, Note Off = su:
/// le combinazioni si fanno tenendo una nota accesa mentre se ne manda un'altra. Vedi M8-RICERCA.md.
enum M8 {

    /// Gli otto tasti. `rawValue` = la nota.
    enum Key: Int, CaseIterable, Identifiable {
        case play = 0, shift = 1, edit = 2, option = 3
        case left = 4, right = 5, up = 6, down = 7

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .play: return "play"
            case .shift: return "shift"
            case .edit: return "edit"
            case .option: return "option"
            case .left: return "sinistra"
            case .right: return "destra"
            case .up: return "su"
            case .down: return "giù"
            }
        }

        /// Il nome detto col Controllo Vocale: le frecce col loro nome, non «su» da solo (si confonde).
        var spoken: String {
            switch self {
            case .left, .right, .up, .down: return "freccia \(label)"
            default: return label
            }
        }

        var symbol: String? {
            switch self {
            case .left: return "arrowtriangle.left.fill"
            case .right: return "arrowtriangle.right.fill"
            case .up: return "arrowtriangle.up.fill"
            case .down: return "arrowtriangle.down.fill"
            default: return nil
            }
        }

        var isArrow: Bool { symbol != nil }
    }

    /// Com'è fatta la faccia dell'M8: la croce a sinistra, option ed edit in alto a destra,
    /// shift e play sotto. nil = posto vuoto.
    static let face: [[Key?]] = [
        [nil, .up, .option, .edit],
        [.left, .down, .right, nil],
        [nil, .shift, .play, nil]
    ]

    static func noteOn(_ k: Key, channel: Int) -> [UInt8] {
        [0x90 | UInt8((channel - 1) & 0x0F), UInt8(k.rawValue), 100]
    }

    static func noteOff(_ k: Key, channel: Int) -> [UInt8] {
        [0x80 | UInt8((channel - 1) & 0x0F), UInt8(k.rawValue), 0]
    }

    static func cc(_ number: Int, _ value: Int, channel: Int) -> [UInt8] {
        [0xB0 | UInt8((channel - 1) & 0x0F), UInt8(number & 0x7F), UInt8(max(0, min(127, value)))]
    }

    /// Il colore dell'M8 in Bobina: il viola delle frecce.
    static let color = Color(red: 0.62, green: 0.45, blue: 0.98)
}

extension MIDIPort {
    var looksLikeM8: Bool {
        let n = name.lowercased()
        return n.contains("m8") || n.contains("dirtywave")
    }
}

/// Il motore dell'M8: sceglie la porta, tiene i tasti agganciati, manda la manopola.
/// Niente cambia molte volte al secondo, quindi basta un oggetto solo.
final class M8Engine: ObservableObject {
    let io = MIDIIO()

    @Published var destinations: [MIDIPort] = []
    @Published var destinationID: MIDIUniqueID? {
        didSet {
            applyPort()
            if let d = destinationID { UserDefaults.standard.set(Int(d), forKey: "bobina.m8.porta") }
        }
    }

    var connected: Bool { io.destination != 0 }
    var connectedName: String { destinations.first(where: { $0.id == destinationID })?.name ?? "" }

    /// Il canale «CONTROL MAP CHAN» dell'M8.
    @Published var channel: Int { didSet { UserDefaults.standard.set(channel, forKey: "bobina.m8.canale") } }
    /// La manopola: un CC che sull'M8 si assegna in Project > MIDI Mapping.
    @Published var knobCC: Int { didSet { UserDefaults.standard.set(knobCC, forKey: "bobina.m8.cc") } }
    @Published private(set) var knob = 64
    /// I tasti tenuti giù.
    @Published private(set) var held: Set<M8.Key> = []

    init() {
        let d = UserDefaults.standard
        channel = d.object(forKey: "bobina.m8.canale") as? Int ?? 10
        knobCC = d.object(forKey: "bobina.m8.cc") as? Int ?? 1
        io.onSetupChanged = { [weak self] in self?.refreshPorts() }
        refreshPorts()
    }

    // MARK: porte

    func refreshPorts() {
        destinations = io.destinations()
        trace("M8 · destinazioni: " + destinations.map { $0.name }.joined(separator: " · "))
        if destinationID == nil || !destinations.contains(where: { $0.id == destinationID }) {
            let saved = MIDIUniqueID(truncatingIfNeeded: UserDefaults.standard.integer(forKey: "bobina.m8.porta"))
            if saved != 0, destinations.contains(where: { $0.id == saved }) {
                destinationID = saved
            } else {
                destinationID = destinations.first(where: { $0.looksLikeM8 })?.id
            }
        }
        applyPort()
    }

    private func applyPort() {
        let dest = destinations.first(where: { $0.id == destinationID })?.ref ?? 0
        if dest != io.destination {
            // se si cambia porta con un tasto tenuto, l'M8 vecchio non resta con shift giù
            releaseAll()
            io.use(destination: dest, source: 0)
            objectWillChange.send()
        }
    }

    // MARK: invio

    private func send(_ bytes: [UInt8], at time: MIDITimeStamp = 0) {
        io.send(bytes, at: time)
        trace("→ M8 " + bytes.map { String(format: "%02x", $0) }.joined(separator: " "))
    }

    /// La metà di sopra: un tocco. Se il tasto era tenuto, lo lascia.
    func touch(_ k: M8.Key) {
        if held.contains(k) { release(k) } else { tap(k) }
    }

    /// La metà di sotto: lo tiene giù, ritoccata lo lascia.
    func toggleHold(_ k: M8.Key) {
        if held.contains(k) { release(k) } else { hold(k) }
    }

    func hold(_ k: M8.Key) {
        guard !held.contains(k) else { return }
        held.insert(k)
        send(M8.noteOn(k, channel: channel))
    }

    func release(_ k: M8.Key) {
        guard held.contains(k) else { return }
        held.remove(k)
        send(M8.noteOff(k, channel: channel))
    }

    /// Premi e lascia dopo 60 ms: abbastanza perché l'M8 lo legga, troppo poco per la ripetizione.
    func tap(_ k: M8.Key) {
        send(M8.noteOn(k, channel: channel))
        io.send(M8.noteOff(k, channel: channel), at: io.now() + io.ticks(ms: 60))
    }

    func releaseAll() {
        guard !held.isEmpty else { return }
        let bytes = held.sorted { $0.rawValue < $1.rawValue }.flatMap { M8.noteOff($0, channel: channel) }
        held.removeAll()
        send(bytes)
    }

    func setKnob(_ v: Int) {
        let v = max(0, min(127, v))
        guard v != knob else { return }
        knob = v
        send(M8.cc(knobCC, v, channel: channel))
    }
}
