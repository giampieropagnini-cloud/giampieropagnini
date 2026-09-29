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
        /// Il pattern che la pagina crede di suonare.
        var patternID: UUID?
    }

    /// Un pattern pronto a entrare all'inizio della prossima battuta.
    struct Part {
        var id: UUID
        var beats: [[Bool]]
        var melodies: [[Int?]]
        var melodyOctaves: [Int]
        var melodyLength: Int
        var locks: [Int?]
        var lockTrack: Int
        var lockCC: UInt8
        var lockBase: Int
        var gate: [Bool]
        /// I suoni delle tracce, mandati all'attacco della battuta.
        var soundBytes: [UInt8]
        /// Il tempo del pattern, se cambia anche quello.
        var bpm: Double?
    }

    /// Un pattern è entrato (sul filo del sequencer).
    var onSwitched: ((UUID) -> Void)?

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
    /// Le note da spegnere, per numero di passo (contato da quando è partito): vanno nel pacchetto di quel passo.
    private var offsAt: [Int: [UInt8]] = [:]
    /// Lo start va nel pacchetto del primo passo, prima del clock e delle note.
    private var startPending = false
    private var clockCount = 0
    private var pending: Part?
    private var override: Part?
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
            offsAt.removeAll()
            startPending = p.sendClock
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
            flushOffs()
        }
    }

    /// Il pattern entra all'inizio della prossima battuta.
    func queuePattern(_ part: Part) { queue.async { [self] in pending = part } }
    func cancelPending() { queue.async { [self] in pending = nil } }

    func releaseGateNow() { queue.async { [self] in releaseGate(plan()) } }
    func melodyOffNow() { queue.async { [self] in flushOffs() } }
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
                flushOffs()
            case 0xFC:
                releaseGate(p)
                flushOffs()
            case 0xF8:
                if clockCount % 6 == 0 {
                    let n = clockCount / 6
                    let t = io.now()
                    let prefix = switchIfDue(n % 16, at: t)
                    fire(n, at: t, effective(p), prefix: prefix, withClock: false)
                }
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
        var p = effective(plan())
        let now = io.now()
        if p.bpm != bpm {
            // il battito continua da dove era, alla nuova velocità
            anchorBeat = beat(at: now)
            anchorTime = now
            bpm = p.bpm
        }
        let horizon = now + io.ticks(ms: lookahead)
        while time(ofBeat: Double(nextSixteenth) / 4) < horizon {
            let n = nextSixteenth
            let t = max(now, time(ofBeat: Double(n) / 4))
            let prefix = switchIfDue(n % 16, at: t)
            if !prefix.isEmpty || override != nil { p = effective(plan()) }
            fire(n, at: t, p, prefix: prefix, withClock: p.sendClock)
            nextSixteenth += 1
        }
        if p.sendClock {
            // un impulso su sei cade insieme a un passo ed è già partito nel suo pacchetto
            while time(ofBeat: Double(nextClockTick) / 24) < horizon {
                if nextClockTick % 6 != 0 {
                    io.send(TX6.clock, at: max(now, time(ofBeat: Double(nextClockTick) / 24)))
                }
                nextClockTick += 1
            }
        } else {
            nextClockTick = nextSixteenth * 6
        }
    }

    // MARK: i pattern

    /// All'inizio della battuta entra il pattern in attesa: i suoni partono nello stesso pacchetto delle note.
    private func switchIfDue(_ i: Int, at t: MIDITimeStamp) -> [UInt8] {
        guard i == 0, let part = pending else { return [] }
        pending = nil
        override = part
        lockSent = nil
        if running, let b = part.bpm, b != bpm {
            anchorBeat = beat(at: t)
            anchorTime = t
            bpm = b
        }
        onSwitched?(part.id)
        return part.soundBytes.isEmpty ? [0xFE] : part.soundBytes
    }

    /// Il piano col pattern appena entrato, finché la pagina non se ne accorge.
    private func effective(_ base: Plan) -> Plan {
        guard let o = override else { return base }
        if base.patternID == o.id {
            override = nil
            return base
        }
        var p = base
        p.beats = o.beats
        p.melodies = o.melodies
        p.melodyOctaves = o.melodyOctaves
        p.melodyLength = o.melodyLength
        p.locks = o.locks
        p.lockTrack = o.lockTrack
        p.lockCC = o.lockCC
        p.lockBase = o.lockBase
        p.gate = o.gate
        if let b = o.bpm { p.bpm = b }
        return p
    }

    // MARK: un sedicesimo

    /// Batteria a passi, passi con manopola, melodia, cancello, pompa. `n` conta i passi da quando è partito.
    /// Col bluetooth ogni pacchetto costa: quello che parte nello stesso istante va insieme, e le note
    /// si spengono nel pacchetto di un passo successivo invece che in uno a parte.
    private func fire(_ n: Int, at t: MIDITimeStamp, _ p: Plan, prefix: [UInt8] = [], withClock: Bool) {
        let i = n % 16
        var now: [UInt8] = []
        if startPending { now += TX6.start; startPending = false }
        if withClock { now += TX6.clock }
        now += offsAt.removeValue(forKey: n) ?? []
        // 0xFE (active sensing) è solo un segnaposto per «è entrato un pattern senza suoni»: non si manda
        if prefix != [0xFE] { now += prefix }
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
                let note = p.padBase + TX6.padSteps[tr - 1]
                now += TX6.noteOn(note, channel: TX6.masterChannel)
                offsAt[n + 1, default: []] += TX6.noteOff(note, channel: TX6.masterChannel)
                hit.insert(tr)
            }
        }

        if p.melodyOn {
            for tr in 1...6 {
                guard let semi = p.melodies[tr - 1][i] else { continue }
                let note = 12 * (p.melodyOctaves[tr - 1] + 1) + semi
                now += TX6.noteOn(note, channel: tr)
                offsAt[n + max(1, p.melodyLength), default: []] += TX6.noteOff(note, channel: tr)
            }
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

        // la pompa: il tuffo parte col passo, poi tre punti per risalire
        if p.pumpOn && i % 4 == 0 && !p.pumpTops.isEmpty {
            func level(_ x: Double) -> [UInt8] {
                p.pumpTops.flatMap { TX6.cc(TX6.Param.volume.cc, Int(($0.top * (1 - p.pumpDepth * (1 - x) * (1 - x))).rounded()), channel: $0.track) }
            }
            now += level(0)
            for k in 1...3 {
                let x = Double(k) / 3
                io.send(level(x), at: t + io.ticks(ms: stepMs * 4 * p.pumpRelease * x))
            }
        }

        if !now.isEmpty { io.send(now, at: t) }
        onStep?(i, t, hit)
    }

    private func releaseGate(_ p: Plan) {
        guard gateState != nil else { return }
        gateState = nil
        var bytes: [UInt8] = []
        for tr in p.gateTracks { bytes += TX6.cc(TX6.ccMute, p.mutes[tr - 1] ? 127 : 0, channel: tr) }
        if !bytes.isEmpty { io.send(bytes) }
    }

    private func flushOffs() {
        let bytes = offsAt.keys.sorted().flatMap { offsAt[$0] ?? [] }
        offsAt.removeAll()
        if !bytes.isEmpty { io.send(bytes) }
    }
}
