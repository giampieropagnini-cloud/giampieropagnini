import Foundation
import CoreMIDI

/// Il suono che c'è adesso sull'NTS-1: manopole e scelte. Sta a parte dal motore perché quando giri una
/// manopola sull'NTS-1 arrivano decine di CC al secondo: si raccolgono e la scheda Suono si ridisegna
/// al massimo dieci volte al secondo, e solo lei (non la pagina col menu «passa a…»).
final class NTS1Sound: ObservableObject {
    @Published private(set) var knobs: [NTS1.Knob: Int] = [:]
    @Published private(set) var choices: [NTS1.Choice: Int] = [:]
    /// I nomi che il suono salvato dà a oscillatore ed effetti (anche quelli user, che non hanno un tasto).
    @Published private(set) var names: [NTS1.Choice: String] = [:]
    @Published private(set) var programName = ""

    private var pendingKnobs: [NTS1.Knob: Int] = [:]
    private var pendingChoices: [NTS1.Choice: Int] = [:]
    private var flushing = false

    func value(_ k: NTS1.Knob) -> Int { knobs[k] ?? (k == .volume ? 100 : 64) }

    /// Un valore cambiato da Bobina: subito.
    func set(_ k: NTS1.Knob, _ v: Int) {
        guard knobs[k] != v else { return }
        knobs[k] = v
    }

    func set(_ c: NTS1.Choice, _ i: Int) {
        guard choices[c] != i else { return }
        choices[c] = i
        names[c] = nil
    }

    /// Un valore arrivato dall'NTS-1: si raccoglie e si mostra fra un decimo di secondo.
    func incoming(_ k: NTS1.Knob, _ v: Int) {
        pendingKnobs[k] = v
        scheduleFlush()
    }

    func incoming(_ c: NTS1.Choice, _ i: Int) {
        pendingChoices[c] = i
        scheduleFlush()
    }

    private func scheduleFlush() {
        guard !flushing else { return }
        flushing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.flushing = false
            var k = self.knobs
            for (key, v) in self.pendingKnobs { k[key] = v }
            var c = self.choices
            var n = self.names
            for (key, i) in self.pendingChoices { c[key] = i; n[key] = nil }
            self.pendingKnobs.removeAll()
            self.pendingChoices.removeAll()
            if k != self.knobs { self.knobs = k }
            if c != self.choices { self.choices = c; self.names = n }
        }
    }

    /// Tutto il suono letto dall'NTS-1 in un colpo.
    func load(_ p: NTS1.Program) {
        var k = knobs
        for (key, v) in p.knobs { k[key] = v }
        knobs = k
        var c = choices
        for (key, i) in p.choices { c[key] = i }
        var n: [NTS1.Choice: String] = [:]
        n[.osc] = p.oscName
        n[.mod] = p.modName
        n[.delay] = p.delayName
        n[.reverb] = p.reverbName
        // il tipo che ha un tasto si accende se il nome combacia; gli altri (user) restano col nome solo
        for (key, name) in n {
            if let i = key.items.firstIndex(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) { c[key] = i } else { c[key] = nil }
        }
        choices = c
        names = n.filter { !$0.value.isEmpty }
        programName = p.name
    }
}

/// Un suono salvato in Bobina: i byte dell'NTS-1 così come arrivano, da rimandargli tali e quali.
struct NTS1Saved: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    /// I dati a 7 bit della funzione 40 (576 byte).
    var data: [UInt8]
    var date = Date()
}

/// Il motore dell'NTS-1: la porta, il canale, il suono, le banche, il tempo.
/// Quello che cambia molte volte al secondo sta in `sound` e in `player.live`.
final class NTS1Engine: ObservableObject {
    let io = MIDIIO()
    let sound = NTS1Sound()
    let player = NTS1Player()
    private(set) lazy var sequencer = NTS1Sequencer(io: io)

    @Published var destinations: [MIDIPort] = []
    @Published var destinationID: MIDIUniqueID? {
        didSet {
            applyPort()
            if let d = destinationID { UserDefaults.standard.set(Int(d), forKey: "bobina.nts1.porta") }
        }
    }

    var connected: Bool { io.destination != 0 }
    var connectedName: String { destinations.first(where: { $0.id == destinationID })?.name ?? "" }

    /// Il canale globale dell'NTS-1. Bobina lo legge da sola al collegamento.
    @Published var channel: Int { didSet { UserDefaults.standard.set(channel, forKey: "bobina.nts1.canale"); player.push() } }
    /// Il firmware letto dall'NTS-1. nil = non ha ancora risposto.
    @Published private(set) var firmware: String?
    /// Le impostazioni globali lette dall'NTS-1. nil = non ancora lette.
    @Published private(set) var global: NTS1.Global?
    /// L'ultima cosa che l'NTS-1 ha detto di un SysEx (salvato, errore…).
    @Published private(set) var lastStatus: String?

