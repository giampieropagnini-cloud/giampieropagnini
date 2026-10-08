import Foundation
import CoreMIDI
import CoreMotion

/// Quello che cambia molte volte al secondo (il passo, l'inclinazione): sta a parte, così si ridisegnano
/// solo i quadratini e la barretta, non tutta la pagina col menu «passa a…».
final class NTS1Live: ObservableObject {
    @Published var step: Int?
    @Published var tilt = 64
}

/// La forma dell'onda che muove una manopola a tempo: le cose che l'NTS-1 da solo non fa.
enum NTS1Shape: Int, CaseIterable, Identifiable {
    case sine, triangle, rampUp, rampDown, gate, pump

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .sine: return "onda"
        case .triangle: return "triangolo"
        case .rampUp: return "sale"
        case .rampDown: return "scende"
        case .gate: return "cancello"
        case .pump: return "pompa"
        }
    }

    /// Da 0 (in basso) a 1 (in alto), con `phase` da 0 a 1 nel giro.
    func level(_ phase: Double) -> Double {
        switch self {
        case .sine: return 0.5 - 0.5 * cos(phase * 2 * .pi)
        case .triangle: return phase < 0.5 ? phase * 2 : 2 - phase * 2
        case .rampUp: return phase
        case .rampDown: return 1 - phase
        case .gate: return phase < 0.5 ? 1 : 0
        // il sidechain: giù di colpo sul battito, poi risale
        case .pump: return 1 - pow(1 - phase, 2.5)
        }
    }
}

/// Come sale l'arpeggio di Bobina.
enum NTS1ArpMode: Int, CaseIterable, Identifiable {
    case up, down, upDown, downUp, random
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .up: return "su"
        case .down: return "giù"
        case .upDown: return "su-giù"
        case .downUp: return "giù-su"
        case .random: return "a caso"
        }
    }
}

/// Le note che l'arpeggio aggiunge a ogni nota tenuta.
enum NTS1ArpChord: Int, CaseIterable, Identifiable {
    case notes, major, minor, sus, seventh, fifth
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .notes: return "solo le note"
        case .major: return "maggiore"
        case .minor: return "minore"
        case .sus: return "sospeso"
        case .seventh: return "settima"
        case .fifth: return "quinta"
        }
    }
    var intervals: [Int] {
        switch self {
        case .notes: return [0]
        case .major: return [0, 4, 7]
        case .minor: return [0, 3, 7]
        case .sus: return [0, 5, 7]
        case .seventh: return [0, 4, 7, 10]
        case .fifth: return [0, 7]
        }
    }
}

/// Bobina che suona l'NTS-1: pad, 16 passi a tempo, un'onda a tempo su una manopola, l'inclinazione.
final class NTS1Player: ObservableObject {
    weak var engine: NTS1Engine?
    let live = NTS1Live()

    /// La nota più bassa dei 16 pad.
    @Published var base: Int { didSet { save() } }
    /// I passi: la nota di ognuno, nil = vuoto.
    @Published var steps: [Int?] { didSet { save(); push() } }
    /// La nota che si scrive toccando un passo vuoto: l'ultimo pad, o l'ultimo tasto dell'NTS-1.
    @Published var pick: Int
    @Published private(set) var stepsOn = false
    /// Quanti passi gira la sequenza: 8 o 16.
    @Published var stepLength: Int { didSet { save(); push(); if cursor >= stepLength { cursor = 0 } } }
    /// Il passo dove va la prossima nota scritta. Dopo ogni nota va avanti da solo.
    @Published var cursor = 0
    /// L'ottava della tastiera dei passi (3 = il do centrale basso, nota 48).
    @Published var writeOctave: Int { didSet { save() } }
    @Published private(set) var held: Set<Int> = []

