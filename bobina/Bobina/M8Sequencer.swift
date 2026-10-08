import Foundation
import CoreMIDI

/// Il tempo per l'M8. Tre cose indipendenti sulla griglia di `BobinaClock`:
/// - **trasporto**: start, 24 impulsi di clock per quarto, stop (sull'M8: SYNC IN = CLOCK+TRANSP.);
/// - **passi**: 16 sedicesimi di note che suonano uno strumento dell'M8 sul suo canale di ingresso;
/// - **manopole**: le onde a tempo e l'automazione a passi, come CC sul canale dei tasti.
/// Se suona già qualcuno (TX-6, PO, OP-Z, NTS-1) si parte all'inizio della battuta dopo.
/// Gira su un filo suo e prepara i messaggi 150 ms prima, come gli altri sequencer.
/// I passi si contano dall'inizio della griglia (battito 0 = inizio di una battuta): così note e
/// automazione delle manopole sono sempre allineate fra loro.
final class M8Sequencer {

    /// Quello che decide la pagina. Si legge sotto lock dal filo del sequencer.
    struct Plan {
        /// La nota di ogni passo (nil = vuoto).
        var steps: [Int?] = Array(repeating: nil, count: 16)
        var channel = 1
        var velocity = 100
        /// Quanto dura la nota, in frazioni di sedicesimo.
        var gate = 0.5
        /// 8 o 16 passi (vale anche per l'automazione delle manopole).
        var length = 16
    }

