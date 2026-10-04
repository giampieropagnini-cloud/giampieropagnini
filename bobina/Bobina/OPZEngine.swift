import Foundation
import CoreMIDI
import SwiftUI

/// Quello che cambia a ogni battito (battuta e quarto, il pattern della canzone): sta a parte,
/// così si ridisegnano solo le caselle che lo mostrano e non la pagina col menu «passa a…».
final class OPZLive: ObservableObject {
    @Published var bar = 0
    @Published var quarter = 0
    /// La voce della canzone che suona adesso.
    @Published var songIndex: Int?
    /// Il passo di Crea che suona (0-15), -1 = Crea tace.
    @Published var step = -1
}

/// Il monitor a parte, come per i PO: le righe arrivano mentre il ritmo gira.
final class OPZLogBook: ObservableObject {
    @Published private(set) var lines: [LogLine] = []
    @Published var paused = false

    func add(_ line: LogLine) {
        guard !paused else { return }
        lines.insert(line, at: 0)
        if lines.count > 150 { lines.removeLast(lines.count - 150) }
    }

    func clear() { lines.removeAll() }
}

/// Il motore dell'OP-Z: parla all'OP-Z (bluetooth o cavo), ricorda com'è messo (l'OP-Z via MIDI
/// non lo dice) e passa il piano al sequencer, che sta sulla griglia di BobinaClock con TX-6 e PO.
final class OPZEngine: ObservableObject {

    let io = MIDIIO()
    let live = OPZLive()
    let logBook = OPZLogBook()
    private(set) lazy var sequencer = OPZSequencer(io: io)

    // MARK: collegamento

    @Published var destinations: [MIDIPort] = []
    @Published var sources: [MIDIPort] = []
    @Published var destinationID: MIDIUniqueID? {
        didSet {
            applyPorts()
            if let d = destinationID { UserDefaults.standard.set(Int(d), forKey: "bobina.opz.porta") }
        }
    }
    @Published var sourceID: MIDIUniqueID? { didSet { applyPorts() } }
    @Published private(set) var viaBluetooth = false

    var connected: Bool { io.destination != 0 }
    var connectedName: String { destinations.first(where: { $0.id == destinationID })?.name ?? "" }

    // MARK: tempo

    @Published var bpm: Double = BobinaClock.shared.bpm {
        didSet { if oldValue != bpm { BobinaClock.shared.setBPM(bpm) } }
    }
    @Published private(set) var running = false
    @Published var sync = OPZSync.clock { didSet { if oldValue != sync && running { toggleRun() }; save() } }
    @Published var clockAlways = false { didSet { save() } }
    @Published var leadMs = 0.0 { didSet { save() } }
    @Published var swing = 64 { didSet { save() } }
    /// Il tempo lo dà il TX-6: qui non si cambia.
    @Published private(set) var followingTX6 = false
    /// Suona qualcun altro sulla griglia: l'OP-Z entrerà alla battuta dopo.
    @Published private(set) var othersRunning = false

    // MARK: pattern

    @Published var project = 1 { didSet { save() } }
    /// Il pattern che Bobina ha chiesto per ultimo (l'OP-Z via MIDI non dice quale suona).
    @Published var pattern = 1
    /// Il pattern che aspetta l'inizio della battuta.
    @Published private(set) var queuedPattern: Int?
    /// I cambi (pattern, scene di muti) aspettano l'inizio della battuta. Da fermi partono subito.
    @Published var onTheBar = true { didSet { save() } }

    @Published var songOn = false { didSet { if !songOn { live.songIndex = nil } } }
    @Published var song: [Int] = [1, 1, 2, 3] { didSet { save() } }
    @Published var songBars = 4 { didSet { save() } }

    // MARK: muti

    /// true = la traccia tace. Quello che Bobina ha mandato: se si muta dall'OP-Z, qui non si vede.
    @Published private(set) var muted: [Bool] = Array(repeating: false, count: 16)
    /// Muto solo l'audio (CC 54): la traccia continua a mandare MIDI e a suonare dentro fx e tape.
    @Published var audioOnly = false { didSet { save() } }
    @Published private(set) var muteGroup: Int?
    /// Quattro scene di muti di Bobina, da richiamare con un tasto.
    @Published var scenes: [[Bool]?] = [nil, nil, nil, nil] { didSet { save() } }

    // MARK: suoni

    @Published var soundTrack = 1
    /// L'ultimo valore mandato per ogni traccia e parametro (64 = a metà, quando non si sa).
    @Published private(set) var values: [[Int]] = Array(repeating: Array(repeating: 64, count: 18), count: 16)
    /// Quanti passi usa ogni traccia (CC 60): con numeri diversi nascono i poliritmi.
    @Published private(set) var stepCount: [Int] = Array(repeating: 16, count: 16)

