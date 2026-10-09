import Foundation

/// Le note che Bobina ha acceso sul TX-6 (canale e nota) dall'ultimo «silenzio». «silenzio» spegne queste e
/// basta: prima ne mandava 768, una per nota e canale, e col bluetooth il TX-6 a volte si bloccava (8/10/2026).
/// Resta salvato, così al collegamento dopo una chiusura brusca si spengono anche quelle rimaste accese.
final class TX6PlayedNotes {
    static let shared = TX6PlayedNotes()
    private let lock = NSLock()
    private var notes: Set<Int>
    private static let key = "bobina.tx6.notesuonate"

    private init() {
        notes = Set(UserDefaults.standard.array(forKey: Self.key) as? [Int] ?? [])
    }

    func add(_ channel: Int, _ note: Int) {
        let k = channel << 8 | (note & 0x7F)
        lock.lock()
        let fresh = notes.insert(k).inserted
        let all = fresh ? Array(notes) : nil
        lock.unlock()
        if let all = all { DispatchQueue.main.async { UserDefaults.standard.set(all, forKey: Self.key) } }
    }

    /// Tutte le note da spegnere, e il registro riparte vuoto.
    func takeAll() -> [(channel: Int, note: Int)] {
        lock.lock()
        let all = notes
        notes.removeAll()
        lock.unlock()
        UserDefaults.standard.set([Int](), forKey: Self.key)
        return all.map { (channel: $0 >> 8, note: $0 & 0x7F) }
    }
}
import CoreMIDI

