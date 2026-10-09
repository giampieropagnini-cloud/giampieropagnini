import Foundation
import CoreMIDI

/// Come il PO sta a tempo con il resto di Bobina.
enum POSync: String, CaseIterable, Identifiable, Codable {
    /// Il PO resta fermo e Bobina gli preme i tasti al momento giusto: basta il bluetooth.
    case live = "Bobina lo suona"
    /// Il PO suona il suo pattern; gli impulsi arrivano col cavo dall'aux del TX-6 (sync 8, PO su SY2).
    case tx6 = "cavo sync dal TX-6"
    /// Il PO suona il suo pattern; Bobina manda il clock all'adattatore e il sync out fa gli impulsi.
    case adapter = "sync out dell'adattatore"
    /// Il PO suona il suo pattern col suo tempo (80 · 120 · 140): Bobina preme play in battere e basta.
    case ear = "senza cavo"

    var id: String { rawValue }

    /// Il PO suona un pattern suo: play all'inizio e alla fine, pattern ed effetti a tempo.
    var ownPattern: Bool { self != .live }
}

/// Il ritmo dei PO su un filo tutto suo, come quello del TX-6: scorrere lo schermo non lo tocca.
/// I passi stanno sulla griglia di `BobinaClock`, la stessa del TX-6: se qualcuno suona già, il PO entra
/// all'inizio della battuta dopo. Prepara i passi 150 ms prima e li consegna a CoreMIDI con la marca temporale.
///
/// Sul PO un tasto numerato fa cose diverse secondo cosa è tenuto premuto: con fx sceglie l'effetto,
/// con pattern il pattern, con bpm il volume. Per questo, mentre un effetto o una combinazione sono in corso,
/// i passi dal vivo tacciono: premerebbero la cosa sbagliata.
final class POSequencer {

    struct Plan {
        var channel = 1
        var sync = POSync.live
        /// Quanto prima della griglia parte tutto, per il ritardo del bluetooth (ms, anche negativo).
        var leadMs = 0.0
        /// Col sync out dell'adattatore: il clock va sempre, anche da fermi, così l'adattatore sa il tempo prima dello start.
        var clockAlways = false
        /// Le scorciatoie a CC dell'adattatore (po_cc_control = 1): un messaggio invece di quattro.
        var useCC = false

        /// Passi dal vivo: per ogni tasto 1-16, sedici passi.
        var liveOn = false
        var live: [[Bool]] = Array(repeating: Array(repeating: false, count: 16), count: 16)
        /// Quanto resta premuto un tasto: 0 = un tocco corto, 1 = fino al passo dopo.
        var holdSteps = 1

        /// Effetti a tempo: in ogni passo un effetto 1-16 o niente. Suonano nell'ultima di ogni `fxEvery` battute.
        var fxOn = false
        var fx: [Int?] = Array(repeating: nil, count: 16)
        var fxEvery = 1
        /// L'effetto scelto inclinando il telefono: vince sugli effetti a passi.
        var tiltFx: Int?

        /// Pattern a tempo: una battuta per voce, pattern 1-16 del PO.
        var songOn = false
        var song: [Int] = [1, 2]

        /// Cancello: a ogni passo spento il PO tace (tonic: muto tenendo 1-4) o scende di volume (gli altri).
        var gateOn = false
        var gate: [Bool] = Array(repeating: true, count: 16)
        var gateByMute = false
        var gateLow = 2
        var gateHigh = 12
    }

    /// Un passo è partito: il numero (0-15), l'istante, i tasti premuti.
    var onStep: ((Int, MIDITimeStamp, Set<Int>) -> Void)?
    /// Un messaggio è partito (per il monitor): i byte. Solo le cose rare, niente clock.
    var onSent: (([UInt8]) -> Void)?

    private let io: MIDIIO
    /// Il suo posto sulla griglia di Bobina: ogni PO entra ed esce per conto suo.
    private let member: BobinaClock.Member
    private let queue: DispatchQueue
    private let lock = NSLock()
    private var shared = Plan()

