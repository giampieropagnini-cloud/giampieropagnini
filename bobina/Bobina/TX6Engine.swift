import Foundation
import CoreMIDI
import CoreMotion
import UIKit

extension MIDIPort {
    var looksLikeTX6: Bool {
        let n = name.lowercased()
        return n.contains("tx-6") || n.contains("tx6") || n.contains("tx–6")
    }
}

/// Una fotografia del mixer come lo ricorda Bobina.
struct TX6Scene: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var values: [[Int]]
    var mutes: [Bool]
    var master: [Int]
    var fxReturn: Int
}

/// Un'onda: muove un parametro delle tracce scelte intorno al valore che hai messo tu.
struct TX6Wave: Codable, Equatable {
    enum Shape: String, Codable, CaseIterable, Identifiable {
        case sine = "onda", triangle = "triangolo", ramp = "rampa", square = "quadra", random = "a caso"
        var id: String { rawValue }
    }
    var on = false
    var tracks: Set<Int> = [1]
    var param = TX6.Param.filter
    var shape = Shape.sine
    /// Un giro ogni tanti quarti.
    var beats: Double = 4
    /// Quanto si allontana dal valore, in passi MIDI.
    var depth: Double = 30
}

enum TX6Chord: String, CaseIterable, Identifiable {
    case single = "una nota", major = "maggiore", minor = "minore", sus = "sospeso", seventh = "settima"
    var id: String { rawValue }
    /// Sei voci, una per traccia.
    var intervals: [Int] {
        switch self {
        case .single: return [0]
        case .major: return [0, 4, 7, 12, 16, 19]
        case .minor: return [0, 3, 7, 12, 15, 19]
        case .sus: return [0, 5, 7, 12, 17, 19]
        case .seventh: return [0, 4, 7, 10, 12, 16]
        }
    }
}

enum TX6ClockMode: String, CaseIterable, Identifiable {
    case own = "tempo di Bobina"
    case send = "Bobina dà il tempo al TX-6"
    case follow = "segui il TX-6"
    var id: String { rawValue }
}

/// La sezione TX-6 di Bobina. Come per il TP-7: vive sul main thread, i passi a tempo partono
/// in anticipo con la marca temporale di CoreMIDI. Il TX-6 non racconta com'è messo:
/// tutto quello che Bobina sa è quello che gli ha mandato.
final class TX6Engine: ObservableObject {

    let io = MIDIIO()
    /// La sezione TP-7, per il ponte: il TX-6 in CTRL OUT comanda il TP-7.
    weak var tp7: Engine?

    // MARK: collegamento

    @Published var destinations: [MIDIPort] = []
    @Published var sources: [MIDIPort] = []
    @Published var destinationID: MIDIUniqueID? { didSet { applyPorts() } }
    @Published var sourceID: MIDIUniqueID? { didSet { applyPorts() } }
    @Published private(set) var log: [LogLine] = []
    @Published var logPaused = false

    var connected: Bool { io.destination != 0 }
    var connectedName: String {
        destinations.first(where: { $0.id == destinationID })?.name ?? "nessuno"
    }

    // MARK: il mixer come lo ricorda Bobina

    @Published private(set) var values: [[Int]] = Array(repeating: TX6.Param.allCases.map { $0.initial }, count: 6)
    @Published private(set) var mutes = Array(repeating: false, count: 6)
    /// main, aux, cue
    @Published private(set) var master = [100, 100, 100]
    @Published private(set) var localOff = false

    // MARK: effetti

    @Published private(set) var fxOn = [false, false]
    @Published private(set) var fxEngine: [Int?] = [nil, nil]
    @Published private(set) var fxParams = [[64, 64, 64], [64, 64, 64]]
    @Published private(set) var fxReturn = 100
    @Published private(set) var fx2Place: Int?

    // MARK: suonare

    @Published var keyTrack = 1
    @Published var octave = 4
    @Published var chord = TX6Chord.single
    /// L'ottava delle note do-la sul canale 7 (da misurare: la guida non la dice).
    @Published var padBase = 60
    @Published private(set) var heldKeys: Set<Int> = []
    @Published private(set) var flashPad: Int?