    @Published private(set) var saved: [NTS1Saved] = []
    /// Il suono salvato che Bobina ha appena rimandato all'NTS-1.
    @Published private(set) var loadedID: UUID?

    /// L'NTS-1 va a tempo con Bobina (start, clock, stop): arpeggio, sequencer e delay bpm.
    @Published private(set) var running = false
    /// Partito con la sua sequenza (start) o solo col tempo.
    @Published private(set) var withSequence = false
    @Published private(set) var bpm = Int(BobinaClock.shared.bpm.rounded())
    private var bpmObserver: NSObjectProtocol?

    private var saveNext = false
    private var refreshPending = false

    init() {
        let d = UserDefaults.standard
        channel = d.object(forKey: "bobina.nts1.canale") as? Int ?? 1
        saved = NTS1Engine.readSaved()
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
        trace("NTS-1 · destinazioni: " + destinations.map { $0.name }.joined(separator: " · "))
        if destinationID == nil || !destinations.contains(where: { $0.id == destinationID }) {
            let saved = MIDIUniqueID(truncatingIfNeeded: UserDefaults.standard.integer(forKey: "bobina.nts1.porta"))
            if saved != 0, destinations.contains(where: { $0.id == saved }) {
                destinationID = saved
            } else {
                destinationID = destinations.first(where: { $0.looksLikeNTS1 })?.id
            }
        }
        applyPort()
    }