    // MARK: effetti

    /// Ottava alta: l'effetto punch-in agisce su tutte le tracce; bassa: sulla traccia attiva (da provare).
    @Published var punchHigh = false { didSet { save() } }
    /// Gli effetti tenuti adesso (0-11).
    @Published private(set) var punchHeld: Set<Int> = []

    // MARK: crea

    /// Bobina suona le tracce 1-8 a passi, col suo clock.
    @Published var createOn = false
    @Published var steps: [[[Int]]] = Array(repeating: Array(repeating: [], count: 16), count: 8) { didSet { save() } }
    /// Le tracce di Crea accese (quelle spente tacciono, i passi restano).
    @Published var trackOn: [Bool] = Array(repeating: true, count: 8) { didSet { save() } }
    /// La traccia che si sta scrivendo (1-8).
    @Published var createTrack = 1
    /// Il suono (batteria) o la nota (synth) che si mette nei passi: 53-76, la tastiera dell'OP-Z.
    @Published var pick = 53
    /// Sta suonando il giro solo per farlo registrare all'OP-Z.
    @Published private(set) var writing = false

    // MARK: interni

    private var timer: DispatchSourceTimer?
    private var bpmObserver: NSObjectProtocol?
    private var loading = false
    private var taps: [Date] = []

    init() {
        load()
        io.onSetupChanged = { [weak self] in self?.refreshPorts() }
        io.onReceive = { [weak self] bytes, stamp in self?.received(bytes, stamp) }
        sequencer.onBeat = { [weak self] bar, quarter, t in
            guard let self = self else { return }
            let delay = self.msUntil(t) / 1000
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.live.bar = bar
                self.live.quarter = quarter
                if quarter == 0, let q = self.queuedPattern {
                    self.pattern = q
                    self.queuedPattern = nil
                }
            }
        }
        sequencer.onSongPattern = { [weak self] idx, pat, t in
            guard let self = self else { return }
            let delay = self.msUntil(t) / 1000
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.live.songIndex = idx
                if self.pattern != pat { self.pattern = pat }
            }
        }
        sequencer.onStep = { [weak self] i, t in
            guard let self = self else { return }
            let delay = self.msUntil(t) / 1000
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if self.live.step != i { self.live.step = i }
            }
        }
        sequencer.onOnceDone = { [weak self] in
            DispatchQueue.main.async {
                self?.writing = false
                self?.logText("giro per l'OP-Z finito")
            }
        }
        sequencer.onSent = { [weak self] bytes in
            DispatchQueue.main.async { self?.note(bytes, incoming: false) }
        }
        bpmObserver = NotificationCenter.default.addObserver(forName: .bobinaBPM, object: nil, queue: .main) { [weak self] n in
            // il numero mostrato è intero: un bpm che tremola di qualche decimo non deve ridisegnare la pagina
            guard let self = self, let v = n.object as? Double, abs(self.bpm - v) >= 0.5 || self.bpm.rounded() != v.rounded() else { return }
            self.bpm = v
        }
        refreshPorts()
        startTimer()
    }

    // MARK: porte

    func refreshPorts() {
        destinations = io.destinations()
        sources = io.sources()
        trace("OP-Z · destinazioni: " + destinations.map { $0.name }.joined(separator: " · ") + " · sorgenti: " + sources.map { $0.name }.joined(separator: " · "))
        if destinationID == nil || !destinations.contains(where: { $0.id == destinationID }) {
            let saved = MIDIUniqueID(truncatingIfNeeded: UserDefaults.standard.integer(forKey: "bobina.opz.porta"))
            if saved != 0, destinations.contains(where: { $0.id == saved }) {
                destinationID = saved
            } else {
                destinationID = destinations.first(where: { $0.looksLikeOPZ })?.id
            }
        }
        // si ascolta la sorgente dello stesso apparecchio
        if let d = destinations.first(where: { $0.id == destinationID }), let s = POEngine.source(of: d.ref),
           let match = sources.first(where: { $0.ref == s }) {
            if sourceID != match.id { sourceID = match.id }
        } else if sourceID == nil || !sources.contains(where: { $0.id == sourceID }) {
            sourceID = sources.first(where: { $0.looksLikeOPZ })?.id
        }
        applyPorts()
    }

    private func applyPorts() {
        let dest = destinations.first(where: { $0.id == destinationID })?.ref ?? 0
        let src = sources.first(where: { $0.id == sourceID })?.ref ?? 0
        let n = connectedName.lowercased()
        viaBluetooth = n.contains("ble") || n.contains("bluetooth")
        if dest != io.destination || src != io.source {
            io.use(destination: dest, source: src)
            objectWillChange.send()
        }
    }

    // MARK: invio

    func send(_ bytes: [UInt8], at time: MIDITimeStamp = 0) {
        io.send(bytes, at: time)
        note(bytes, incoming: false)
        trace("→ OP-Z " + bytes.map { String(format: "%02x", $0) }.joined(separator: " "))
    }

    /// Alla battuta se il ritmo gira e «alla battuta» è acceso; se no subito.
    private func sendOnBar(_ bytes: [UInt8]) {
        if running && onTheBar && sequencer.atNextBar(bytes) {
            logText("alla battuta: " + describeAll(bytes))
        } else {
            send(bytes)
        }
    }

    private func ms(_ v: Double) -> MIDITimeStamp { io.now() + io.ticks(ms: v) }

    // MARK: play

    func toggleRun() {
        if running {
            running = false
            sequencer.stop()
            queuedPattern = nil
        } else {
            sequencer.update(makePlan())
            sequencer.start(at: ms(30))
            running = true
        }
    }

    /// Solo lo stop, anche se Bobina crede che l'OP-Z sia fermo (per esempio l'ha fatto partire Ele dalla macchina).
    func forceStop() {
        if running { toggleRun() } else { send(OPZ.stop) }
    }

    func tap() {
        let now = Date()
        taps = taps.filter { now.timeIntervalSince($0) < 2.5 } + [now]
        guard taps.count >= 2 else { return }
        let gaps = zip(taps.dropFirst(), taps).map { $0.timeIntervalSince($1) }
        setBPM((60 / (gaps.reduce(0, +) / Double(gaps.count))).rounded())
    }

    func setBPM(_ v: Double) {
        let range = sync == .own ? OPZ.tempoRange : 40...200
        bpm = max(range.lowerBound, min(range.upperBound, v))
        // da fermo l'OP-Z il tempo lo sa solo dal CC 56; mentre suona ci pensa il sequencer (col clock lo segue da sé)
        if !running { send(OPZ.tempo(min(OPZ.tempoRange.upperBound, bpm))) }
    }

    func setSwing(_ v: Int) {
        swing = max(0, min(127, v))
        send(OPZ.swing(swing))
    }

    // MARK: pattern

    func choosePattern(_ n: Int) {
        let n = max(1, min(16, n))
        if songOn { songOn = false }
        if running && onTheBar {
            queuedPattern = n
            sendOnBar(OPZ.pattern(n, project: project))
        } else {
            pattern = n
            send(OPZ.pattern(n, project: project))
        }
    }

    func stepPattern(_ delta: Int) {
        if songOn { songOn = false }
        let target = ((pattern - 1 + delta) % 16 + 16) % 16 + 1
        if running && onTheBar {
            queuedPattern = target
            sendOnBar(delta > 0 ? OPZ.nextPattern() : OPZ.previousPattern())
        } else {
            pattern = target
            send(delta > 0 ? OPZ.nextPattern() : OPZ.previousPattern())
        }
    }

    // MARK: muti

    func toggleMute(_ track: Int) {
        guard (1...16).contains(track) else { return }
        muted[track - 1].toggle()
        muteGroup = nil
        send(OPZ.mute(track, muted[track - 1], audioOnly: audioOnly))
    }

    /// Tutte le tracce suonano: sedici messaggi in un pacchetto solo.
    func unmuteAll() {
        muted = Array(repeating: false, count: 16)
        muteGroup = nil
        sendOnBar((1...16).flatMap { OPZ.mute($0, false, audioOnly: audioOnly) })
    }

    /// Solo la batteria, solo i synth…: le tracce scelte suonano, le altre di suono tacciono.
    func solo(_ tracks: ClosedRange<Int>) {
        var bytes: [UInt8] = []
        for t in 1...8 {
            let m = !tracks.contains(t)
            muted[t - 1] = m
            bytes += OPZ.mute(t, m, audioOnly: audioOnly)
        }
        muteGroup = nil
        sendOnBar(bytes)
    }

    func chooseMuteGroup(_ n: Int) {
        muteGroup = n
        sendOnBar(OPZ.muteGroup(n))
    }

    func saveScene(_ i: Int) {
        guard scenes.indices.contains(i) else { return }
        scenes[i] = muted
        logText("scena \(i + 1) salvata")
    }

    /// Richiama una scena: solo le tracce che cambiano, tutte in un pacchetto.
    func recallScene(_ i: Int) {
        guard scenes.indices.contains(i), let s = scenes[i] else { return }
        var bytes: [UInt8] = []
        for t in 0..<16 where s[t] != muted[t] { bytes += OPZ.mute(t + 1, s[t], audioOnly: audioOnly) }
        muted = s
        muteGroup = nil
        if !bytes.isEmpty { sendOnBar(bytes) }
    }

    // MARK: suoni

    func value(_ cc: Int, track: Int) -> Int { values[track - 1][cc - 1] }

    /// Valore assoluto (CC 1-18).
    func setValue(_ cc: Int, _ v: Int, track: Int) {
        let v = max(0, min(127, v))
        guard values[track - 1][cc - 1] != v else { return }
        values[track - 1][cc - 1] = v
        send(OPZ.cc(cc, v, channel: track))
    }

    /// Un passo su o giù coi CC relativi: l'OP-Z parte dal valore che ha davvero.
    func nudge(_ cc: Int, up: Bool, track: Int) {
        send(OPZ.cc(cc + 31, up ? 1 : 127, channel: track))
    }

    func setSteps(_ n: Int, track: Int) {
        let n = max(1, min(16, n))
        stepCount[track - 1] = n
        send(OPZ.cc(60, n, channel: track))
    }

    /// Un poliritmo pronto: kick 16, snare 12, perc 7… in un pacchetto.
    func polyrhythm(_ counts: [Int]) {
        var bytes: [UInt8] = []
        for (i, n) in counts.enumerated() where i < 16 {
            stepCount[i] = n
            bytes += OPZ.cc(60, n, channel: i + 1)
        }
        sendOnBar(bytes)
    }

    // MARK: crea

    func hasStep(_ i: Int) -> Bool { steps[createTrack - 1][i].contains(pick) }
    func anyStep(_ i: Int) -> Bool { !steps[createTrack - 1][i].isEmpty }

    /// Mette o toglie il suono scelto in un passo. Sul basso una nota per passo; sugli altri anche più insieme.
    func toggleStep(_ i: Int) {
        var cell = steps[createTrack - 1][i]
        if cell.contains(pick) {
            cell.removeAll { $0 == pick }
        } else if createTrack == 5 {
            cell = [pick]
        } else if cell.count < (createTrack == 8 ? 4 : 3) {
            cell.append(pick)
        }
        steps[createTrack - 1][i] = cell
    }

    /// Suona il suono scelto subito, per sentirlo prima di metterlo.
    func audition(_ note: Int) {
        pick = note
        send(OPZ.noteOn(note, channel: createTrack))
        io.send(OPZ.noteOff(note, channel: createTrack), at: ms(250))
    }

    func clearTrack() { steps[createTrack - 1] = Array(repeating: [], count: 16) }
    func clearAll() { steps = Array(repeating: Array(repeating: [], count: 16), count: 8) }

    /// Un ritmo pronto da cui partire: cassa in quattro, rullante sul 2 e sul 4, perc in levare.
    func starter() {
        var s = steps
        s[0] = (0..<16).map { $0 % 4 == 0 ? [53] : [] }
        s[1] = (0..<16).map { $0 == 4 || $0 == 12 ? [53] : [] }
        s[2] = (0..<16).map { $0 % 4 == 2 ? [53] : [] }
        steps = s
    }

    /// Un giro solo dei passi, dalla battuta dopo: con il record lock acceso sull'OP-Z (Ele: REC + PLAY)
    /// l'OP-Z dovrebbe scriverli nel suo pattern. Se l'OP-Z è fermo, prima lo fa partire.
    func writeOnce() {
        writing = true
        sequencer.playOnce()
        if !running { toggleRun() }
        logText("giro per l'OP-Z dalla battuta dopo")
    }

    // MARK: effetti punch-in (traccia 13)

    private func punchNote(_ i: Int) -> Int { OPZ.punchF + i + (punchHigh ? 12 : 0) }

    /// Metà di sopra del tasto: l'effetto per un momento.
    func punchTap(_ i: Int, length: Double = 500) {
        if punchHeld.contains(i) { punchRelease(i); return }
        let n = punchNote(i)
        send(OPZ.noteOn(n, channel: 13))
        io.send(OPZ.noteOff(n, channel: 13), at: ms(length))
    }

    /// Metà di sotto: l'effetto resta finché non lo ritocchi.
    func punchToggle(_ i: Int) {
        if punchHeld.contains(i) { punchRelease(i) } else {
            punchHeld.insert(i)
            send(OPZ.noteOn(punchNote(i), channel: 13))
        }
    }

    func punchRelease(_ i: Int) {
        guard punchHeld.contains(i) else { return }
        punchHeld.remove(i)
        send(OPZ.noteOff(OPZ.punchF + i, channel: 13) + OPZ.noteOff(OPZ.punchF + i + 12, channel: 13))
    }

    func punchReleaseAll() {
        guard !punchHeld.isEmpty else { return }
        let bytes = punchHeld.flatMap { OPZ.noteOff(OPZ.punchF + $0, channel: 13) + OPZ.noteOff(OPZ.punchF + $0 + 12, channel: 13) }
        punchHeld.removeAll()
        send(bytes)
    }

    // MARK: l'orologio della pagina

    private func makePlan() -> OPZSequencer.Plan {
        var p = OPZSequencer.Plan()
        p.sync = sync
        p.leadMs = leadMs
        p.clockAlways = clockAlways
        p.bpm = bpm
        p.project = project
        p.songOn = songOn
        p.song = song
        p.songBars = songBars
        p.createOn = createOn
        p.steps = steps
        p.trackOn = trackOn
        return p
    }

    private func startTimer() {
        let t = DispatchSource.makeTimerSource(flags: .strict, queue: .main)
        t.schedule(deadline: .now() + .milliseconds(50), repeating: .milliseconds(40), leeway: .milliseconds(5))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    private func tick() {
        sequencer.update(makePlan())
        let line = BobinaClock.shared.snapshot()
        let following = line.followedBy != nil
        if following != followingTX6 { followingTX6 = following }
        let others = line.running && !BobinaClock.shared.isMember(.opz)
        if others != othersRunning { othersRunning = others }
    }

    private func msUntil(_ t: MIDITimeStamp) -> Double {
        let now = io.now()
        return t > now ? io.ms(ticks: t - now) : 0
    }

    // MARK: ricezione

    /// L'OP-Z manda le note e le manopole delle sue tracce: qui si scrivono nel monitor.
    private func received(_ m: [UInt8], _ stamp: MIDITimeStamp) {
        guard let status = m.first, status != 0xF8, status != 0xFE else { return }
        note(m, incoming: true)
    }

    // MARK: monitor

    private func note(_ bytes: [UInt8], incoming: Bool) {
        guard !logBook.paused, !bytes.isEmpty else { return }
        let raw = bytes.prefix(12).map { String(format: "%02x", $0) }.joined(separator: " ")
        logBook.add(LogLine(incoming: incoming, text: describeAll(bytes), raw: raw))
    }

    private func describeAll(_ bytes: [UInt8]) -> String {
        var parts: [String] = []
        var i = 0
        while i < bytes.count {
            let len = bytes[i] == 0xF0 ? bytes.count - i : max(1, MIDIIO.length(of: bytes[i]))
            parts.append(OPZ.describe(Array(bytes[i..<min(bytes.count, i + len)])))
            i += len
        }
        if parts.count > 3 { return parts.prefix(2).joined(separator: " · ") + " · e altri \(parts.count - 2)" }
        return parts.joined(separator: " · ")
    }

    private func logText(_ text: String) {
        logBook.add(LogLine(incoming: false, text: text, raw: ""))
    }

    func clearLog() { logBook.clear() }

    // MARK: memoria

    private struct Saved: Codable {
        var sync: OPZSync
        var clockAlways: Bool
        var leadMs: Double
        var swing: Int
        var project: Int
        var onTheBar: Bool
        var song: [Int]
        var songBars: Int
        var audioOnly: Bool
        var scenes: [[Bool]?]
        var punchHigh: Bool
        var steps: [[[Int]]]?
        var trackOn: [Bool]?
    }

    private func save() {
        guard !loading else { return }
        let s = Saved(sync: sync, clockAlways: clockAlways, leadMs: leadMs, swing: swing, project: project,
                      onTheBar: onTheBar, song: song, songBars: songBars, audioOnly: audioOnly, scenes: scenes,
                      punchHigh: punchHigh, steps: steps, trackOn: trackOn)
        if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: "bobina.opz") }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: "bobina.opz"),
              let s = try? JSONDecoder().decode(Saved.self, from: data),
              s.scenes.count == 4, !s.song.isEmpty else { return }
        loading = true
        sync = s.sync
        clockAlways = s.clockAlways
        leadMs = s.leadMs
        swing = s.swing
        project = s.project
        onTheBar = s.onTheBar
        song = s.song
        songBars = s.songBars
        audioOnly = s.audioOnly
        scenes = s.scenes
        punchHigh = s.punchHigh
        if let st = s.steps, st.count == 8, st.allSatisfy({ $0.count == 16 }) { steps = st }
        if let on = s.trackOn, on.count == 8 { trackOn = on }
        loading = false
    }
}