    // MARK: tempo

    @Published var bpm: Double = 120 { didSet { if oldValue != bpm { reanchor(oldBPM: oldValue) } } }
    @Published private(set) var running = false
    @Published private(set) var step = 0
    @Published var clockMode = TX6ClockMode.own { didSet { if oldValue != clockMode && running { toggleRun() } } }
    @Published private(set) var clockBPM: Double?

    var pulsing: Bool { running || (clockMode == .follow && clockBPM != nil) }

    // MARK: giochi a tempo

    @Published var beatsOn = false
    @Published var beats: [[Bool]] = Array(repeating: Array(repeating: false, count: 16), count: 6) { didSet { save() } }
    /// Passi con manopola: a ogni passo un valore diverso per un parametro di una traccia.
    @Published var lockOn = false { didSet { if !lockOn { restoreLock() } } }
    @Published var lockTrack = 1 { didSet { save() } }
    @Published var lockParam = TX6.Param.freq { didSet { save() } }
    @Published var locks: [Int?] = Array(repeating: nil, count: 16) { didSet { save() } }

    @Published var gateOn = false { didSet { if !gateOn { releaseGate() } } }
    @Published var gate: [Bool] = [true, false, true, false, true, true, false, true, true, false, true, false, true, true, false, false] { didSet { save() } }
    @Published var gateTracks: Set<Int> = [1] { didSet { save() } }

    @Published var pumpOn = false
    @Published var pumpDepth = 0.7
    @Published var pumpRelease = 0.6
    @Published var pumpTracks: Set<Int> = [1] { didSet { save() } }

    @Published var waves: [TX6Wave] = [TX6Wave(), TX6Wave(tracks: [2], param: .pan, shape: .triangle, beats: 8, depth: 40)] { didSet { save() } }

    @Published var driftOn = false { didSet { if !driftOn { resetDrift() } } }
    @Published var driftAmount = 0.5
    @Published var driftTracks: Set<Int> = [1, 2, 3]
    @Published var driftPan = false

    @Published var tiltOn = false { didSet { if tiltOn { startMotion() } else { stopMotion() } } }
    @Published var tiltParam = TX6.Param.filter
    @Published var tiltTracks: Set<Int> = [1]
    @Published private(set) var tilt = 0.0

    @Published var scenes: [TX6Scene] = [] { didSet { save() } }
    @Published var morphBars: Double = 2
    @Published private(set) var morphProgress: Double?

    // MARK: quello che arriva dal TX-6 in CTRL OUT

    @Published private(set) var faders: [Int?] = Array(repeating: nil, count: 6)
    @Published private(set) var knobs: [[Int?]] = Array(repeating: Array(repeating: nil, count: 6), count: 3)
    @Published private(set) var pressed: Set<String> = []
    @Published private(set) var encoderSteps = 0
    @Published private(set) var lastControl = "—"
    /// Il TX-6 comanda il TP-7: fader → volumi, tasti traccia → muti, FX I → play/stop.
    @Published var bridgeOn = false

    // MARK: interni

    private var timer: DispatchSourceTimer?
    private var lastTick: MIDITimeStamp = 0
    private var anchorTime: MIDITimeStamp = 0
    private var anchorBeat = 0.0
    private var nextSixteenth = 0
    private var nextClockTick = 0
    private var lastSent: [[Int?]] = Array(repeating: Array(repeating: nil, count: TX6.Param.allCases.count), count: 6)
    private var lastModAt: MIDITimeStamp = 0
    private var masterSent: [Int?] = [nil, nil, nil]
    private var gateState: Bool?
    private var driftLevels = Array(repeating: 1.0, count: 6)
    private var driftVelocity = Array(repeating: 0.0, count: 6)
    private var driftPanPos = Array(repeating: 0.0, count: 6)
    private var driftPanVel = Array(repeating: 0.0, count: 6)
    private var waveCycle = [-1, -1]
    private var waveRandom = [0.0, 0.0]
    private var morph: (from: TX6Scene, to: TX6Scene, start: MIDITimeStamp, length: Double)?
    private var clockStamps: [MIDITimeStamp] = []
    private var clockTimeout: DispatchWorkItem?
    private var clockCount = 0
    private var lastClockAt: MIDITimeStamp = 0
    private var held: [Int: [(track: Int, note: Int)]] = [:]
    private let motion = CMMotionManager()
    private let haptic = UIImpactFeedbackGenerator(style: .rigid)