    /// L'onda a tempo.
    @Published private(set) var waveOn = false
    @Published var waveKnob: NTS1.Knob { didSet { if waveKnob.steadyOnly { waveKnob = .cutoff }; save(); push() } }
    @Published var waveShape: NTS1Shape { didSet { save(); push() } }
    /// Quanti quarti dura un giro: 1/4, 1/2, 1, 2, 4, 8, 16.
    @Published var waveBeats: Double { didSet { save(); push() } }
    /// Quanto si muove, 0-127, sotto il valore della manopola.
    @Published var waveDepth: Int { didSet { save(); push() } }

    /// L'arpeggio di Bobina: suona le note tenute a tempo, senza il tasto ARP dell'NTS-1.
    @Published private(set) var arpOn = false
    @Published var arpMode: NTS1ArpMode { didSet { save(); push() } }
    @Published var arpChord: NTS1ArpChord { didSet { save(); push() } }
    /// Quante ottave sale: 1, 2 o 3.
    @Published var arpOctaves: Int { didSet { save(); push() } }
    /// Colpi per quarto: da 1/8 (una nota ogni due battute) a 8 (trentaduesimi).
    @Published var arpDiv: Double { didSet { save(); push() } }

    /// Le velocità dell'arpeggio, dalla più lenta: colpi per quarto e nome sul tasto.
    static let arpSpeeds: [(Double, String)] = [(0.125, "2 battute"), (0.25, "1 battuta"), (0.5, "metà"), (1, "quarti"),
                                                (2, "ottavi"), (4, "sedicesimi"), (8, "trentaduesimi")]

    @Published var tiltOn = false { didSet { tiltOn ? startMotion() : stopMotion() } }
    @Published var tiltKnob: NTS1.Knob { didSet { if tiltKnob.steadyOnly { tiltKnob = .cutoff }; save() } }

    static let waveLengths: [(Double, String)] = [(0.25, "1/16"), (0.5, "1/8"), (1, "1/4"), (2, "1/2"), (4, "1 battuta"), (8, "2 battute"), (16, "4 battute")]

    private let motion = CMMotionManager()
    private var lastTilt = -1

    init() {
        let d = UserDefaults.standard
        base = d.object(forKey: "bobina.nts1.suona.base") as? Int ?? 48
        if let data = d.data(forKey: "bobina.nts1.suona.passi"), let s = try? JSONDecoder().decode([Int?].self, from: data), s.count == 16 {
            steps = s
        } else {
            steps = Array(repeating: nil, count: 16)
        }
        pick = d.object(forKey: "bobina.nts1.suona.base") as? Int ?? 48
        stepLength = d.object(forKey: "bobina.nts1.passi.lunghezza") as? Int ?? 16
        writeOctave = d.object(forKey: "bobina.nts1.passi.ottava") as? Int ?? 3
        // un guadagno salvato da prima della regola torna sul taglio
        let savedWave = NTS1.Knob(rawValue: d.string(forKey: "bobina.nts1.onda.manopola") ?? "") ?? .cutoff
        waveKnob = savedWave.steadyOnly ? .cutoff : savedWave
        waveShape = NTS1Shape(rawValue: d.integer(forKey: "bobina.nts1.onda.forma")) ?? .sine
        waveBeats = d.object(forKey: "bobina.nts1.onda.quarti") as? Double ?? 4
        waveDepth = d.object(forKey: "bobina.nts1.onda.quanto") as? Int ?? 64
        let savedTilt = NTS1.Knob(rawValue: d.string(forKey: "bobina.nts1.inclina.manopola") ?? "") ?? .cutoff
        tiltKnob = savedTilt.steadyOnly ? .cutoff : savedTilt
        arpMode = NTS1ArpMode(rawValue: d.integer(forKey: "bobina.nts1.arp.modo")) ?? .up
        arpChord = NTS1ArpChord(rawValue: d.integer(forKey: "bobina.nts1.arp.accordo")) ?? .notes
        arpOctaves = d.object(forKey: "bobina.nts1.arp.ottave") as? Int ?? 1
        arpDiv = (d.object(forKey: "bobina.nts1.arp.colpi") as? NSNumber)?.doubleValue ?? 4
    }

