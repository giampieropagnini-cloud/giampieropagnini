import Foundation
import CoreMIDI
import CoreMotion

/// Quello che cambia molte volte al secondo (il passo, l'inclinazione): sta a parte, così si ridisegnano
/// solo i quadratini e la barretta, non tutta la pagina col menu «passa a…».
final class M8Live: ObservableObject {
    @Published var step: Int?
    @Published var tilt = 64
}

/// Bobina che suona l'M8: pad, 16 passi a tempo, inclinazione su un CC.
/// Le note vanno al canale d'ingresso di una traccia (Project > MIDI > Settings > TRACK INPUT, CHAN).
final class M8Player: ObservableObject {
    weak var engine: M8Engine?
    let live = M8Live()

    /// Il canale d'ingresso della traccia che suona.
    @Published var channel: Int { didSet { save(); push() } }
    /// La nota più bassa dei 16 pad.
    @Published var base: Int { didSet { save() } }
    /// I passi: la nota di ognuno, nil = vuoto.
    @Published var steps: [Int?] { didSet { save(); push() } }
    /// La nota che si scrive toccando un passo vuoto. L'ultimo pad suonato.
    @Published var pick: Int
    @Published private(set) var stepsOn = false
    /// 8 o 16 passi.
    @Published var stepLength: Int { didSet { save(); push(); if cursor >= stepLength { cursor = 0 } } }
    /// Il passo dove va la prossima nota scritta in fila.
    @Published var cursor = 0
    /// L'ottava della tastiera dei passi (3 = C-3…B-3).
    @Published var writeOctave: Int { didSet { save() } }
    /// I pad: «tocca» suona un attimo, «tieni» lascia la nota accesa finché non la ritocchi.
    @Published var holdMode = false { didSet { if !holdMode { releaseAll() } } }
    @Published private(set) var held: Set<Int> = []

    @Published var tiltOn = false { didSet { tiltOn ? startMotion() : stopMotion() } }
    /// Il CC dell'inclinazione: sull'M8 si assegna in Project > MIDI Mapping, come la manopola.
    @Published var tiltCC: Int { didSet { save() } }

    private let motion = CMMotionManager()
    private var lastTilt = -1

    init() {
        let d = UserDefaults.standard
        channel = d.object(forKey: "bobina.m8.suona.canale") as? Int ?? 1
        base = d.object(forKey: "bobina.m8.suona.base") as? Int ?? 48
        tiltCC = d.object(forKey: "bobina.m8.suona.cc") as? Int ?? 2
        if let data = d.data(forKey: "bobina.m8.suona.passi"), let s = try? JSONDecoder().decode([Int?].self, from: data), s.count == 16 {
            steps = s
        } else {
            steps = Array(repeating: nil, count: 16)
        }
        pick = d.object(forKey: "bobina.m8.suona.base") as? Int ?? 48
        stepLength = d.object(forKey: "bobina.m8.suona.lunghezza") as? Int ?? 16
        writeOctave = d.object(forKey: "bobina.m8.suona.ottava") as? Int ?? 3
        if let p = d.array(forKey: "bobina.m8.suona.strumenti") as? [Int], p.count == 16 {
            programs = p.map { $0 < 0 ? nil : $0 }
        }
    }

    func attach(_ e: M8Engine) {
        engine = e
        e.sequencer.onStep = { [weak self] i, _ in
            DispatchQueue.main.async { self?.live.step = i }
        }
        push()
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(channel, forKey: "bobina.m8.suona.canale")
        d.set(base, forKey: "bobina.m8.suona.base")
        d.set(tiltCC, forKey: "bobina.m8.suona.cc")
        d.set(stepLength, forKey: "bobina.m8.suona.lunghezza")
        d.set(writeOctave, forKey: "bobina.m8.suona.ottava")
        if let data = try? JSONEncoder().encode(steps) { d.set(data, forKey: "bobina.m8.suona.passi") }
    }

    private func push() {
        engine?.sequencer.update(M8Sequencer.Plan(steps: steps, channel: channel, length: stepLength))
    }

    private func send(_ bytes: [UInt8], at t: MIDITimeStamp = 0) {
        guard let io = engine?.io else { return }
        io.send(bytes, at: t)
        trace("→ M8 " + bytes.map { String(format: "%02x", $0) }.joined(separator: " "))
    }

    private var ch: UInt8 { UInt8((channel - 1) & 0x0F) }

    // MARK: traccia

    /// La traccia dell'M8 che suonano pad e passi. Sull'M8 la traccia N ascolta il canale N
    /// (Project > MIDI > Settings, TRACK INPUT, CHAN): quindi traccia = canale.
    /// Le note tenute si lasciano prima, sul canale vecchio.
    func setTrack(_ n: Int) {
        let n = max(1, min(16, n))
        guard n != channel else { return }
        releaseAll()
        channel = n
    }

    // MARK: strumento

    /// Lo strumento mandato a ogni canale col Program Change (nil = non ancora mandato da Bobina).
    /// Sull'M8 la traccia lo prende solo con PG CHANGE acceso (MIDI Settings, TRACK INPUT).
    @Published private(set) var programs: [Int?] = Array(repeating: nil, count: 16)

