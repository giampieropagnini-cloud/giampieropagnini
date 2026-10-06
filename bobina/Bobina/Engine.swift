import Foundation
import CoreMIDI
import CoreMotion
import UIKit

/// Una riga del monitor.
struct LogLine: Identifiable {
    let id = UUID()
    let incoming: Bool
    let text: String
    let raw: String
}

enum LoopState { case off, started, on }

/// Quello che cambia molte volte al secondo (la casella del passo, il pad che lampeggia, la velocità
/// dell'inclinazione) vive a parte: così si ridisegnano solo le griglie che lo mostrano, non tutta la pagina.
/// Se cambiasse dentro Engine, a ogni sedicesimo SwiftUI rifarebbe anche il menu «passa a…», e i tocchi si perderebbero.
final class Pulse: ObservableObject {
    @Published var step = 0
    @Published var flashPad: Int?
    @Published var motionSpeed = 1.0
}

/// Quello che cambia decine di volte al secondo mentre giri la bobina, o mentre il TP-7 in ctrl manda i suoi
/// tasti: vive a parte come Pulse, così si ridisegnano solo le scritte che lo mostrano e non tutte le pagine.
/// (Misurato dalla sessione TX-6 il 1/10/2026: con la leva in Engine lo scratch dava 80-120 cambi al secondo.)
final class Live: ObservableObject {
    @Published var lever = TP7.leverCenter
    @Published var pressed: Set<UInt8> = []
    @Published var wheelSteps = 0
    @Published var rocker = 0
}

/// Il monitor dei messaggi: anche lui a parte, perché durante lo scratch o col TP-7 in ctrl si riempie di continuo.
final class LogBook: ObservableObject {
    @Published var lines: [LogLine] = []
}

/// Tutto quello che Bobina sa e fa. Vive sul main thread; i messaggi a tempo partono
/// in anticipo con la marca temporale di CoreMIDI, così il ritmo non dipende dallo schermo.
final class Engine: ObservableObject {

    let io = MIDIIO()

    // MARK: collegamento

    @Published var destinations: [MIDIPort] = []
    @Published var sources: [MIDIPort] = []
    @Published var destinationID: MIDIUniqueID? { didSet { applyPorts() } }
    @Published var sourceID: MIDIUniqueID? { didSet { applyPorts() } }
    let logBook = LogBook()
    let live = Live()
    @Published var logPaused = false

    var connected: Bool { io.destination != 0 }
    var connectedName: String {
        destinations.first(where: { $0.id == destinationID })?.name ?? "nessuno"
    }

    // MARK: nastro

    /// Velocità di base scelta con lo slider (×0,5 … ×2). Solo mentre il TP-7 suona.
    @Published var speed: Double = 1.0
    /// Il nastro è stato fermato da Bobina (60 + 708): il pitch bend resta fermo lì.
    @Published private(set) var halted = false
    private(set) var lever = TP7.leverCenter {
        didSet { if lever >= 0 && live.lever != lever { live.lever = lever } }
    }
    /// Il trasporto col TP-7 su cue, dove start e stop li ignora: ▶ e ■ si fanno con la leva.
    /// fermo (64) · suona con la leva (68, il TP-7 resta «fermo» ma il nastro corre) ·
    /// suona (dopo un pad, il TP-7 è in play e la leva a 64 è la velocità normale) · tenuto fermo (60 + pitch bend +708, come «dito»).
    enum CueTape { case stopped, leverPlay, playing, frozen }
    @Published private(set) var cueTape = CueTape.stopped

    /// Avvolgimento veloce: −1 indietro, +1 avanti, 0 fermo.
    @Published private(set) var winding = 0

    // MARK: effetti continui

    @Published var wowOn = false
    @Published var wowDepth = 0.35      // quanto ondeggia
    @Published var wowRate = 0.7        // Hz dell'ondeggiare lento
    @Published var flutter = 0.25       // quanto trema veloce

    @Published var motionOn = false {
        didSet {
            if motionOn { startMotion() } else { stopMotion() }
        }
    }
    let pulse = Pulse()
    private var motionSpeed: Double { pulse.motionSpeed }
    @Published var shakeAction = ShakeAction.tapeStop

    enum ShakeAction: String, CaseIterable, Identifiable {
        case tapeStop = "tape stop"
        case randomCue = "cue a caso"
        case nothing = "niente"
        var id: String { rawValue }
    }

    // MARK: cue

    @Published var markMode = false { didSet { if oldValue != markMode { send(TP7.cc(TP7.ccCueRec, markMode ? 127 : 0)) } } }
    @Published var padsSet: Set<Int> = []
    /// Pad «finché lo tieni»: il nastro suona solo mentre un pad è premuto, e si ferma quando lo lasci.
    @Published var padHold = UserDefaults.standard.bool(forKey: "bobina.padHold") {
        didSet { UserDefaults.standard.set(padHold, forKey: "bobina.padHold") }
    }
    private var heldPads = Set<Int>()
    @Published private(set) var lastPad: Int?

    // MARK: tempo e giochi a tempo

    /// Da 40 a 240: i limiti li tengono i controlli.
    @Published var bpm: Double = 120
    @Published private(set) var running = false
    var step: Int { pulse.step }
    /// Col TP-7 su MIDI → sync, i passi li detta il suo clock (il tempo del file, anche quando lo rallenti).
    @Published var followClock = false { didSet { if followClock && running { toggleRun() } } }
    private var clockTicks = 0