    func attach(_ e: NTS1Engine) {
        engine = e
        e.sequencer.onStep = { [weak self] i, _ in
            DispatchQueue.main.async { self?.live.step = i }
        }
        push()
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(base, forKey: "bobina.nts1.suona.base")
        d.set(stepLength, forKey: "bobina.nts1.passi.lunghezza")
        d.set(writeOctave, forKey: "bobina.nts1.passi.ottava")
        if let data = try? JSONEncoder().encode(steps) { d.set(data, forKey: "bobina.nts1.suona.passi") }
        d.set(waveKnob.rawValue, forKey: "bobina.nts1.onda.manopola")
        d.set(waveShape.rawValue, forKey: "bobina.nts1.onda.forma")
        d.set(waveBeats, forKey: "bobina.nts1.onda.quarti")
        d.set(waveDepth, forKey: "bobina.nts1.onda.quanto")
        d.set(tiltKnob.rawValue, forKey: "bobina.nts1.inclina.manopola")
        d.set(arpMode.rawValue, forKey: "bobina.nts1.arp.modo")
        d.set(arpChord.rawValue, forKey: "bobina.nts1.arp.accordo")
        d.set(arpOctaves, forKey: "bobina.nts1.arp.ottave")
        d.set(arpDiv, forKey: "bobina.nts1.arp.colpi")
    }

    /// Manda al sequencer quello che deve suonare.
    func push() {
        guard let e = engine else { return }
        var p = NTS1Sequencer.Plan()
        p.steps = steps
        p.length = stepLength
        p.channel = e.channel
        p.waveCC = waveKnob.cc
        p.waveShape = waveShape
        p.waveBeats = waveBeats
        p.waveDepth = waveDepth
        p.waveTop = e.sound.value(waveKnob)
        p.arpNotes = arpOn ? arpSequence() : []
        p.arpDiv = arpDiv
        p.arpRandom = arpMode == .random
        e.sequencer.update(p)
    }

    private var ch: UInt8 { UInt8(((engine?.channel ?? 1) - 1) & 0x0F) }

    private func send(_ bytes: [UInt8]) { engine?.send(bytes) }

    // MARK: pad

    static let names = ["do", "do#", "re", "re#", "mi", "fa", "fa#", "sol", "sol#", "la", "la#", "si"]

    /// Il nome detto: «do 3», «fa# 4».
    static func name(_ n: Int) -> String { "\(names[n % 12]) \(n / 12 - 1)" }

    /// La metà di sopra: suona la nota per un quarto di secondo. Se era tenuta, la lascia.
    /// Come risponde un pad: suona un attimo, resta acceso, o entra nell'arpeggio di Bobina.
    enum PadMode { case tap, hold, arp }

    @Published private(set) var holdMode = false

    var padMode: PadMode { arpOn ? .arp : holdMode ? .hold : .tap }

    func setPadMode(_ m: PadMode) {
        guard m != padMode else { return }
        if arpOn { toggleArp() }
        if m != .hold { releaseAll() }
        holdMode = m == .hold
        if m == .arp { toggleArp() }
    }

    /// Il tocco di un pad, secondo il modo.
    func pad(_ n: Int) {
        switch padMode {
        case .tap: touch(n)
        case .hold, .arp: toggleHold(n)
        }
    }

    func touch(_ n: Int) {
        pick = n
        if arpOn { toggleHold(n); return }
        if held.contains(n) { release(n); return }
        guard let io = engine?.io else { return }
        send([0x90 | ch, UInt8(n), 100])
        io.send([0x80 | ch, UInt8(n), 64], at: io.now() + io.ticks(ms: 250))
    }

    /// La metà di sotto: tiene la nota finché non la ritocchi. Con più note tenute suona l'arpeggio.
    func toggleHold(_ n: Int) {
        pick = n
        if arpOn {
            // con l'arpeggio di Bobina le note tenute non suonano da sole: le suona l'arpeggio
            if held.contains(n) { held.remove(n) } else { held.insert(n) }
            push()
            return
        }
        if held.contains(n) { release(n) } else {
            held.insert(n)
            send([0x90 | ch, UInt8(n), 100])
        }
    }

