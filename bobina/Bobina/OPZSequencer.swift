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
        /// I 16 pattern di Crea: per ognuno 8 tracce × 32 passi (se ne usano `lengths`), ognuno con le sue note.
        var patterns: [[[[Int]]]] = Array(repeating: Array(repeating: Array(repeating: [], count: 32), count: 8), count: 16)
        /// Quanti passi ha ogni traccia di ogni pattern di Crea (1-32): tracce di lunghezza diversa = poliritmi.
        var lengths: [[Int]] = Array(repeating: Array(repeating: 16, count: 8), count: 16)
        /// Quanto dura una nota di ogni traccia, in passi; 0 = tenuta fino alla nota dopo (per arp e accordi).
        var gates: [[Int]] = Array(repeating: Array(repeating: 1, count: 8), count: 16)
        /// La catena di Crea: pattern (0-15) e quante volte, uno dopo l'altro.
        var chainOn = false
        var chain: [OPZChainStep] = []
        /// Alla fine della catena ricomincia (se no Crea si ferma lì).
        var chainLoop = true
        /// L'arpeggio di Bobina sulla traccia arp: sempre a tempo con la griglia di Bobina.
        var arpOn = false
        var arpStyle = OPZArpStyle.up
        /// Ogni quanti trentaduesimi parte una nota: 1 = 1/32, 2 = 1/16, 4 = 1/8, 8 = 1/4.
        var arpRate = 2
        var arpOctaves = 1
        /// Le note tenute dal vivo sull'arp (tasto «tieni»): finché ci sono, l'arpeggio gira su queste.
        var liveArp: [Int] = []
        /// Il pattern di Crea da suonare (0-15): cambia all'inizio della battuta. Con la canzone accesa decide la canzone.
        var createPattern = 0
        var trackOn: [Bool] = Array(repeating: true, count: 8)
        /// Gli effetti di Bobina tenuti adesso dal vivo.
        var fxLive: Set<CreaFx> = []
        /// Su quale traccia (1-8) lavorano gli effetti; nil = su tutte.
        var fxTrack: Int?
        /// Gli effetti scritti nei passi, per pattern: 32 passi, un effetto o niente.
        var fxSteps: [[CreaFx?]] = Array(repeating: Array(repeating: nil, count: 32), count: 16)
        /// L'automazione a passi, per pattern: 4 righe, ognuna una manopola di una traccia con un valore per passo.
        var autom: [[OPZLane]] = Array(repeating: OPZLane.empty, count: 16)
        /// Gli effetti dei passi suonano solo nell'ultima di ogni tot battute (1 = sempre).
        var fxEvery = 1
    }

    /// Un battito è partito: battuta (da 0) e quarto (0-3), con l'istante. Per la pagina.
    var onBeat: ((Int, Int, MIDITimeStamp) -> Void)?
    /// La canzone ha chiesto un pattern (1-16): voce della canzone e pattern, con l'istante.
    var onSongPattern: ((Int, Int, MIDITimeStamp) -> Void)?
    /// Un sedicesimo di Crea è partito: quanti da quando è cominciato il pattern, con l'istante; -1 = Crea tace.
    /// Ogni griglia lo riporta dentro la lunghezza della sua traccia.
    var onStep: ((Int, MIDITimeStamp) -> Void)?
    /// Il pattern di Crea che comincia adesso (0-15) e la voce della catena (o nil), con l'istante.
    var onCreatePattern: ((Int, Int?, MIDITimeStamp) -> Void)?
    /// Il sequencer si è fermato da solo (dopo il giro «scrivi sull'OP-Z»).
    var onHalted: (() -> Void)?
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
    private var onceBarsWanted = 1
    private var onceFirstWanted: Int?

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
    /// Le note tenute adesso (canale × 128 + nota) e il sedicesimo in cui vanno lasciate.
    private var heldUntil: [Int: Int] = [:]
    /// L'arpeggio di Bobina: le note dell'ultimo passo pieno della traccia arp, e quante ne ha già suonate.
    private var arpChord: [Int] = []
    private var arpCount = 0
    private var arpTick = 0
    private var liveWasOn = false
    /// Il pattern di Crea che suona adesso.
    private var curCreate = 0
    /// A che passo del pattern di Crea si è (0 = comincia), quante volte è già girato, quanti giri in tutto.
    private var crPos = 0
    private var crRep = 0
    private var crPasses = 0
    /// I sedicesimi suonati da quando è cominciato questo pattern: ogni traccia ci gira sopra con la sua lunghezza.
    private var crTotal = 0
    /// La voce della catena che suona, e se la catena è finita (senza ricominciare).
    private var chainIdx: Int?
    private var chainDone = false
    /// Il giro solo per scrivere sull'OP-Z: acceso per un giro del pattern.
    private var onceActive = false
    /// Il sedicesimo in cui è cominciato il giro per l'OP-Z: dopo 16 tutto si ferma, esattamente lì.
    private var onceStart: Int?
    /// Quante battute scrive questo giro e in quale pattern dell'OP-Z comincia.
    private var onceBars = 1
    private var onceFirst: Int?
    /// Le note che partono più tardi (l'eco), per sedicesimo.
    private var onsAt: [Int: [UInt8]] = [:]
    /// Gli effetti accesi al passo prima, e da quando.
    private var fxPrev: Set<CreaFx> = []
    private var fxSince: [CreaFx: Int] = [:]
    /// Il passo del pattern in cui l'effetto è cominciato (per il loop).
    private var fxAnchor: [CreaFx: Int] = [:]
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
    /// `bars` battute (1, 2 o 4): ogni battuta va in un pattern dell'OP-Z, da `firstPattern` (1-16) in avanti,
    /// perché un pattern dell'OP-Z ha al massimo 16 passi. Bobina cambia pattern da sola fra una battuta e l'altra.
    func playOnce(bars: Int = 1, firstPattern: Int? = nil) {
        lock.lock()
        onceRequested = true
        onceBarsWanted = max(1, min(4, bars))
        onceFirstWanted = firstPattern
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
            crPos = 0
            crRep = 0
            crPasses = 0
            crTotal = 0
            chainIdx = nil
            chainDone = false
            onceActive = false
            if p.songOn, let pat = p.song.first {
                head += OPZ.pattern(pat, project: p.project)
                songIndex = 0
                onSongPattern?(0, pat, t0)
            }
            // l'arpeggio di Bobina vuole l'arpeggio dell'OP-Z spento (velocità tutta a sinistra = 0):
            // il 4/10/2026 col valore 8 l'OP-Z arpeggiava ancora, lentissimo, sopra quello di Bobina
            if p.arpOn { head += OPZ.cc(9, 0, channel: 7) }
            // il tempo anche col clock: se l'OP-Z non ascolta il clock (tasto 4 spento) almeno parte allo stesso bpm
            let v = tempoValue(line.bpm)
            head += OPZ.tempo(Double(v))
            lastTempo = v
            if !head.isEmpty { send(head, at: t0 > io.ticks(ms: 40) ? t0 - io.ticks(ms: 40) : t0) }
            startTimer()
        }
    }

    /// Si ferma: stop all'OP-Z, e la griglia lo lascia andare.
    func stop() {
        queue.async { [self] in halt(at: 0) }
    }

    /// Ferma tutto all'istante `t` (0 = subito): le note tenute si lasciano e lo stop parte nello stesso pacchetto.
    /// Solo sul filo del sequencer.
    private func halt(at t: MIDITimeStamp) {
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
            let offs = offsAt.values.flatMap { $0 } + heldUntil.keys.flatMap { OPZ.noteOff($0 % 128, channel: $0 / 128) } + fxRestore(all: true)
            offsAt.removeAll()
            heldUntil.removeAll()
            onsAt.removeAll()
            fxPrev = []
            arpChord = []
            fxSince = [:]
            if onceActive { onceActive = false; onOnceDone?() }
            lock.lock()
            onceRequested = false
            lock.unlock()
            send(OPZ.stop, at: t)
            // le note già consegnate a CoreMIDI arrivano fino a `lookahead` dopo: le note-off partono dopo di loro,
            // se no una nota partita un attimo dopo lo stop resta suonata per sempre (8/10/2026: «suoni che restano fissi»)
            let base = t == 0 ? io.now() : t
            let late = base + io.ticks(ms: lookahead + max(0, p.leadMs) + 40)
            io.send(offs + OPZ.allNotesOff(), at: late)
            onStep?(-1, io.now())
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
                let oldSixteenth = nextSixteenth
                nextBeat = Int(line.beat(at: now).rounded(.up))
                nextSixteenth = Int((line.beat(at: now) * 4).rounded(.up))
                shiftPending(by: nextSixteenth - oldSixteenth)
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
            while running && line.time(ofBeat: Double(nextBeat)) < horizon {
                beat(nextBeat, p, now)
                nextBeat += 1
            }
            while running && line.time(ofBeat: Double(nextSixteenth) / 4) < horizon {
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
                    bytes += OPZ.pattern(pat, project: p.project)
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

    /// La griglia è saltata (avanti o indietro, per esempio seguendo il TX-6 che riparte): tutto quello che
    /// aspettava un sedicesimo preciso si sposta con lei. Se no le note-off aspetterebbero un passo che non arriva
    /// più (note appese) e il giro per scrivere sull'OP-Z non finirebbe mai (idea dalle chat TX-6 e M8, 8/10/2026).
    private func shiftPending(by delta: Int) {
        guard delta != 0 else { return }
        offsAt = Dictionary(uniqueKeysWithValues: offsAt.map { ($0.key + delta, $0.value) })
        onsAt = Dictionary(uniqueKeysWithValues: onsAt.map { ($0.key + delta, $0.value) })
        heldUntil = heldUntil.mapValues { $0 + delta }
        fxSince = fxSince.mapValues { $0 + delta }
        if let s0 = onceStart { onceStart = s0 + delta }
        nextSixteenthStart += delta
    }

    // MARK: un sedicesimo di Crea

    /// Le note di tutte le tracce di questo passo in un pacchetto solo, con le note del passo prima che finiscono.
    private func sixteenth(_ n: Int, _ p: Plan, _ now: MIDITimeStamp) {
        let t = max(now, at(line.time(ofBeat: Double(n) / 4), p))
        // il giro per l'OP-Z dura sempre 16 passi, una battuta: quanto un pattern dell'OP-Z di serie.
        // (6/10/2026: col giro lungo quanto la traccia più lunga di Crea si fermava dopo 32 e registrava troppo)
        // fra una battuta e l'altra del giro: il pattern dell'OP-Z dopo, un soffio prima del battere
        if onceActive, let s0 = onceStart, let f = onceFirst, n > s0, (n - s0) % 16 == 0, (n - s0) / 16 < onceBars {
            let early = io.ticks(ms: patternEarlyMs)
            send(OPZ.pattern(min(16, f + (n - s0) / 16), project: p.project), at: t > now + early ? t - early : now)
        }
        if onceActive, let s0 = onceStart, n - s0 >= 16 * onceBars {
            onceStart = nil
            if !p.createOn {
                halt(at: t)
                onHalted?()
                return
            }
            onceActive = false
            onOnceDone?()
        }
        // un giro del pattern di Crea è finito: si decide il prossimo (la catena, o quello scelto)
        if crPos == 0 {
            lock.lock()
            let wanted = onceRequested
            onceRequested = false
            if wanted {
                onceBars = onceBarsWanted
                onceFirst = onceFirstWanted
            }
            lock.unlock()
            if wanted {
                onceActive = true
                onceStart = n
                // la prima battuta nel primo pattern scelto
                if let f = onceFirst {
                    let early = io.ticks(ms: 40)
                    send(OPZ.pattern(f, project: p.project), at: t > now + early ? t - early : now)
                }
            }
            var next = p.createPattern
            if p.chainOn && !p.chain.isEmpty {
                if chainIdx == nil || chainIdx! >= p.chain.count {
                    chainIdx = 0
                    crRep = 0
                } else if crRep >= max(1, p.chain[chainIdx!].times) {
                    if chainIdx! + 1 < p.chain.count { chainIdx! += 1 } else if p.chainLoop { chainIdx = 0 } else { chainDone = true }
                    crRep = 0
                }
                next = p.chain[chainIdx!].pattern
            } else {
                chainIdx = nil
                chainDone = false
            }
            if next != curCreate { crRep = 0; crTotal = 0 }
            curCreate = max(0, min(15, next))
            onCreatePattern?(curCreate, p.chainOn ? chainIdx : nil, t)
        }
        let lens = p.lengths.indices.contains(curCreate) ? p.lengths[curCreate].map { max(1, min(32, $0)) } : Array(repeating: 16, count: 8)
        // un giro del pattern = la traccia più lunga; le altre ricominciano per conto loro
        let len = lens.max() ?? 16
        let i = min(crPos, len - 1)
        let total = crTotal
        crTotal += 1
        crPos += 1
        if crPos >= len {
            crPos = 0
            crRep += 1
            crPasses += 1
        }
        let playing = (p.createOn && !(p.chainOn && chainDone)) || onceActive
        var bytes = offsAt.removeValue(forKey: n) ?? []
        // le note arrivate alla fine della loro durata
        for (key, until) in heldUntil where until <= n {
            bytes += OPZ.noteOff(key % 128, channel: key / 128)
            heldUntil[key] = nil
        }
        bytes += onsAt.removeValue(forKey: n) ?? []

        // gli effetti: quelli tenuti dal vivo più quello scritto in questo passo
        var active = playing ? p.fxLive : []
        let pass = i == len - 1 ? crPasses - 1 : crPasses
        let fxBar = p.fxEvery <= 1 || pass % p.fxEvery == p.fxEvery - 1
        if playing && fxBar, p.fxSteps.indices.contains(curCreate), let f = p.fxSteps[curCreate][i] { active.insert(f) }
        for f in active.subtracting(fxPrev) { fxSince[f] = n; fxAnchor[f] = total }
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
            // da quale sedicesimo si leggono le note (poi ogni traccia lo riporta dentro la sua lunghezza)
            var src = total
            // il loop ripete i passi suonati appena prima, contando da questo passo all'indietro
            if active.contains(.loop2), let a = fxSince[.loop2], let at0 = fxAnchor[.loop2] { src = at0 - 8 + (n - a) % 8 }
            else if active.contains(.loop1), let a = fxSince[.loop1], let at0 = fxAnchor[.loop1] { src = at0 - 4 + (n - a) % 4 }
            let shuffle = active.contains(.random)
            var repeats = 1
            if active.contains(.rampUp), let a = fxSince[.rampUp] { repeats = min(4, 1 + (n - a) / 4) }
            if active.contains(.rampDown), let a = fxSince[.rampDown] { repeats = max(1, 4 - (n - a) / 4) }

            var shortOffs: [UInt8] = []
            let gates = p.gates.indices.contains(curCreate) ? p.gates[curCreate] : Array(repeating: 1, count: 8)
            var subs: [[UInt8]] = Array(repeating: [], count: 4)
            for track in 0..<min(8, steps.count) where p.trackOn[track] {
                let mine = scope.contains(track)
                let tl = lens[track]
                let idx = mine && shuffle ? Int.random(in: 0..<tl) : (((mine ? src : total) % tl) + tl) % tl
                if track == 6 && p.arpOn {
                    arpStep(steps[track][idx], p, t, stepMs, &bytes)
                    continue
                }
                // quanti passi resta giù: fisso, o fino al prossimo passo pieno di questa traccia
                var gate = gates.indices.contains(track) ? gates[track] : 1
                if gate <= 0 {
                    gate = tl
                    for d in 1...tl where !steps[track][(idx + d) % tl].isEmpty { gate = d; break }
                }
                if mine && active.contains(.long) { gate = max(gate, 3) }
                for raw in steps[track][idx] {
                    let note = mine && active.contains(.pitch) && track >= 4 ? min(127, raw + 12) : raw
                    let ch = track + 1
                    let key = ch * 128 + note
                    // la stessa nota ancora tenuta: prima la si lascia, se no l'OP-Z non la ribatte
                    if heldUntil[key] != nil { bytes += OPZ.noteOff(note, channel: ch) }
                    bytes += OPZ.noteOn(note, velocity: 100, channel: ch)
                    if mine && repeats > 1 {
                        for j in 1..<repeats { subs[j] += OPZ.noteOff(note, channel: ch) + OPZ.noteOn(note, velocity: 90, channel: ch) }
                    }
                    if mine && active.contains(.short) {
                        shortOffs += OPZ.noteOff(note, channel: ch)
                        heldUntil[key] = nil
                    } else {
                        heldUntil[key] = n + gate
                    }
                    if mine && active.contains(.echo) {
                        onsAt[n + 3, default: []] += OPZ.noteOn(note, velocity: 45, channel: ch)
                        offsAt[n + 4, default: []] += OPZ.noteOff(note, channel: ch)
                    }
                }
            }
            if !shortOffs.isEmpty { io.send(shortOffs, at: t + io.ticks(ms: min(30, stepMs / 3))) }
            for j in 1..<repeats where !subs[j].isEmpty {
                io.send(subs[j], at: t + io.ticks(ms: stepMs * Double(j) / Double(repeats)))
            }

            // l'automazione a passi: in un passo con un valore, la manopola va lì (un CC per riga, nel pacchetto del passo)
            if p.autom.indices.contains(curCreate) {
                // mai un guadagno a passi (regola dell'8/10/2026), anche se una riga vecchia l'aveva
                for lane in p.autom[curCreate] where lane.values.indices.contains(i) && !OPZ.gainCCs.contains(lane.cc) {
                    if let v = lane.values[i] { bytes += OPZ.cc(lane.cc, OPZLane.value(v), channel: lane.track) }
                }
            }

            // filter sweep: giù per mezza battuta, su per l'altra metà
            if active.contains(.sweep), let a = fxSince[.sweep] {
                let phase = ((n - a) % 16 + 16) % 16   // mezza battuta giù, mezza su: non dipende dalla lunghezza del pattern
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
        // l'arpeggio dal vivo gira anche quando Crea tace
        if !(playing && p.trackOn[6]) && p.arpOn && (!p.liveArp.isEmpty || liveWasOn) {
            arpStep([], p, t, line.beatMs / 4, &bytes)
        }
        if !bytes.isEmpty { io.send(bytes, at: t) }
        onStep?(playing ? total : -1, t)
    }

    // MARK: l'arpeggio di Bobina

    /// Un sedicesimo dell'arpeggio: un passo pieno della traccia arp cambia l'accordo e fa ripartire la figura;
    /// poi le note escono una alla volta alla velocità scelta, sulla griglia di Bobina.
    private func arpStep(_ cell: [Int], _ p: Plan, _ t: MIDITimeStamp, _ stepMs: Double, _ bytes: inout [UInt8]) {
        let live = p.liveArp.sorted()
        if !live.isEmpty {
            // le note tenute dal vivo vincono sui passi
            if live != arpChord { arpChord = live; arpCount = 0; arpTick = 0 }
        } else if liveWasOn {
            arpChord = []
        }
        liveWasOn = !live.isEmpty
        if live.isEmpty && !cell.isEmpty {
            arpChord = cell.sorted()
            arpCount = 0
            arpTick = 0
        }
        guard !arpChord.isEmpty else { return }
        let seq = p.arpStyle.sequence(arpChord, octaves: p.arpOctaves)
        guard !seq.isEmpty else { return }
        // in trentaduesimi: due per sedicesimo
        for half in 0..<2 {
            defer { arpTick += 1 }
            guard arpTick % max(1, p.arpRate) == 0 else { continue }
            let notes: [Int]
            if p.arpStyle == .chord {
                notes = seq
            } else if p.arpStyle == .random {
                notes = [seq[Int.random(in: 0..<seq.count)]]
            } else {
                notes = [seq[arpCount % seq.count]]
            }
            arpCount += 1
            let on = notes.flatMap { OPZ.noteOn(min(127, $0), velocity: 100, channel: 7) }
            let off = notes.flatMap { OPZ.noteOff(min(127, $0), channel: 7) }
            let lenMs = stepMs / 2 * Double(max(1, p.arpRate)) * 0.8
            if half == 0 { bytes += on } else { io.send(on, at: t + io.ticks(ms: stepMs / 2)) }
            io.send(off, at: t + io.ticks(ms: (half == 0 ? 0 : stepMs / 2) + lenMs))
        }
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

/// Una voce della catena di Crea: quale pattern (0-15) e quante volte di fila.
struct OPZChainStep: Codable, Hashable {
    var pattern: Int
    var times: Int
}

/// Le figure dell'arpeggio di Bobina.
enum OPZArpStyle: Int, CaseIterable, Identifiable, Codable {
    case up, down, upDown, downUp, random, converge, diverge, pinky, thumb, chord, upOctave, skip

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .up: return "su"
        case .down: return "giù"
        case .upDown: return "su e giù"
        case .downUp: return "giù e su"
        case .random: return "a caso"
        case .converge: return "verso il centro"
        case .diverge: return "dal centro"
        case .pinky: return "mignolo"
        case .thumb: return "pollice"
        case .chord: return "accordo"
        case .upOctave: return "su + ottava"
        case .skip: return "a salti"
        }
    }

    /// La fila di note da suonare in giro, dalle note dell'accordo (in ordine) e dalle ottave.
    func sequence(_ chord: [Int], octaves: Int) -> [Int] {
        var base: [Int] = []
        for o in 0..<max(1, min(3, octaves)) { base += chord.map { $0 + 12 * o } }
        guard base.count > 1 else { return base }
        switch self {
        case .up, .random, .chord: return base
        case .down: return base.reversed()
        case .upDown: return base + base.reversed().dropFirst().dropLast()
        case .downUp: return base.reversed() + base.dropFirst().dropLast()
        case .converge:
            var r: [Int] = [], lo = 0, hi = base.count - 1
            while lo <= hi { r.append(base[lo]); if lo != hi { r.append(base[hi]) }; lo += 1; hi -= 1 }
            return r
        case .diverge:
            var r: [Int] = [], lo = (base.count - 1) / 2, hi = lo + 1
            while lo >= 0 || hi < base.count { if lo >= 0 { r.append(base[lo]) }; if hi < base.count { r.append(base[hi]) }; lo -= 1; hi += 1 }
            return r
        case .pinky:
            let top = base.last!
            return base.dropLast().flatMap { [$0, top] }
        case .thumb:
            let low = base.first!
            return base.dropFirst().flatMap { [low, $0] }
        case .upOctave: return base.flatMap { [$0, $0 + 12] }
        case .skip:
            let even = stride(from: 0, to: base.count, by: 2).map { base[$0] }
            let odd = stride(from: 1, to: base.count, by: 2).map { base[$0] }
            return even + odd
        }
    }
}

/// Una riga di automazione a passi: quale traccia (1-8), quale manopola (CC 1-16), e in ogni passo un livello 1-8 o niente.
struct OPZLane: Codable, Hashable {
    var track = 5
    var cc = 3
    var values: [Int?] = Array(repeating: nil, count: 32)

    static let empty: [OPZLane] = [OPZLane(track: 5, cc: 3), OPZLane(track: 6, cc: 3), OPZLane(track: 1, cc: 1), OPZLane(track: 8, cc: 13)]

    /// Livello 1-8 → valore del CC (1 = minimo, 8 = massimo).
    static func value(_ level: Int) -> Int { Int((Double(max(1, min(8, level)) - 1) / 7 * 127).rounded()) }
}
