import Foundation
import CoreMIDI
import CoreMotion
import SwiftUI

/// Quello che cambia molte volte al secondo (il passo, i tasti che lampeggiano, l'inclinazione):
/// sta a parte, così a ogni passo si ridisegnano solo i quadratini e non tutta la pagina.
final class POLive: ObservableObject {
    @Published var step = 0
    @Published var flash: Set<Int> = []
    @Published var tilt = 0.0
    /// L'effetto scelto dall'inclinazione adesso, per mostrarlo.
    @Published var tiltFx: Int?
}

/// Tutti i PO collegati, uno per adattatore (da 1 a 4). Ognuno ha il suo motore; tutti stanno sulla
/// griglia di BobinaClock, quindi suonano insieme e a tempo col TX-6. Le pagine comandano quello scelto.
final class POBank: ObservableObject {
    @Published private(set) var units: [POEngine]
    @Published var current: Int { didSet { UserDefaults.standard.set(current, forKey: "bobina.po.attivo") } }

    static let maxUnits = 4

    init() {
        let saved = UserDefaults.standard.integer(forKey: "bobina.po.quanti")
        let n = max(2, min(POBank.maxUnits, saved))
        units = (0..<n).map { POEngine(slot: $0) }
        current = max(0, min(n - 1, UserDefaults.standard.integer(forKey: "bobina.po.attivo")))
        // le porte si scelgono dopo, in fila: così due adattatori con lo stesso nome non finiscono sullo stesso PO
        for u in units { u.bank = self }
        for u in units { u.refreshPorts() }
    }

    var unit: POEngine { units[current] }
    var anyRunning: Bool { units.contains { $0.running } }

    /// Le porte già prese dagli altri PO.
    func taken(except slot: Int) -> (destinations: Set<MIDIUniqueID>, sources: Set<MIDIUniqueID>) {
        let others = units.filter { $0.slot != slot }
        return (Set(others.compactMap { $0.destinationID }), Set(others.compactMap { $0.sourceID }))
    }

    /// Tutti i PO partono nello stesso istante, quindi sulla stessa battuta.
    func startAll() {
        let t = units[0].io.now() + units[0].io.ticks(ms: 30)
        for u in units where !u.running && u.connected { u.start(at: t) }
        objectWillChange.send()
    }

    func stopAll() {
        for u in units where u.running { u.toggleRun() }
        objectWillChange.send()
    }

    func add() {
        guard units.count < POBank.maxUnits else { return }
        let u = POEngine(slot: units.count)
        u.bank = self
        units.append(u)
        u.refreshPorts()
        UserDefaults.standard.set(units.count, forKey: "bobina.po.quanti")
    }

    func removeLast() {
        guard units.count > 2, let last = units.last else { return }
        if last.running { last.toggleRun() }
        last.releaseAll()
        last.shutdown()
        units.removeLast()
        if current >= units.count { current = units.count - 1 }
        UserDefaults.standard.set(units.count, forKey: "bobina.po.quanti")
    }
}

/// Il motore di un Pocket Operator: parla al suo adattatore di Hanz, tiene i tasti agganciati,
/// passa il piano al sequencer e segue l'orologio unico di Bobina.
final class POEngine: ObservableObject {

    /// Il suo numero: 0 = PO 1.
    let slot: Int
    weak var bank: POBank?
    let io = MIDIIO()
    let live = POLive()
    private(set) lazy var sequencer = POSequencer(io: io, member: BobinaClock.po(slot))

    var member: BobinaClock.Member { BobinaClock.po(slot) }
    var title: String { "PO \(slot + 1)" }
    private var storeKey: String { slot == 0 ? "bobina.po" : "bobina.po.\(slot + 1)" }
    private var portKey: String { "bobina.po.porta.\(slot + 1)" }

    // MARK: collegamento

    @Published var destinations: [MIDIPort] = []
    @Published var sources: [MIDIPort] = []
    @Published var destinationID: MIDIUniqueID? {
        didSet {
            applyPorts()
            if let d = destinationID { UserDefaults.standard.set(Int(d), forKey: portKey) }
        }
    }
    @Published var sourceID: MIDIUniqueID? { didSet { applyPorts() } }
    @Published private(set) var viaBluetooth = false

    var connected: Bool { io.destination != 0 }
    var connectedName: String { destinations.first(where: { $0.id == destinationID })?.name ?? "" }

    // MARK: il PO