    /// Il ritmo sta andando: col tempo di Bobina o con quello del TP-7.
    var pulsing: Bool { running || (followClock && clockBPM != nil) }

    /// Balbettio: finché è tenuto, ripete l'ultimo pad ogni `stutter` sedicesimi (0,5 = trentaduesimi).
    @Published var stutter: Double? = nil

    @Published var seqOn = false
    @Published var seq: [Int?] = Array(repeating: nil, count: 16) { didSet { save() } }

    @Published var gateOn = false { didSet { if !gateOn { releaseGate() } } }
    @Published var gate: [Bool] = [true, false, true, false, true, true, false, true, true, false, true, false, true, true, false, false] { didSet { save() } }
    @Published var gateTracks: Set<Int> = [1] { didSet { save() } }

    @Published var pumpOn = false { didSet { if !pumpOn { restoreVolumes() } } }
    @Published var pumpDepth = 0.7
    @Published var pumpRelease = 0.6    // frazione del quarto
    @Published var pumpTracks: Set<Int> = [1]

    /// Deriva: i volumi delle tracce scelte vagano piano, ognuno per conto suo.
    @Published var driftOn = false { didSet { if !driftOn { restoreDrift() } } }
    @Published var driftAmount = 0.5
    @Published var driftTracks: Set<Int> = [1, 2, 3]
    private var driftLevels: [Double] = Array(repeating: 1, count: 6)
    private var driftVelocity: [Double] = Array(repeating: 0, count: 6)
    private var driftSentAt: MIDITimeStamp = 0

    @Published var collageOn = false
    @Published var collageEvery = 4     // sedicesimi
    @Published var collageChance = 0.5

    // MARK: loop, mixer, ingressi

    @Published private(set) var loop = LoopState.off
    @Published var volumes: [Int] = Array(repeating: 127, count: 6)
    @Published var mutes: [Bool] = Array(repeating: false, count: 6)
    @Published var gains: [Int] = Array(repeating: 0, count: 3)
    @Published var armed = false

    // MARK: quello che arriva dal TP-7 (in ctrl) e il clock

    var pressed: Set<UInt8> { live.pressed }
    @Published private(set) var clockBPM: Double?

    // MARK: interni

    private var timer: DispatchSourceTimer?
    private var nextStepAt: MIDITimeStamp = 0
    private var stepIndex = 0
    private var lastBendSent: Int?
    private var lastBendAt: MIDITimeStamp = 0
    private var phase = 0.0
    private var flutterPhase = 0.0
    private var drift = 0.0
    private var lastTick: MIDITimeStamp = 0
    private var leverRemindedAt: MIDITimeStamp = 0
    /// Scalini di leva a tempo (tape stop e avvio col nastro mosso dalla leva): il tick li manda uno alla volta.
    private var leverSteps: [(value: Int, at: MIDITimeStamp)] = []
    private var leverStepsEnd: CueTape?
    /// L'ultimo trasporto usato era quello in cue: tape stop e avvio lo usano per sapere come fermare e partire.
    private var lastTransportCue = false
    private var ramp: (from: Double, to: Double, start: MIDITimeStamp, length: Double, stopAfter: Double?)?
    private var bendQuietUntil: MIDITimeStamp = 0
    private var gateState: Bool?
    /// L'istante dell'ultimo passo già consegnato a CoreMIDI.
    private var lastFiredAt: MIDITimeStamp = 0
    private var clockStamps: [MIDITimeStamp] = []
    private var clockTimeout: DispatchWorkItem?
    private let motion = CMMotionManager()
    private var lastShake = Date.distantPast
    private let haptic = UIImpactFeedbackGenerator(style: .rigid)

    init() {
        // su iOS 27 il pannello bluetooth di Apple chiudeva l'app: la riparazione è in IOS27.swift
        // (trovata dalla sessione TX-6). Chiamarla due volte non fa danni.
        IOS27.install()
        load()
        io.onSetupChanged = { [weak self] in self?.refreshPorts() }
        io.onReceive = { [weak self] bytes, stamp in self?.received(bytes, stamp) }
        refreshPorts()
        startTimer()
    }

    // MARK: porte

    func refreshPorts() {
        destinations = io.destinations()
        sources = io.sources()
        trace("destinazioni: " + destinations.map { "\($0.name) id \($0.id) ref \($0.ref)" }.joined(separator: " · "))
        trace("sorgenti: " + sources.map { "\($0.name) id \($0.id) ref \($0.ref)" }.joined(separator: " · "))
        if destinationID == nil || !destinations.contains(where: { $0.id == destinationID }) {
            destinationID = destinations.first(where: { $0.looksLikeTP7 })?.id
        }
        if sourceID == nil || !sources.contains(where: { $0.id == sourceID }) {
            sourceID = sources.first(where: { $0.looksLikeTP7 })?.id
        }
        applyPorts()
    }

    private func applyPorts() {
        let dest = destinations.first(where: { $0.id == destinationID })?.ref ?? 0
        let src = sources.first(where: { $0.id == sourceID })?.ref ?? 0
        if dest != io.destination || src != io.source {
            let newDestination = dest != 0 && dest != io.destination
            io.use(destination: dest, source: src)
            objectWillChange.send()
            if newDestination {
                // se Bobina si era chiusa col nastro mosso dalla leva, il TP-7 continua a correre:
                // appena si ricollega la leva torna al centro (come il «silenzio» delle note del TX-6)
                io.send(TP7.cc(TP7.ccLever, TP7.leverCenter))
                lever = TP7.leverCenter
                cueTape = .stopped
            }
        }
    }