    private let io: MIDIIO
    private let queue = DispatchQueue(label: "bobina.m8.tempo", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private let lookahead = 150.0
    /// Quante volte per battito si ricalcolano le onde. Col cavo USB c'è posto; si manda solo se il valore cambia.
    private let waveRate = 16

    private let lock = NSLock()
    private var shared = Plan()
    private var sharedKnobs: [M8Knob] = []
    private var knobChannel = 10

    private var line = BobinaClock.Timeline()
    private var transport = false
    private var stepsOn = false
    private var knobsOn = false
    private var nextClockTick = 0
    private var nextSixteenth = 0
    /// Le note dei passi partono da qui (la battuta dopo l'accensione).
    private var notesFrom = 0
    private var nextWave = 0
    private var lastClockAt: MIDITimeStamp = 0
    /// L'ultimo valore mandato per ogni manopola (-1 = ancora niente).
    private var knobValues: [Int] = Array(repeating: 64, count: 8)
    private var knobSent: [Int] = Array(repeating: -1, count: 8)

    /// Il passo che sta per suonare (0-15), col suo istante. Chiamata sul filo del sequencer.
    var onStep: ((Int, MIDITimeStamp) -> Void)?
    /// I valori delle manopole e il passo dell'automazione, una volta per sedicesimo (sul filo del sequencer).
    var onKnobs: (([Int], Int?) -> Void)?

    init(io: MIDIIO) {
        self.io = io
    }

    func update(_ plan: Plan) {
        lock.lock()
        shared = plan
        lock.unlock()
    }

    /// Le manopole, il canale dove vanno i loro CC e i valori di adesso (da lì riparte un'onda).
    func updateKnobs(_ knobs: [M8Knob], channel: Int, values: [Int]) {
        lock.lock()
        sharedKnobs = knobs
        knobChannel = channel
        lock.unlock()
        queue.async { [self] in
            // fermi: i valori sono quelli messi a mano
            if !knobsOn && values.count == 8 { knobValues = values }
        }
    }

    private func plan() -> (Plan, [M8Knob], Int) {
        lock.lock()
        defer { lock.unlock() }
        return (shared, sharedKnobs, knobChannel)
    }

    // MARK: accendere e spegnere

    /// Start e clock all'M8.
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

    /// I 16 passi di Bobina.
    func setSteps(_ on: Bool) {
        queue.async { [self] in
            guard on != stepsOn else { return }
            if on {
                let first = joinIfNeeded()
                stepsOn = true
                notesFrom = Int((first * 4).rounded())
            } else {
                stepsOn = false
                leaveIfIdle()
            }
        }
    }

    /// Le manopole che si muovono da sole (onde o passi): appena ce n'è una, il sequencer gira.
    func setKnobsActive(_ on: Bool) {
        queue.async { [self] in
            guard on != knobsOn else { return }
            if on {
                _ = joinIfNeeded()
                knobsOn = true
                nextWave = Int((line.beat(at: io.now() + io.ticks(ms: 30)) * Double(waveRate)).rounded(.up))
                knobSent = Array(repeating: -1, count: 8)
            } else {
                knobsOn = false
                leaveIfIdle()
            }
        }
    }

    private var running: Bool { transport || stepsOn || knobsOn }

    /// Entra sulla griglia se non c'è già; restituisce il battito da cui partire.
    private func joinIfNeeded() -> Double {
        if running {
            // un'altra parte gira già: si parte alla battuta dopo, sulla stessa griglia
            return line.bar(atOrAfter: io.now() + io.ticks(ms: 30))
        }
        let (l, first) = BobinaClock.shared.join(.m8, at: io.now() + io.ticks(ms: 30))
        line = l
        nextSixteenth = Int((first * 4).rounded())
        startTimer()
        return first
    }

    private func leaveIfIdle() {
        guard !running else { return }
        stopTimer()
        BobinaClock.shared.leave(.m8)
        let values = knobValues
        onKnobs?(values, nil)
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

    // MARK: il giro

    private func tick() {
        let now = io.now()
        let fresh = BobinaClock.shared.snapshot()
        if fresh.generation != line.generation {
            // cambio di tempo: si riprende dal primo impulso, passo e punto d'onda non ancora partiti
            line = fresh
            nextClockTick = Int((line.beat(at: now) * 24).rounded(.up))
            nextSixteenth = Int((line.beat(at: now) * 4).rounded(.up))
            nextWave = Int((line.beat(at: now) * Double(waveRate)).rounded(.up))
        }
        let horizon = now + io.ticks(ms: lookahead)
        let (p, knobs, kch) = plan()

        if transport {
            while line.time(ofBeat: Double(nextClockTick) / 24) < horizon {
                let due = line.time(ofBeat: Double(nextClockTick) / 24)
                // un impulso già in ritardo non si manda: storcerebbe il tempo che misura l'M8
                if due >= now && due > lastClockAt + io.ticks(ms: 2) {
                    io.send([0xF8], at: due)
                    lastClockAt = due
                }
                nextClockTick += 1
            }
        }

        // le onde: un punto ogni 1/16 di battito, mandato solo se il valore cambia
        if knobsOn && knobs.contains(where: { $0.motion == .wave }) {
            while line.time(ofBeat: Double(nextWave) / Double(waveRate)) < horizon {
                let t = line.time(ofBeat: Double(nextWave) / Double(waveRate))
                let beat = Double(nextWave) / Double(waveRate)
                for (k, knob) in knobs.enumerated() where k < 8 && knob.motion == .wave {
                    let length = max(0.25, knob.beats)
                    let turns = beat / length
                    let turn = Int(turns.rounded(.down))
                    var phase = turns - Double(turn)
                    if phase < 0 { phase += 1 }
                    let low = min(knob.low, knob.high), high = max(knob.low, knob.high)
                    let v = Int((Double(low) + Double(high - low) * knob.shape.level(phase, turn: turn, knob: k)).rounded())
                    knobValues[k] = v
                    if t >= now && v != knobSent[k] {
                        io.send(M8.cc(knob.cc, v, channel: kch), at: t)
                        knobSent[k] = v
                    }
                }
                nextWave += 1
            }
        } else {
            nextWave = Int((line.beat(at: now) * Double(waveRate)).rounded(.up))
        }

        // i sedicesimi: le note dei passi e l'automazione delle manopole
        while line.time(ofBeat: Double(nextSixteenth) / 4) < horizon {
            let t = line.time(ofBeat: Double(nextSixteenth) / 4)
            let len = max(1, min(16, p.length))
            let i = (nextSixteenth % len + len) % len
            if stepsOn && nextSixteenth >= notesFrom {
                if t >= now, let note = p.steps[i] {
                    let ch = UInt8((p.channel - 1) & 0x0F)
                    let n = UInt8(max(0, min(127, note)))
                    // la nota parte insieme al suo spegnimento: allo stop non resta niente acceso
                    io.send([0x90 | ch, n, UInt8(max(1, min(127, p.velocity)))], at: t)
                    io.send([0x80 | ch, n, 0], at: t + io.ticks(ms: line.beatMs / 4 * p.gate))
                }
                onStep?(i, t)
            }
            var autoStep: Int?
            if knobsOn {
                for (k, knob) in knobs.enumerated() where k < 8 && knob.motion == .steps {
                    autoStep = i
                    if let v = knob.steps[i] {
                        knobValues[k] = v
                        if t >= now && v != knobSent[k] {
                            io.send(M8.cc(knob.cc, v, channel: kch), at: t)
                            knobSent[k] = v
                        }
                    }
                }
                onKnobs?(knobValues, autoStep)
            }
            nextSixteenth += 1
        }
    }
}