    @Published var model = PO.Model.ko { didSet { save() } }
    @Published var channel = 1 { didSet { save() } }
    /// Le scorciatoie a CC sono accese nel configuratore dell'adattatore.
    @Published var useCC = false { didSet { save() } }
    /// I tasti tenuti giù dalla faccia.
    @Published private(set) var held: Set<PO.Key> = []

    // MARK: tempo

    @Published var bpm: Double = BobinaClock.shared.bpm {
        didSet { if oldValue != bpm { BobinaClock.shared.setBPM(bpm) } }
    }
    @Published private(set) var running = false
    @Published var sync = POSync.live { didSet { if oldValue != sync && running { toggleRun() }; save() } }
    /// Col sync out dell'adattatore il clock va sempre, così sa il tempo prima dello start.
    @Published var clockAlways = false
    /// Quanto prima parte tutto, per il ritardo del bluetooth.
    @Published var leadMs = 0.0 { didSet { save() } }
    /// Il tempo lo sta dando il TX-6 (Bobina segue il suo clock): qui non si cambia.
    @Published private(set) var followingTX6 = false
    /// Suona qualcun altro sulla griglia (per esempio il TX-6): il PO entrerà alla battuta dopo.
    @Published private(set) var othersRunning = false

    // MARK: giochi a tempo

    @Published var liveOn = false
    @Published var liveSteps: [[Bool]] = Array(repeating: Array(repeating: false, count: 16), count: 16) { didSet { save() } }
    /// Il tasto che si sta scrivendo nei passi dal vivo (1-16).
    @Published var liveKey = 1
    @Published var holdSteps = 1 { didSet { save() } }

    @Published var fxOn = false
    @Published var fxSteps: [Int?] = Array(repeating: nil, count: 16) { didSet { save() } }
    @Published var fxPick = 9
    @Published var fxEvery = 1 { didSet { save() } }

    @Published var songOn = false
    @Published var song: [Int] = [1, 1, 2, 2] { didSet { save() } }

    @Published var gateOn = false
    @Published var gate: [Bool] = [true, true, false, true, true, false, true, false, true, true, false, true, true, false, false, true] { didSet { save() } }
    @Published var gateLow = 2 { didSet { save() } }
    @Published var gateHigh = 12 { didSet { save() } }

    @Published var tiltOn = false { didSet { if tiltOn { startMotion() } else { stopMotion() } } }
    /// Quattro effetti: inclinando a sinistra poco e tanto, a destra poco e tanto.
    @Published var tiltSet: [Int] = [5, 9, 11, 15] { didSet { save() } }

    // MARK: monitor

    @Published private(set) var log: [LogLine] = []
    @Published var logPaused = false

    // MARK: interni

    private var timer: DispatchSourceTimer?
    private var lastPlanAt: MIDITimeStamp = 0
    private let motion = CMMotionManager()
    private var loading = false
    private var taps: [Date] = []

    init(slot: Int) {
        self.slot = slot
        // un modello diverso per ogni nuovo PO, senza salvarlo sopra quello di ieri
        loading = true
        if slot > 0 { model = [.ko, .tonic, .sub, .speak][slot] }
        loading = false
        load()
        io.onSetupChanged = { [weak self] in self?.refreshPorts() }
        io.onReceive = { [weak self] bytes, stamp in self?.received(bytes, stamp) }
        sequencer.onStep = { [weak self] i, t, hit in
            DispatchQueue.main.async { self?.stepped(i, t, hit) }
        }
        sequencer.onSent = { [weak self] bytes in
            DispatchQueue.main.async { self?.note(bytes, incoming: false) }
        }
        bpmObserver = NotificationCenter.default.addObserver(forName: .bobinaBPM, object: nil, queue: .main) { [weak self] n in
            guard let self = self, let v = n.object as? Double, abs(self.bpm - v) > 0.0001 else { return }
            self.bpm = v
        }
        startTimer()
    }

    private var bpmObserver: NSObjectProtocol?

    /// Tolto dal banco: niente più timer né notifiche.
    func shutdown() {
        timer?.cancel()
        timer = nil
        stopMotion()
        if let o = bpmObserver { NotificationCenter.default.removeObserver(o) }
        io.use(destination: 0, source: 0)
    }

    // MARK: porte