    // MARK: invio

    func send(_ bytes: [UInt8], at time: MIDITimeStamp = 0, quiet: Bool = false) {
        io.send(bytes, at: time)
        if let first = bytes.first, first & 0xF0 != 0xE0 {
            let ahead = time > io.now() ? Int(io.ms(ticks: time - io.now())) : 0
            trace("manda " + TP7.describe(bytes, incoming: false) + (ahead > 0 ? " tra \(ahead) ms" : ""))
        }
        if !quiet { note(bytes, incoming: false) }
    }

    private func note(_ bytes: [UInt8], incoming: Bool) {
        guard !logPaused else { return }
        let raw = bytes.prefix(12).map { String(format: "%02x", $0) }.joined(separator: " ")
        logBook.lines.insert(LogLine(incoming: incoming, text: TP7.describe(bytes, incoming: incoming), raw: raw), at: 0)
        if logBook.lines.count > 150 { logBook.lines.removeLast(logBook.lines.count - 150) }
    }

    func clearLog() { logBook.lines.removeAll() }

    // MARK: trasporto

    /// Quello che Bobina crede: il TP-7 non racconta mai com'è messo.
    @Published private(set) var rolling = false
    @Published private(set) var recording = false

    /// La leva finta (cc 18): 64 centro. Si somma a quello che il nastro sta già facendo.
    func setLever(_ value: Int, quiet: Bool = false) {
        let v = max(0, min(127, value))
        guard v != lever else { return }
        lever = v
        send(TP7.cc(TP7.ccLever, v), quiet: quiet)
    }

    private func forceLever(_ value: Int) {
        cancelLeverSteps()
        winding = 0
        lever = -1
        setLever(value)
    }

    /// ▶ continue: riparte da dove si trova.
    func play() {
        lastTransportCue = false
        ramp = nil
        halted = false
        forceLever(TP7.leverCenter)
        sendBend(currentBend(), force: true)
        send(TP7.continuePlay)
        rolling = true
        cueTape = .playing
    }

    /// ⏮ start: riavvolge e suona dall'inizio del file.
    func fromTop() {
        lastTransportCue = false
        ramp = nil
        halted = false
        forceLever(TP7.leverCenter)
        sendBend(currentBend(), force: true)
        send(TP7.start)
        rolling = true
        cueTape = .playing
    }

    /// ■ stop: si ferma dov'è. Premuto di nuovo da fermo torna all'inizio, come sulla macchina.
    func stop() {
        lastTransportCue = false
        ramp = nil
        halted = false
        forceLever(TP7.leverCenter)
        send(TP7.stop)
        rolling = false
        cueTape = .stopped
        if recording {
            recording = false
            armed = false
        }
    }

    /// ● registra: arma e parte. Nasce sempre un file nuovo; ■ chiude la ripresa.
    func record() {
        lastTransportCue = false
        send(TP7.cc(TP7.ccArm, 127))
        armed = true
        forceLever(TP7.leverCenter)
        send(TP7.continuePlay)
        rolling = true
        recording = true
    }

    /// Tenuto premuto: il nastro resta fermo come sotto il dito, e riparte quando lasci.
    /// Se il nastro corre con la leva (▶ in cue) il dito è la leva al centro; durante il play è 60 + pitch bend +708;
    /// a nastro fermo non fa niente, perché la leva a 60 lo farebbe riavvolgere.
    func holdStill(_ on: Bool) {
        ramp = nil
        switch cueTape {
        case .leverPlay:
            cancelLeverSteps()
            setLever(on ? TP7.leverCenter : TP7.leverCuePlay)
        case .stopped:
            break
        case .playing, .frozen:
            if on {
                halted = true
                forceLever(TP7.leverHalt)
                sendBend(TP7.haltBend, force: true)
            } else {
                halted = false
                forceLever(TP7.leverCenter)
                sendBend(currentBend(), force: true)
            }
        }
    }

    /// Tape stop: il nastro rallenta fino a ×0,5 col pitch bend, poi la leva lo porta a zero e lo stop lo ferma.
    /// Col nastro mosso dalla leva (▶ in cue) il pitch bend non si sente: lì la leva scende a scalini fino al centro.
    func tapeStop(seconds: Double) {
        if cueTape == .leverPlay {
            startLeverSteps([TP7.leverCuePlay - 1, TP7.leverCuePlay - 2, TP7.leverCuePlay - 3, TP7.leverCenter],
                            seconds: seconds, end: .stopped)
            return
        }
        halted = false
        let length = max(0.1, seconds) * 1000
        ramp = (from: currentSpeedFactor(), to: TP7.minSpeed, start: io.now(), length: length * 0.8, stopAfter: length * 0.2)
    }

