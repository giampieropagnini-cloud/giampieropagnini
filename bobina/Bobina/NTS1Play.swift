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
    @Published private(set) var held: Set<Int> = []

    /// L'onda a tempo.
    @Published private(set) var waveOn = false
    @Published var waveKnob: NTS1.Knob { didSet { save(); push() } }
    @Published var waveShape: NTS1Shape { didSet { save(); push() } }
    /// Quanti quarti dura un giro: 1/4, 1/2, 1, 2, 4, 8, 16.
    @Published var waveBeats: Double { didSet { save(); push() } }
    /// Quanto si muove, 0-127, sotto il valore della manopola.
    @Published var waveDepth: Int { didSet { save(); push() } }

    @Published var tiltOn = false { didSet { tiltOn ? startMotion() : stopMotion() } }
    @Published var tiltKnob: NTS1.Knob { didSet { save() } }

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
        waveKnob = NTS1.Knob(rawValue: d.string(forKey: "bobina.nts1.onda.manopola") ?? "") ?? .cutoff
        waveShape = NTS1Shape(rawValue: d.integer(forKey: "bobina.nts1.onda.forma")) ?? .sine
        waveBeats = d.object(forKey: "bobina.nts1.onda.quarti") as? Double ?? 4
        waveDepth = d.object(forKey: "bobina.nts1.onda.quanto") as? Int ?? 64
        tiltKnob = NTS1.Knob(rawValue: d.string(forKey: "bobina.nts1.inclina.manopola") ?? "") ?? .cutoff
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
        if let data = try? JSONEncoder().encode(steps) { d.set(data, forKey: "bobina.nts1.suona.passi") }
        d.set(waveKnob.rawValue, forKey: "bobina.nts1.onda.manopola")
        d.set(waveShape.rawValue, forKey: "bobina.nts1.onda.forma")
        d.set(waveBeats, forKey: "bobina.nts1.onda.quarti")
        d.set(waveDepth, forKey: "bobina.nts1.onda.quanto")
        d.set(tiltKnob.rawValue, forKey: "bobina.nts1.inclina.manopola")
    }

    /// Manda al sequencer quello che deve suonare.
    func push() {
        guard let e = engine else { return }
        var p = NTS1Sequencer.Plan()
        p.steps = steps
        p.channel = e.channel
        p.waveCC = waveKnob.cc
        p.waveShape = waveShape
        p.waveBeats = waveBeats
        p.waveDepth = waveDepth
        p.waveTop = e.sound.value(waveKnob)
        e.sequencer.update(p)
    }

    private var ch: UInt8 { UInt8(((engine?.channel ?? 1) - 1) & 0x0F) }

    private func send(_ bytes: [UInt8]) { engine?.send(bytes) }

    // MARK: pad

    static let names = ["do", "do#", "re", "re#", "mi", "fa", "fa#", "sol", "sol#", "la", "la#", "si"]

    /// Il nome detto: «do 3», «fa# 4».
    static func name(_ n: Int) -> String { "\(names[n % 12]) \(n / 12 - 1)" }

    /// La metà di sopra: suona la nota per un quarto di secondo. Se era tenuta, la lascia.
    func touch(_ n: Int) {
        pick = n
        if held.contains(n) { release(n); return }
        guard let io = engine?.io else { return }
        send([0x90 | ch, UInt8(n), 100])
        io.send([0x80 | ch, UInt8(n), 64], at: io.now() + io.ticks(ms: 250))
    }

    /// La metà di sotto: tiene la nota finché non la ritocchi. Con più note tenute suona l'arpeggio.
    func toggleHold(_ n: Int) {
        pick = n
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
    }

    func toggleSteps() {
        stepsOn.toggle()
        engine?.sequencer.setSteps(stepsOn)
        if !stepsOn { live.step = nil }
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
        var channel = 1
        var velocity = 100
        var gate = 0.5
        var waveCC = 43
        var waveShape = NTS1Shape.sine
        var waveBeats = 4.0
        var waveDepth = 64
        /// Il valore della manopola: l'onda scende da qui.
        var waveTop = 100
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

    private var playing: Bool { transport || stepsOn || waveOn }

    func setTransport(_ on: Bool) {
        queue.async { [self] in
            guard on != transport else { return }
            if on {
                let first = joinIfNeeded()
                transport = true
                nextClockTick = Int((first * 24).rounded())
                lastClockAt = 0
                io.send([0xFA], at: line.time(ofBeat: first))
            } else {
                transport = false
                io.send([0xFC])
                leaveIfIdle()
            }
        }
    }

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
                let i = ((nextSixteenth - firstSixteenth) % 16 + 16) % 16
                if t >= now, let note = p.steps[i] {
                    let n = UInt8(max(0, min(127, note)))
                    io.send([0x90 | ch, n, UInt8(max(1, min(127, p.velocity)))], at: t)
                    io.send([0x80 | ch, n, 64], at: t + io.ticks(ms: line.beatMs / 4 * p.gate))
                }
                onStep?(i, t)
                nextSixteenth += 1
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
