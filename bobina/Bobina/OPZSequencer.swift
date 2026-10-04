import Foundation
import CoreMIDI

/// Il ritmo dell'OP-Z su un filo tutto suo, come quelli del TX-6 e dei PO: scorrere lo schermo non lo tocca.
/// Sta sulla griglia di `BobinaClock`: se qualcuno suona già, l'OP-Z parte all'inizio della battuta dopo.
///
/// Cosa fa a tempo:
/// - col clock: 24 impulsi per quarto, start sul primo battito;
/// - da solo: tempo (CC 56) e start sul primo battito, poi l'OP-Z va col suo orologio;
/// - a ogni inizio di battuta: i cambi chiesti «alla battuta» (pattern, scene di muti) e la canzone a pattern.
///
/// Il cambio pattern dell'OP-Z è immediato e tiene la posizione del passo: per questo parte un soffio prima
/// della battuta, così il primo passo è già quello del pattern nuovo. Tutto quello che cade nello stesso istante
/// parte in un solo pacchetto: col bluetooth ogni pacchetto costa.
final class OPZSequencer {

    struct Plan {
        var sync = OPZSync.clock
        /// Quanto prima della griglia parte tutto, per il ritardo del bluetooth (ms, anche negativo).
        var leadMs = 0.0
        /// Col clock: gli impulsi vanno anche da fermi, così l'OP-Z sa già il tempo quando arriva lo start.
        var clockAlways = false
        var bpm = 120.0
        /// Il progetto dell'OP-Z (1-10): è il canale del CC 103.
        var project = 1
        /// La canzone a pattern: un pattern (1-16) per voce, ognuno per `songBars` battute.
        var songOn = false
        var song: [Int] = [1, 2]
        var songBars = 4
        /// Crea: Bobina suona le tracce 1-8 a passi. Per ogni traccia, 16 passi, ognuno con le sue note.
        var createOn = false
        /// I 16 pattern di Crea: per ognuno 8 tracce × 16 passi, ognuno con le sue note.
        var patterns: [[[[Int]]]] = Array(repeating: Array(repeating: Array(repeating: [], count: 16), count: 8), count: 16)
        /// Il pattern di Crea da suonare (0-15): cambia all'inizio della battuta. Con la canzone accesa decide la canzone.
        var createPattern = 0
        var trackOn: [Bool] = Array(repeating: true, count: 8)
        /// Gli effetti di Bobina tenuti adesso dal vivo.
        var fxLive: Set<CreaFx> = []
        /// Su quale traccia (1-8) lavorano gli effetti; nil = su tutte.
        var fxTrack: Int?
        /// Gli effetti scritti nei passi, per pattern: 16 passi, un effetto o niente.
        var fxSteps: [[CreaFx?]] = Array(repeating: Array(repeating: nil, count: 16), count: 16)
        /// Gli effetti dei passi suonano solo nell'ultima di ogni tot battute (1 = sempre).
        var fxEvery = 1
    }

    /// Un battito è partito: battuta (da 0) e quarto (0-3), con l'istante. Per la pagina.
    var onBeat: ((Int, Int, MIDITimeStamp) -> Void)?
    /// La canzone ha chiesto un pattern (1-16): voce della canzone e pattern, con l'istante.
    var onSongPattern: ((Int, Int, MIDITimeStamp) -> Void)?
    /// Un sedicesimo di Crea è partito (0-15), con l'istante; -1 = Crea tace. Per le caselle.
    var onStep: ((Int, MIDITimeStamp) -> Void)?
    /// Il pattern di Crea che suona da questa battuta (0-15), con l'istante.
    var onCreatePattern: ((Int, MIDITimeStamp) -> Void)?
    /// Il giro «scrivi sull'OP-Z» è finito.
    var onOnceDone: (() -> Void)?
    /// Un messaggio raro è partito (per il monitor). Niente clock.
    var onSent: (([UInt8]) -> Void)?

    private let io: MIDIIO
    private let queue = DispatchQueue(label: "bobina.opz.ritmo", qos: .userInteractive)
    private let lock = NSLock()
    private var shared = Plan()
    /// Quello che aspetta l'inizio della battuta dopo, già in byte.
    private var waiting: [UInt8] = []
    /// Chiesto un giro solo dei passi di Crea, dalla battuta dopo (sotto lock).
    private var onceRequested = false