    private func finishTapeStop(tail: Double) {
        let t0 = io.now()
        bendQuietUntil = t0 + io.ticks(ms: tail + 40)
        if lastTransportCue {
            // in cue lo stop (FC) è ignorato: alla fine il nastro resta tenuto fermo come sotto il dito,
            // e il ▶ in cue lo lascia ripartire
            send(TP7.cc(TP7.ccLever, TP7.leverCenter - 2), quiet: true)
            send(TP7.cc(TP7.ccLever, TP7.leverHalt), at: t0 + io.ticks(ms: tail), quiet: true)
            send(TP7.bend(TP7.haltBend), at: t0 + io.ticks(ms: tail), quiet: true)
            lastBendSent = TP7.haltBend
            lever = TP7.leverHalt
            halted = true
            rolling = false
            cueTape = .frozen
            return
        }
        send(TP7.cc(TP7.ccLever, TP7.leverCenter - 1), quiet: true)
        send(TP7.cc(TP7.ccLever, TP7.leverCenter - 2), at: t0 + io.ticks(ms: tail * 0.5), quiet: true)
        send(TP7.stop, at: t0 + io.ticks(ms: tail))
        send(TP7.cc(TP7.ccLever, TP7.leverCenter), at: t0 + io.ticks(ms: tail + 5), quiet: true)
        let restore = currentBend()
        send(TP7.bend(restore), at: t0 + io.ticks(ms: tail + 10), quiet: true)
        lastBendSent = restore
        lever = TP7.leverCenter
        rolling = false
        cueTape = .stopped
    }

    /// Avvio: parte fermo, la leva lo sblocca, il pitch bend lo porta a velocità.
    /// In cue a nastro fermo (o mosso dalla leva) il play vero non c'è: la leva sale a scalini fino a 68.
    func tapeStart(seconds: Double) {
        if lastTransportCue && (cueTape == .stopped || cueTape == .leverPlay) {
            startLeverSteps([TP7.leverCenter + 1, TP7.leverCenter + 2, TP7.leverCenter + 3, TP7.leverCuePlay],
                            seconds: seconds, end: .leverPlay)
            return
        }
        let length = max(0.1, seconds) * 1000
        let t0 = io.now()
        halted = false
        forceLever(TP7.leverCenter - 2)
        sendBend(TP7.bendFor(speed: TP7.minSpeed), force: true)
        send(TP7.continuePlay)
        send(TP7.cc(TP7.ccLever, TP7.leverCenter - 1), at: t0 + io.ticks(ms: length * 0.1), quiet: true)
        send(TP7.cc(TP7.ccLever, TP7.leverCenter), at: t0 + io.ticks(ms: length * 0.2), quiet: true)
        lever = TP7.leverCenter
        ramp = (from: TP7.minSpeed, to: max(TP7.minSpeed, speed), start: t0 + io.ticks(ms: length * 0.2), length: length * 0.8, stopAfter: nil)
        rolling = true
        cueTape = .playing
    }

    private func cancelLeverSteps() {
        leverSteps.removeAll()
        leverStepsEnd = nil
    }

    /// Una scala di valori di leva distribuita su `seconds`: il primo subito, l'ultimo alla fine.
    private func startLeverSteps(_ values: [Int], seconds: Double, end: CueTape) {
        cancelLeverSteps()
        ramp = nil
        halted = false
        winding = 0
        let t0 = io.now()
        let length = max(0.1, seconds) * 1000
        let last = Double(max(1, values.count - 1))
        leverSteps = values.enumerated().map { k, v in (value: v, at: t0 + io.ticks(ms: length * Double(k) / last)) }
        leverStepsEnd = end
    }

    /// ⏪ ⏩: la leva tutta indietro o tutta avanti, cioè l'avvolgimento velocissimo della macchina.
    /// Un tocco parte, un altro tocco (o un altro tasto del trasporto) si ferma: niente da tenere premuto.
    func wind(_ direction: Int) {
        if winding == direction {
            winding = 0
            setLever(TP7.leverCenter)
            return
        }
        ramp = nil
        halted = false
        cancelLeverSteps()
        if cueTape == .leverPlay { cueTape = .stopped }
        winding = direction
        setLever(direction > 0 ? 127 : 0)
    }

    /// ▶ in cue: da fermo la leva a 60 fa correre il nastro; se era tenuto fermo dopo un pad, lo lascia andare.
    func cuePlay() {
        lastTransportCue = true
        switch cueTape {
        case .stopped:
            ramp = nil
            halted = false
            forceLever(TP7.leverCuePlay)
            cueTape = .leverPlay
        case .frozen:
            holdStill(false)
            cueTape = .playing
        case .leverPlay:
            // il TP-7 può essersi fermato da solo (fine del file, o leva rilasciata): si riprova sempre
            forceLever(TP7.leverCuePlay)
        case .playing:
            break
        }
    }

    /// ■ in cue: toglie la leva del ▶, oppure, se il nastro suona da solo dopo un pad, lo tiene fermo come «dito».
    func cueStop() {
        lastTransportCue = true
        if !leverSteps.isEmpty {
            // un avvio a scalini in corso: si ferma qui
            forceLever(TP7.leverCenter)
            cueTape = .stopped
            return
        }
        if recording {
            send(TP7.cc(TP7.ccArm, 0))
            armed = false
            recording = false
        }
        switch cueTape {
        case .leverPlay:
            forceLever(TP7.leverCenter)
            cueTape = .stopped
        case .playing:
            holdStill(true)
            cueTape = .frozen
        case .stopped, .frozen:
            break
        }
    }

