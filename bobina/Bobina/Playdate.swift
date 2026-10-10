import Foundation
import CoreMIDI
import Network
import SwiftUI
import UIKit

/// Il Playdate (10/10/2026): Bobina gira al ponte sul Mac di casa (domani sul Raspberry da portare in giro) le note
/// che arrivano da una macchina, per esempio il TX-6 con una traccia a suono MIDI, e il tempo di Bobina. Il ponte
/// le suona nei synth di Modular Play: moduli Serial Note Input e Serial Clock Input.
/// Va via Wi-Fi: TCP sulla porta 8791, MIDI così com'è (il ponte lo legge come una macchina collegata al Mac).
enum Playdate {
    static let color = Color(red: 1.0, green: 0.77, blue: 0.0)
    static let port: UInt16 = 8791
    /// Dove sta il ponte. Il nome si risolve da solo sulla rete di casa, niente indirizzi da scrivere.
    static let hosts = [("Mac di casa", "Opens-Mac-mini.local"), ("Raspberry", "bobina-pi.local")]
    /// Lo schermo e i tasti del Playdate, nel browser.
    static let remote = "http://Opens-Mac-mini.local:8790"
}

/// Il filo fra Bobina e il ponte del Playdate. Ha un client CoreMIDI tutto suo: ascolta la macchina scelta senza
/// toccare la sua sezione (CoreMIDI consegna a tutti quelli che ascoltano, non si ruba niente a nessuno).
final class PlaydateLink: ObservableObject {
    @Published private(set) var connected = false
    @Published private(set) var sources: [String] = []
    @Published private(set) var sentNotes = 0
    @Published private(set) var lastNote: UInt8?
    /// Le macchine a cui Bobina può parlare: il ponte le mostra sulla tastiera degli amici.
    @Published private(set) var destinations: [String] = []
    @Published private(set) var friendNotes = 0
    @Published private(set) var lastFriend = ""

    @Published var host: String {
        didSet { UserDefaults.standard.set(host, forKey: Keys.host); setTarget(host) }
    }
    /// La macchina da ascoltare, per nome. "" = nessuna.
    @Published var sourceName: String {
        didSet { UserDefaults.standard.set(sourceName, forKey: Keys.source); attachSources() }
    }
    /// 0 = tutte le tracce; 1-16 = solo quel canale (sul TX-6 il canale è la traccia, 7 la batteria).
    @Published var channel: Int {
        didSet { UserDefaults.standard.set(channel, forKey: Keys.channel); updateFilter() }
    }
    @Published var notesOn: Bool {
        didSet { UserDefaults.standard.set(notesOn, forKey: Keys.notes); updateFilter() }
    }
    /// Il tempo di Bobina (BobinaClock) va al Playdate come clock MIDI, 24 per battito.
    @Published var clockOn: Bool {
        didSet { UserDefaults.standard.set(clockOn, forKey: Keys.clock); updateFilter() }
    }
    /// La tastiera degli amici (pagina /amici del ponte) può suonare le macchine collegate a Bobina.
    @Published var friendsOn: Bool {
        didSet {
            UserDefaults.standard.set(friendsOn, forKey: Keys.friends)
            updateFilter()
            if !friendsOn { queue.async { [weak self] in self?.releaseFriends() } }
        }
    }

    private enum Keys {
        static let host = "bobina.playdate.ponte"
        static let source = "bobina.playdate.sorgente"
        static let channel = "bobina.playdate.canale"
        static let notes = "bobina.playdate.note"
        static let clock = "bobina.playdate.tempo"
        static let friends = "bobina.playdate.amici"
    }

    /// Quello che leggono i fili di CoreMIDI e del tempo, copiato sotto lock dal main thread.
    private struct Filter {
        var notes = true
        var clock = true
        var channel = 0
        var friends = true
    }

    private let lock = NSLock()
    private var filter = Filter()
    private var held: UInt8?  // la nota accesa sul Playdate, da spegnere se Bobina va in secondo piano
    private var machineList: [String] = []  // copia di `destinations` per il filo della rete, sotto lock

    private let queue = DispatchQueue(label: "bobina.playdate", qos: .userInteractive)
    private var conn: NWConnection?  // solo su `queue`
    private var ready = false  // solo su `queue`
    private var target = ""  // solo su `queue`
    private var envelope: [UInt8]?  // busta SysEx in arrivo dal ponte, solo su `queue`
    private var friendHeld: [String: Set<UInt16>] = [:]  // note degli amici ancora giù: macchina → canale·nota, solo su `queue`

