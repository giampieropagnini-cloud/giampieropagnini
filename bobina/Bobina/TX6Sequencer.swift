import Foundation
import CoreMIDI

/// Il ritmo del TX-6 su un filo tutto suo: scorrere lo schermo non lo tocca.
/// La pagina gli passa il piano (cosa suonare) ogni volta che cambia; lui prepara i passi
/// 150 ms prima e li consegna a CoreMIDI con la marca temporale. Quando Bobina segue il TX-6,
/// il clock arriva qui direttamente dal filo del MIDI.
final class TX6Sequencer {

    /// Tutto quello che serve per suonare un passo. Lo scrive la pagina, lo legge il sequencer.
    struct Plan {
        var bpm = 120.0
        var sendClock = false
        var follow = false
        var padBase = 60
        var beatsOn = false
        var beats: [[Bool]] = Array(repeating: Array(repeating: false, count: 16), count: 6)
        var lockOn = false
        var lockTrack = 1
        var lockCC: UInt8 = 89
        var lockBase = 64
        var locks: [Int?] = Array(repeating: nil, count: 16)
        var melodyOn = false
        var melodies: [[Int?]] = Array(repeating: Array(repeating: nil, count: 16), count: 6)
        var melodyOctaves: [Int] = Array(repeating: 4, count: 6)
        var melodyLength = 1
        var gateOn = false
        var gate: [Bool] = Array(repeating: true, count: 16)
        var gateTracks: [Int] = []
        var mutes: [Bool] = Array(repeating: false, count: 6)
        var pumpOn = false
        var pumpDepth = 0.7
        var pumpRelease = 0.6
        /// Per ogni traccia della pompa, il volume di partenza.
        var pumpTops: [(track: Int, top: Double)] = []
    }

    /// Un passo è partito (sul filo del sequencer): il numero, l'istante, i pad che hanno suonato.
    var onStep: ((Int, MIDITimeStamp, Set<Int>) -> Void)?

    private let io: MIDIIO
    private let queue = DispatchQueue(label: "bobina.tx6.ritmo", qos: .userInteractive)
    private let lock = NSLock()
    private var shared = Plan()

    // da qui in giù: solo sul filo del sequencer
    private var timer: DispatchSourceTimer?
    private var running = false
    private var anchorTime: MIDITimeStamp = 0
    private var anchorBeat = 0.0
    private var bpm = 120.0
    private var nextSixteenth = 0
    private var nextClockTick = 0
    private var gateState: Bool?
    private var lockSent: Int?
    private var melodySounding: [Int: Int] = [:]
    private var clockCount = 0
    private let lookahead = 150.0

    init(io: MIDIIO) {
        self.io = io
    }

    // MARK: dalla pagina

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

    /// Parte col tempo di Bobina all'istante `at`. Se manda il clock, manda anche lo start.
    func start(at start: MIDITimeStamp) {
        queue.async { [self] in
            let p = plan()
            bpm = p.bpm
            anchorTime = start
            anchorBeat = 0
            nextSixteenth = 0
            nextClockTick = 0
            gateState = nil
            lockSent = nil
            if p.sendClock { io.send(TX6.start, at: start) }
            running = true
            startTimer()
        }
    }

    /// Si ferma: stop al TX-6 se era Bobina a dare il tempo, muti del cancello tolti, note della melodia spente.
    func stop(sendStop: Bool) {
        queue.async { [self] in
            running = false
            timer?.cancel()
            timer = nil
            if sendStop { io.send(TX6.stop) }
            releaseGate(plan())
            melodyOff()
        }
    }

    func releaseGateNow() { queue.async { [self] in releaseGate(plan()) } }
    func melodyOffNow() { queue.async { [self] in melodyOff() } }
    func forgetLock() { queue.async { [self] in lockSent = nil } }

    // MARK: dal filo del MIDI (Bobina segue il TX-6)

    func realtime(_ status: UInt8, _ stamp: MIDITimeStamp) {
        queue.async { [self] in
            let p = plan()
            guard p.follow else { return }
            switch status {
            case 0xFA, 0xFB:
                clockCount = 0
                gateState = nil
                lockSent = nil
            case 0xFC:
                releaseGate(p)
                melodyOff()
            case 0xF8:
                if clockCount % 6 == 0 { fire((clockCount / 6) % 16, at: io.now(), p) }
                clockCount += 1
            default:
                break
            }
        }
    }

    // MARK: l'orologio