    /// In cue un pad fa saltare il nastro al suo segno, ma suona solo se il nastro sta già correndo
    /// (provato il 1/10/2026). Se è fermo, Bobina lo fa correre in avanti con la leva; se corre già, la leva resta.
    /// Se era tenuto fermo durante il play, il pad lo lascia ripartire dal segno.
    private func padStartsTape(at time: MIDITimeStamp) {
        lastTransportCue = true
        if !leverSteps.isEmpty { cancelLeverSteps() }
        switch cueTape {
        case .stopped:
            ramp = nil
            halted = false
            winding = 0
            lever = TP7.leverCuePlay
            send(TP7.cc(TP7.ccLever, TP7.leverCuePlay), at: time, quiet: true)
            cueTape = .leverPlay
        case .frozen:
            let restore = currentBend()
            send(TP7.bend(restore), at: time, quiet: true)
            lastBendSent = restore
            halted = false
            lever = TP7.leverCenter
            send(TP7.cc(TP7.ccLever, TP7.leverCenter), at: time, quiet: true)
            cueTape = .playing
        case .leverPlay, .playing:
            // il sequencer passa di qui a ogni colpo: niente da cambiare, niente da pubblicare
            break
        }
    }

    /// ● in cue: arma soltanto (cc 14). Provato il 1/10/2026, con la leva sia a 60 sia a 68: in cue la ripresa
    /// parte solo dal ▶ della macchina. Il ■ in cue la chiude, perché il disarmo (cc 14 a 0) la ferma.
    func cueRecord() {
        lastTransportCue = true
        send(TP7.cc(TP7.ccArm, 127))
        armed = true
        recording = true
    }

    // MARK: bobina virtuale

    private var scrubbing = false
    private var lastScrubAt: MIDITimeStamp = 0
    private var lastScrubSentAt: MIDITimeStamp = 0

    /// Il dito sulla bobina virtuale: la sua velocità diventa la leva.
    func scrub(_ value: Int) {
        cancelLeverSteps()
        winding = 0
        if cueTape == .leverPlay { cueTape = .stopped }
        scrubbing = true
        lastScrubAt = io.now()
        // col bluetooth al massimo un messaggio ogni 30 ms: con due macchine il canale si intasa
        let now = io.now()
        if overBluetooth && io.ms(ticks: now &- lastScrubSentAt) < 30 { return }
        lastScrubSentAt = now
        // agli estremi (0 e 127) il TP-7 passa al riavvolgimento velocissimo: meglio restarne lontani.
        // quiet: lo scratch non riempie il monitor, che ridisegnerebbe la pagina a ogni passo
        setLever(max(16, min(112, value)), quiet: true)
    }

    func endScrub() {
        scrubbing = false
        setLever(TP7.leverCenter)
    }

    // MARK: cue

    func hitPad(_ index: Int, at time: MIDITimeStamp = 0, fromUser: Bool = true) {
        let note = TP7.padBase + index
        send(TP7.noteOn(note), at: time, quiet: !fromUser)
        send(TP7.noteOff(note), at: time == 0 ? 0 : time + io.ticks(ms: 2), quiet: true)
        if fromUser {
            lastPad = index
            if markMode { padsSet.insert(index) }
            haptic.impactOccurred()
        }
        if !markMode {
            padStartsTape(at: time)
            resendMixer(after: time)
        }
        flash(index, at: time)
    }

    /// Dopo un salto di cue il TP-7 rimette il mixer a zero: Bobina gli rimanda volumi e muti.
    private func resendMixer(after time: MIDITimeStamp) {
        let base = time == 0 ? io.now() : time
        let when = base + io.ticks(ms: 40)
        for tr in 1...6 {
            if volumes[tr - 1] != 127 && !(pumpOn && pumpTracks.contains(tr)) {
                send(TP7.cc(TP7.ccVolume, volumes[tr - 1], channel: tr), at: when, quiet: true)
            }
            if mutes[tr - 1] && !(gateOn && gateTracks.contains(tr)) {
                send(TP7.cc(TP7.ccMute, 127, channel: tr), at: when, quiet: true)
            }
        }
    }