    init() {
        load()
        io.onSetupChanged = { [weak self] in self?.refreshPorts() }
        io.onReceive = { [weak self] bytes, stamp in self?.received(bytes, stamp) }
        anchorTime = io.now()
        refreshPorts()
        startTimer()
    }

    // MARK: porte

    func refreshPorts() {
        destinations = io.destinations()
        sources = io.sources()
        if destinationID == nil || !destinations.contains(where: { $0.id == destinationID }) {
            destinationID = destinations.first(where: { $0.looksLikeTX6 })?.id
        }
        if sourceID == nil || !sources.contains(where: { $0.id == sourceID }) {
            sourceID = sources.first(where: { $0.looksLikeTX6 })?.id
        }
        applyPorts()
    }

    private func applyPorts() {
        let dest = destinations.first(where: { $0.id == destinationID })?.ref ?? 0
        let src = sources.first(where: { $0.id == sourceID })?.ref ?? 0
        if dest != io.destination || src != io.source {
            io.use(destination: dest, source: src)
            objectWillChange.send()
        }
    }

    // MARK: invio

    func send(_ bytes: [UInt8], at time: MIDITimeStamp = 0, quiet: Bool = false) {
        io.send(bytes, at: time)
        if !quiet { note(bytes, incoming: false) }
    }

    private func note(_ bytes: [UInt8], incoming: Bool) {
        guard !logPaused else { return }
        let raw = bytes.prefix(12).map { String(format: "%02x", $0) }.joined(separator: " ")
        log.insert(LogLine(incoming: incoming, text: TX6.describe(bytes, incoming: incoming), raw: raw), at: 0)
        if log.count > 150 { log.removeLast(log.count - 150) }
    }

    func clearLog() { log.removeAll() }

    // MARK: le tracce

    func value(_ track: Int, _ p: TX6.Param) -> Int { values[track - 1][p.rawValue] }

    /// Il valore scelto da te. Se un'onda o la pompa lo stanno muovendo, parte subito quello mosso.
    func set(_ track: Int, _ p: TX6.Param, _ v: Int) {
        let v = max(0, min(127, v))
        guard v != values[track - 1][p.rawValue] || lastSent[track - 1][p.rawValue] == nil else { return }
        values[track - 1][p.rawValue] = v
        sendParam(track, p, output(track, p, io.now()), quiet: false)
    }

    private func sendParam(_ track: Int, _ p: TX6.Param, _ v: Int, at time: MIDITimeStamp = 0, quiet: Bool) {
        send(TX6.cc(p.cc, v, channel: track), at: time, quiet: quiet)
        lastSent[track - 1][p.rawValue] = v
    }

    func toggleMute(_ track: Int) {
        mutes[track - 1].toggle()
        if !(gateOn && gateTracks.contains(track) && gateState == false) {
            send(TX6.cc(TX6.ccMute, mutes[track - 1] ? 127 : 0, channel: track))
        }
    }

    /// EQ piatto e filtro spento sulla traccia.
    func flatten(_ track: Int) {
        for p in [TX6.Param.eqHigh, .eqMid, .eqLow, .filter] { set(track, p, 64) }
    }

    // MARK: il generale

    func setMaster(_ i: Int, _ v: Int) {
        let v = max(0, min(127, v))
        master[i] = v
        sendMaster(i, v, quiet: false)
    }