    // da qui in giù: solo sul filo del sequencer
    private var timer: DispatchSourceTimer?
    private var running = false
    private var line = BobinaClock.Timeline()
    private var nextSixteenth = 0
    private var nextClockTick = 0
    private var firstStep = 0
    /// Le note da lasciare, per numero di passo: vanno nel pacchetto di quel passo.
    private var offsAt: [Int: [PO.Key]] = [:]
    /// L'effetto tenuto adesso (fx giù + questo numero giù).
    private var fxDown: Int?
    private var fxHeld = false
    /// Il cancello: nil = mai toccato da quando è partito.
    private var gateClosed: Bool?
    /// Il pattern chiesto l'ultima volta dal pattern a tempo.
    private var songPattern: Int?
    /// Fino a quando una combinazione tiene occupati i tasti numerati.
    private var busyUntil: MIDITimeStamp = 0
    /// L'ultimo clock partito: col clock sempre acceso, alla partenza non se ne manda uno doppio.
    private var lastClockAt: MIDITimeStamp = 0
    private let lookahead = 150.0
    private let gap = 25.0

    init(io: MIDIIO, member: BobinaClock.Member = .po) {
        self.io = io
        self.member = member
        queue = DispatchQueue(label: "bobina.\(member.rawValue).ritmo", qos: .userInteractive)
    }

    // MARK: dalla pagina

    func update(_ plan: Plan) {
        lock.lock()
        let wasClock = shared.clockAlways
        shared = plan
        lock.unlock()
        if plan.clockAlways != wasClock {
            queue.async { [self] in
                if plan.clockAlways { startTimer() } else if !running { stopTimer() }
            }
        }
    }

    private func plan() -> Plan {
        lock.lock()
        defer { lock.unlock() }
        return shared
    }

    /// Parte all'istante `start`, o all'inizio della battuta dopo se qualcuno suona già.
    func start(at start: MIDITimeStamp) {
        queue.async { [self] in
            let p = plan()
            var start = start
            if p.sync == .adapter && timer != nil && lastClockAt != 0 {
                // il clock va già: si parte su un suo impulso non ancora partito, così la fila di impulsi
                // non si rompe e lo start arriva prima del primo impulso della battuta
                let cur = BobinaClock.shared.snapshot()
                let sent = p.leadMs >= 0 ? lastClockAt + io.ticks(ms: p.leadMs) : lastClockAt - io.ticks(ms: -p.leadMs)
                let k = (cur.beat(at: max(start, sent + io.ticks(ms: 1))) * 24).rounded(.up)
                start = cur.time(ofBeat: k / 24)
            }
            let (l, first) = BobinaClock.shared.join(member, at: start)
            line = l
            nextSixteenth = Int((first * 4).rounded())
            firstStep = nextSixteenth
            // il clock riprende dal prossimo impulso della griglia (quelli già partiti non si ripetono: vedi lastClockAt)
            nextClockTick = Int((line.beat(at: io.now()) * 24).rounded(.up))
            offsAt.removeAll()
            gateClosed = nil
            songPattern = nil
            busyUntil = 0
            running = true
            let t0 = at(line.time(ofBeat: first), p)
            // il pattern della prima battuta prima di tutto
            if p.sync.ownPattern && p.songOn, let pat = p.song.first {
                combo(.pattern, pat, at: t0 > io.ticks(ms: 200) ? t0 - io.ticks(ms: 200) : t0, p)
                songPattern = pat
            }
            // col cavo del TX-6 e senza cavo play va premuto un soffio prima del battere;
            // col sync out lo preme l'adattatore quando arriva lo start (nel pacchetto del primo passo)
            if p.sync == .tx6 || p.sync == .ear { tap(.play, at: t0 > io.ticks(ms: 30) ? t0 - io.ticks(ms: 30) : t0, p) }
            startTimer()
        }
    }