    private func applyPort() {
        let dest = destinations.first(where: { $0.id == destinationID })?.ref ?? 0
        guard dest != io.destination else { return }
        player.releaseAll()
        io.use(destination: dest, source: dest == 0 ? 0 : (POEngine.source(of: dest) ?? 0))
        firmware = nil
        global = nil
        if dest != 0 {
            // note rimaste accese da prima (Bobina chiusa o reinstallata con un pad tenuto): silenzio
            send(NTS1.cc(123, 0, channel: channel))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.readAll() }
        }
        objectWillChange.send()
    }

    // MARK: invio

    func send(_ bytes: [UInt8], at time: MIDITimeStamp = 0) {
        io.send(bytes, at: time)
        trace("→ NTS-1 " + bytes.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " ") + (bytes.count > 16 ? " … (\(bytes.count))" : ""))
    }

    /// Una manopola da Bobina.
    func set(_ k: NTS1.Knob, _ v: Int) {
        let v = max(0, min(127, v))
        sound.set(k, v)
        send(NTS1.cc(k.cc, v, channel: channel))
        // l'onda a tempo scende dal valore della manopola: se cambia, cambia anche lei
        if k == player.waveKnob { player.push() }
    }

    /// Un tasto di scelta da Bobina.
    func set(_ c: NTS1.Choice, _ i: Int) {
        guard c.sendValues.indices.contains(i) else { return }
        sound.set(c, i)
        send(NTS1.cc(c.cc, c.sendValues[i], channel: channel))
    }

    // MARK: leggere l'NTS-1

    /// Al collegamento: chi sei (canale e firmware), le impostazioni, il suono di adesso.
    func readAll() {
        guard connected else { return }
        send(NTS1.search(echo: 0x11))
        // se non risponde alla ricerca, si prova col canale che si conosce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self = self else { return }
            self.send(NTS1.sysex(NTS1.globalRequest, channel: self.channel))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.readProgram() }
        }
    }

    func readProgram() {
        send(NTS1.sysex(NTS1.programRequest, channel: channel))
    }

    /// Accende sull'NTS-1 i messaggi brevi e il clock automatico, lasciando il resto com'è.
    func fixGlobal() {
        guard let g = global else { return }
        let ready = g.readyForBobina()
        send(NTS1.sysex(NTS1.globalDump, NTS1.pack(ready.bytes), channel: channel))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.send(NTS1.sysex(NTS1.globalRequest, channel: self.channel))
        }
    }

    private func received(_ bytes: [UInt8]) {
        // l'NTS-1 manda il suo clock di continuo (circa 50 al secondo): qui non serve, si scarta subito
        guard let status = bytes.first, status < 0xF8 else { return }
        switch status & 0xF0 {
        case 0xB0 where bytes.count == 3:
            let cc = Int(bytes[1]), v = Int(bytes[2])
            if let k = NTS1.Knob.byCC(cc) {
                sound.incoming(k, v)
            } else if let c = NTS1.Choice.byCC(cc) {
                sound.incoming(c, c.index(of: v))
            }
        case 0x90 where bytes.count == 3 && bytes[2] > 0:
            // una nota suonata sulla tastiera dell'NTS-1 diventa la nota da scrivere nei passi
            player.pickFromNTS1(Int(bytes[1]))
        case 0xF0 where status == 0xF0:
            receivedSysex(bytes)
        default:
            break
        }
    }

    private func receivedSysex(_ bytes: [UInt8]) {
        trace("NTS-1 ← " + bytes.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " ") + (bytes.count > 16 ? " … (\(bytes.count))" : ""))
        if let reply = NTS1.searchReply(bytes) {
            firmware = reply.version
            if reply.channel != channel { channel = reply.channel }
            return
        }
        guard let (function, data) = NTS1.body(bytes) else { return }
        switch function {
        case NTS1.programDump:
            let d = NTS1.unpack(data)
            if let p = NTS1.Program(d) {
                sound.load(p)
                player.push()
                if saveNext {
                    saveNext = false
                    let n = p.name.isEmpty ? "suono \(saved.count + 1)" : p.name
                    saved.append(NTS1Saved(name: uniqueName(n), data: data))
                    writeSaved()
                    lastStatus = "salvato in Bobina: \(saved.last?.name ?? "")"
                }
            } else {
                lastStatus = "suono illeggibile (\(d.count) byte)"
            }
        case NTS1.globalDump:
            if let g = NTS1.Global(NTS1.unpack(data)) {
                global = g
                if g.channel != channel { channel = g.channel }
            }
        case NTS1.programChanged:
            // il suono è cambiato sull'NTS-1 (un altro programma, o una manopola): si rilegge, al massimo ogni secondo
            guard !refreshPending else { return }
            refreshPending = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.refreshPending = false
                self?.readProgram()
            }
        case NTS1.ack:
            lastStatus = "l'NTS-1 ha ricevuto"
        case 0x24...0x2F:
            lastStatus = String(format: "l'NTS-1 ha rifiutato (errore %02X)", function)
        default:
            break
        }
    }

    // MARK: suoni salvati

    /// Chiede il suono all'NTS-1 e lo salva in Bobina quando arriva.
    func saveCurrent() {
        guard connected else { lastStatus = "NTS-1 non collegato"; return }
        saveNext = true
        lastStatus = "leggo il suono…"
        readProgram()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self, self.saveNext else { return }
            self.saveNext = false
            self.lastStatus = "l'NTS-1 non ha mandato il suono"
        }
    }

    /// Rimanda all'NTS-1 un suono salvato. Va nel suono in modifica: per tenerlo sull'NTS-1 si salva lì.
    func load(_ s: NTS1Saved) {
        guard connected else { lastStatus = "NTS-1 non collegato"; return }
        loadedID = s.id
        lastStatus = "mando «\(s.name)»…"
        send(NTS1.sysex(NTS1.programDump, s.data, channel: channel))
        if let p = NTS1.Program(NTS1.unpack(s.data)) { sound.load(p) }
    }

    func delete(_ s: NTS1Saved) {
        saved.removeAll { $0.id == s.id }
        if loadedID == s.id { loadedID = nil }
        writeSaved()
    }

    func move(_ s: NTS1Saved, by d: Int) {
        guard let i = saved.firstIndex(of: s) else { return }
        let j = max(0, min(saved.count - 1, i + d))
        guard i != j else { return }
        saved.swapAt(i, j)
        writeSaved()
    }

    private func uniqueName(_ n: String) -> String {
        var name = n
        var k = 2
        while saved.contains(where: { $0.name == name }) { name = "\(n) \(k)"; k += 1 }
        return name
    }

    private static var file: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("nts1-suoni.json")
    }

    private static func readSaved() -> [NTS1Saved] {
        guard let data = try? Data(contentsOf: file) else { return [] }
        return (try? JSONDecoder().decode([NTS1Saved].self, from: data)) ?? []
    }

    private func writeSaved() {
        if let data = try? JSONEncoder().encode(saved) { try? data.write(to: NTS1Engine.file, options: .atomic) }
    }

    // MARK: tempo

    /// Solo il tempo: clock senza start, la sequenza dell'NTS-1 resta ferma.
    func startClock() {
        guard !running else { return }
        running = true
        withSequence = false
        sequencer.setTransport(true, start: false)
    }

    /// Il tempo e la partenza: la sequenza dell'NTS-1 suona.
    func startWithSequence() {
        guard !running else { return }
        running = true
        withSequence = true
        sequencer.setTransport(true, start: true)
    }

    func stopRun() {
        guard running else { return }
        running = false
        sequencer.setTransport(false)
    }

    func setBPM(_ v: Int) {
        BobinaClock.shared.setBPM(Double(max(20, min(300, v))))
        bpm = Int(BobinaClock.shared.bpm.rounded())
    }
}