    // da qui in giù: solo sul filo del sequencer
    private var timer: DispatchSourceTimer?
    private var running = false
    private var line = BobinaClock.Timeline()
    private var firstBeat = 0.0
    private var nextBeat = 0
    private var nextClockTick = 0
    private var lastClockAt: MIDITimeStamp = 0
    private var startPending = false
    private var songIndex: Int?
    /// L'ultimo tempo detto all'OP-Z col CC 56: seguendo il TX-6 la griglia si sposta a ogni battito, il bpm intero no.
    private var lastTempo: Int?
    private var nextSixteenth = 0
    /// Il primo sedicesimo dopo la partenza: lì si dice sempre alla pagina quale pattern di Crea suona.
    private var nextSixteenthStart = 0
    /// Le note da lasciare, per sedicesimo: vanno nel pacchetto di quel passo.
    private var offsAt: [Int: [UInt8]] = [:]
    /// La battuta del giro solo (Crea → scrivi sull'OP-Z).
    private var onceBar: Int?
    /// Il pattern di Crea che suona adesso.
    private var curCreate = 0
    /// Le note che partono più tardi (l'eco), per sedicesimo.
    private var onsAt: [Int: [UInt8]] = [:]
    /// Gli effetti accesi al passo prima, e da quando.
    private var fxPrev: Set<CreaFx> = []
    private var fxSince: [CreaFx: Int] = [:]
    /// Quanti passi relativi in giù (filtro e volume) restano da riportare su, per traccia: così l'OP-Z torna com'era.
    private var sweepNet: [Int: Int] = [:]
    private var duckNet: [Int: Int] = [:]
    /// Il filter sweep su tutte usa il filtro del master (neutro a 64): va rimesso a 64.
    private var masterSwept = false
    private let lookahead = 150.0
    /// Quanto prima della battuta parte il cambio pattern.
    private let patternEarlyMs = 15.0

    init(io: MIDIIO) {
        self.io = io
    }

    // MARK: dalla pagina

    func update(_ plan: Plan) {
        lock.lock()
        let wasClock = shared.clockAlways && shared.sync == .clock
        shared = plan
        lock.unlock()
        let isClock = plan.clockAlways && plan.sync == .clock
        if isClock != wasClock {
            queue.async { [self] in
                if isClock { startTimer() } else if !running { stopTimer() }
            }
        }
    }

    private func plan() -> Plan {
        lock.lock()
        defer { lock.unlock() }
        return shared
    }