    /// Si ferma: play (o stop all'adattatore), e lascia tutti i tasti che teneva.
    func stop() {
        queue.async { [self] in
            guard running else { return }
            let p = plan()
            running = false
            BobinaClock.shared.leave(member)
            if !p.clockAlways { stopTimer() }
            var bytes: [UInt8] = []
            for k in offsAt.values.flatMap({ $0 }) { bytes += PO.noteOff(k, channel: p.channel) }
            offsAt.removeAll()
            bytes += releaseFx(p)
            bytes += releaseGate(p)
            switch p.sync {
            case .live: break
            case .adapter: bytes = PO.stop + bytes
            case .tx6, .ear:
                bytes += PO.noteOn(.play, channel: p.channel)
                io.send(PO.noteOff(.play, channel: p.channel), at: io.now() + io.ticks(ms: 60))
            }
            if !bytes.isEmpty { send(bytes, at: 0) }
            // i passi già consegnati a CoreMIDI (fino a 150 ms avanti) arrivano dopo questo stop: dopo l'ultimo
            // si lasciano tutti i 23 tasti, così sul PO non resta niente giù (lezione dell'OP-Z, 8/10/2026)
            let after = io.now() + io.ticks(ms: lookahead + max(0, p.leadMs) + 40)
            send(PO.Key.allCases.flatMap { PO.noteOff($0, channel: p.channel) }, at: after)
        }
    }

    /// I rilasci in coda sono contati coi passi: dopo un salto (della griglia, o di Bobina sospesa) quei passi non
    /// arrivano più e il tasto resterebbe giù (lezione dell'OP-Z). Si lasciano dopo i passi già consegnati con la loro
    /// marca temporale, se no il tasto si riabbasserebbe dopo.
    private func dropQueuedReleases(_ p: Plan, at now: MIDITimeStamp) {
        let keys = offsAt.values.flatMap { $0 }
        offsAt.removeAll()
        if !keys.isEmpty { send(keys.flatMap { PO.noteOff($0, channel: p.channel) }, at: now + io.ticks(ms: lookahead + max(0, p.leadMs) + 40)) }
    }

