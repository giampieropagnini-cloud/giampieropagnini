import Foundation
import CoreMIDI

extension Notification.Name {
    /// Il tempo di Bobina è cambiato. `object` è il nuovo bpm (Double). Arriva sul main thread.
    static let bobinaBPM = Notification.Name("bobina.bpm")
}

/// L'orologio unico di Bobina: una griglia di battiti che tutte le sezioni leggono, così TX-6, PO e TP-7
/// suonano sulla stessa battuta. Non ha un timer suo: è un'ancora (un istante e il battito che cade lì)
/// più il bpm. Chi suona mette i suoi passi a `time(ofBeat:)`, ognuno dal suo filo.
///
/// Il bpm ha un padrone solo, questo: le schede Ritmo di tutte le sezioni lo mostrano e lo cambiano.
/// Chi parte per secondo non riancora: si aggancia all'inizio della battuta dopo.
final class BobinaClock {
    static let shared = BobinaClock()

    /// Chi suona sulla griglia. Ogni PO (ogni adattatore) è uno a sé: po, po2, po3, po4.
    enum Member: String { case tx6, po, po2, po3, po4, tp7, opz, m8 }

    static func po(_ slot: Int) -> Member { [.po, .po2, .po3, .po4][max(0, min(3, slot))] }

    /// Una fotografia della griglia, da leggere senza lock.
    struct Timeline {
        var running = false
        var anchorTime: MIDITimeStamp = 0
        var anchorBeat = 0.0
        var bpm = 120.0
        /// Cresce a ogni partenza e a ogni riancoraggio: chi legge capisce che la griglia si è spostata.
        var generation = 0
        /// Il tempo arriva da fuori (il TX-6 in «segui il TX-6»): il bpm non si cambia da Bobina.
        var followedBy: Member?

        var beatMs: Double { 60_000 / max(20, min(300, bpm)) }

        func beat(at t: MIDITimeStamp) -> Double {
            let ms = t >= anchorTime ? BobinaClock.ms(t - anchorTime) : -BobinaClock.ms(anchorTime - t)
            return anchorBeat + ms / beatMs
        }

        func time(ofBeat b: Double) -> MIDITimeStamp {
            let ms = (b - anchorBeat) * beatMs
            return ms >= 0 ? anchorTime &+ BobinaClock.ticks(ms) : anchorTime &- BobinaClock.ticks(-ms)
        }

        /// Il primo inizio di battuta (4 quarti) che cade a `t` o dopo.
        func bar(atOrAfter t: MIDITimeStamp) -> Double {
            (beat(at: t) / 4 - 1e-9).rounded(.up) * 4
        }
    }

    private let lock = NSLock()
    private var line = Timeline()
    private var members: Set<Member> = []
    private var lastPosted = 120.0

    private init() {
        line.anchorTime = mach_absolute_time()
    }

    // MARK: leggere

    func snapshot() -> Timeline {
        lock.lock()
        defer { lock.unlock() }
        return line
    }

    var bpm: Double { snapshot().bpm }

    func isMember(_ m: Member) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return members.contains(m)
    }

    // MARK: partire e fermarsi

    /// Una sezione comincia a suonare all'istante `start`. Se non suona nessuno la griglia riparte da lì
    /// (battito 0) col bpm di Bobina; se qualcuno suona già, la sezione si aggancia alla battuta dopo.
    /// Restituisce la griglia e il battito da cui cominciare.
    @discardableResult
    func join(_ m: Member, at start: MIDITimeStamp) -> (Timeline, Double) {
        lock.lock()
        defer { lock.unlock() }
        members.insert(m)
        if !line.running {
            line.running = true
            line.anchorTime = start
            line.anchorBeat = 0
            line.generation += 1
            trace("orologio: parte \(m.rawValue) a \(line.bpm) bpm")
            return (line, 0)
        }
        let first = line.bar(atOrAfter: start)
        trace("orologio: \(m.rawValue) si aggancia al battito \(first)")
        return (line, first)
    }

    /// Una sezione smette. Quando non suona più nessuno la griglia si ferma (ma resta valida per le onde).
    func leave(_ m: Member) {
        lock.lock()
        defer { lock.unlock() }
        guard members.remove(m) != nil else { return }
        if line.followedBy == m { line.followedBy = nil }
        if members.isEmpty {
            line.running = false
            trace("orologio: fermo")
        }
    }

    // MARK: il tempo

    /// Quanto dopo un cambio di tempo entra in vigore: i sequencer hanno già preparato i passi fino a
    /// 150 ms avanti, e quelli restano col tempo vecchio. Così nessuna sezione ha un passo storto.
    static let changeDelayMs = 160.0

    /// Cambia il bpm fra `changeDelayMs`: il battito continua da dove era, alla nuova velocità.
    func setBPM(_ value: Double) {
        setBPM(value, at: mach_absolute_time() &+ BobinaClock.ticks(BobinaClock.changeDelayMs))
    }

    /// Cambia il bpm a partire dall'istante `t`: il battito continua da dove era, alla nuova velocità.
    /// Non fa niente se il tempo arriva da fuori.
    func setBPM(_ value: Double, at t: MIDITimeStamp) {
        let v = max(20, min(300, value))
        lock.lock()
        guard line.followedBy == nil, abs(v - line.bpm) > 0.0001 else { lock.unlock(); return }
        line.anchorBeat = line.beat(at: t)
        line.anchorTime = t
        line.bpm = v
        line.generation += 1
        lastPosted = v
        lock.unlock()
        post(v)
    }

    /// Per chi segue un clock che arriva da fuori (il TX-6 in «segui il TX-6»): il battito `beat` cade a `time`.
    /// Il bpm lo misura chi chiama, dagli impulsi. Chi segue diventa anche uno che suona: `leave` quando il clock smette.
    func follow(time: MIDITimeStamp, beat: Double, bpm value: Double, by m: Member) {
        let v = max(20, min(300, value))
        lock.lock()
        members.insert(m)
        line.running = true
        line.followedBy = m
        line.anchorTime = time
        line.anchorBeat = beat
        line.bpm = v
        line.generation += 1
        // chi mostra il numero lo arrotonda: basta avvisare quando cambia di un decimo
        let changed = abs(v - lastPosted) >= 0.1
        if changed { lastPosted = v }
        lock.unlock()
        if changed { post(v) }
    }

    private func post(_ v: Double) {
        DispatchQueue.main.async { NotificationCenter.default.post(name: .bobinaBPM, object: v) }
    }

    // MARK: unità

    private static let timebase: mach_timebase_info_data_t = {
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)
        return tb
    }()

    static func ms(_ ticks: MIDITimeStamp) -> Double {
        Double(ticks) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000
    }

    static func ticks(_ ms: Double) -> MIDITimeStamp {
        MIDITimeStamp(max(0, ms) * 1_000_000 * Double(timebase.denom) / Double(timebase.numer))
    }
}