    private func startTimer() {
        timer?.cancel()
        let t = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        t.schedule(deadline: .now(), repeating: .milliseconds(5), leeway: .milliseconds(1))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    private var beatMs: Double { 60_000 / max(40, min(300, bpm)) }

    private func beat(at t: MIDITimeStamp) -> Double {
        let ms = t >= anchorTime ? io.ms(ticks: t - anchorTime) : -io.ms(ticks: anchorTime - t)
        return anchorBeat + ms / beatMs
    }

    private func time(ofBeat b: Double) -> MIDITimeStamp {
        anchorTime + io.ticks(ms: (b - anchorBeat) * beatMs)
    }

    private func tick() {
        guard running else { return }
        let p = plan()
        let now = io.now()
        if p.bpm != bpm {
            // il battito continua da dove era, alla nuova velocità
            anchorBeat = beat(at: now)
            anchorTime = now
            bpm = p.bpm
        }
        let horizon = now + io.ticks(ms: lookahead)
        while time(ofBeat: Double(nextSixteenth) / 4) < horizon {
            fire(nextSixteenth % 16, at: max(now, time(ofBeat: Double(nextSixteenth) / 4)), p)
            nextSixteenth += 1
        }
        if p.sendClock {
            while time(ofBeat: Double(nextClockTick) / 24) < horizon {
                io.send(TX6.clock, at: max(now, time(ofBeat: Double(nextClockTick) / 24)))
                nextClockTick += 1
            }
        }
    }

    // MARK: un sedicesimo

    /// Batteria a passi, passi con manopola, melodia, cancello, pompa.
    /// Col bluetooth ogni pacchetto costa: quello che parte nello stesso istante va insieme.
    private func fire(_ i: Int, at t: MIDITimeStamp, _ p: Plan) {
        var now: [UInt8] = []
        var off: [UInt8] = []
        var hit: Set<Int> = []
        let stepMs = 60_000 / max(40, min(300, p.bpm)) / 4

        if p.beatsOn {
            if p.lockOn {
                let target = p.locks[i] ?? p.lockBase
                if target != lockSent {
                    now += TX6.cc(p.lockCC, target, channel: p.lockTrack)
                    lockSent = target
                }
            }
            for tr in 1...6 where p.beats[tr - 1][i] {
                let n = p.padBase + TX6.padSteps[tr - 1]
                now += TX6.noteOn(n, channel: TX6.masterChannel)
                off += TX6.noteOff(n, channel: TX6.masterChannel)
                hit.insert(tr)
            }
        }

        if p.melodyOn {
            var end: [UInt8] = []
            for tr in 1...6 {
                guard let semi = p.melodies[tr - 1][i] else { continue }
                let n = 12 * (p.melodyOctaves[tr - 1] + 1) + semi
                now += TX6.noteOn(n, channel: tr)
                end += TX6.noteOff(n, channel: tr)
                melodySounding[tr] = n
            }
            if !end.isEmpty { io.send(end, at: t + io.ticks(ms: stepMs * Double(p.melodyLength) * 0.9)) }
        }

        if p.gateOn {
            let open = p.gate[i]
            if open != gateState {
                gateState = open
                for tr in p.gateTracks {
                    now += TX6.cc(TX6.ccMute, open ? (p.mutes[tr - 1] ? 127 : 0) : 127, channel: tr)
                }
            }
        }

        if !now.isEmpty { io.send(now, at: t) }
        if !off.isEmpty { io.send(off, at: t + io.ticks(ms: 40)) }

        if p.pumpOn && i % 4 == 0 && !p.pumpTops.isEmpty {
            let points = 6
            for k in 0...points {
                let x = Double(k) / Double(points)
                var bytes: [UInt8] = []
                for (tr, top) in p.pumpTops {
                    bytes += TX6.cc(TX6.Param.volume.cc, Int((top * (1 - p.pumpDepth * (1 - x) * (1 - x))).rounded()), channel: tr)
                }
                io.send(bytes, at: t + io.ticks(ms: stepMs * 4 * p.pumpRelease * x))
            }
        }

        onStep?(i, t, hit)
    }

    private func releaseGate(_ p: Plan) {
        guard gateState != nil else { return }
        gateState = nil
        var bytes: [UInt8] = []
        for tr in p.gateTracks { bytes += TX6.cc(TX6.ccMute, p.mutes[tr - 1] ? 127 : 0, channel: tr) }
        if !bytes.isEmpty { io.send(bytes) }
    }

    private func melodyOff() {
        var bytes: [UInt8] = []
        for (tr, n) in melodySounding { bytes += TX6.noteOff(n, channel: tr) }
        melodySounding.removeAll()
        if !bytes.isEmpty { io.send(bytes) }
    }
}