    var program: Int? { programs[channel - 1] }

    /// Strumento − e +: manda il Program Change sul canale della traccia scelta.
    func stepProgram(_ d: Int) {
        let p = max(0, min(127, (program ?? (d > 0 ? -1 : 1)) + d))
        programs[channel - 1] = p
        UserDefaults.standard.set(programs.map { $0 ?? -1 }, forKey: "bobina.m8.suona.strumenti")
        send([0xC0 | ch, UInt8(p)])
    }

    /// Il numero come lo scrive l'M8: due cifre esadecimali (00-7F).
    static func hex(_ n: Int?) -> String { n.map { String(format: "%02X", $0) } ?? "--" }

    // MARK: pad

    static let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    /// Il nome come sull'M8: C-4, C#4…
    static func name(_ n: Int) -> String {
        let s = names[n % 12]
        return s + (s.count == 1 ? "-" : "") + "\(n / 12 - 1)"
    }

    /// Il tocco di un pad, secondo il modo.
    func pad(_ n: Int) {
        if holdMode { toggleHold(n) } else { touch(n) }
    }

    /// La metà di sopra: suona la nota per un quarto di secondo. Se era tenuta, la lascia.
    func touch(_ n: Int) {
        pick = n
        if held.contains(n) { release(n); return }
        guard let io = engine?.io else { return }
        send([0x90 | ch, UInt8(n), 100])
        io.send([0x80 | ch, UInt8(n), 0], at: io.now() + io.ticks(ms: 250))
    }

    /// La metà di sotto: tiene la nota finché non la ritocchi.
    func toggleHold(_ n: Int) {
        pick = n
        if held.contains(n) { release(n) } else {
            held.insert(n)
            send([0x90 | ch, UInt8(n), 100])
        }
    }

    private func release(_ n: Int) {
        held.remove(n)
        send([0x80 | ch, UInt8(n), 0])
    }

    func releaseAll() {
        guard !held.isEmpty else { return }
        let c = ch
        let bytes: [UInt8] = held.sorted().flatMap { [0x80 | c, UInt8($0), 0] }
        held.removeAll()
        send(bytes)
    }

    /// Dopo il silenzio: niente più note tenute.
    func forgetHeld() { held.removeAll() }

    func octave(_ d: Int) {
        releaseAll()
        base = max(0, min(108, base + 12 * d))
        pick = max(base, min(base + 15, pick))
    }

    // MARK: passi

    func clearSteps() {
        steps = Array(repeating: nil, count: 16)
        cursor = 0
    }

    /// Scrittura in fila: la nota (0-11 nell'ottava scelta) si sente, va nel passo del cursore
    /// e il cursore passa al passo dopo. Un tocco per nota.
    func write(_ semitone: Int) {
        let n = max(0, min(127, (writeOctave + 1) * 12 + semitone))
        preview(n)
        pick = n
        steps[cursor] = n
        advance()
    }

    /// Il passo del cursore resta vuoto, e si va avanti.
    func rest() {
        steps[cursor] = nil
        advance()
    }

    /// Il cursore torna indietro di uno, per correggere l'ultima nota.
    func back() {
        cursor = (cursor - 1 + stepLength) % stepLength
    }

    /// Il cursore va su un passo; se c'è una nota si sente.
    func select(_ i: Int) {
        cursor = i
        if let n = steps[i] { preview(n) }
    }

    /// I passi 1-8 copiati su 9-16.
    func copyHalf() {
        var s = steps
        for i in 0..<8 { s[i + 8] = s[i] }
        steps = s
    }

    private func advance() {
        cursor = (cursor + 1) % stepLength
    }

    private func preview(_ n: Int) {
        guard let io = engine?.io else { return }
        send([0x90 | ch, UInt8(n), 100])
        io.send([0x80 | ch, UInt8(n), 0], at: io.now() + io.ticks(ms: 200))
    }

    func toggleSteps() {
        stepsOn.toggle()
        engine?.sequencer.setSteps(stepsOn)
        if !stepsOn { live.step = nil }
    }

    // MARK: inclinazione

    private func startMotion() {
        guard motion.isDeviceMotionAvailable else { tiltOn = false; return }
        motion.deviceMotionUpdateInterval = 1.0 / 30
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let d = data, let e = self.engine else { return }
            // telefono dritto = metà; 45° a sinistra = 0, 45° a destra = 127
            let roll = d.attitude.roll * 180 / .pi
            let v = Int(((max(-45, min(45, roll)) + 45) / 90 * 127).rounded())
            // un messaggio solo quando il valore cambia: niente flussi inutili
            guard v != self.lastTilt else { return }
            self.lastTilt = v
            self.live.tilt = v
            e.io.send(M8.cc(self.tiltCC, v, channel: e.channel))
        }
    }

    private func stopMotion() {
        motion.stopDeviceMotionUpdates()
        lastTilt = -1
    }
}