    private func sendMaster(_ i: Int, _ v: Int, quiet: Bool) {
        send(TX6.cc([TX6.ccMain, TX6.ccAux, TX6.ccCue][i], v, channel: TX6.masterChannel), quiet: quiet)
        masterSent[i] = v
    }

    func toggleLocal() {
        localOff.toggle()
        send(TX6.cc(TX6.ccLocal, localOff ? 0 : 127, channel: TX6.masterChannel))
    }

    /// Start/stop del TX-6 (cc 46): un interruttore, il TX-6 non dice se sta suonando.
    func startStopTX6() { send(TX6.cc(TX6.ccStartStop, 127, channel: TX6.masterChannel)) }

    func nudgeTempo(_ delta: Int) { send(TX6.tempoStep(delta)) }

    func recallTX6Scene(_ i: Int) { send(TX6.scene(i)) }

    // MARK: effetti

    func toggleFx(_ i: Int) {
        fxOn[i].toggle()
        send(TX6.cc(TX6.ccFxOn, fxOn[i] ? 127 : 0, channel: TX6.fxChannels[i]))
    }

    func setFxEngine(_ i: Int, _ index: Int) {
        fxEngine[i] = index
        send(TX6.cc(TX6.ccFxEngine, TX6.spread(index, TX6.fxEngines[i].count), channel: TX6.fxChannels[i]))
    }

    func setFxParam(_ i: Int, _ k: Int, _ v: Int) {
        fxParams[i][k] = max(0, min(127, v))
        send(TX6.cc(TX6.ccFxParams[k], fxParams[i][k], channel: TX6.fxChannels[i]))
    }

    func setFxReturn(_ v: Int) {
        fxReturn = max(0, min(127, v))
        send(TX6.cc(TX6.ccFxReturn, fxReturn, channel: TX6.fxChannels[0]))
    }

    func setFx2Place(_ index: Int) {
        fx2Place = index
        send(TX6.cc(TX6.ccFx2Place, TX6.spread(index, TX6.fx2Places.count), channel: TX6.fxChannels[1]))
    }

    // MARK: suonare

    /// Un tasto della tastiera (0 = do dell'ottava scelta). Con un accordo suonano tutte e sei le tracce.
    func keyDown(_ k: Int) {
        guard held[k] == nil else { return }
        let root = 12 * (octave + 1) + k
        let list: [(track: Int, note: Int)] = chord == .single
            ? [(keyTrack, root)]
            : chord.intervals.enumerated().map { (track: $0.offset + 1, note: root + $0.element) }
        let playable = list.filter { $0.note <= 127 }
        held[k] = playable
        heldKeys.insert(k)
        for n in playable { send(TX6.noteOn(n.note, channel: n.track)) }
        haptic.impactOccurred()
    }

    func keyUp(_ k: Int) {
        guard let list = held.removeValue(forKey: k) else { return }
        heldKeys.remove(k)
        for n in list { send(TX6.noteOff(n.note, channel: n.track), quiet: true) }
    }