    func refreshPorts() {
        destinations = io.destinations()
        sources = io.sources()
        trace("PO · destinazioni: " + destinations.map { $0.name }.joined(separator: " · ") + " · sorgenti: " + sources.map { $0.name }.joined(separator: " · "))
        let taken = bank?.taken(except: slot) ?? (destinations: [], sources: [])
        if destinationID == nil || !destinations.contains(where: { $0.id == destinationID }) {
            // prima la porta di ieri, poi il primo adattatore che nessun altro PO sta usando
            let saved = MIDIUniqueID(truncatingIfNeeded: UserDefaults.standard.integer(forKey: portKey))
            if saved != 0, destinations.contains(where: { $0.id == saved }), !taken.destinations.contains(saved) {
                destinationID = saved
            } else {
                destinationID = destinations.first(where: { $0.looksLikePO && !taken.destinations.contains($0.id) })?.id
            }
        }
        // l'ascolto è la sorgente dello stesso adattatore (serve solo per l'eco nel monitor)
        if let d = destinations.first(where: { $0.id == destinationID }), let s = POEngine.source(of: d.ref),
           let match = sources.first(where: { $0.ref == s }) {
            if sourceID != match.id { sourceID = match.id }
        } else if sourceID == nil || !sources.contains(where: { $0.id == sourceID }) {
            sourceID = sources.first(where: { $0.looksLikePO && !taken.sources.contains($0.id) })?.id
        }
        applyPorts()
    }

    /// La sorgente che sta nello stesso apparecchio di una destinazione (col bluetooth: lo stesso adattatore).
    static func source(of destination: MIDIEndpointRef) -> MIDIEndpointRef? {
        var entity = MIDIEntityRef()
        guard MIDIEndpointGetEntity(destination, &entity) == noErr, entity != 0, MIDIEntityGetNumberOfSources(entity) > 0 else { return nil }
        let s = MIDIEntityGetSource(entity, 0)
        return s == 0 ? nil : s
    }

    /// Il nome da mostrare per una porta: se due adattatori si chiamano uguale, anche il numero.
    func portName(_ p: MIDIPort) -> String {
        let same = destinations.filter { $0.name == p.name }
        guard same.count > 1, let i = same.firstIndex(where: { $0.id == p.id }) else { return p.name }
        return "\(p.name) · \(i + 1)"
    }

    /// Quale altro PO usa questa porta, se qualcuno la usa.
    func user(of p: MIDIPort) -> String? {
        bank?.units.first { $0.slot != slot && $0.destinationID == p.id }?.title
    }

    /// Preme l'1 su questo adattatore: si sente quale PO risponde.
    func identify() {
        tap(.number(1))
    }

    private func applyPorts() {
        let dest = destinations.first(where: { $0.id == destinationID })?.ref ?? 0
        let src = sources.first(where: { $0.id == sourceID })?.ref ?? 0
        let n = connectedName.lowercased()
        viaBluetooth = n.contains("ble") || n.contains("bluetooth")
        if dest != io.destination || src != io.source {
            io.use(destination: dest, source: src)
            objectWillChange.send()
        }
    }

    // MARK: invio

    func send(_ bytes: [UInt8], at time: MIDITimeStamp = 0) {
        io.send(bytes, at: time)
        note(bytes, incoming: false)
        trace("→ PO " + bytes.map { String(format: "%02x", $0) }.joined(separator: " ") + " · " + PO.describe(bytes, model: model))
    }

    private func ms(_ v: Double) -> MIDITimeStamp { io.now() + io.ticks(ms: v) }

    // MARK: la faccia

    /// La metà di sotto di un tasto: lo tiene giù, ritoccata lo lascia.
    func toggleHold(_ k: PO.Key) {
        if held.contains(k) { release(k) } else { hold(k) }
    }

    /// La metà di sopra: un tocco. Se il tasto era tenuto, lo lascia.
    func touch(_ k: PO.Key) {
        if held.contains(k) { release(k) } else { tap(k) }
    }

    func hold(_ k: PO.Key) {
        guard !held.contains(k) else { return }
        held.insert(k)
        send(PO.noteOn(k, channel: channel))
        if let n = k.number { flash([n], at: io.now()) }
    }

    func release(_ k: PO.Key) {
        guard held.contains(k) else { return }
        held.remove(k)
        send(PO.noteOff(k, channel: channel))
    }

    /// Premi e lascia: 60 ms, abbastanza lungo perché il PO se ne accorga.
    func tap(_ k: PO.Key) {
        send(PO.noteOn(k, channel: channel))
        io.send(PO.noteOff(k, channel: channel), at: ms(60))
        if let n = k.number { flash([n], at: io.now()) }
    }