    /// Mette da parte dei messaggi per l'inizio della battuta dopo. Se l'OP-Z è fermo non li prende
    /// e restituisce false: allora li manda subito chi chiama.
    func atNextBar(_ bytes: [UInt8]) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard runningCopy else { return false }
        waiting += bytes
        return true
    }

    /// Copia di `running` da leggere sotto lock fuori dal filo del sequencer.
    private var runningCopy = false

    /// Un giro solo dei passi di Crea, dalla prossima battuta: per farli registrare all'OP-Z in record lock.
    func playOnce() {
        lock.lock()
        onceRequested = true
        lock.unlock()
    }

    /// Parte all'istante `start`, o all'inizio della battuta dopo se qualcuno suona già.
    func start(at start: MIDITimeStamp) {
        queue.async { [self] in
            guard !running else { return }
            let p = plan()
            let (l, first) = BobinaClock.shared.join(.opz, at: start)
            line = l
            firstBeat = first
            nextBeat = Int(first.rounded())
            nextClockTick = Int((first * 24).rounded())
            nextSixteenth = Int((first * 4).rounded())
            nextSixteenthStart = nextSixteenth
            offsAt.removeAll()
            onceBar = nil
            if p.sync == .clock && timer != nil && lastClockAt != 0 {
                // il clock va già: si riprende dal primo impulso non ancora partito
                nextClockTick = max(nextClockTick, Int((line.beat(at: io.now()) * 24).rounded(.up)))
            }
            startPending = true
            songIndex = nil
            running = true
            setRunningCopy(true)
            let t0 = at(line.time(ofBeat: first), p)
            var head: [UInt8] = []
            // la canzone comincia dal suo primo pattern, prima dello start
            curCreate = p.createPattern
            if p.songOn, let pat = p.song.first {
                // con Crea acceso la canzone cambia i pattern di Bobina, non quelli dell'OP-Z
                if p.createOn { curCreate = pat - 1 } else { head += OPZ.pattern(pat, project: p.project) }
                songIndex = 0
                onSongPattern?(0, pat, t0)
            }
            if p.sync == .own {
                let v = tempoValue(line.bpm)
                head += OPZ.tempo(Double(v))
                lastTempo = v
            }
            if !head.isEmpty { send(head, at: t0 > io.ticks(ms: 40) ? t0 - io.ticks(ms: 40) : t0) }
            startTimer()
        }
    }

    /// Si ferma: stop all'OP-Z, e la griglia lo lascia andare.
    func stop() {
        queue.async { [self] in
            guard running else { return }
            let p = plan()
            running = false
            setRunningCopy(false)
            startPending = false
            lock.lock()
            waiting.removeAll()
            lock.unlock()
            BobinaClock.shared.leave(.opz)
            if !(p.clockAlways && p.sync == .clock) { stopTimer() }
            let offs = offsAt.values.flatMap { $0 } + fxRestore(all: true)
            offsAt.removeAll()
            onsAt.removeAll()
            fxPrev = []
            fxSince = [:]
            if onceBar != nil { onceBar = nil; onOnceDone?() }
            lock.lock()
            onceRequested = false
            lock.unlock()
            send(offs + OPZ.stop, at: 0)
            onStep?(-1, io.now())
        }
    }

    private func setRunningCopy(_ v: Bool) {
        lock.lock()
        runningCopy = v
        lock.unlock()
    }

    // MARK: l'orologio

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
        lastClockAt = 0
    }

    /// L'istante vero di un evento della griglia: un po' prima, per il ritardo del bluetooth.
    private func at(_ t: MIDITimeStamp, _ p: Plan) -> MIDITimeStamp {
        p.leadMs >= 0 ? t &- io.ticks(ms: p.leadMs) : t &+ io.ticks(ms: -p.leadMs)
    }

    private func tick() {
        let p = plan()
        let now = io.now()
        let fresh = BobinaClock.shared.snapshot()
        if fresh.generation != line.generation {
            line = fresh
            // la griglia si è spostata (cambio di tempo, il TX-6 è ripartito): si riparte dal battito giusto
            let t = line.time(ofBeat: Double(nextBeat))
            if running && (t + io.ticks(ms: 30) < now || t > now + io.ticks(ms: line.beatMs + lookahead)) {
                nextBeat = Int(line.beat(at: now).rounded(.up))
                nextSixteenth = Int((line.beat(at: now) * 4).rounded(.up))
            }
            nextClockTick = Int((line.beat(at: now) * 24).rounded(.up))
            // da solo l'OP-Z non sente il clock: il tempo nuovo glielo si dice
            if running && p.sync == .own && tempoValue(line.bpm) != lastTempo {
                let v = tempoValue(line.bpm)
                send(OPZ.tempo(Double(v)), at: 0)
                lastTempo = v
            }
        }
        let horizon = now + io.ticks(ms: lookahead + max(0, p.leadMs))

        // i battiti: start, cambi alla battuta, canzone
        if running {
            while line.time(ofBeat: Double(nextBeat)) < horizon {
                beat(nextBeat, p, now)
                nextBeat += 1
            }
            while line.time(ofBeat: Double(nextSixteenth) / 4) < horizon {
                sixteenth(nextSixteenth, p, now)
                nextSixteenth += 1
            }
        }

        // il clock, in ordine, ognuno col suo istante
        let clockOn = p.sync == .clock && (running || p.clockAlways)
        if clockOn {
            while line.time(ofBeat: Double(nextClockTick) / 24) < horizon {
                let due = at(line.time(ofBeat: Double(nextClockTick) / 24), p)
                // un impulso già in ritardo non si manda: storcerebbe il tempo che misura l'OP-Z
                if due >= now && due > lastClockAt + io.ticks(ms: 2) {
                    io.send(OPZ.clock, at: due)
                    lastClockAt = due
                }
                nextClockTick += 1
            }
        } else {
            nextClockTick = Int((line.beat(at: now) * 24).rounded(.up))
        }
    }

    private func tempoValue(_ bpm: Double) -> Int {
        Int(min(OPZ.tempoRange.upperBound, max(OPZ.tempoRange.lowerBound, bpm)).rounded())
    }

    // MARK: un battito

    private func beat(_ b: Int, _ p: Plan, _ now: MIDITimeStamp) {
        let t = max(now, at(line.time(ofBeat: Double(b)), p))
        let rel = b - Int(firstBeat.rounded())
        let bar = rel >= 0 ? rel / 4 : 0
        let quarter = ((rel % 4) + 4) % 4
        if startPending {
            startPending = false
            // lo start nello stesso pacchetto del primo impulso: arriva prima, l'OP-Z parte su quell'impulso
            send(OPZ.start, at: t)
        }
        // a ogni battere (non il primo): i cambi aspettati e la canzone, un soffio prima
        if quarter == 0 && rel > 0 {
            var bytes: [UInt8] = []
            lock.lock()
            bytes += waiting
            waiting.removeAll()
            lock.unlock()
            if p.songOn && !p.song.isEmpty {
                let idx = (bar / max(1, p.songBars)) % p.song.count
                if idx != songIndex {
                    let pat = p.song[idx]
                    if !p.createOn { bytes += OPZ.pattern(pat, project: p.project) }
                    songIndex = idx
                    onSongPattern?(idx, pat, t)
                }
            }
            if !bytes.isEmpty {
                let early = io.ticks(ms: patternEarlyMs)
                send(bytes, at: t > now + early ? t - early : now)
            }
        }
        onBeat?(bar, quarter, t)
    }

    // MARK: un sedicesimo di Crea

    /// Le note di tutte le tracce di questo passo in un pacchetto solo, con le note del passo prima che finiscono.
    private func sixteenth(_ n: Int, _ p: Plan, _ now: MIDITimeStamp) {
        let t = max(now, at(line.time(ofBeat: Double(n) / 4), p))
        let i = ((n % 16) + 16) % 16
        let bar = n >= 0 ? n / 16 : (n - 15) / 16
        if i == 0 {
            if let b = onceBar, bar > b {
                onceBar = nil
                onOnceDone?()
            }
            lock.lock()
            let wanted = onceRequested
            onceRequested = false
            lock.unlock()
            if wanted { onceBar = bar }
            let next = p.createOn && p.songOn && !p.song.isEmpty ? p.song[songIndex ?? 0] - 1 : p.createPattern
            if next != curCreate || n == nextSixteenthStart {
                curCreate = max(0, min(15, next))
                onCreatePattern?(curCreate, t)
            }
        }
        let playing = p.createOn || onceBar == bar
        var bytes = offsAt.removeValue(forKey: n) ?? []
        bytes += onsAt.removeValue(forKey: n) ?? []

        // gli effetti: quelli tenuti dal vivo più quello scritto in questo passo
        var active = playing ? p.fxLive : []
        let fxBar = p.fxEvery <= 1 || (bar - nextSixteenthStart / 16) % p.fxEvery == p.fxEvery - 1
        if playing && fxBar, p.fxSteps.indices.contains(curCreate), let f = p.fxSteps[curCreate][i] { active.insert(f) }
        for f in active.subtracting(fxPrev) { fxSince[f] = n }
        if !fxPrev.subtracting(active).isEmpty {
            // finito un filter sweep o un duck: il filtro e il volume tornano dov'erano
            if fxPrev.contains(.sweep) && !active.contains(.sweep) { bytes += fxRestore(sweep: true) }
            if fxPrev.contains(.duck) && !active.contains(.duck) { bytes += fxRestore(duck: true) }
        }
        fxPrev = active
        let scope: Set<Int> = p.fxTrack.map { [$0 - 1] } ?? Set(0..<8)
        let stepMs = line.beatMs / 4

        if playing {
            let steps = p.patterns[max(0, min(p.patterns.count - 1, curCreate))]
            // da quale passo si leggono le note: il loop ripete, il random rimescola
            var src = i
            if active.contains(.loop2), let a = fxSince[.loop2] { src = ((a - 8 + (n - a) % 8) % 16 + 16) % 16 }
            else if active.contains(.loop1), let a = fxSince[.loop1] { src = ((a - 4 + (n - a) % 4) % 16 + 16) % 16 }
            if active.contains(.random) { src = Int.random(in: 0..<16) }
            var repeats = 1
            if active.contains(.rampUp), let a = fxSince[.rampUp] { repeats = min(4, 1 + (n - a) / 4) }
            if active.contains(.rampDown), let a = fxSince[.rampDown] { repeats = max(1, 4 - (n - a) / 4) }

            var offs: [UInt8] = []
            var shortOffs: [UInt8] = []
            var longOffs: [UInt8] = []
            var subs: [[UInt8]] = Array(repeating: [], count: 4)
            for track in 0..<min(8, steps.count) where p.trackOn[track] {
                let mine = scope.contains(track)
                for raw in steps[track][mine ? src : i] {
                    let note = mine && active.contains(.pitch) && track >= 4 ? min(127, raw + 12) : raw
                    let ch = track + 1
                    bytes += OPZ.noteOn(note, velocity: 100, channel: ch)
                    if mine && repeats > 1 {
                        for j in 1..<repeats { subs[j] += OPZ.noteOff(note, channel: ch) + OPZ.noteOn(note, velocity: 90, channel: ch) }
                    }
                    if mine && active.contains(.short) { shortOffs += OPZ.noteOff(note, channel: ch) }
                    else if mine && active.contains(.long) { longOffs += OPZ.noteOff(note, channel: ch) }
                    else { offs += OPZ.noteOff(note, channel: ch) }
                    if mine && active.contains(.echo) {
                        onsAt[n + 3, default: []] += OPZ.noteOn(note, velocity: 45, channel: ch)
                        offsAt[n + 4, default: []] += OPZ.noteOff(note, channel: ch)
                    }
                }
            }
            if !offs.isEmpty { offsAt[n + 1, default: []] += offs }
            if !longOffs.isEmpty { offsAt[n + 3, default: []] += longOffs }
            if !shortOffs.isEmpty { io.send(shortOffs, at: t + io.ticks(ms: min(30, stepMs / 3))) }
            for j in 1..<repeats where !subs[j].isEmpty {
                io.send(subs[j], at: t + io.ticks(ms: stepMs * Double(j) / Double(repeats)))
            }

            // filter sweep: giù per mezza battuta, su per l'altra metà
            if active.contains(.sweep), let a = fxSince[.sweep] {
                let phase = ((n - a) % 16 + 16) % 16
                if p.fxTrack == nil {
                    let depth = phase < 8 ? phase : 16 - phase
                    bytes += OPZ.cc(3, 64 - depth * 7, channel: 12)
                    masterSwept = true
                } else {
                    for track in scope {
                        let down = phase < 8
                        bytes += relative(cc: 3, track: track + 1, count: 12, down: down)
                        sweepNet[track, default: 0] += down ? 12 : -12
                    }
                }
            }
            // duck: a ogni battere il volume giù, poi risale nei tre sedicesimi dopo
            if active.contains(.duck) {
                let q = ((n % 4) + 4) % 4
                for track in scope where p.trackOn[track] {
                    // 4/10/2026: con 8 giù si sentiva poco («pompa un po' di più»)
                    let amount = q == 0 ? 20 : (q == 3 ? 6 : 7)
                    bytes += relative(cc: 16, track: track + 1, count: amount, down: q == 0)
                    duckNet[track, default: 0] += q == 0 ? amount : -amount
                }
            }
        }
        if !bytes.isEmpty { io.send(bytes, at: t) }
        onStep?(playing ? i : -1, t)
    }

    /// `count` passi relativi (CC 32-49) in su o in giù, in un pezzo solo.
    private func relative(cc: Int, track: Int, count: Int, down: Bool) -> [UInt8] {
        (0..<max(0, count)).flatMap { _ in OPZ.cc(cc + 31, down ? 127 : 1, channel: track) }
    }

    /// Riporta filtro e volume dove erano prima del filter sweep e del duck.
    private func fxRestore(sweep: Bool = false, duck: Bool = false, all: Bool = false) -> [UInt8] {
        var bytes: [UInt8] = []
        if sweep || all {
            for (track, net) in sweepNet where net != 0 { bytes += relative(cc: 3, track: track + 1, count: abs(net), down: net < 0) }
            sweepNet = [:]
            if masterSwept { bytes += OPZ.cc(3, 64, channel: 12); masterSwept = false }
        }
        if duck || all {
            for (track, net) in duckNet where net != 0 { bytes += relative(cc: 16, track: track + 1, count: abs(net), down: net < 0) }
            duckNet = [:]
        }
        return bytes
    }

    private func send(_ bytes: [UInt8], at t: MIDITimeStamp) {
        io.send(bytes, at: t)
        onSent?(bytes)
    }
}