    /// Un pad: do re mi fa sol la sul canale 7, le tracce 1-6 alla loro frequenza.
    func hitPad(_ track: Int, at time: MIDITimeStamp = 0, fromUser: Bool = true) {
        let n = padBase + TX6.padSteps[track - 1]
        send(TX6.noteOn(n, channel: TX6.masterChannel), at: time, quiet: !fromUser)
        let off = (time == 0 ? io.now() : time) + io.ticks(ms: 40)
        send(TX6.noteOff(n, channel: TX6.masterChannel), at: off, quiet: true)
        if fromUser { haptic.impactOccurred() }
        let delay = time == 0 ? 0 : msUntil(time)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay / 1000) { [weak self] in
            self?.flashPad = track
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { [weak self] in
                if self?.flashPad == track { self?.flashPad = nil }
            }
        }
    }

    // MARK: scene di Bobina

    private func snapshot(_ name: String) -> TX6Scene {
        TX6Scene(name: name, values: values, mutes: mutes, master: master, fxReturn: fxReturn)
    }

    func saveScene() {
        var n = scenes.count + 1
        while scenes.contains(where: { $0.name == "scena \(n)" }) { n += 1 }
        scenes.append(snapshot("scena \(n)"))
    }

    func deleteScene(_ s: TX6Scene) { scenes.removeAll { $0.id == s.id } }

    /// Richiama una scena: di colpo, o sfumando in `morphBars` battute.
    func recall(_ s: TX6Scene, fade: Bool) {
        if fade {
            morph = (from: snapshot("da"), to: s, start: io.now(), length: max(0.25, morphBars) * 4 * beatMs)
            morphProgress = 0
            return
        }
        morph = nil
        morphProgress = nil
        apply(s, fraction: 1, force: true)
    }

    private func apply(_ s: TX6Scene, fraction p: Double, from: TX6Scene? = nil, force: Bool = false) {
        let a = from ?? s
        for t in 0..<6 {
            for param in TX6.Param.allCases {
                let x = Double(a.values[t][param.rawValue]), y = Double(s.values[t][param.rawValue])
                let v = param.continuous ? Int((x + (y - x) * p).rounded()) : (p >= 0.5 ? Int(y) : Int(x))
                values[t][param.rawValue] = v
                if force { sendParam(t + 1, param, output(t + 1, param, io.now()), quiet: true) }
            }
            let m = p >= 1 ? s.mutes[t] : a.mutes[t]
            if m != mutes[t] || force {
                mutes[t] = m
                send(TX6.cc(TX6.ccMute, m ? 127 : 0, channel: t + 1), quiet: true)
            }
        }
        for i in 0..<3 {
            let v = Int((Double(a.master[i]) + Double(s.master[i] - a.master[i]) * p).rounded())
            master[i] = v
            if force || masterSent[i] != v { sendMaster(i, v, quiet: true) }
        }
        let r = Int((Double(a.fxReturn) + Double(s.fxReturn - a.fxReturn) * p).rounded())
        if force || r != fxReturn {
            fxReturn = r
            send(TX6.cc(TX6.ccFxReturn, r, channel: TX6.fxChannels[0]), quiet: true)
        }
        if force { logText("scena «\(s.name)» mandata") }
    }

    private func logText(_ text: String) {
        guard !logPaused else { return }
        log.insert(LogLine(incoming: false, text: text, raw: ""), at: 0)
        if log.count > 150 { log.removeLast(log.count - 150) }
    }

    // MARK: tempo

    private var beatMs: Double { 60_000 / max(40, min(300, bpm)) }

    private var taps: [Date] = []
    func tap() {
        let now = Date()
        taps = taps.filter { now.timeIntervalSince($0) < 2.5 } + [now]
        guard taps.count >= 2 else { return }
        let gaps = zip(taps.dropFirst(), taps).map { $0.timeIntervalSince($1) }
        bpm = max(40, min(300, (60 / (gaps.reduce(0, +) / Double(gaps.count))).rounded()))
    }

    func toggleRun() {
        if running {
            running = false
            if clockMode == .send { send(TX6.stop) }
            releaseGate()
            restoreLock()
        } else {
            guard clockMode != .follow else { return }
            let start = io.now() + io.ticks(ms: 30)
            anchorTime = start
            anchorBeat = 0
            nextSixteenth = 0
            nextClockTick = 0
            gateState = nil
            if clockMode == .send { send(TX6.start, at: start) }
            running = true
        }
    }

    /// Quando cambia il bpm il battito continua da dove era, alla nuova velocità.
    private func reanchor(oldBPM: Double) {
        let now = io.now()
        anchorBeat = beat(at: now, bpm: oldBPM)
        anchorTime = now
    }

    private func beat(at t: MIDITimeStamp, bpm b: Double) -> Double {
        let ms = t >= anchorTime ? io.ms(ticks: t - anchorTime) : -io.ms(ticks: anchorTime - t)
        return anchorBeat + ms / (60_000 / max(40, min(300, b)))
    }

    private func time(ofBeat b: Double) -> MIDITimeStamp {
        anchorTime + io.ticks(ms: (b - anchorBeat) * beatMs)
    }

    /// Dove siamo nel battito: dal clock del TX-6 se lo seguiamo, altrimenti dal tempo di Bobina.
    private func beatNow(_ now: MIDITimeStamp) -> Double {
        if clockMode == .follow, clockBPM != nil, lastClockAt != 0 {
            let tickMs = beatMs / 24
            let frac = min(1, io.ms(ticks: now &- lastClockAt) / tickMs)
            return (Double(max(0, clockCount - 1)) + frac) / 24
        }
        return beat(at: now, bpm: bpm)
    }

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

        // i sedicesimi e il clock, preparati 60 ms prima
        if running && clockMode != .follow {
            let horizon = now + io.ticks(ms: 60)
            while time(ofBeat: Double(nextSixteenth) / 4) < horizon {
                fire(nextSixteenth % 16, at: max(now, time(ofBeat: Double(nextSixteenth) / 4)))
                nextSixteenth += 1
            }
            if clockMode == .send {
                while time(ofBeat: Double(nextClockTick) / 24) < horizon {
                    send(TX6.clock, at: max(now, time(ofBeat: Double(nextClockTick) / 24)), quiet: true)
                    nextClockTick += 1
                }
            }
        }

        driftUpdate(dt)

        if let m = morph {
            let p = min(1, io.ms(ticks: now &- m.start) / m.length)
            apply(m.to, fraction: p, from: m.from)
            morphProgress = p
            if p >= 1 { morph = nil; morphProgress = nil }
        }

        // le modulazioni continue: al massimo una volta ogni 30 ms, e solo se il valore cambia
        guard io.ms(ticks: now &- lastModAt) >= 30 else { return }
        lastModAt = now
        for t in 1...6 {
            for p in TX6.Param.allCases where p.continuous {
                if p == .volume && pumpOn && pulsing && pumpTracks.contains(t) { continue }
                if beatsOn && lockOn && pulsing && t == lockTrack && p == lockParam { continue }
                let out = output(t, p, now)
                let current = lastSent[t - 1][p.rawValue] ?? values[t - 1][p.rawValue]
                if out != current { sendParam(t, p, out, quiet: true) }
            }
        }
    }

    /// Il valore che deve avere adesso un parametro: il tuo, più onde, deriva e inclinazione.
    private func output(_ t: Int, _ p: TX6.Param, _ now: MIDITimeStamp) -> Int {
        var v = Double(values[t - 1][p.rawValue])
        guard p.continuous else { return Int(v) }
        if p == .volume && driftOn && driftTracks.contains(t) { v *= driftLevels[t - 1] }
        if p == .pan && driftOn && driftPan && driftTracks.contains(t) { v += driftPanPos[t - 1] * 50 * driftAmount }
        for (i, w) in waves.enumerated() where w.on && w.param == p && w.tracks.contains(t) {
            v += w.depth * waveValue(i, w, now)
        }
        if tiltOn && tiltParam == p && tiltTracks.contains(t) { v += tilt * 63 }
        return max(0, min(127, Int(v.rounded())))
    }

    private func waveValue(_ i: Int, _ w: TX6Wave, _ now: MIDITimeStamp) -> Double {
        let pos = beatNow(now) / max(0.25, w.beats)
        let ph = pos - pos.rounded(.down)
        switch w.shape {
        case .sine: return sin(ph * 2 * .pi)
        case .triangle: return ph < 0.5 ? ph * 4 - 1 : 3 - ph * 4
        case .ramp: return ph * 2 - 1
        case .square: return ph < 0.5 ? 1 : -1
        case .random:
            let cycle = Int(pos.rounded(.down))
            if cycle != waveCycle[i] { waveCycle[i] = cycle; waveRandom[i] = Double.random(in: -1...1) }
            return waveRandom[i]
        }
    }

    /// Una passeggiata a caso per ogni traccia: volume (e pan, se vuoi).
    private func driftUpdate(_ dt: Double) {
        guard driftOn else { return }
        for tr in driftTracks {
            let k = tr - 1
            driftVelocity[k] = max(-0.4, min(0.4, driftVelocity[k] + Double.random(in: -1...1) * dt * 0.8))
            driftLevels[k] = max(1 - driftAmount, min(1, driftLevels[k] + driftVelocity[k] * dt))
            if driftLevels[k] <= 1 - driftAmount || driftLevels[k] >= 1 { driftVelocity[k] = -driftVelocity[k] * 0.5 }
            driftPanVel[k] = max(-0.3, min(0.3, driftPanVel[k] + Double.random(in: -1...1) * dt * 0.6))
            driftPanPos[k] = max(-1, min(1, driftPanPos[k] + driftPanVel[k] * dt))
            if abs(driftPanPos[k]) >= 1 { driftPanVel[k] = -driftPanVel[k] * 0.5 }
        }
    }

    private func resetDrift() {
        driftLevels = Array(repeating: 1, count: 6)
        driftVelocity = Array(repeating: 0, count: 6)
        driftPanPos = Array(repeating: 0, count: 6)
        driftPanVel = Array(repeating: 0, count: 6)
    }

    /// Un sedicesimo: batteria a passi, passi con manopola, cancello, pompa.
    private func fire(_ i: Int, at t: MIDITimeStamp) {
        let delay = msUntil(t) / 1000
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.step = i }

        if beatsOn {
            if lockOn {
                let target = locks[i] ?? values[lockTrack - 1][lockParam.rawValue]
                if target != lastSent[lockTrack - 1][lockParam.rawValue] {
                    sendParam(lockTrack, lockParam, target, at: t, quiet: true)
                }
            }
            for tr in 1...6 where beats[tr - 1][i] {
                hitPad(tr, at: t + io.ticks(ms: 1), fromUser: false)
            }
        }

        if gateOn {
            let open = gate[i]
            if open != gateState {
                gateState = open
                for tr in gateTracks.sorted() {
                    send(TX6.cc(TX6.ccMute, open ? (mutes[tr - 1] ? 127 : 0) : 127, channel: tr), at: t, quiet: true)
                }
            }
        }

        if pumpOn && i % 4 == 0 {
            let points = 6
            for tr in pumpTracks.sorted() {
                let top = Double(values[tr - 1][TX6.Param.volume.rawValue]) * (driftOn && driftTracks.contains(tr) ? driftLevels[tr - 1] : 1)
                for k in 0...points {
                    let p = Double(k) / Double(points)
                    let v = Int((top * (1 - pumpDepth * (1 - p) * (1 - p))).rounded())
                    sendParam(tr, .volume, v, at: t + io.ticks(ms: beatMs * pumpRelease * p), quiet: true)
                }
            }
        }
    }

    private func releaseGate() {
        guard gateState != nil else { return }
        gateState = nil
        for tr in gateTracks.sorted() {
            send(TX6.cc(TX6.ccMute, mutes[tr - 1] ? 127 : 0, channel: tr), quiet: true)
        }
    }

    private func restoreLock() {
        let base = values[lockTrack - 1][lockParam.rawValue]
        if lastSent[lockTrack - 1][lockParam.rawValue] != nil && lastSent[lockTrack - 1][lockParam.rawValue] != base {
            sendParam(lockTrack, lockParam, base, quiet: true)
        }
    }

    // MARK: movimento

    private func startMotion() {
        guard motion.isDeviceMotionAvailable else { tiltOn = false; return }
        motion.deviceMotionUpdateInterval = 1.0 / 30
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let d = data else { return }
            // inclinato a destra apre, a sinistra chiude: 45° = tutta la corsa
            self.tilt = max(-1, min(1, d.attitude.roll / (.pi / 4)))
        }
    }

    private func stopMotion() {
        motion.stopDeviceMotionUpdates()
        tilt = 0
    }

    // MARK: ricezione

    private func received(_ m: [UInt8], _ stamp: MIDITimeStamp) {
        guard let status = m.first else { return }
        if status == 0xF8 { clock(stamp); return }
        trace("TX-6 manda " + m.map { String(format: "%02x", $0) }.joined(separator: " "))
        note(m, incoming: true)
        if status == 0xFA || status == 0xFB {
            clockCount = 0
            gateState = nil
            return
        }
        if status == 0xFC {
            if clockMode == .follow { releaseGate(); restoreLock() }
            return
        }
        guard status == 0xB0, m.count >= 3, let c = TX6.control(m[1]) else { return }
        let v = Int(m[2])
        switch c {
        case .fader(let t): faders[t - 1] = v
        case .knob(let r, let t): knobs[r - 1][t - 1] = v
        case .encoder: encoderSteps += TX6.relative(m[2])
        default:
            if v > 0 { pressed.insert(c.name) } else { pressed.remove(c.name) }
        }
        if c == .encoder {
            let d = TX6.relative(m[2])
            lastControl = "select girato \(d > 0 ? "+" : "")\(d)"
        } else if v > 0 || c.name.hasPrefix("fader") || c.name.hasPrefix("manopola") {
            lastControl = "\(c.name) · cc \(m[1]) = \(v)"
        }
        if bridgeOn { bridge(c, m[2]) }
    }

    /// Il TX-6 in CTRL OUT comanda la sezione TP-7 (che parla al TP-7, per esempio via bluetooth).
    private func bridge(_ c: TX6.Control, _ raw: UInt8) {
        guard let tp = tp7 else { return }
        let v = Int(raw)
        switch c {
        case .fader(let t): tp.setVolume(t, v)
        case .trackButton(let t): if v > 0 { tp.toggleMute(t) }
        case .fx1: if v > 0 { if tp.rolling { tp.stop() } else { tp.play() } }
        case .fx2: if v > 0 { tp.tapeStop(seconds: 0.8) }
        case .encoder: tp.speed = max(0.5, min(2, tp.speed + Double(TX6.relative(raw)) * 0.02))
        case .select: if v > 0 { tp.speed = 1 }
        default: break
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
        lastClockAt = stamp
        if clockMode == .follow {
            if clockCount % 6 == 0 { fire((clockCount / 6) % 16, at: io.now()) }
            if let c = clockBPM, abs(bpm - c) > 0.05 { bpm = max(40, min(300, c)) }
        }
        clockCount += 1
        clockTimeout?.cancel()
        let w = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.clockStamps.removeAll()
            self.clockBPM = nil
            self.lastClockAt = 0
            if self.clockMode == .follow { self.releaseGate(); self.restoreLock() }
        }
        clockTimeout = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: w)
    }

    // MARK: memoria

    private struct Saved: Codable {
        var beats: [[Bool]]
        var gate: [Bool]
        var gateTracks: [Int]
        var pumpTracks: [Int]
        var locks: [Int?]
        var lockTrack: Int
        var lockParam: TX6.Param
        var waves: [TX6Wave]
        var scenes: [TX6Scene]
    }

    private var loading = false

    private func save() {
        guard !loading else { return }
        let s = Saved(beats: beats, gate: gate, gateTracks: gateTracks.sorted(), pumpTracks: pumpTracks.sorted(),
                      locks: locks, lockTrack: lockTrack, lockParam: lockParam, waves: waves, scenes: scenes)
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: "bobina.tx6")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: "bobina.tx6"),
              let s = try? JSONDecoder().decode(Saved.self, from: data),
              s.beats.count == 6, s.gate.count == 16, s.locks.count == 16, s.waves.count == 2 else { return }
        loading = true
        beats = s.beats
        gate = s.gate
        gateTracks = Set(s.gateTracks)
        pumpTracks = Set(s.pumpTracks)
        locks = s.locks
        lockTrack = s.lockTrack
        lockParam = s.lockParam
        waves = s.waves
        scenes = s.scenes.filter { $0.values.count == 6 && $0.values.allSatisfy { $0.count == TX6.Param.allCases.count } }
        loading = false
    }
}