/// Il ritmo del TX-6 su un filo tutto suo: scorrere lo schermo non lo tocca.
/// La pagina gli passa il piano (cosa suonare) ogni volta che cambia; lui prepara i passi
/// 150 ms prima e li consegna a CoreMIDI con la marca temporale. Quando Bobina segue il TX-6,
/// il clock arriva qui direttamente dal filo del MIDI.
/// I passi stanno sulla griglia di `BobinaClock`, la stessa dei PO: se qualcuno suona già, il TX-6
/// entra all'inizio della battuta dopo. Quando segue il TX-6, è lui a spostare la griglia.
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
        /// Per ogni traccia 16 passi (una battuta) o 32 (due): ognuna gira sulla sua lunghezza.
        var melodies: [[Int?]] = Array(repeating: Array(repeating: nil, count: 16), count: 6)
        var melodyOctaves: [Int] = Array(repeating: 4, count: 6)
        /// Quanti sedicesimi resta giù ogni nota, per traccia: 0 = tenuta fino alla nota dopo.
        var melodyGates: [Int] = Array(repeating: 1, count: 6)
        var gateOn = false
        var gate: [Bool] = Array(repeating: true, count: 16)
        var gateTracks: [Int] = []
        var mutes: [Bool] = Array(repeating: false, count: 6)
        /// Il volume di ogni traccia come deve uscire adesso (zero se è muta): il cancello lo rimette nei passi aperti.
        var volumes: [Int] = Array(repeating: 100, count: 6)
        var pumpOn = false
        var pumpDepth = 0.7
        var pumpRelease = 0.6
        /// Per ogni traccia della pompa, il volume di partenza.
        var pumpTops: [(track: Int, top: Double)] = []
        /// Il pattern che la pagina crede di suonare.
        var patternID: UUID?
        /// Lo swing come sulle MPC: 0,5 dritto, 0,66 terzina. I sedicesimi dispari arrivano in ritardo.
        var swing = 0.5
    }

    /// Un pattern pronto a entrare all'inizio della prossima battuta.
    struct Part {
        var id: UUID
        var beats: [[Bool]]
        var melodies: [[Int?]]
        var melodyOctaves: [Int]
        var melodyGates: [Int]
        var locks: [Int?]
        var lockTrack: Int
        var lockCC: UInt8
        var lockBase: Int
        var gate: [Bool]
        /// I suoni delle tracce, mandati all'attacco della battuta.
        var soundBytes: [UInt8]
        /// Il tempo del pattern, se cambia anche quello.
        var bpm: Double?
        /// Lo swing del pattern, se ne ha uno.
        var swing: Double? = nil
    }

    /// Un pattern è entrato (sul filo del sequencer).
    var onSwitched: ((UUID) -> Void)?

    /// Un passo è partito (sul filo del sequencer): il numero (contato da quando è partito), l'istante, i pad che hanno suonato.
    var onStep: ((Int, MIDITimeStamp, Set<Int>) -> Void)?

    private let io: MIDIIO
    private let queue = DispatchQueue(label: "bobina.tx6.ritmo", qos: .userInteractive)
    private let lock = NSLock()
    private var shared = Plan()

    // da qui in giù: solo sul filo del sequencer
    private var timer: DispatchSourceTimer?
    private var running = false
    /// La griglia di Bobina, letta a ogni giro.
    private var line = BobinaClock.Timeline()
    private var nextSixteenth = 0
    private var nextClockTick = 0
    private var gateState: Bool?
    private var lockSent: Int?
    /// Le note da spegnere, per numero di passo (contato da quando è partito): vanno nel pacchetto di quel passo.
    private var offsAt: [Int: [UInt8]] = [:]
    /// Le note delle melodie ancora giù, una per traccia (una traccia del TX-6 suona una nota alla volta):
    /// la nota e il passo in cui va spenta. Una nota nuova sulla stessa traccia spegne prima quella di prima,
    /// così uno spegnimento in ritardo non taglia mai la nota dopo (anche con durate lunghe e note fitte).
    /// `at` è l'istante della nota accesa (può essere fino a 150 ms avanti): lo spegnimento non deve mai partire prima.
    private var melodyHeld: [Int: (note: Int, until: Int, at: MIDITimeStamp)] = [:]
    /// Lo start va nel pacchetto del primo passo, prima del clock e delle note.
    private var startPending = false
    private var clockCount = 0
    /// Seguendo il TX-6: gli ultimi impulsi (per il bpm) e il battito di Bobina dove è caduto il suo start.
    private var followStamps: [MIDITimeStamp] = []
    private var followBase = 0.0
    private var pending: Part?
    private var override: Part?
    /// Il pattern che la pagina diceva di suonare quando è entrato `override`: se la pagina passa ad altro
    /// (per esempio una batteria pronta), il pattern entrato non vale più.
    private var overrideFrom: UUID?
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

    /// Parte col tempo di Bobina all'istante `at`, o alla battuta dopo se qualcuno suona già.
    /// Se manda il clock, manda anche lo start (nel pacchetto del primo passo).
    func start(at start: MIDITimeStamp) {
        queue.async { [self] in
            let p = plan()
            let (l, first) = BobinaClock.shared.join(.tx6, at: start)
            line = l
            nextSixteenth = Int((first * 4).rounded())
            nextClockTick = nextSixteenth * 6
            gateState = nil
            lockSent = nil
            offsAt.removeAll()
            melodyHeld.removeAll()
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
            BobinaClock.shared.leave(.tx6)
            if sendStop { io.send(TX6.stop) }
            // i passi già consegnati a CoreMIDI col loro istante (fino a 150 ms avanti) arrivano dopo lo stop:
            // gli spegnimenti e i muti del cancello vanno mandati dopo di loro, se no le note restano appese
            let after = io.now() + io.ticks(ms: lookahead + 40)
            releaseGate(plan(), at: after)
            flushOffs(at: after)
        }
    }

    /// Quanto dopo lo stop arriva l'ultimo messaggio già preparato (per chi deve rimettere a posto dopo).
    static let tailMs = 150.0 + 40

    /// Bobina va in secondo piano (per esempio per dettare un messaggio): iOS la ferma dopo pochi secondi, a metà
    /// nota, e la nota tenuta restava a suonare sul TX-6 per sempre («si blocca e suona una traccia sola»,
    /// 9/10/2026). Qui, subito e prima di tornare: si spengono le note giù e si smette di mandare passi.
    /// Come lo stop, ma senza stop al TX-6 e aspettando che sia fatto (iOS può fermare l'app appena dopo).
    func suspend() {
        queue.sync {
            if running {
                running = false
                timer?.cancel()
                timer = nil
                BobinaClock.shared.leave(.tx6)
            }
            // anche seguendo il TX-6 (lì i passi li dà il suo clock): le note giù si spengono comunque
            let after = io.now() + io.ticks(ms: lookahead + 40)
            releaseGate(plan(), at: after)
            flushOffs(at: after)
        }
    }

    /// Per le prove sul Mac: il filo del sequencer resta fermo per tanti millisecondi, come un'app sospesa.
    func blockForTest(_ ms: Double) { queue.async { Thread.sleep(forTimeInterval: ms / 1000) } }

    /// I cambi di suono delle pronte (sei comandi per traccia): col bluetooth, tutti insieme in un pacchetto, il TX-6
    /// si ingolfava, perdeva comandi e alcune tracce restavano mute fino a spegnerlo (9/10/2026; come il vecchio
    /// «silenzio»). Qui prima si lasciano le note tenute delle tracce che cambiano suono, poi i comandi partono a
    /// gruppi di otto (24 byte) ogni 20 ms, come lo spegnimento al collegamento che non ha mai bloccato niente.
    func sendPaced(_ messages: [[UInt8]], releasing tracks: Set<Int> = []) {
        queue.async { [self] in
            let start = io.now()
            var k = 0
            for tr in tracks.sorted() {
                // la nota può non essere ancora partita (preparata fino a 150 ms avanti): lo spegnimento va dopo di lei,
                // se no la nota partiva dopo e restava accesa per sempre (il «synth fisso», 9/10/2026)
                if let h = melodyHeld.removeValue(forKey: tr) {
                    io.send(TX6.noteOff(h.note, channel: tr), at: max(start, h.at))
                    k = 1
                }
            }
            for i in stride(from: 0, to: messages.count, by: Self.chunkMessages) {
                let chunk = messages[i..<min(messages.count, i + Self.chunkMessages)].flatMap { $0 }
                io.send(chunk, at: start + io.ticks(ms: Self.chunkGapMs * Double(k)))
                k += 1
            }
        }
    }

    /// Quanti messaggi per pacchetto e ogni quanto, per non ingolfare il bluetooth del TX-6.
    static let chunkMessages = 8
    static let chunkGapMs = 20.0

    /// Il pattern entra all'inizio della prossima battuta.
    func queuePattern(_ part: Part) { queue.async { [self] in pending = part } }
    func cancelPending() { queue.async { [self] in pending = nil } }

    func releaseGateNow() { queue.async { [self] in releaseGate(plan()) } }
    /// Il clock del TX-6 non arriva più: la griglia di Bobina smette di seguirlo.
    func clockLost() { queue.async { BobinaClock.shared.leave(.tx6) } }
    func melodyOffNow() { queue.async { [self] in flushOffs() } }

    #if DEBUG
    /// Per le prove: il piano che il sequencer suonerebbe adesso, col pattern entrato se c'è.
    func debugEffectivePlan(_ done: @escaping (Plan) -> Void) {
        queue.async { [self] in
            let p = effective(plan())
            DispatchQueue.main.async { done(p) }
        }
    }
    #endif
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
                // il battere del TX-6 diventa un inizio di battuta di Bobina: chi suona già si rimette in fila
                let cur = BobinaClock.shared.snapshot()
                followBase = cur.running ? cur.bar(atOrAfter: stamp) : 0
                followStamps = []
                BobinaClock.shared.follow(time: stamp, beat: followBase, bpm: cur.bpm, by: .tx6)
            case 0xFC:
                releaseGate(p)
                flushOffs()
                followStamps.removeAll()
                BobinaClock.shared.leave(.tx6)
            case 0xF8:
                followClock(stamp)
                // un clock vecchio (arrivato in coda dopo una sospensione) conta ma non suona: niente raffica
                let stale = io.now() > stamp &+ io.ticks(ms: 250)
                if clockCount % 6 == 0 && !stale {
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

    /// A ogni quarto del TX-6 la griglia di Bobina si rimette sul suo battito. Bpm e istante vengono da una retta
    /// passata per gli ultimi 48 impulsi (due quarti): il tremolio del bluetooth si media e ai PO non arriva.
    private func followClock(_ stamp: MIDITimeStamp) {
        if let last = followStamps.last, stamp > last, io.ms(ticks: stamp - last) > 200 {
            // un buco: il clock si era fermato, si ricomincia a contare da qui
            followStamps.removeAll()
        }
        followStamps.append(stamp)
        if followStamps.count > 48 { followStamps.removeFirst(followStamps.count - 48) }
        let cur = BobinaClock.shared.snapshot()
        guard clockCount % 24 == 0, followStamps.count >= 7, let last = followStamps.last else { return }
        let n = Double(followStamps.count)
        var sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0
        for (i, t) in followStamps.enumerated() {
            let x = Double(i)
            let y = t >= last ? io.ms(ticks: t - last) : -io.ms(ticks: last - t)
            sx += x; sy += y; sxx += x * x; sxy += x * y
        }
        let slope = (n * sxy - sx * sy) / (n * sxx - sx * sx)
        guard slope > 0.5 else { return }
        let fit = (sy - slope * sx) / n + slope * (n - 1)
        let anchor = fit >= 0 ? last + io.ticks(ms: fit) : last - io.ticks(ms: -fit)
        if cur.followedBy != .tx6 {
            // il clock c'era già senza start (Bobina collegata a metà): si va avanti dalla battuta dopo
            followBase = (cur.running ? cur.bar(atOrAfter: stamp) : 0) - Double(clockCount) / 24
        }
        BobinaClock.shared.follow(time: anchor, beat: followBase + Double(clockCount) / 24, bpm: 60_000 / (slope * 24), by: .tx6)
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

    private func time(ofBeat b: Double) -> MIDITimeStamp { line.time(ofBeat: b) }

    private func tick() {
        guard running else { return }
        var p = effective(plan())
        let now = io.now()
        // il bpm lo tiene BobinaClock: se qualcuno l'ha cambiato, la griglia è già riancorata lì
        let fresh = BobinaClock.shared.snapshot()
        if fresh.generation != line.generation {
            line = fresh
            // la griglia è saltata avanti (il TX-6 è ripartito mentre lo seguiamo): niente raffica di passi vecchi.
            // O è saltata indietro (ripartita da zero mentre suoniamo): il prossimo passo sarebbe fra minuti e il
            // TX-6 resterebbe muto. In tutti e due i casi si riparte dal passo di adesso.
            let next = time(ofBeat: Double(nextSixteenth) / 4)
            let farAhead = now &+ io.ticks(ms: lookahead + line.beatMs * 4 + 50)
            if next &+ io.ticks(ms: 30) < now || next > farAhead {
                // gli spegnimenti in coda sono legati ai numeri dei passi vecchi: col salto non arriverebbero
                // più e le note resterebbero accese. Partono dopo le note già preparate (la lezione dello stop).
                flushOffs()
                nextSixteenth = Int((line.beat(at: now) * 4).rounded(.up))
                nextClockTick = nextSixteenth * 6
            }
        }
        // il filo è stato fermo (app sospesa, telefono bloccato): i passi persi non si mandano tutti insieme, era una
        // raffica di centinaia di note che ingolfava il bluetooth del TX-6. Si riparte dal passo di adesso.
        if now > time(ofBeat: Double(nextSixteenth) / 4) &+ io.ticks(ms: 250) {
            flushOffs()
            nextSixteenth = Int((line.beat(at: now) * 4).rounded(.up))
            nextClockTick = nextSixteenth * 6
        }
        let horizon = now + io.ticks(ms: lookahead)
        while time(ofBeat: Double(nextSixteenth) / 4) < horizon {
            let n = nextSixteenth
            // lo swing sposta in avanti i sedicesimi dispari: 0,5 dritto, 0,66 terzina (fino a un ottavo di quarto)
            let late = n % 2 == 1 ? (min(0.75, max(0.5, p.swing)) - 0.5) * 0.5 : 0
            let t = max(now, time(ofBeat: Double(n) / 4 + late))
            let prefix = switchIfDue(n % 16, at: t)
            if !prefix.isEmpty || override != nil { p = effective(plan()) }
            // il clock resta dritto: se il passo è spostato dallo swing, l'impulso parte da solo
            fire(n, at: t, p, prefix: prefix, withClock: p.sendClock && late == 0)
            nextSixteenth += 1
        }
        if p.sendClock {
            // un impulso su sei cade insieme a un passo ed è già partito nel suo pacchetto, se il passo è dritto
            while time(ofBeat: Double(nextClockTick) / 24) < horizon {
                let onStep = nextClockTick % 6 == 0
                let swungStep = onStep && (nextClockTick / 6) % 2 == 1 && p.swing > 0.5
                if !onStep || swungStep {
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
        overrideFrom = plan().patternID
        lockSent = nil
        if running, let b = part.bpm, b != line.bpm {
            BobinaClock.shared.setBPM(b, at: t)
            line = BobinaClock.shared.snapshot()
        }
        onSwitched?(part.id)
        return part.soundBytes.isEmpty ? [0xFE] : part.soundBytes
    }

    /// Il piano col pattern appena entrato, finché la pagina non se ne accorge.
    private func effective(_ base: Plan) -> Plan {
        guard let o = override else { return base }
        // la pagina ha preso il pattern entrato, o è già passata ad altro: vale quello che dice la pagina
        if base.patternID == o.id || base.patternID != overrideFrom {
            override = nil
            return base
        }
        var p = base
        p.beats = o.beats
        p.melodies = o.melodies
        p.melodyOctaves = o.melodyOctaves
        p.melodyGates = o.melodyGates
        p.locks = o.locks
        p.lockTrack = o.lockTrack
        p.lockCC = o.lockCC
        p.lockBase = o.lockBase
        p.gate = o.gate
        if let b = o.bpm { p.bpm = b }
        if let s = o.swing { p.swing = s }
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
        // le note delle melodie che finiscono qui (anche se intanto la melodia è stata spenta)
        for (tr, h) in melodyHeld where h.until <= n {
            now += TX6.noteOff(h.note, channel: tr)
            melodyHeld[tr] = nil
        }
        // 0xFE (active sensing) è solo un segnaposto per «è entrato un pattern senza suoni»: non si manda
        if prefix != [0xFE] { now += prefix }
        var hit: Set<Int> = []
        let stepMs = line.beatMs / 4

        if p.beatsOn {
            if p.lockOn {
                let target = p.locks[i] ?? p.lockBase
                if target != lockSent {
                    now += TX6.cc(p.lockCC, target, channel: p.lockTrack)
                    lockSent = target
                }
            }
            for tr in 1...6 where p.beats[tr - 1][i] {
                // sul canale 7: la traccia suona alla sua frequenza, e la leva della frequenza si sente
                let note = TX6.drumNote(tr)
                now += TX6.noteOn(note, channel: TX6.masterChannel)
                TX6PlayedNotes.shared.add(TX6.masterChannel, note)
                offsAt[n + 1, default: []] += TX6.noteOff(note, channel: TX6.masterChannel)
                hit.insert(tr)
            }
        }

        if p.melodyOn {
            for tr in 1...6 {
                // ogni traccia gira sulla sua lunghezza: una battuta o due
                let mel = p.melodies[tr - 1]
                let len = mel.count
                guard len > 0 else { continue }
                let k = ((n % len) + len) % len
                guard let semi = mel[k] else { continue }
                let note = max(0, min(127, 12 * (p.melodyOctaves[tr - 1] + 1) + semi))
                // quanti passi resta giù: fisso, o (tenuta) fino al prossimo passo pieno della traccia.
                // Lo spegnimento va nel pacchetto di quel passo, prima della nota nuova: il legato non si interrompe.
                var gate = p.melodyGates.indices.contains(tr - 1) ? p.melodyGates[tr - 1] : 1
                if gate <= 0 {
                    gate = len
                    for d in 1...len where mel[(k + d) % len] != nil { gate = d; break }
                }
                if let h = melodyHeld[tr] {
                    now += TX6.noteOff(h.note, channel: tr)
                }
                now += TX6.noteOn(note, channel: tr)
                TX6PlayedNotes.shared.add(tr, note)
                melodyHeld[tr] = (note, n + max(1, gate), t)
            }
        }

        if p.gateOn {
            let open = p.gate[i]
            if open != gateState {
                gateState = open
                // il muto del TX-6 più il volume: col synth acceso il cc 120 da solo non basta
                for tr in p.gateTracks {
                    now += TX6.cc(TX6.ccMute, open ? (p.mutes[tr - 1] ? 127 : 0) : 127, channel: tr)
                    now += TX6.cc(TX6.Param.volume.cc, open ? p.volumes[tr - 1] : 0, channel: tr)
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

        // un pacchetto solo per passo: spezzarlo non serve (CoreMIDI riunisce i pezzi con lo stesso istante) e coi pezzi
        // sfasati di 3 ms uno spegnimento poteva arrivare prima della sua nota (9/10/2026)
        if !now.isEmpty { io.send(now, at: t) }
        onStep?(n, t, hit)
    }

    private func releaseGate(_ p: Plan, at time: MIDITimeStamp = 0) {
        guard gateState != nil else { return }
        gateState = nil
        var bytes: [UInt8] = []
        for tr in p.gateTracks {
            bytes += TX6.cc(TX6.ccMute, p.mutes[tr - 1] ? 127 : 0, channel: tr)
            bytes += TX6.cc(TX6.Param.volume.cc, p.volumes[tr - 1], channel: tr)
        }
        if !bytes.isEmpty { io.send(bytes, at: time) }
    }

    /// Manda tutti gli spegnimenti in attesa. Mentre il ritmo gira (o subito dopo lo stop) vanno dopo le note
    /// già preparate, quindi di serie a 190 ms da adesso.
    private func flushOffs(at time: MIDITimeStamp? = nil) {
        let bytes = offsAt.keys.sorted().flatMap { offsAt[$0] ?? [] }
            + melodyHeld.keys.sorted().flatMap { TX6.noteOff(melodyHeld[$0]!.note, channel: $0) }
        offsAt.removeAll()
        melodyHeld.removeAll()
        if !bytes.isEmpty { io.send(bytes, at: time ?? io.now() + io.ticks(ms: lookahead + 40)) }
    }
}