    private func flash(_ index: Int, at time: MIDITimeStamp) {
        let delay = time == 0 ? 0 : msUntil(time)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay / 1000) { [weak self] in
            self?.pulse.flashPad = index
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { [weak self] in
                if self?.pulse.flashPad == index { self?.pulse.flashPad = nil }
            }
        }
    }

    func forgetPads() { padsSet.removeAll(); lastPad = nil }

    /// Fra quali pad pescano il collage e «scuoti → cue a caso»: quelli segnati in Bobina, oppure, se non
    /// ne hai segnati (banche e album hanno i segni già scritti nel file), tutti e 16.
    private var randomPadPool: [Int] { padsSet.isEmpty ? Array(0..<16) : Array(padsSet) }

    /// Il dito sul pad: salta al segno e suona.
    func padDown(_ index: Int) {
        heldPads.insert(index)
        hitPad(index)
    }

    /// Il dito che lascia il pad: con «finché lo tieni» il nastro si ferma, ma solo quando non resta
    /// nessun pad premuto. In «segna» no: lì i pad mettono i segni. La registrazione non si tocca.
    func padUp(_ index: Int) {
        heldPads.remove(index)
        guard padHold, !markMode, heldPads.isEmpty else { return }
        switch cueTape {
        case .leverPlay:
            forceLever(TP7.leverCenter)
            cueTape = .stopped
        case .playing:
            holdStill(true)
            cueTape = .frozen
        case .stopped, .frozen:
            break
        }
    }

    /// ⏮ ⏭ canzone: in un «album» (un file con un segno all'inizio di ogni canzone, legato ai pad 1-16)
    /// passano alla canzone prima o dopo. Sempre in «richiama»: in «segna» sposterebbero i segni.
    func skipSong(_ step: Int) {
        if markMode { markMode = false }
        let current = lastPad ?? (step > 0 ? -1 : 0)
        hitPad((current + step + 16) % 16)
    }

    // MARK: balbettio e collage (partono col tempo di Bobina)

    private var startedForStutter = false

    func beginStutter(_ division: Double) {
        stutter = division
        if let pad = lastPad { hitPad(pad, fromUser: false) }
        if !running {
            toggleRun()
            startedForStutter = true
        }
    }

    func endStutter() {
        stutter = nil
        if startedForStutter && running && !seqOn && !gateOn && !pumpOn && !collageOn {
            toggleRun()
        }
        startedForStutter = false
    }

    func setCollage(_ on: Bool) {
        collageOn = on
        if on && !running { toggleRun() }
    }

    // MARK: loop

    func loopStart() { guard loop == .off else { return }; send(TP7.cc(TP7.ccLoop, 1)); loop = .started }
    func loopEnd() { guard loop == .started else { return }; send(TP7.cc(TP7.ccLoop, 2)); loop = .on }
    func loopOff() { send(TP7.cc(TP7.ccLoop, 0)); loop = .off }

    /// Loop a tempo: si apre alla prossima battuta e si chiude dopo `bars` battute.
    func loopInTime(bars: Double) {
        if !running { toggleRun() }
        if loop != .off { send(TP7.cc(TP7.ccLoop, 0)) }
        let stepTicks = io.ticks(ms: stepMs)
        let toBar = (16 - stepIndex) % 16
        let start = nextStepAt + MIDITimeStamp(toBar) * stepTicks
        let end = start + io.ticks(ms: stepMs * 16 * bars)
        send(TP7.cc(TP7.ccLoop, 1), at: start)
        send(TP7.cc(TP7.ccLoop, 2), at: end)
        loop = .started
        DispatchQueue.main.asyncAfter(deadline: .now() + msUntil(end) / 1000) { [weak self] in
            if self?.loop == .started { self?.loop = .on }
        }
    }

    // MARK: mixer e ingressi

    func setVolume(_ track: Int, _ value: Int) {
        volumes[track - 1] = value
        send(TP7.cc(TP7.ccVolume, value, channel: track))
    }

    func toggleMute(_ track: Int) {
        mutes[track - 1].toggle()
        send(TP7.cc(TP7.ccMute, mutes[track - 1] ? 127 : 0, channel: track))
    }

    func setGain(_ input: Int, _ value: Int) {
        gains[input - 1] = value
        send(TP7.cc(TP7.ccGain, value, channel: input))
    }

    func toggleArm() {
        armed.toggle()
        send(TP7.cc(TP7.ccArm, armed ? 127 : 0))
    }

    // MARK: tempo

    private var taps: [Date] = []
    func tap() {
        let now = Date()
        taps = taps.filter { now.timeIntervalSince($0) < 2.5 } + [now]
        guard taps.count >= 2 else { return }
        let gaps = zip(taps.dropFirst(), taps).map { $0.timeIntervalSince($1) }
        bpm = max(40, min(240, (60 / (gaps.reduce(0, +) / Double(gaps.count))).rounded()))
    }

    func toggleRun() {
        if running {
            running = false
            releaseGate()
            restoreVolumes()
        } else {
            stepIndex = 0
            gateState = nil
            nextStepAt = io.now() + io.ticks(ms: 30)
            running = true
        }
    }

    private var stepMs: Double { 60_000 / max(40, min(240, bpm)) / 4 }

    /// Quanti millisecondi mancano a un istante di CoreMIDI (0 se è già passato).
    private func msUntil(_ t: MIDITimeStamp) -> Double {
        let now = io.now()
        return t > now ? io.ms(ticks: t - now) : 0
    }

    // MARK: l'orologio

    private func startTimer() {
        let t = DispatchSource.makeTimerSource(flags: .strict, queue: .main)
        t.schedule(deadline: .now() + .milliseconds(50), repeating: .milliseconds(8), leeway: .milliseconds(1))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    private func tick() {
        let now = io.now()
        let dt = lastTick == 0 ? 0.008 : min(0.1, io.ms(ticks: now &- lastTick) / 1000)
        lastTick = now

        // i passi a tempo, preparati 150 ms prima: CoreMIDI li consegna all'istante giusto,
        // così il ritmo non inciampa se lo schermo tiene occupato il main thread (per esempio scorrendo)
        if running && !followClock {
            let horizon = now + io.ticks(ms: 150)
            if nextStepAt < now { nextStepAt = now }
            while nextStepAt < horizon {
                fire(stepIndex, at: nextStepAt)
                stepIndex = (stepIndex + 1) % 16
                nextStepAt += io.ticks(ms: stepMs)
            }
        }

        driftTick(now, dt)

        // gli scalini di leva di tape stop e avvio, al loro momento
        while let next = leverSteps.first, next.at <= now {
            leverSteps.removeFirst()
            lever = next.value
            io.send(TP7.cc(TP7.ccLever, next.value))
            if leverSteps.isEmpty, let end = leverStepsEnd {
                leverStepsEnd = nil
                cueTape = end
            }
        }

        // ▶ in cue: la leva si ricorda al TP-7 due volte al secondo, nel caso la lasci andare da sola
        if cueTape == .leverPlay && lever == TP7.leverCuePlay && io.ms(ticks: now &- leverRemindedAt) > 500 {
            leverRemindedAt = now
            io.send(TP7.cc(TP7.ccLever, TP7.leverCuePlay))
        }

        // dito fermo sulla bobina virtuale: la leva torna al centro
        if scrubbing && lever != TP7.leverCenter && io.ms(ticks: now &- lastScrubAt) > 90 {
            setLever(TP7.leverCenter)
        }

        // la velocità, ricalcolata di continuo
        if halted { return }
        if now < bendQuietUntil { return }
        if let r = ramp {
            let elapsed = now > r.start ? io.ms(ticks: now - r.start) : 0
            let p = min(1, elapsed / r.length)
            let s = r.from + (r.to - r.from) * (r.stopAfter != nil ? p * p : sqrt(p))
            sendBend(TP7.bendFor(speed: s), force: false)
            if p >= 1 {
                ramp = nil
                if let tail = r.stopAfter { finishTapeStop(tail: tail) }
            }
            return
        }
        if wowOn {
            phase += dt * wowRate * 2 * .pi
            flutterPhase += dt * 9.3 * 2 * .pi
            drift = max(-1, min(1, drift + Double.random(in: -1...1) * dt * 1.5))
            if phase > 2 * .pi { phase -= 2 * .pi }
            if flutterPhase > 2 * .pi { flutterPhase -= 2 * .pi }
        }
        sendBend(currentBend(), force: false)
    }

    /// Una passeggiata a caso per ogni traccia, aggiornata cinque volte al secondo.
    private func driftTick(_ now: MIDITimeStamp, _ dt: Double) {
        guard driftOn else { return }
        for tr in driftTracks {
            let k = tr - 1
            driftVelocity[k] = max(-0.4, min(0.4, driftVelocity[k] + Double.random(in: -1...1) * dt * 0.8))
            driftLevels[k] = max(1 - driftAmount, min(1, driftLevels[k] + driftVelocity[k] * dt))
            if driftLevels[k] <= 1 - driftAmount || driftLevels[k] >= 1 { driftVelocity[k] = -driftVelocity[k] * 0.5 }
        }
        guard io.ms(ticks: now &- driftSentAt) > 200 else { return }
        driftSentAt = now
        for tr in driftTracks.sorted() where !mutes[tr - 1] {
            let v = Double(volumes[tr - 1]) * driftLevels[tr - 1]
            send(TP7.cc(TP7.ccVolume, Int(v.rounded()), channel: tr), quiet: true)
        }
    }

    private func restoreDrift() {
        driftLevels = Array(repeating: 1, count: 6)
        driftVelocity = Array(repeating: 0, count: 6)
        for tr in driftTracks.sorted() {
            send(TP7.cc(TP7.ccVolume, volumes[tr - 1], channel: tr), quiet: true)
        }
    }

    private func currentSpeedFactor() -> Double {
        var s = speed * (motionOn ? motionSpeed : 1)
        if wowOn {
            let wow = sin(phase) * 0.7 + drift * 0.3
            let flut = sin(flutterPhase) * 0.5 + sin(flutterPhase * 1.73) * 0.5
            s *= 1 + wowDepth * 0.12 * wow + flutter * 0.02 * flut
        }
        return max(TP7.minSpeed, min(TP7.maxSpeed, s))
    }

    private func currentBend() -> Int { TP7.bendFor(speed: currentSpeedFactor()) }

    /// Il TP-7 è collegato col bluetooth: iOS chiama queste porte «… Bluetooth».
    var overBluetooth: Bool { connectedName.lowercased().contains("bluetooth") }

    /// Il pitch bend parte solo se cambia davvero, al massimo ogni 12 ms col cavo e ogni 40 ms col bluetooth:
    /// ogni invio è un pacchetto, e un bluetooth solo, con due macchine, si intasa.
    private func sendBend(_ value: Int, force: Bool) {
        let now = io.now()
        if !force {
            let ble = overBluetooth
            if let last = lastBendSent, abs(value - last) < (ble ? 24 : 6) { return }
            if lastBendSent == nil && value == 0 { return }
            if io.ms(ticks: now &- lastBendAt) < (ble ? 40 : 12) { return }
        }
        lastBendSent = value
        lastBendAt = now
        send(TP7.bend(value), quiet: !force)
    }

    /// Un sedicesimo: sequencer, balbettio, cancello, pompa, collage.
    private func fire(_ i: Int, at t: MIDITimeStamp) {
        lastFiredAt = max(lastFiredAt, t)
        let shown = i
        let delay = msUntil(t) / 1000
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.pulse.step = shown }

        if seqOn, let pad = seq[i] {
            hitPad(pad, at: t, fromUser: false)
        }

        if let div = stutter, let pad = lastPad {
            if div < 1 {
                hitPad(pad, at: t, fromUser: false)
                hitPad(pad, at: t + io.ticks(ms: stepMs / 2), fromUser: false)
            } else if i % Int(div) == 0 {
                hitPad(pad, at: t, fromUser: false)
            }
        }

        if gateOn {
            let open = gate[i]
            if open != gateState {
                gateState = open
                for tr in gateTracks.sorted() {
                    send(TP7.cc(TP7.ccMute, open ? (mutes[tr - 1] ? 127 : 0) : 127, channel: tr), at: t, quiet: true)
                }
            }
        }

        if pumpOn && i % 4 == 0 {
            let beat = stepMs * 4
            let points = 6
            for tr in pumpTracks.sorted() {
                let top = Double(volumes[tr - 1])
                for k in 0...points {
                    let p = Double(k) / Double(points)
                    let v = top * (1 - pumpDepth * (1 - p))
                    let when = t + io.ticks(ms: beat * pumpRelease * p)
                    send(TP7.cc(TP7.ccVolume, Int(v.rounded()), channel: tr), at: when, quiet: true)
                }
            }
        }

        if collageOn && i % max(1, collageEvery) == 0 && Double.random(in: 0..<1) < collageChance {
            if let pad = randomPadPool.randomElement() {
                hitPad(pad, at: t, fromUser: false)
            }
        }
    }

    private func releaseGate() {
        guard gateState != nil else { return }
        gateState = nil
        // i muti già preparati in anticipo arriverebbero dopo: il rilascio va messo in coda a loro
        let when = lastFiredAt > io.now() ? lastFiredAt + io.ticks(ms: 1) : 0
        for tr in gateTracks.sorted() {
            send(TP7.cc(TP7.ccMute, mutes[tr - 1] ? 127 : 0, channel: tr), at: when, quiet: true)
        }
    }

    private func restoreVolumes() {
        for tr in pumpTracks.sorted() {
            send(TP7.cc(TP7.ccVolume, volumes[tr - 1], channel: tr), quiet: true)
        }
    }

    // MARK: movimento

    private func startMotion() {
        guard motion.isDeviceMotionAvailable else { motionOn = false; return }
        motion.deviceMotionUpdateInterval = 1.0 / 30
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let d = data else { return }
            // inclinato a destra accelera, a sinistra rallenta: 45° = raddoppio o metà
            let roll = max(-1.2, min(1.2, d.attitude.roll))
            self.pulse.motionSpeed = max(TP7.minSpeed, min(TP7.maxSpeed, pow(2, roll / (.pi / 4))))
            let a = d.userAcceleration
            let g = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
            if g > 2.2 && Date().timeIntervalSince(self.lastShake) > 1.2 {
                self.lastShake = Date()
                self.shake()
            }
        }
    }

    private func stopMotion() {
        motion.stopDeviceMotionUpdates()
        pulse.motionSpeed = 1
    }

    private func shake() {
        switch shakeAction {
        case .tapeStop: tapeStop(seconds: 0.8)
        case .randomCue: if let p = randomPadPool.randomElement() { hitPad(p, fromUser: false) }
        case .nothing: break
        }
    }

    // MARK: ricezione

    private func received(_ m: [UInt8], _ stamp: MIDITimeStamp) {
        guard let status = m.first else { return }
        if status != 0xF8 { trace("ricevuto " + m.map { String(format: "%02x", $0) }.joined(separator: " ")) }
        if status == 0xF8 { clock(stamp); return }
        note(m, incoming: true)
        if status & 0xF0 == 0xB0, m.count >= 3 {
            if TP7.buttonNames[m[1]] != nil {
                if m[2] > 0 { live.pressed.insert(m[1]) } else { live.pressed.remove(m[1]) }
            } else if m[1] == TP7.ccWheel {
                live.wheelSteps += TP7.wheelDelta(m[2])
            }
        } else if status & 0xF0 == 0xE0, m.count >= 3 {
            live.rocker = (Int(m[2]) << 7 | Int(m[1])) - 8192
        }
    }

    private func clock(_ stamp: MIDITimeStamp) {
        clockStamps.append(stamp)
        if clockStamps.count > 49 { clockStamps.removeFirst() }
        if clockStamps.count > 12, let first = clockStamps.first, let last = clockStamps.last, last > first {
            let perTick = io.ms(ticks: last - first) / Double(clockStamps.count - 1)
            let value = (60_000 / (perTick * 24) * 10).rounded() / 10
            if clockBPM.map({ abs($0 - value) > 0.2 }) ?? true { clockBPM = value }
        }
        if followClock {
            if clockStamps.count == 1 {
                clockTicks = 0
                stepIndex = 0
                gateState = nil
            }
            if clockTicks % 6 == 0 {
                fire(stepIndex, at: io.now())
                stepIndex = (stepIndex + 1) % 16
            }
            clockTicks += 1
            if let c = clockBPM, abs(bpm - c) > 0.05 { bpm = max(40, min(240, c)) }
        }
        clockTimeout?.cancel()
        let w = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.clockStamps.removeAll()
            self.clockBPM = nil
            if self.followClock {
                self.releaseGate()
                self.restoreVolumes()
            }
        }
        clockTimeout = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: w)
    }

    // MARK: memoria dei pattern

    private struct Saved: Codable {
        var seq: [Int?]
        var gate: [Bool]
        var gateTracks: [Int]
    }

    private var loading = false

    private func save() {
        guard !loading else { return }
        let s = Saved(seq: seq, gate: gate, gateTracks: gateTracks.sorted())
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: "bobina.pattern")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: "bobina.pattern"),
              let s = try? JSONDecoder().decode(Saved.self, from: data),
              s.seq.count == 16, s.gate.count == 16 else { return }
        loading = true
        seq = s.seq
        gate = s.gate
        gateTracks = Set(s.gateTracks)
        loading = false
    }
}
