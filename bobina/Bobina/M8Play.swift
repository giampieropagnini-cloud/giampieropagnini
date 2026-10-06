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
        if let data = try? JSONEncoder().encode(steps) { d.set(data, forKey: "bobina.m8.suona.passi") }
    }

    private func push() {
        engine?.sequencer.update(M8Sequencer.Plan(steps: steps, channel: channel))
    }

    private func send(_ bytes: [UInt8], at t: MIDITimeStamp = 0) {
        guard let io = engine?.io else { return }
        io.send(bytes, at: t)
        trace("→ M8 " + bytes.map { String(format: "%02x", $0) }.joined(separator: " "))
    }

    private var ch: UInt8 { UInt8((channel - 1) & 0x0F) }

    // MARK: pad

    static let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    /// Il nome come sull'M8: C-4, C#4…
    static func name(_ n: Int) -> String {
        let s = names[n % 12]
        return s + (s.count == 1 ? "-" : "") + "\(n / 12 - 1)"
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

    /// Un passo vuoto prende la nota scelta; uno pieno si svuota.
    func toggleStep(_ i: Int) {
        steps[i] = steps[i] == nil ? pick : nil
    }

    func clearSteps() {
        steps = Array(repeating: nil, count: 16)
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