    private var client = MIDIClientRef()
    private var inPort = MIDIPortRef()
    private var outPort = MIDIPortRef()
    private var attached: [MIDIEndpointRef] = []
    private var status: UInt8 = 0  // running status, solo sul filo di CoreMIDI
    private var data: [UInt8] = []

    init() {
        let d = UserDefaults.standard
        host = d.string(forKey: Keys.host) ?? Playdate.hosts[0].1
        sourceName = d.string(forKey: Keys.source) ?? ""
        channel = d.object(forKey: Keys.channel) as? Int ?? 0
        notesOn = d.object(forKey: Keys.notes) as? Bool ?? true
        clockOn = d.object(forKey: Keys.clock) as? Bool ?? true
        friendsOn = d.object(forKey: Keys.friends) as? Bool ?? true
        updateFilter()

        MIDIClientCreateWithBlock("Bobina Playdate" as CFString, &client) { [weak self] note in
            if note.pointee.messageID == .msgSetupChanged {
                DispatchQueue.main.async { self?.refreshSources() }
            }
        }
        MIDIInputPortCreateWithBlock(client, "Playdate ingresso" as CFString, &inPort) { [weak self] list, _ in
            self?.read(list)
        }
        MIDIOutputPortCreate(client, "Playdate uscita" as CFString, &outPort)
        refreshSources()
        setTarget(host)

        let tempo = Thread { [weak self] in self?.clockLoop() }
        tempo.qualityOfService = .userInteractive
        tempo.name = "bobina.playdate.tempo"
        tempo.start()

        let nc = NotificationCenter.default
        nc.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            // fra pochi secondi iOS sospende Bobina: la nota tenuta si spegne adesso, se no il Playdate la tiene
            self?.releaseHeld()
        }
        nc.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.setTarget(self.host)
        }
    }

    // MARK: macchine

    func refreshSources() {
        var names: [String] = []
        for i in 0..<MIDIGetNumberOfSources() {
            let n = name(of: MIDIGetSource(i))
            if !names.contains(n) { names.append(n) }
        }
        sources = names
        var outs: [String] = []
        for i in 0..<MIDIGetNumberOfDestinations() {
            let n = name(of: MIDIGetDestination(i))
            if !outs.contains(n) { outs.append(n) }
        }
        if outs != destinations {
            destinations = outs
            lock.lock()
            machineList = outs
            lock.unlock()
            queue.async { [weak self] in self?.sendMachineList() }
        }
        // la prima volta, se c'è il TX-6, si ascolta lui
        if UserDefaults.standard.string(forKey: Keys.source) == nil, let tx6 = names.first(where: { $0.uppercased().contains("TX-6") }) {
            sourceName = tx6
        }
        attachSources()
    }

    private func attachSources() {
        for s in attached { MIDIPortDisconnectSource(inPort, s) }
        attached = []
        guard !sourceName.isEmpty else { return }
        for i in 0..<MIDIGetNumberOfSources() {
            let s = MIDIGetSource(i)
            if name(of: s) == sourceName, MIDIPortConnectSource(inPort, s, nil) == noErr {
                attached.append(s)
            }
        }
        trace("playdate: ascolto \(sourceName) (\(attached.count))")
    }

    private func name(of endpoint: MIDIEndpointRef) -> String {
        var cf: Unmanaged<CFString>?
        if MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &cf) == noErr, let s = cf?.takeRetainedValue() {
            return s as String
        }
        return "senza nome"
    }

    private func updateFilter() {
        lock.lock()
        filter = Filter(notes: notesOn, clock: clockOn, channel: channel, friends: friendsOn)
        lock.unlock()
    }

    private var currentFilter: Filter {
        lock.lock()
        defer { lock.unlock() }
        return filter
    }

    // MARK: note dalla macchina (filo di CoreMIDI)

    private func read(_ list: UnsafePointer<MIDIPacketList>) {
        let count = Int(list.pointee.numPackets)
        guard count > 0 else { return }
        let listOffset = MemoryLayout<MIDIPacketList>.offset(of: \MIDIPacketList.packet) ?? 4
        let dataOffset = MemoryLayout<MIDIPacket>.offset(of: \MIDIPacket.data) ?? 10
        let lengthOffset = MemoryLayout<MIDIPacket>.offset(of: \MIDIPacket.length) ?? 8
        var packet = UnsafeRawPointer(list).advanced(by: listOffset).assumingMemoryBound(to: MIDIPacket.self)
        let f = currentFilter
        for i in 0..<count {
            // come in MIDIIO: i pacchetti sono impaccati a 4 byte, i campi si leggono senza allineamento
            let base = UnsafeRawPointer(packet)
            let length = Int(base.loadUnaligned(fromByteOffset: lengthOffset, as: UInt16.self))
            let raw = UnsafeRawBufferPointer(start: base.advanced(by: dataOffset), count: length)
            for b in raw { feed(b, f) }
            if i < count - 1 { packet = UnsafePointer(MIDIPacketNext(packet)) }
        }
    }

    /// Tiene solo note accese e spente. Il clock della macchina no: il tempo lo dà Bobina (il clock del TX-6
    /// via bluetooth faceva andare a singhiozzo i comandi, 7/10/2026).
    private func feed(_ b: UInt8, _ f: Filter) {
        if b >= 0xF8 { return }
        if b & 0x80 != 0 {
            status = b < 0xF0 ? b : 0  // SysEx e compagnia: i loro dati si saltano
            data.removeAll()
            return
        }
        guard status != 0 else { return }
        data.append(b)
        let kind = status & 0xF0
        guard data.count == ((kind == 0xC0 || kind == 0xD0) ? 1 : 2) else { return }
        defer { data.removeAll() }
        guard f.notes, kind == 0x80 || kind == 0x90 else { return }
        guard f.channel == 0 || Int(status & 0x0F) + 1 == f.channel else { return }
        let on = kind == 0x90 && data[1] > 0
        send([status, data[0], data[1]])
        lock.lock()
        if on { held = data[0] } else if held == data[0] { held = nil }
        lock.unlock()
        let note = data[0]
        DispatchQueue.main.async {
            if on {
                self.sentNotes += 1
                self.lastNote = note
            }
        }
    }

    /// Una nota sola, per sentire se il filo arriva fino al Playdate.
    func testNote() {
        send([0x90, 60, 100])
        sentNotes += 1
        lastNote = 60
        queue.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.sendOnQueue([0x80, 60, 0]) }
    }

    private func releaseHeld() {
        lock.lock()
        let note = held
        held = nil
        lock.unlock()
        if let note = note { send([0x80, note, 0]) }
    }

    // MARK: il tempo di Bobina (filo suo)

    /// Legge la griglia di BobinaClock senza esserne membro e manda al ponte start, 24 clock per battito e stop.
    private func clockLoop() {
        var last: Int?
        var generation = -1
        var running = false
        while true {
            let line = BobinaClock.shared.snapshot()
            let on = currentFilter.clock && line.running
            if on {
                let beat = line.beat(at: mach_absolute_time())
                if beat >= 0 {
                    let tick = Int((beat * 24).rounded(.down))
                    if !running || line.generation != generation {
                        send([0xFA])
                        running = true
                        generation = line.generation
                        last = tick - 1
                    }
                    if let l = last, tick > l {
                        // dopo una pausa (Bobina sospesa) niente raffica: un clock solo e si riparte da qui
                        send([0xF8])
                        if tick - l > 3 { trace("playdate: tempo ripreso, salto \(tick - l) clock") }
                        last = tick
                    }
                }
            } else if running {
                send([0xFC])
                running = false
                last = nil
            }
            // spento: un'occhiata ogni 50 ms basta, acceso: ogni millisecondo per stare a tempo
            usleep(on || running ? 1000 : 50_000)
        }
    }

    // MARK: rete

    private func setTarget(_ host: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.target = host
            self.connect()
        }
    }

    /// Solo su `queue`.
    private func connect() {
        conn?.cancel()
        ready = false
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 5
        let c = NWConnection(host: NWEndpoint.Host(target), port: NWEndpoint.Port(rawValue: Playdate.port)!,
                             using: NWParameters(tls: nil, tcp: tcp))
        conn = c
        c.stateUpdateHandler = { [weak self, weak c] state in
            guard let self = self, let c = c, c === self.conn else { return }
            switch state {
            case .ready:
                self.ready = true
                self.publish(true)
                self.sendMachineList()
                self.receive(c)
            case .failed, .waiting:
                self.retry(c)
            case .cancelled:
                self.ready = false
                self.publish(false)
            default:
                break
            }
        }
        c.start(queue: queue)
    }

    /// Dal ponte arrivano solo buste SysEx F0 7D <json> F7: {"d": "TX-6", "m": [144, 60, 100]} è una nota
    /// della tastiera degli amici per quella macchina.
    private func receive(_ c: NWConnection) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self, weak c] data, _, done, error in
            guard let self = self, let c = c, c === self.conn else { return }
            if let data = data {
                for b in data {
                    if var part = self.envelope {
                        if b == 0xF7 {
                            self.envelope = nil
                            self.openEnvelope(part)
                        } else if b >= 0x80 {
                            self.envelope = nil
                        } else {
                            part.append(b)
                            self.envelope = part
                        }
                    } else if b == 0xF0 {
                        self.envelope = []
                    }
                }
            }
            if done || error != nil { self.retry(c) } else { self.receive(c) }
        }
    }

    /// Solo su `queue`.
    private func openEnvelope(_ part: [UInt8]) {
        guard part.first == 0x7D, currentFilter.friends,
              let obj = try? JSONSerialization.jsonObject(with: Data(part.dropFirst())) as? [String: Any],
              let machine = obj["d"] as? String, let m = obj["m"] as? [Int], m.count == 3 else { return }
        let bytes = m.map { UInt8(clamping: $0) }
        let kind = bytes[0] & 0xF0
        guard kind == 0x80 || kind == 0x90 else { return }
        midiSend(bytes, to: machine)
        let key = UInt16(bytes[0] & 0x0F) << 8 | UInt16(bytes[1])
        if kind == 0x90 && bytes[2] > 0 {
            friendHeld[machine, default: []].insert(key)
            let label = "\(machine) · \(PlaydateTabs.noteName(bytes[1]))"
            DispatchQueue.main.async {
                self.friendNotes += 1
                self.lastFriend = label
            }
        } else {
            friendHeld[machine]?.remove(key)
        }
    }

    /// Solo su `queue`: il ponte è sparito o gli amici sono stati spenti, le loro note tenute si spengono.
    private func releaseFriends() {
        for (machine, keys) in friendHeld {
            for k in keys { midiSend([0x80 | UInt8(k >> 8), UInt8(k & 0xFF), 0], to: machine) }
        }
        friendHeld = [:]
    }

    /// Solo su `queue`: al ponte la lista delle macchine, per la tastiera degli amici.
    private func sendMachineList() {
        lock.lock()
        let list = machineList
        lock.unlock()
        guard let json = try? JSONSerialization.data(withJSONObject: ["macchine": list]),
              let text = String(data: json, encoding: .utf8) else { return }
        // dentro una SysEx stanno solo byte sotto 0x80: le lettere accentate diventano \uXXXX
        var ascii = ""
        for u in text.unicodeScalars {
            if u.value < 0x80 { ascii.unicodeScalars.append(u) } else {
                for unit in String(u).utf16 { ascii += String(format: "\\u%04x", unit) }
            }
        }
        sendOnQueue([0xF0, 0x7D] + Array(ascii.utf8) + [0xF7])
    }

    /// Manda un messaggio a tutte le destinazioni CoreMIDI con quel nome (il TX-6 col cavo o col bluetooth).
    private func midiSend(_ bytes: [UInt8], to machine: String) {
        var buffer = [UInt8](repeating: 0, count: 256)
        buffer.withUnsafeMutableBytes { raw in
            let list = raw.baseAddress!.assumingMemoryBound(to: MIDIPacketList.self)
            let first = MIDIPacketListInit(list)
            bytes.withUnsafeBufferPointer { b in
                _ = MIDIPacketListAdd(list, 256, first, 0, b.count, b.baseAddress!)
            }
            for i in 0..<MIDIGetNumberOfDestinations() {
                let d = MIDIGetDestination(i)
                if name(of: d) == machine { MIDISend(outPort, d, list) }
            }
        }
    }

    /// Solo su `queue`: il ponte non risponde (Mac spento, fuori casa): si riprova ogni 2 secondi.
    private func retry(_ c: NWConnection) {
        releaseFriends()
        envelope = nil
        ready = false
        publish(false)
        c.cancel()
        queue.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self, self.conn === c else { return }
            self.connect()
        }
    }

    private func publish(_ value: Bool) {
        DispatchQueue.main.async {
            if self.connected != value { self.connected = value }
        }
    }

    private func send(_ bytes: [UInt8]) {
        queue.async { [weak self] in self?.sendOnQueue(bytes) }
    }

    private func sendOnQueue(_ bytes: [UInt8]) {
        guard ready, let c = conn else { return }
        c.send(content: Data(bytes), completion: .contentProcessed { _ in })
    }
}
