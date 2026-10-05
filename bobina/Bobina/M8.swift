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

    /// Mute e solo delle tracce 1-8: note 12-19 e 20-27 sullo stesso canale. Come un tasto «toggle»
    /// di un controller: Note On accende, Note Off spegne.
    static func mute(_ track: Int, _ on: Bool, channel: Int) -> [UInt8] { trackNote(11 + track, on, channel) }
    static func solo(_ track: Int, _ on: Bool, channel: Int) -> [UInt8] { trackNote(19 + track, on, channel) }

    private static func trackNote(_ note: Int, _ on: Bool, _ channel: Int) -> [UInt8] {
        let ch = UInt8((channel - 1) & 0x0F)
        return on ? [0x90 | ch, UInt8(note), 127] : [0x80 | ch, UInt8(note), 0]
    }

    static func cc(_ number: Int, _ value: Int, channel: Int) -> [UInt8] {
        [0xB0 | UInt8((channel - 1) & 0x0F), UInt8(number & 0x7F), UInt8(max(0, min(127, value)))]
    }

    // MARK: SysEx dello schermo remoto (firmware 6)

    static let header: [UInt8] = [0xF0, 0x00, 0x02, 0x61, 0x00]

    static func sysex(_ body: [UInt8]) -> [UInt8] { header + body + [0xF7] }

    /// I dati arrivano a 7 bit: ogni 8° byte porta i bit alti dei 7 che seguono.
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
    /// Il microfono dell'iPhone tenuto acceso col cavo dell'M8 attaccato.
    let mic = M8Mic()
    private(set) lazy var sequencer = M8Sequencer(io: io)
    /// Bobina che suona l'M8 (scheda Suona).
    let player = M8Player()

    /// L'M8 va a tempo con Bobina (start, clock, stop).
    @Published private(set) var running = false
    /// Il bpm di Bobina, intero: si ridisegna solo quando cambia il numero.
    @Published private(set) var bpm = Int(BobinaClock.shared.bpm.rounded())
    private var bpmObserver: NSObjectProtocol?

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
    /// Il firmware letto dall'M8 (es. «6.1.2»). nil = non ancora letto; «prima del 6» = non ha risposto.
    @Published private(set) var firmware: String?
    @Published private(set) var model: String?
    private var probing = false

    /// Le tracce (1-8) col mute o col solo accesi da Bobina. Quello che cambi sull'M8 a mano qui non si vede.
    @Published private(set) var muted: Set<Int> = []
    @Published private(set) var soloed: Set<Int> = []

    /// I tasti tenuti giù.
    @Published private(set) var held: Set<M8.Key> = []

    init() {
        let d = UserDefaults.standard
        channel = d.object(forKey: "bobina.m8.canale") as? Int ?? 10
        knobCC = d.object(forKey: "bobina.m8.cc") as? Int ?? 1
        io.onSetupChanged = { [weak self] in self?.refreshPorts() }
        io.onReceive = { [weak self] bytes, _ in self?.received(bytes) }
        bpmObserver = NotificationCenter.default.addObserver(forName: .bobinaBPM, object: nil, queue: .main) { [weak self] n in
            guard let self = self, let v = n.object as? Double, Int(v.rounded()) != self.bpm else { return }
            self.bpm = Int(v.rounded())
        }
        refreshPorts()
        player.attach(self)
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
            // l'ascolto è la sorgente dello stesso M8: serve per leggere il firmware
            io.use(destination: dest, source: dest == 0 ? 0 : (POEngine.source(of: dest) ?? 0))
            if dest != 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.readFirmware() }
            }
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

    /// Live mode: dal Song, shift + sinistra (manuale p. 10). Un tocco entra, un altro esce.
    func liveMode() { combo([.shift, .left]) }

    /// Tieni i primi, tocca l'ultimo, lascia. I tasti già tenuti dalla faccia restano giù.
    func combo(_ keys: [M8.Key]) {
        guard let last = keys.last else { return }
        let first = keys.dropLast().filter { !held.contains($0) }
        let now = io.now()
        send(first.flatMap { M8.noteOn($0, channel: channel) })
        io.send(M8.noteOn(last, channel: channel), at: now + io.ticks(ms: 40))
        io.send(M8.noteOff(last, channel: channel), at: now + io.ticks(ms: 110))
        io.send(first.reversed().flatMap { M8.noteOff($0, channel: channel) }, at: now + io.ticks(ms: 160))
    }

    // MARK: tempo

    func toggleRun() {
        running.toggle()
        sequencer.setTransport(running)
    }

    func setBPM(_ v: Int) {
        let v = max(20, min(300, v))
        BobinaClock.shared.setBPM(Double(v))
        bpm = Int(BobinaClock.shared.bpm.rounded())
    }

    func toggleMute(_ t: Int) {
        let on = !muted.contains(t)
        if on { muted.insert(t) } else { muted.remove(t) }
        send(M8.mute(t, on, channel: channel))
    }

    func toggleSolo(_ t: Int) {
        let on = !soloed.contains(t)
        if on { soloed.insert(t) } else { soloed.remove(t) }
        send(M8.solo(t, on, channel: channel))
    }

    /// Spegne tutti i mute e i solo, in un pacchetto solo.
    func clearTracks() {
        let bytes = (1...8).flatMap { M8.mute($0, false, channel: channel) + M8.solo($0, false, channel: channel) }
        muted.removeAll()
        soloed.removeAll()
        send(bytes)
    }

    func setKnob(_ v: Int) {
        let v = max(0, min(127, v))
        guard v != knob else { return }
        knob = v
        send(M8.cc(knobCC, v, channel: channel))
    }

    // MARK: firmware

    /// Accende per un attimo lo schermo remoto (SysEx, dal firmware 6): l'M8 risponde con modello e
    /// firmware, poi si spegne subito per non riempire il cavo. Vedi M8-RICERCA.md, punto 8.
    func readFirmware() {
        guard connected, io.source != 0 else { firmware = nil; return }
        probing = true
        firmware = nil
        send(M8.sysex([0x00, 0x44]))   // 'D' stacca
        io.send(M8.sysex([0x00, 0x45]), at: io.now() + io.ticks(ms: 80))   // 'E' accende
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self, self.probing else { return }
            self.probing = false
            self.send(M8.sysex([0x00, 0x44]))
            self.firmware = "nessuna risposta: prima del 6"
        }
    }

    private func received(_ bytes: [UInt8]) {
        guard probing else { return }
        trace("M8 ← " + bytes.prefix(24).map { String(format: "%02x", $0) }.joined(separator: " ") + (bytes.count > 24 ? " … (\(bytes.count))" : ""))
        guard bytes.count > 7, Array(bytes.prefix(5)) == M8.header else { return }
        let data = M8.unpack(Array(bytes[5..<(bytes.count - 1)]))
        // 0xFF modello, maggiore, minore, correzione, font
        guard let i = data.firstIndex(of: 0xFF), i + 4 < data.count, data[i + 1] <= 3 else { return }
        probing = false
        send(M8.sysex([0x00, 0x44]))
        model = ["Headless", "Beta M8", "M8 Model:01", "M8 Model:02"][Int(data[i + 1])]
        firmware = "\(data[i + 2]).\(data[i + 3]).\(data[i + 4])"
        trace("M8 firmware \(firmware ?? "") · \(model ?? "")")
    }
}