    private func release(_ n: Int) {
        held.remove(n)
        send([0x80 | ch, UInt8(n), 64])
    }

    func releaseAll() {
        guard !held.isEmpty else { return }
        if arpOn { held.removeAll(); push(); return }
        let c = ch
        let bytes: [UInt8] = held.sorted().flatMap { [0x80 | c, UInt8($0), 64] }
        held.removeAll()
        send(bytes)
    }

    /// Tutte le note spente, anche quelle rimaste appese (CC 123).
    func panic() {
        releaseAll()
        send([0xB0 | ch, 123, 0])
    }

    func octave(_ d: Int) {
        releaseAll()
        base = max(0, min(108, base + 12 * d))
        pick = max(base, min(base + 15, pick))
    }

    func pickFromNTS1(_ n: Int) {
        if pick != n { pick = n }
    }

    // MARK: passi

    func toggleStep(_ i: Int) {
        steps[i] = steps[i] == nil ? pick : nil
    }

    func clearSteps() {
        steps = Array(repeating: nil, count: 16)
        cursor = 0
    }

    /// Scrittura in fila: la nota (0-11 nell'ottava scelta) si sente, va nel passo del cursore,
    /// e il cursore passa al passo dopo. Un tocco per nota.
    func write(_ semitone: Int) {
        let n = max(0, min(127, (writeOctave + 1) * 12 + semitone))
        preview(n)
        pick = n
        steps[cursor] = n
        presetName = nil
        advance()
    }

    /// Il passo del cursore resta vuoto, e si va avanti.
    func rest() {
        steps[cursor] = nil
        advance()
    }

    /// Il cursore torna indietro di uno, per correggere l'ultima nota.
    func back() {
        cursor = (cursor - 1 + stepLength) % stepLength
    }

    func select(_ i: Int) {
        cursor = i
        if let n = steps[i] { preview(n) }
    }

    // MARK: sequenze pronte

    /// I passi di prima dell'ultima sequenza pronta caricata: «annulla» li rimette.
    @Published private(set) var undo: (steps: [Int?], length: Int)?
    @Published private(set) var presetName: String?
    /// Con una sequenza pronta cambia anche il tempo di Bobina (per tutte le macchine).
    @Published var presetTempo = UserDefaults.standard.bool(forKey: "bobina.nts1.passi.tempo") {
        didSet { UserDefaults.standard.set(presetTempo, forKey: "bobina.nts1.passi.tempo") }
    }

    func load(_ p: NTS1Preset) {
        if undo == nil || presetName == nil { undo = (steps, stepLength) }
        steps = p.steps
        stepLength = p.length
        cursor = 0
        presetName = p.name
        if presetTempo { engine?.setBPM(p.bpm) }
    }

    func undoPreset() {
        guard let u = undo else { return }
        steps = u.steps
        stepLength = u.length
        cursor = 0
        undo = nil
        presetName = nil
    }

    /// I passi 1-8 copiati su 9-16.
    func copyHalf() {
        var s = steps
        for i in 0..<8 { s[i + 8] = s[i] }
        steps = s
    }

    private func advance() {
        cursor = (cursor + 1) % stepLength
    }

    /// Fa sentire una nota per un attimo, anche con l'arpeggio acceso.
    private func preview(_ n: Int) {
        guard let io = engine?.io else { return }
        send([0x90 | ch, UInt8(n), 100])
        io.send([0x80 | ch, UInt8(n), 64], at: io.now() + io.ticks(ms: 200))
    }

    func toggleSteps() {
        stepsOn.toggle()
        engine?.sequencer.setSteps(stepsOn)
        if !stepsOn { live.step = nil }
    }

    // MARK: arpeggio di Bobina

