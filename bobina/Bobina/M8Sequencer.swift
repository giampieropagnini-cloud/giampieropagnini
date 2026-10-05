import Foundation
import CoreMIDI

/// Il tempo per l'M8: start, 24 impulsi di clock per quarto, stop. Sta sulla griglia di `BobinaClock`:
/// se suona già qualcuno (TX-6, PO, OP-Z) l'M8 parte all'inizio della battuta dopo.
/// Sull'M8: Project > MIDI > Settings > SYNC IN = CLOCK+TRANSP.
/// Gira su un filo suo e prepara i messaggi 150 ms prima, come gli altri sequencer.
final class M8Sequencer {
    private let io: MIDIIO
    private let queue = DispatchQueue(label: "bobina.m8.tempo", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private let lookahead = 150.0

    private var line = BobinaClock.Timeline()
    private var running = false
    private var nextClockTick = 0
    private var nextSixteenth = 0
    private var lastClockAt: MIDITimeStamp = 0

    /// Ogni sedicesimo che sta per suonare, col suo istante (sul filo del sequencer). Per i passi di Suona.
    var onSixteenth: ((Int, MIDITimeStamp) -> Void)?

    init(io: MIDIIO) {
        self.io = io
    }

    /// Parte adesso, o alla battuta dopo se qualcuno suona già.
    func start() {
        queue.async { [self] in
            guard !running else { return }
            let (l, first) = BobinaClock.shared.join(.m8, at: io.now() + io.ticks(ms: 30))
            line = l
            nextClockTick = Int((first * 24).rounded())
            nextSixteenth = Int((first * 4).rounded())
            lastClockAt = 0
            running = true
            io.send([0xFA], at: line.time(ofBeat: first))
            startTimer()
        }
    }

    func stop() {
        queue.async { [self] in
            guard running else { return }
            running = false
            stopTimer()
            io.send([0xFC])
            BobinaClock.shared.leave(.m8)
        }
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
        guard running else { return }
        let now = io.now()
        let fresh = BobinaClock.shared.snapshot()
        if fresh.generation != line.generation {
            // cambio di tempo: si riprende dal primo impulso che non è ancora partito
            line = fresh
            nextClockTick = Int((line.beat(at: now) * 24).rounded(.up))
            nextSixteenth = Int((line.beat(at: now) * 4).rounded(.up))
        }
        let horizon = now + io.ticks(ms: lookahead)
        while line.time(ofBeat: Double(nextClockTick) / 24) < horizon {
            let due = line.time(ofBeat: Double(nextClockTick) / 24)
            // un impulso già in ritardo non si manda: storcerebbe il tempo che misura l'M8
            if due >= now && due > lastClockAt + io.ticks(ms: 2) {
                io.send([0xF8], at: due)
                lastClockAt = due
            }
            nextClockTick += 1
        }
        while line.time(ofBeat: Double(nextSixteenth) / 4) < horizon {
            onSixteenth?(nextSixteenth, line.time(ofBeat: Double(nextSixteenth) / 4))
            nextSixteenth += 1
        }
    }
}
