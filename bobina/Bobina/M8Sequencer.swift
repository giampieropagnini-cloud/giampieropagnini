import Foundation
import CoreMIDI

/// Il tempo per l'M8. Due cose indipendenti sulla griglia di `BobinaClock`:
/// - **trasporto**: start, 24 impulsi di clock per quarto, stop (sull'M8: SYNC IN = CLOCK+TRANSP.);
/// - **passi**: 16 sedicesimi di note che suonano uno strumento dell'M8 sul suo canale di ingresso.
/// Se suona già qualcuno (TX-6, PO, OP-Z) si parte all'inizio della battuta dopo.
/// Gira su un filo suo e prepara i messaggi 150 ms prima, come gli altri sequencer.
final class M8Sequencer {

    /// Quello che decide la pagina. Si legge sotto lock dal filo del sequencer.
    struct Plan {
        /// La nota di ogni passo (nil = vuoto).
        var steps: [Int?] = Array(repeating: nil, count: 16)
        var channel = 1
        var velocity = 100
        /// Quanto dura la nota, in frazioni di sedicesimo.
        var gate = 0.5
        /// 8 o 16 passi.
        var length = 16
    }

    private let io: MIDIIO
    private let queue = DispatchQueue(label: "bobina.m8.tempo", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private let lookahead = 150.0

    private let lock = NSLock()
    private var shared = Plan()

    private var line = BobinaClock.Timeline()
    private var transport = false
    private var stepsOn = false
    private var nextClockTick = 0
    private var nextSixteenth = 0
    private var firstSixteenth = 0
    private var lastClockAt: MIDITimeStamp = 0

    /// Il passo che sta per suonare (0-15), col suo istante. Chiamata sul filo del sequencer.
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
                nextSixteenth = Int((first * 4).rounded())
                firstSixteenth = nextSixteenth
            } else {
                stepsOn = false
                leaveIfIdle()
            }
        }
    }

    /// Entra sulla griglia se non c'è già; restituisce il battito da cui partire.
    private func joinIfNeeded() -> Double {
        if transport || stepsOn {
            // l'altra metà gira già: si parte alla battuta dopo, sulla stessa griglia
            return line.bar(atOrAfter: io.now() + io.ticks(ms: 30))
        }
        let (l, first) = BobinaClock.shared.join(.m8, at: io.now() + io.ticks(ms: 30))
        line = l
        startTimer()
        return first
    }

    private func leaveIfIdle() {
        guard !transport && !stepsOn else { return }
        stopTimer()
        BobinaClock.shared.leave(.m8)
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
            // cambio di tempo: si riprende dal primo impulso e dal primo passo non ancora partiti
            line = fresh
            nextClockTick = Int((line.beat(at: now) * 24).rounded(.up))
            nextSixteenth = Int((line.beat(at: now) * 4).rounded(.up))
        }
        let horizon = now + io.ticks(ms: lookahead)
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
        if stepsOn {
            let p = plan()
            while line.time(ofBeat: Double(nextSixteenth) / 4) < horizon {
                let t = line.time(ofBeat: Double(nextSixteenth) / 4)
                let len = max(1, min(16, p.length))
                let i = ((nextSixteenth - firstSixteenth) % len + len) % len
                if t >= now, let note = p.steps[i] {
                    let ch = UInt8((p.channel - 1) & 0x0F)
                    let n = UInt8(max(0, min(127, note)))
                    io.send([0x90 | ch, n, UInt8(max(1, min(127, p.velocity)))], at: t)
                    io.send([0x80 | ch, n, 0], at: t + io.ticks(ms: line.beatMs / 4 * p.gate))
                }
                onStep?(i, t)
                nextSixteenth += 1
            }
        }
    }
}