    func toggleArp() {
        if !arpOn {
            // le note tenute smettono di suonare da sole e passano all'arpeggio
            let c = ch
            let off: [UInt8] = held.sorted().flatMap { [0x80 | c, UInt8($0), 64] }
            if !off.isEmpty { send(off) }
        }
        arpOn.toggle()
        if !arpOn { held.removeAll() }
        push()
        engine?.sequencer.setArp(arpOn)
    }

    /// Le note nell'ordine in cui le suona l'arpeggio.
    func arpSequence() -> [Int] {
        let base = held.sorted()
        guard !base.isEmpty else { return [] }
        var notes = base.flatMap { n in arpChord.intervals.map { n + $0 } }
        notes = Array(Set(notes)).sorted()
        var all: [Int] = []
        for o in 0..<max(1, arpOctaves) { all += notes.map { $0 + 12 * o } }
        all = all.filter { $0 <= 127 }
        switch arpMode {
        case .up, .random: return all
        case .down: return all.reversed()
        case .upDown: return all.count > 2 ? all + all.dropFirst().dropLast().reversed() : all
        case .downUp: return all.count > 2 ? all.reversed() + all.dropFirst().dropLast() : all.reversed()
        }
    }

    // MARK: onda

    func toggleWave() {
        waveOn.toggle()
        push()
        engine?.sequencer.setWave(waveOn)
        if !waveOn, let e = engine {
            // la manopola torna dov'era
            e.set(waveKnob, e.sound.value(waveKnob))
        }
    }

    // MARK: inclinazione

    private func startMotion() {
        guard motion.isDeviceMotionAvailable else { tiltOn = false; return }
        motion.deviceMotionUpdateInterval = 1.0 / 30
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let d = data, let e = self.engine else { return }
            // telefono dritto = metà; 45° a sinistra = 0, 45° a destra = 127
            let roll = d.attitude.roll * 180 / .pi
            let v = Int(((max(-45, min(45, roll)) + 45) / 90 * 127).rounded())
            guard v != self.lastTilt else { return }
            self.lastTilt = v
            self.live.tilt = v
            // un CC all'NTS-1, ma niente sulla pagina: il valore si vede solo nella barretta
            e.io.send(NTS1.cc(self.tiltKnob.cc, v, channel: e.channel))
        }
    }

    private func stopMotion() {
        motion.stopDeviceMotionUpdates()
        lastTilt = -1
        if let e = engine { e.set(tiltKnob, e.sound.value(tiltKnob)) }
    }
}

/// Il tempo per l'NTS-1, sulla griglia di `BobinaClock`. Tre cose indipendenti:
/// - **trasporto**: start, 24 impulsi di clock per quarto, stop (sull'NTS-1: Clock = Auto). Arpeggio,
///   sequencer e delay «bpm» dell'NTS-1 vanno al tempo di Bobina;
/// - **passi**: 16 sedicesimi di note;
/// - **onda**: una manopola mossa a tempo, un valore ogni trentaduesimo, solo quando cambia.
/// Se suona già qualcuno si parte all'inizio della battuta dopo. Prepara i messaggi 150 ms prima.
final class NTS1Sequencer {

    struct Plan {
        var steps: [Int?] = Array(repeating: nil, count: 16)
        /// Quanti passi gira: 8 o 16.
        var length = 16
        var channel = 1
        var velocity = 100
        var gate = 0.5
        var waveCC = 43
        var waveShape = NTS1Shape.sine
        var waveBeats = 4.0
        var waveDepth = 64
        /// Il valore della manopola: l'onda scende da qui.
        var waveTop = 100
        /// L'arpeggio di Bobina: le note già messe in ordine (su, giù…), una per colpo.
        var arpNotes: [Int] = []
        /// Colpi per quarto: 0,125 = uno ogni due battute … 4 = sedicesimi, 8 = trentaduesimi.
        var arpDiv = 4.0
        var arpRandom = false
        var arpGate = 0.6
    }