    /// Bobina va in secondo piano e iOS sta per sospenderla: tutti i tasti su adesso e dopo l'ultimo passo consegnato,
    /// effetto e cancello compresi. Aspetta che sia fatto: chi chiama tiene viva l'app con un background task.
    func releaseForBackground() {
        queue.sync {
            let p = plan()
            var bytes: [UInt8] = []
            for k in offsAt.values.flatMap({ $0 }) { bytes += PO.noteOff(k, channel: p.channel) }
            offsAt.removeAll()
            bytes += releaseFx(p)
            if gateClosed == true && p.gateByMute { bytes += (1...4).flatMap { PO.noteOff(.number($0), channel: p.channel) } }
            gateClosed = nil
            if !bytes.isEmpty { send(bytes, at: 0) }
            let after = io.now() + io.ticks(ms: lookahead + max(0, p.leadMs) + 40)
            send(PO.Key.allCases.flatMap { PO.noteOff($0, channel: p.channel) }, at: after)
        }
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
            // la griglia è saltata (il TX-6 è ripartito, o si è riancorata lontano): si riparte dal passo giusto
            let t = line.time(ofBeat: Double(nextSixteenth) / 4)
            if running && (t + io.ticks(ms: 30) < now || t > now + io.ticks(ms: line.beatMs * 4 + lookahead)) {
                nextSixteenth = Int((line.beat(at: now) * 4).rounded(.up))
                dropQueuedReleases(p, at: now)
            }
            nextClockTick = Int((line.beat(at: now) * 24).rounded(.up))
        }
        // Bobina sospesa da iOS (in secondo piano): al ritorno i passi persi non partono tutti insieme in una raffica,
        // si riparte dal passo di adesso (lezione del TX-6, 9/10/2026)
        if running && line.time(ofBeat: Double(nextSixteenth) / 4) + io.ticks(ms: 250) < now {
            dropQueuedReleases(p, at: now)
            nextSixteenth = Int((line.beat(at: now) * 4).rounded(.up))
        }
        if line.time(ofBeat: Double(nextClockTick) / 24) + io.ticks(ms: 250) < now {
            nextClockTick = Int((line.beat(at: now) * 24).rounded(.up))
        }
        let horizon = now + io.ticks(ms: lookahead + max(0, p.leadMs))
        let clockOn = p.sync == .adapter && (p.clockAlways || running)
        if clockOn {
            // col clock i passi partono dal giro degli impulsi, in ordine: un impulso su sei porta anche il passo
            while line.time(ofBeat: Double(nextClockTick) / 24) < horizon {
                let k = nextClockTick
                let due = at(line.time(ofBeat: Double(k) / 24), p)
                let t = max(now, due)
                if running && k % 6 == 0 && k / 6 >= nextSixteenth {
                    while nextSixteenth <= k / 6 {
                        let n = nextSixteenth
                        fire(n, at: max(now, at(line.time(ofBeat: Double(n) / 4), p)), p, withClock: n == k / 6)
                        nextSixteenth += 1
                    }
                } else if due >= now && t > lastClockAt + io.ticks(ms: 2) {
                    // un impulso in ritardo (il clock si è appena acceso) non si manda: storcerebbe il tempo misurato
                    io.send(PO.clock, at: t)
                    lastClockAt = t
                }
                nextClockTick += 1
            }
        } else {
            if running {
                while line.time(ofBeat: Double(nextSixteenth) / 4) < horizon {
                    let n = nextSixteenth
                    fire(n, at: max(now, at(line.time(ofBeat: Double(n) / 4), p)), p, withClock: false)
                    nextSixteenth += 1
                }
            }
            nextClockTick = Int((line.beat(at: now) * 24).rounded(.up))
        }
    }

    // MARK: un sedicesimo

    private func fire(_ n: Int, at t: MIDITimeStamp, _ p: Plan, withClock: Bool) {
        let i = n % 16
        let bar = n / 16
        let ch = p.channel
        var head: [UInt8] = []
        var early: [UInt8] = []
        var offs: [UInt8] = []
        var fxBytes: [UInt8] = []
        var ons: [UInt8] = []
        var hit: Set<Int> = []

        if p.sync == .adapter && n == firstStep { head += PO.start }
        if withClock && t > lastClockAt + io.ticks(ms: 2) {
            head += PO.clock
            lastClockAt = t
        }

        // l'effetto: prima si lascia il numero vecchio, poi si preme il nuovo; fx va giù un soffio prima
        let fxBar = p.fxEvery <= 1 || (bar - firstStep / 16) % p.fxEvery == p.fxEvery - 1
        let desired = p.tiltFx ?? (p.fxOn && fxBar ? p.fx[i] : nil)
        var fxReleased = false
        var fxPressed = false
        if desired != fxDown {
            if let old = fxDown { fxBytes += PO.noteOff(.number(old), channel: ch) }
            if let d = desired {
                if !fxHeld { early += PO.noteOn(.fx, channel: ch); fxHeld = true; fxPressed = true }
                fxBytes += PO.noteOn(.number(d), channel: ch)
            } else if fxHeld {
                fxBytes += PO.noteOff(.fx, channel: ch)
                fxHeld = false
                fxReleased = true
            }
            fxDown = desired
        }

        // il cancello, quando il PO suona il suo pattern
        var gateBytes: [UInt8] = []
        if p.gateOn && p.sync.ownPattern {
            let closed = !p.gate[i]
            if closed != gateClosed {
                gateClosed = closed
                if p.gateByMute {
                    for c in 1...4 { gateBytes += closed ? PO.noteOn(.number(c), channel: ch) : PO.noteOff(.number(c), channel: ch) }
                } else {
                    combo(.volume, closed ? p.gateLow : p.gateHigh, at: t, p)
                }
            }
        }

        // il pattern a tempo: sull'ultimo sedicesimo della battuta si chiede il pattern della battuta dopo
        if p.songOn && p.sync.ownPattern && i == 15 && !p.song.isEmpty {
            let target = p.song[(bar + 1 - firstStep / 16) % p.song.count]
            if target != songPattern {
                combo(.pattern, target, at: t, p)
                songPattern = target
            }
        }

        // i passi dal vivo (dopo le combinazioni, che li fanno tacere); se lo stesso tasto va ripremuto adesso lo si lascia 20 ms prima, se no il PO non se ne accorge
        let wanted = fxReleased ? [] : liveKeys(i, p, t)
        for k in offsAt.removeValue(forKey: n) ?? [] {
            if wanted.contains(k) { early += PO.noteOff(k, channel: ch) } else { offs += PO.noteOff(k, channel: ch) }
        }
        for k in wanted {
            ons += PO.noteOn(k, channel: ch)
            if p.holdSteps <= 0 {
                io.send(PO.noteOff(k, channel: ch), at: t + io.ticks(ms: 60))
            } else {
                offsAt[n + p.holdSteps, default: []].append(k)
            }
            if let num = k.number { hit.insert(num) }
        }

        // fx va giù solo quando nessun numero è tenuto, se no il PO lo prenderebbe per un effetto
        if fxPressed {
            early = offs + early
            offs = []
        }
        if !early.isEmpty { send(early, at: t > io.ticks(ms: 20) ? t - io.ticks(ms: 20) : t) }
        let packet = head + offs + fxBytes + ons + gateBytes
        if !packet.isEmpty { io.send(packet, at: t) }
        if !fxBytes.isEmpty || !gateBytes.isEmpty { onSent?(fxBytes + gateBytes) }
        onStep?(i, t, hit)
    }

    /// I tasti da premere in questo passo, se niente li occupa.
    private func liveKeys(_ i: Int, _ p: Plan, _ t: MIDITimeStamp) -> [PO.Key] {
        guard p.liveOn, !fxHeld, p.tiltFx == nil, t >= busyUntil else { return [] }
        if p.gateOn && !p.sync.ownPattern && !p.gate[i] { return [] }
        return (0..<16).filter { p.live[$0][i] }.map { PO.Key.number($0 + 1) }
    }

    // MARK: le combinazioni

    /// Tieni un tasto, premi il numero, lascia: pattern, suono o volume. Col CC è un messaggio solo.
    private func combo(_ s: PO.Shortcut, _ number: Int, at t: MIDITimeStamp, _ p: Plan) {
        if p.useCC {
            send(PO.cc(s, number, channel: p.channel), at: t)
            busyUntil = t + io.ticks(ms: 80)
            return
        }
        let k = PO.Key.number(number)
        let g = io.ticks(ms: gap)
        send(PO.noteOn(s.held, channel: p.channel), at: t > g ? t - g : t)
        io.send(PO.noteOn(k, channel: p.channel), at: t)
        io.send(PO.noteOff(k, channel: p.channel), at: t + g)
        io.send(PO.noteOff(s.held, channel: p.channel), at: t + 2 * g)
        busyUntil = t + 3 * g
    }

    private func tap(_ k: PO.Key, at t: MIDITimeStamp, _ p: Plan) {
        send(PO.noteOn(k, channel: p.channel), at: t)
        io.send(PO.noteOff(k, channel: p.channel), at: t + io.ticks(ms: 60))
    }

    private func releaseFx(_ p: Plan) -> [UInt8] {
        var bytes: [UInt8] = []
        if let d = fxDown { bytes += PO.noteOff(.number(d), channel: p.channel) }
        if fxHeld { bytes += PO.noteOff(.fx, channel: p.channel) }
        fxDown = nil
        fxHeld = false
        return bytes
    }

    private func releaseGate(_ p: Plan) -> [UInt8] {
        guard gateClosed == true else { gateClosed = nil; return [] }
        gateClosed = nil
        if p.gateByMute { return (1...4).flatMap { PO.noteOff(.number($0), channel: p.channel) } }
        combo(.volume, p.gateHigh, at: io.now(), p)
        return []
    }

    private func send(_ bytes: [UInt8], at t: MIDITimeStamp) {
        io.send(bytes, at: t)
        onSent?(bytes)
    }
}