    /// Lascia tutti i tasti agganciati.
    func releaseAll() {
        guard !held.isEmpty else { return }
        let bytes = held.sorted { $0.note < $1.note }.flatMap { PO.noteOff($0, channel: channel) }
        held.removeAll()
        send(bytes)
    }

    /// Tieni un tasto, premi un numero, lascia. Col CC acceso è un messaggio solo.
    func combo(_ s: PO.Shortcut, _ number: Int) {
        if useCC {
            send(PO.cc(s, number, channel: channel))
            return
        }
        let k = PO.Key.number(number)
        send(PO.noteOn(s.held, channel: channel))
        io.send(PO.noteOn(k, channel: channel), at: ms(25))
        io.send(PO.noteOff(k, channel: channel), at: ms(50))
        io.send(PO.noteOff(s.held, channel: channel), at: ms(75))
    }

    /// Tieni `first`, tocca `then`, lascia: per esempio tasto in alto + bpm (il modo di sync).
    func pair(_ first: PO.Key, _ then: PO.Key) {
        send(PO.noteOn(first, channel: channel))
        io.send(PO.noteOn(then, channel: channel), at: ms(25))
        io.send(PO.noteOff(then, channel: channel), at: ms(65))
        io.send(PO.noteOff(first, channel: channel), at: ms(90))
    }

    /// Un effetto per un momento: fx + tasto per `ms` millisecondi.
    func fxShot(_ n: Int, length: Double = 600) {
        let k = PO.Key.number(n)
        send(PO.noteOn(.fx, channel: channel))
        io.send(PO.noteOn(k, channel: channel), at: ms(25))
        io.send(PO.noteOff(k, channel: channel) + PO.noteOff(.fx, channel: channel), at: ms(25 + length))
    }

    // MARK: tempo

    func tap() {
        let now = Date()
        taps = taps.filter { now.timeIntervalSince($0) < 2.5 } + [now]
        guard taps.count >= 2 else { return }
        let gaps = zip(taps.dropFirst(), taps).map { $0.timeIntervalSince($1) }
        bpm = max(40, min(300, (60 / (gaps.reduce(0, +) / Double(gaps.count))).rounded()))
    }

    func toggleRun() {
        if running {
            running = false
            sequencer.stop()
        } else {
            start(at: ms(30))
        }
        bank?.objectWillChange.send()
    }

    /// Parte all'istante `t` (o alla battuta dopo, se qualcuno suona già).
    func start(at t: MIDITimeStamp) {
        guard !running else { return }
        sequencer.update(makePlan())
        sequencer.start(at: t)
        running = true
    }

    private func makePlan() -> POSequencer.Plan {
        var p = POSequencer.Plan()
        p.channel = channel
        p.sync = sync
        p.leadMs = leadMs
        p.clockAlways = sync == .adapter && clockAlways
        p.useCC = useCC
        p.liveOn = liveOn
        p.live = liveSteps
        p.holdSteps = holdSteps
        p.fxOn = fxOn
        p.fx = fxSteps
        p.fxEvery = fxEvery
        p.tiltFx = tiltOn ? live.tiltFx : nil
        p.songOn = songOn
        p.song = song
        p.gateOn = gateOn
        p.gate = gate
        p.gateByMute = model.gateByMute
        p.gateLow = gateLow
        p.gateHigh = gateHigh
        return p
    }