    private let io: MIDIIO
    private let queue = DispatchQueue(label: "bobina.nts1.tempo", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private let lookahead = 150.0

    private let lock = NSLock()
    private var shared = Plan()

    private var line = BobinaClock.Timeline()
    private var transport = false
    private var stepsOn = false
    private var waveOn = false
    private var nextClockTick = 0
    private var nextSixteenth = 0
    private var firstSixteenth = 0
    private var nextWave = 0
    private var lastWave = -1
    private var arpOn = false
    private var nextArp = 0
    private var arpDivNow = 4.0
    /// Il quarto da cui conta l'arpeggio: i colpi cadono a arpOrigin + k / arpDivNow.
    private var arpOrigin = 0.0
    private var arpIndex = 0
    private var lastClockAt: MIDITimeStamp = 0

    var onStep: ((Int, MIDITimeStamp) -> Void)?

    init(io: MIDIIO) {
        self.io = io
    }

    func update(_ plan: Plan) {
        lock.lock()
        shared = plan
        lock.unlock()
    }

    private func plan() -> Plan {
        lock.lock()
        defer { lock.unlock() }
        return shared
    }

    private var playing: Bool { transport || stepsOn || waveOn || arpOn }

    /// Il clock all'NTS-1. Con `start` gli manda anche start e stop, e la sua sequenza parte;
    /// senza, gli dà solo il tempo (delay «bpm» e arpeggio della macchina) e la sequenza resta ferma.
    func setTransport(_ on: Bool, start: Bool = true) {
        queue.async { [self] in
            guard on != transport else { return }
            if on {
                let first = joinIfNeeded()
                transport = true
                sentStart = start
                nextClockTick = Int((first * 24).rounded())
                lastClockAt = 0
                if start { io.send([0xFA], at: line.time(ofBeat: first)) }
            } else {
                transport = false
                if sentStart { io.send([0xFC]) }
                leaveIfIdle()
            }
        }
    }

    private var sentStart = false

    func setSteps(_ on: Bool) {
        queue.async { [self] in
            guard on != stepsOn else { return }
            if on {
                let first = joinIfNeeded()
                stepsOn = true
                nextSixteenth = Int((first * 4).rounded())
                firstSixteenth = nextSixteenth
            } else {
                stepsOn = false
                leaveIfIdle()
            }
        }
    }

    func setWave(_ on: Bool) {
        queue.async { [self] in
            guard on != waveOn else { return }
            if on {
                // l'onda non aspetta la battuta: comincia dal prossimo trentaduesimo della griglia
                if !playing {
                    let (l, _) = BobinaClock.shared.join(.nts1, at: io.now() + io.ticks(ms: 30))
                    line = l
                    startTimer()
                }
                waveOn = true
                nextWave = Int((line.beat(at: io.now() + io.ticks(ms: 30)) * 8).rounded(.up))
                lastWave = -1
            } else {
                waveOn = false
                leaveIfIdle()
            }
        }
    }

    /// L'arpeggio di Bobina: comincia dal prossimo colpo della griglia, senza aspettare la battuta.
    func setArp(_ on: Bool) {
        queue.async { [self] in
            guard on != arpOn else { return }
            if on {
                if !playing {
                    let (l, _) = BobinaClock.shared.join(.nts1, at: io.now() + io.ticks(ms: 30))
                    line = l
                    startTimer()
                }
                arpOn = true
                arpDivNow = plan().arpDiv
                // parte sul prossimo quarto, anche alle velocità lente: niente attese di due battute
                arpOrigin = line.beat(at: io.now() + io.ticks(ms: 30)).rounded(.up)
                nextArp = 0
                arpIndex = 0
            } else {
                arpOn = false
                leaveIfIdle()
            }
        }
    }

    private func joinIfNeeded() -> Double {
        if playing {
            return line.bar(atOrAfter: io.now() + io.ticks(ms: 30))
        }
        let (l, first) = BobinaClock.shared.join(.nts1, at: io.now() + io.ticks(ms: 30))
        line = l
        startTimer()
        return first
    }

    private func leaveIfIdle() {
        guard !playing else { return }
        stopTimer()
        BobinaClock.shared.leave(.nts1)
    }

    private func startTimer() {
        guard timer == nil else { return }
        let t = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        t.schedule(deadline: .now(), repeating: .milliseconds(5), leeway: .milliseconds(1))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        let now = io.now()
        let fresh = BobinaClock.shared.snapshot()
        if fresh.generation != line.generation {
            line = fresh
            nextClockTick = Int((line.beat(at: now) * 24).rounded(.up))
            nextSixteenth = Int((line.beat(at: now) * 4).rounded(.up))
            nextWave = Int((line.beat(at: now) * 8).rounded(.up))
            nextArp = Int(((line.beat(at: now) - arpOrigin) * arpDivNow).rounded(.up))
        }
        let horizon = now + io.ticks(ms: lookahead)
        let p = plan()
        if transport {
            while line.time(ofBeat: Double(nextClockTick) / 24) < horizon {
                let due = line.time(ofBeat: Double(nextClockTick) / 24)
                if due >= now && due > lastClockAt + io.ticks(ms: 2) {
                    io.send([0xF8], at: due)
                    lastClockAt = due
                }
                nextClockTick += 1
            }
        }
        let ch = UInt8((p.channel - 1) & 0x0F)
        if stepsOn {
            while line.time(ofBeat: Double(nextSixteenth) / 4) < horizon {
                let t = line.time(ofBeat: Double(nextSixteenth) / 4)
                let len = max(1, min(16, p.length))
                let i = ((nextSixteenth - firstSixteenth) % len + len) % len
                if t >= now, let note = p.steps[i] {
                    let n = UInt8(max(0, min(127, note)))
                    io.send([0x90 | ch, n, UInt8(max(1, min(127, p.velocity)))], at: t)
                    io.send([0x80 | ch, n, 64], at: t + io.ticks(ms: line.beatMs / 4 * p.gate))
                }
                onStep?(i, t)
                nextSixteenth += 1
            }
        }
        if arpOn {
            if p.arpDiv != arpDivNow {
                // cambio di velocità: si riprende dal prossimo colpo della nuova griglia
                let b = Double(nextArp) / arpDivNow
                arpDivNow = p.arpDiv
                arpOrigin += b.rounded(.up)
                nextArp = 0
            }
            while line.time(ofBeat: arpOrigin + Double(nextArp) / arpDivNow) < horizon {
                let t = line.time(ofBeat: arpOrigin + Double(nextArp) / arpDivNow)
                if t >= now, !p.arpNotes.isEmpty {
                    let note = p.arpRandom ? p.arpNotes.randomElement()! : p.arpNotes[arpIndex % p.arpNotes.count]
                    let n = UInt8(max(0, min(127, note)))
                    io.send([0x90 | ch, n, UInt8(max(1, min(127, p.velocity)))], at: t)
                    io.send([0x80 | ch, n, 64], at: t + io.ticks(ms: line.beatMs / arpDivNow * p.arpGate))
                    arpIndex += 1
                }
                nextArp += 1
            }
        }
        if waveOn {
            while line.time(ofBeat: Double(nextWave) / 8) < horizon {
                let t = line.time(ofBeat: Double(nextWave) / 8)
                let beat = Double(nextWave) / 8
                let phase = (beat / p.waveBeats).truncatingRemainder(dividingBy: 1)
                let low = max(0, p.waveTop - p.waveDepth)
                let v = Int((Double(low) + Double(p.waveTop - low) * p.waveShape.level(phase < 0 ? phase + 1 : phase)).rounded())
                // solo quando il valore cambia: niente flussi inutili sul cavo
                if t >= now && v != lastWave {
                    io.send([0xB0 | ch, UInt8(p.waveCC & 0x7F), UInt8(max(0, min(127, v)))], at: t)
                    lastWave = v
                }
                nextWave += 1
            }
        }
    }
}