    private func stepped(_ i: Int, _ t: MIDITimeStamp, _ hit: Set<Int>) {
        let delay = msUntil(t) / 1000
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.live.step = i }
        if !hit.isEmpty { flash(hit, at: t) }
    }

    private func flash(_ keys: Set<Int>, at t: MIDITimeStamp) {
        let delay = msUntil(t) / 1000
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.live.flash.formUnion(keys)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { self?.live.flash.subtract(keys) }
        }
    }

    private func msUntil(_ t: MIDITimeStamp) -> Double {
        let now = io.now()
        return t > now ? io.ms(ticks: t - now) : 0
    }

    // MARK: l'orologio della pagina

    /// Ogni 40 ms il sequencer riceve il piano aggiornato; la pagina guarda chi dà il tempo.
    private func startTimer() {
        let t = DispatchSource.makeTimerSource(flags: .strict, queue: .main)
        t.schedule(deadline: .now() + .milliseconds(50), repeating: .milliseconds(40), leeway: .milliseconds(5))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    private func tick() {
        sequencer.update(makePlan())
        let line = BobinaClock.shared.snapshot()
        let following = line.followedBy != nil
        if following != followingTX6 { followingTX6 = following }
        let others = line.running && !BobinaClock.shared.isMember(member)
        if others != othersRunning { othersRunning = others }
    }

    // MARK: inclinazione

    private func startMotion() {
        guard motion.isDeviceMotionAvailable else { tiltOn = false; return }
        motion.deviceMotionUpdateInterval = 1.0 / 30
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let d = data else { return }
            let roll = d.attitude.roll * 180 / .pi
            self.live.tilt = max(-1, min(1, roll / 45))
            // dritto = niente; a sinistra poco e tanto, a destra poco e tanto: quattro effetti
            let zone: Int? = roll < -30 ? 0 : roll < -12 ? 1 : roll > 30 ? 3 : roll > 12 ? 2 : nil
            let fx = zone.map { self.tiltSet[$0] }
            if fx != self.live.tiltFx {
                self.live.tiltFx = fx
                // il sequencer la prende al passo dopo; se il ritmo è fermo si manda subito
                if self.running { self.sequencer.update(self.makePlan()) } else { self.tiltNow(fx) }
            }
        }
    }

    private func stopMotion() {
        motion.stopDeviceMotionUpdates()
        live.tilt = 0
        if live.tiltFx != nil {
            live.tiltFx = nil
            if !running { tiltNow(nil) }
        }
    }

    /// Senza ritmo l'inclinazione tiene l'effetto direttamente.
    private var tiltHeld: Int?
    private func tiltNow(_ fx: Int?) {
        var bytes: [UInt8] = []
        if let old = tiltHeld { bytes += PO.noteOff(.number(old), channel: channel) }
        if let n = fx {
            if tiltHeld == nil { bytes += PO.noteOn(.fx, channel: channel) }
            send(bytes)
            io.send(PO.noteOn(.number(n), channel: channel), at: ms(20))
            note(PO.noteOn(.number(n), channel: channel), incoming: false)
        } else {
            if tiltHeld != nil { bytes += PO.noteOff(.fx, channel: channel) }
            if !bytes.isEmpty { send(bytes) }
        }
        tiltHeld = fx
    }

    // MARK: ricezione

    /// L'adattatore non manda niente di suo: torna indietro solo l'eco di quello che parte da qui.
    private func received(_ m: [UInt8], _ stamp: MIDITimeStamp) {
        guard let status = m.first, status != 0xF8 else { return }
        note(m, incoming: true)
    }

    // MARK: monitor

    private func note(_ bytes: [UInt8], incoming: Bool) {
        guard !logPaused, !bytes.isEmpty else { return }
        let raw = bytes.prefix(12).map { String(format: "%02x", $0) }.joined(separator: " ")
        log.insert(LogLine(incoming: incoming, text: PO.describe(bytes, model: model), raw: raw), at: 0)
        if log.count > 150 { log.removeLast(log.count - 150) }
    }

    func clearLog() { log.removeAll() }

    // MARK: memoria

    private struct Saved: Codable {
        var model: PO.Model
        var channel: Int
        var useCC: Bool
        var sync: POSync
        var leadMs: Double
        var liveSteps: [[Bool]]
        var holdSteps: Int
        var fxSteps: [Int?]
        var fxEvery: Int
        var song: [Int]
        var gate: [Bool]
        var gateLow: Int
        var gateHigh: Int
        var tiltSet: [Int]
    }

    private func save() {
        guard !loading else { return }
        let s = Saved(model: model, channel: channel, useCC: useCC, sync: sync, leadMs: leadMs, liveSteps: liveSteps,
                      holdSteps: holdSteps, fxSteps: fxSteps, fxEvery: fxEvery, song: song, gate: gate,
                      gateLow: gateLow, gateHigh: gateHigh, tiltSet: tiltSet)
        if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: storeKey) }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storeKey),
              let s = try? JSONDecoder().decode(Saved.self, from: data),
              s.liveSteps.count == 16, s.liveSteps.allSatisfy({ $0.count == 16 }), s.fxSteps.count == 16,
              s.gate.count == 16, s.tiltSet.count == 4, !s.song.isEmpty else { return }
        loading = true
        model = s.model
        channel = s.channel
        useCC = s.useCC
        sync = s.sync
        leadMs = s.leadMs
        liveSteps = s.liveSteps
        holdSteps = s.holdSteps
        fxSteps = s.fxSteps
        fxEvery = s.fxEvery
        song = s.song
        gate = s.gate
        gateLow = s.gateLow
        gateHigh = s.gateHigh
        tiltSet = s.tiltSet
        loading = false
    }
}
