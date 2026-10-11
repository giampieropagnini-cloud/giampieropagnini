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
    /// Il pattern di Crea che sta suonando (1-16).
    @Published var createPlaying = 1
    /// La voce della catena che suona (da 0), o nil.
    @Published var chainIndex: Int?
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
    /// La traccia attiva dell'OP-Z scelta da Bobina (nil = non ancora scelta: vale quella scelta sulla macchina).
    @Published private(set) var activeTrack: Int?

    /// Rende attiva sull'OP-Z una traccia: gli effetti punch-in «sulla traccia» lavorano su quella.
    func setActiveTrack(_ t: Int) {
        activeTrack = t
        // 8/10/2026: dopo un effetto sul kick, toccando snare l'OP-Z restava sul kick. Prima si lasciano tutti gli
        // effetti (anche quelli che Bobina crede già lasciati), poi la traccia nuova, un attimo dopo.
        punchHeld.removeAll()
        send((OPZ.punchF..<(OPZ.punchF + 24)).flatMap { OPZ.noteOff($0, channel: 13) })
        io.send(OPZ.activeTrack(t), at: ms(40))
        note(OPZ.activeTrack(t), incoming: false)
    }

    /// Prima di ogni effetto si ridice all'OP-Z la traccia attiva: se l'ha persa, l'effetto va comunque lì.
    private func punchPrefix() -> [UInt8] { activeTrack.map { OPZ.activeTrack($0) } ?? [] }
    /// Gli effetti tenuti adesso (0-11).
    @Published private(set) var punchHeld: Set<Int> = []

    // MARK: crea

    /// Bobina suona le tracce 1-8 a passi, col suo clock.
    @Published var createOn = false
    /// I 16 pattern di Crea, ognuno 8 tracce × 16 passi.
    @Published var patterns: [[[[Int]]]] = Array(repeating: OPZEngine.emptyPattern, count: 16) { didSet { save() } }
    static let emptyPattern: [[[Int]]] = Array(repeating: Array(repeating: [], count: 32), count: 8)
    /// Quanti passi ha ogni traccia di ogni pattern di Crea: lunghezze diverse = poliritmi.
    @Published var lengths: [[Int]] = Array(repeating: Array(repeating: 16, count: 8), count: 16) { didSet { save() } }
    static let lengthChoices = [4, 8, 12, 16, 24, 32]
    /// La catena di Crea: i pattern uno dopo l'altro, ognuno tot volte, e poi da capo (o fermi).
    @Published var chainOn = false { didSet { if chainOn { createOn = true } } }
    @Published var chain: [OPZChainStep] = [] { didSet { save() } }
    @Published var chainLoop = true { didSet { save() } }
    /// Quante volte ripetere il pattern che si aggiunge alla catena.
    @Published var chainTimes = 2

    /// I passi della traccia che si scrive.
    var length: Int {
        get { lengths[createPattern - 1][createTrack - 1] }
        set { lengths[createPattern - 1][createTrack - 1] = max(1, min(32, newValue)) }
    }

    /// Quanto dura una nota di ogni traccia, in passi; 0 = tenuta fino alla nota dopo.
    @Published var gates: [[Int]] = Array(repeating: [1, 1, 1, 1, 1, 1, 0, 0], count: 16) { didSet { save() } }

    /// La durata delle note della traccia che si scrive.
    var gate: Int {
        get { gates[createPattern - 1][createTrack - 1] }
        set { gates[createPattern - 1][createTrack - 1] = max(0, min(32, newValue)) }
    }

    /// Un giro del pattern: la traccia più lunga.
    var patternLength: Int { lengths[createPattern - 1].max() ?? 16 }

    /// La stessa lunghezza a tutte le tracce del pattern.
    func setAllLengths(_ l: Int) { lengths[createPattern - 1] = Array(repeating: max(1, min(32, l)), count: 8) }
    /// Il pattern di Crea che si scrive e che suonerà dalla battuta dopo (1-16).
    @Published var createPattern = 1
    /// Il pattern copiato, da incollare.
    @Published private(set) var copied: [[[Int]]]?
    private var copiedFx: [CreaFx?]?
    private var copiedAutom: [OPZLane]?
    private var copiedLength: [Int]?
    private var copiedGates: [Int]?

    /// I passi del pattern che si sta scrivendo.
    var steps: [[[Int]]] {
        get { patterns[createPattern - 1] }
        set { patterns[createPattern - 1] = newValue }
    }
    /// Le tracce di Crea accese (quelle spente tacciono, i passi restano).
    @Published var trackOn: [Bool] = Array(repeating: true, count: 8) { didSet { save() } }
    /// La traccia che si sta scrivendo (1-8).
    @Published var createTrack = 1
    /// Il suono (batteria) o la nota (synth) che si mette nei passi: 53-76, la tastiera dell'OP-Z.
    @Published var pick = 53
    /// Gli effetti di Bobina tenuti adesso (tasto «tieni», o «tocca» per una battuta).
    @Published private(set) var fxHeld: Set<CreaFx> = [] { didSet { sequencer.update(makePlan()) } }
    private var fxTapped: [CreaFx: Int] = [:]
    /// Gli effetti di Bobina lavorano su tutte le tracce, o solo su quella che scrivi.
    @Published var fxAll = true { didSet { save() } }
    /// Gli effetti scritti nei passi, per ognuno dei 16 pattern.
    @Published var fxSteps: [[CreaFx?]] = Array(repeating: Array(repeating: nil, count: 32), count: 16) { didSet { save() } }
    @Published var fxPick = CreaFx.rampUp
    @Published var fxEvery = 1 { didSet { save() } }
    /// Sta suonando il giro solo per farlo registrare all'OP-Z.
    @Published private(set) var writing = false
    /// La scrittura è finita: il record lock dell'OP-Z è ancora acceso (lo stop MIDI non lo spegne, misurato 7/10/2026).
    @Published var recordLockReminder = false

    // MARK: interni

    private var timer: DispatchSourceTimer?
    private var bpmObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?
    private var loading = false
    private var taps: [Date] = []

    init() {
        load()
        // fino al 4/10/2026 c'era un progetto solo: diventa il progetto 1
        if OPZEngine.loadProject(creaProject) == nil, let data = try? JSONEncoder().encode(snapshot()) {
            UserDefaults.standard.set(data, forKey: OPZEngine.projectKey(creaProject))
        }
        if let c = OPZEngine.loadProject(creaProject) { apply(c) }
        refreshProjectsUsed()
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
        sequencer.onCreatePattern = { [weak self] i, c, t in
            guard let self = self else { return }
            let delay = self.msUntil(t) / 1000
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if self.live.createPlaying != i + 1 { self.live.createPlaying = i + 1 }
                if self.live.chainIndex != c { self.live.chainIndex = c }
            }
        }
        sequencer.onHalted = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.running = false
                self.queuedPattern = nil
                self.logText("giro per l'OP-Z finito: fermo")
                self.recordLockReminder = true
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
        // in secondo piano (per esempio mentre Giampiero detta un messaggio) iOS sospende Bobina dopo pochi secondi:
        // prima si spengono le note tenute, comprese quelle tenute a mano
        backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            // con «resta sveglia» del Playdate Bobina continua a suonare dietro: Crea va avanti senza buchi e
            // i tasti tenuti restano giù (come PO e NTS-1)
            let d = UserDefaults.standard
            if d.bool(forKey: "bobina.playdate.sveglia") && d.bool(forKey: "bobina.playdate.tempo") { return }
            if self.running { self.sequencer.releaseForBackground() }
            if !self.liveHeld.isEmpty || !self.punchHeld.isEmpty {
                var bytes: [UInt8] = []
                for (t, notes) in self.liveHeld { for n in notes { bytes += OPZ.noteOff(n, channel: t) } }
                bytes += self.punchHeld.flatMap { OPZ.noteOff(OPZ.punchF + $0, channel: 13) + OPZ.noteOff(OPZ.punchF + $0 + 12, channel: 13) }
                self.liveHeld = [:]
                self.punchHeld.removeAll()
                self.io.send(bytes, at: self.ms(200))
            }
        }
        bpmObserver = NotificationCenter.default.addObserver(forName: .bobinaBPM, object: nil, queue: .main) { [weak self] n in
            // il numero mostrato è intero: un bpm che tremola di qualche decimo non deve ridisegnare la pagina
            guard let self = self, let v = n.object as? Double, abs(self.bpm - v) >= 0.5 || self.bpm.rounded() != v.rounded() else { return }
            self.bpm = v
            // il tempo cambiato da un'altra sezione arriva anche all'OP-Z
            self.sendTempo()
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
            let wasOff = io.destination == 0
            io.use(destination: dest, source: src)
            objectWillChange.send()
            // appena l'OP-Z si collega: silenzio, così una nota rimasta giù da prima non suona per sempre
            if wasOff && dest != 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.silence() }
            }
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
        // sempre anche il CC 56 (8/10/2026: «Crea e l'OP-Z vanno a due tempi diversi»): se l'OP-Z non segue il clock
        // (tasto 4 delle impostazioni MIDI spento) almeno il suo tempo è lo stesso. Oltre 127 il CC non arriva.
        sendTempo()
    }

    /// Il tempo di Bobina all'OP-Z col CC 56, solo quando cambia il numero intero.
    private var lastTempoSent: Int?
    private func sendTempo() {
        let v = Int(min(OPZ.tempoRange.upperBound, max(OPZ.tempoRange.lowerBound, bpm)).rounded())
        guard v != lastTempoSent, connected else { return }
        lastTempoSent = v
        send(OPZ.tempo(Double(v)))
    }

    // MARK: silenzio

    /// Spegne tutto quello che può essere rimasto acceso: le note di Crea e quelle tenute, gli effetti tenuti,
    /// e «tutte le note giù» (CC 123) sulle tracce che suonano. Le note-off sono solo quelle che Bobina usa,
    /// così il bluetooth non si intasa.
    func silence() {
        var bytes: [UInt8] = []
        // le note tenute a mano (tieni) prima di tutto: possono non essere in nessun pattern
        for (t, notes) in liveHeld { for n in notes { bytes += OPZ.noteOff(n, channel: t) } }
        punchHeld.removeAll()
        fxHeld = []
        liveHeld = [:]
        var perTrack: [[UInt8]] = []
        for t in 1...8 {
            var notes = Set<Int>()
            for pat in patterns { for cell in pat[t - 1] { notes.formUnion(cell) } }
            if t <= 4 { notes.insert(drumPick[t - 1]) }
            perTrack.append(notes.sorted().flatMap { OPZ.noteOff($0, channel: t) })
        }
        bytes += OPZ.allNotesOff()
        send(bytes)
        // il resto a pezzi, una traccia ogni 15 ms: tutto in un colpo intasava il bluetooth (lezione del TX-6, 8/10/2026)
        var pieces: [[UInt8]] = perTrack
        pieces.append((OPZ.punchF..<(OPZ.punchF + 24)).flatMap { OPZ.noteOff($0, channel: 13) })
        for (k, piece) in pieces.enumerated() where !piece.isEmpty {
            io.send(piece, at: ms(15 * Double(k + 1)))
        }
        logText("silenzio")
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
        // un guadagno non si mette mai a un valore assoluto (regola dell'8/10/2026)
        guard !OPZ.gainCCs.contains(cc) else { return }
        let v = max(0, min(127, v))
        // si manda sempre: Bobina non sa dov'è davvero la manopola (l'OP-Z può averla mossa)
        values[track - 1][cc - 1] = v
        send(OPZ.cc(cc, v, channel: track))
    }

    /// Lo slider di una manopola (per il QuadStick): il valore si vede subito, il CC parte al massimo ogni 30 ms
    /// (il bluetooth non si intasa) e l'ultimo valore parte sempre.
    private var slideLast: [Int: Date] = [:]
    private var slidePending: [Int: DispatchWorkItem] = [:]

    func slide(_ cc: Int, _ v: Int, track: Int) {
        let v = max(0, min(127, v))
        values[track - 1][cc - 1] = v
        let key = track * 128 + cc
        slidePending[key]?.cancel()
        let wait = 0.03 - Date().timeIntervalSince(slideLast[key] ?? .distantPast)
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.slideLast[key] = Date()
            self.slidePending[key] = nil
            self.io.send(OPZ.cc(cc, self.values[track - 1][cc - 1], channel: track))
        }
        slidePending[key] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, wait), execute: work)
    }

    /// Un passo su o giù coi CC relativi: l'OP-Z parte dal valore che ha davvero.
    /// Un passo relativo dell'OP-Z è minuscolo (6/10/2026: con un messaggio solo «non vedo cambiamenti»):
    /// ogni tocco ne manda 8, in un pacchetto solo.
    func nudge(_ cc: Int, up: Bool, track: Int) {
        send((0..<8).flatMap { _ in OPZ.cc(cc + 31, up ? 1 : 127, channel: track) })
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
        } else if cell.count < (createTrack >= 7 ? 4 : 3) {
            cell.append(pick)
        }
        steps[createTrack - 1][i] = cell
    }

    // MARK: crea in uno schermo (8/10/2026): batteria a griglia, note scritte col cursore

    /// Il passo dove va la prossima nota scritta (traccia melodica scelta).
    @Published var cursor = 0
    /// Cosa scrive un tocco sulla tastiera: una nota o un accordo intero.
    @Published var chordType = OPZChord.single
    /// L'ottava della tastiera delle note: 4 = il do centrale (60), dentro la tastiera dell'OP-Z (53-76).
    @Published var noteOctave = 4
    /// Cosa fa un tocco sulla tastiera: scrive nel passo del cursore, suona e basta, o tiene la nota.
    @Published var noteMode = OPZNoteMode.write
    /// Il suono di ogni riga della batteria (kick, snare, perc, sample): 53-76.
    @Published var drumPick: [Int] = [53, 53, 53, 53]

    /// Quante note insieme regge la traccia: il basso una, il lead tre, arp e accordi quattro.
    func polyphony(_ track: Int) -> Int { track == 5 ? 1 : track == 6 ? 3 : 4 }

    /// Un tocco sulla tastiera: la nota (o l'accordo) suona; in «scrivi» va nel passo del cursore e il cursore va avanti.
    func keyNote(_ semitone: Int) {
        let tr = max(5, createTrack)
        let root = 12 * (noteOctave + 1) + semitone
        let notes = Array(chordType.notes(root).prefix(polyphony(tr))).filter { $0 <= 127 }
        switch noteMode {
        case .hold:
            for n in notes { toggleLiveHold(n) }
            return
        case .play, .write:
            send(notes.flatMap { OPZ.noteOn($0, channel: tr) })
            io.send(notes.flatMap { OPZ.noteOff($0, channel: tr) }, at: ms(220))
        }
        guard noteMode == .write else { return }
        let len = lengths[createPattern - 1][tr - 1]
        if cursor >= len { cursor = 0 }
        steps[tr - 1][cursor] = notes
        pick = root
        cursor = (cursor + 1) % max(1, len)
    }

    /// Un passo vuoto, e il cursore va avanti.
    func writeRest() {
        let tr = max(5, createTrack)
        let len = lengths[createPattern - 1][tr - 1]
        if cursor >= len { cursor = 0 }
        steps[tr - 1][cursor] = []
        cursor = (cursor + 1) % max(1, len)
    }

    func cursorBack() {
        let len = lengths[createPattern - 1][max(5, createTrack) - 1]
        cursor = (cursor - 1 + max(1, len)) % max(1, len)
    }

    /// Batteria: accende o spegne il suono della riga in un passo.
    func toggleDrum(_ track: Int, _ i: Int) {
        let p = drumPick[track - 1]
        var cell = steps[track - 1][i]
        if cell.contains(p) { cell.removeAll { $0 == p } } else if cell.count < 3 { cell.append(p) }
        steps[track - 1][i] = cell
        createTrack = track
    }

    /// Svuota tutta la batteria (tracce 1-4) del pattern che scrivi.
    func clearDrums() {
        var st = steps
        for r in 0..<4 { st[r] = Array(repeating: [], count: 32) }
        steps = st
        logText("batteria svuotata")
    }

    /// Svuota tutte le melodie (tracce 5-8: bass, lead, arp, chord) del pattern che scrivi.
    func clearMelodies() {
        var st = steps
        for t in 4..<8 { st[t] = Array(repeating: [], count: 32) }
        steps = st
        cursor = 0
        logText("melodie svuotate")
    }

    /// Batteria: il suono di una riga (la senti subito).
    func setDrumPick(_ track: Int, _ note: Int) {
        drumPick[track - 1] = note
        createTrack = track
        auditionDrum(track)
    }

    func auditionDrum(_ track: Int) {
        let n = drumPick[track - 1]
        send(OPZ.noteOn(n, channel: track))
        io.send(OPZ.noteOff(n, channel: track), at: ms(200))
    }

    /// Batteria: riempie una riga in un tocco (ogni 4, ogni 2, in levare, tutti, niente).
    func fillDrum(_ track: Int, every: Int, offset: Int = 0) {
        let p = drumPick[track - 1]
        let len = lengths[createPattern - 1][track - 1]
        var row = steps[track - 1]
        for i in 0..<32 {
            if every == 0 { row[i] = [] } else if i < len { row[i] = i % every == offset ? [p] : [] }
        }
        steps[track - 1] = row
        createTrack = track
    }

    // MARK: sequenze pronte (OPZPresets.swift)

    /// Una sequenza pronta cambia anche il tempo di Bobina (di serie no).
    @Published var presetTempo = false
    /// L'ultima sequenza pronta caricata, per mostrarla accesa.
    @Published private(set) var presetName: String?
    @Published private(set) var canUndoPreset = false
    /// Il tempo del disco dell'ultima sequenza pronta caricata: «metti N bpm» lo mette con un tocco.
    @Published private(set) var presetBPM: Int?

    private struct PresetUndo {
        var steps: [[[Int]]]
        var lengths: [Int]
        var gates: [Int]
        var drumPick: [Int]
        var trackOn: [Bool]
        var arpOn: Bool
        var arpStyle: OPZArpStyle
        var arpRate: Int
        var arpOctaves: Int
        var bpm: Double
        var name: String?
    }
    private var presetUndo: PresetUndo?

    private func rememberForUndo() {
        presetUndo = PresetUndo(steps: steps, lengths: lengths[createPattern - 1], gates: gates[createPattern - 1],
                                drumPick: drumPick, trackOn: trackOn, arpOn: arpOn, arpStyle: arpStyle, arpRate: arpRate,
                                arpOctaves: arpOctaves, bpm: bpm, name: presetName)
        canUndoPreset = true
    }

    /// Una batteria pronta nelle tracce 1-4 del pattern che scrivi (le melodie restano).
    func loadDrums(_ p: OPZDrumPreset) {
        rememberForUndo()
        var st = steps
        var l = lengths[createPattern - 1]
        var g = gates[createPattern - 1]
        for r in 0..<4 {
            let row = p.steps(r)
            let note = OPZ.keyboardF + max(1, min(24, p.sounds[r])) - 1
            st[r] = (0..<32).map { i in i < row.count && row[i] ? [note] : [] }
            drumPick[r] = note
            l[r] = 16
            g[r] = 1
            trackOn[r] = true
        }
        steps = st
        lengths[createPattern - 1] = l
        gates[createPattern - 1] = g
        if presetTempo { setBPM(Double(p.bpm)) }
        presetName = p.name
        presetBPM = p.bpm
        logText("batteria pronta: \(p.name)")
    }

    /// Una melodia pronta nelle tracce 5-8 del pattern che scrivi (la batteria resta). Le tracce che la melodia
    /// non usa si svuotano, così non restano note vecchie in mezzo.
    func loadMelody(_ p: OPZMelodyPreset) {
        rememberForUndo()
        var st = steps
        var l = lengths[createPattern - 1]
        var g = gates[createPattern - 1]
        for t in 5...8 {
            let cells = p.steps(track: t)
            if cells.isEmpty {
                st[t - 1] = Array(repeating: [], count: 32)
                continue
            }
            st[t - 1] = (0..<32).map { i in i < cells.count ? Array(cells[i].prefix(polyphony(t))) : [] }
            l[t - 1] = max(1, min(32, cells.count))
            g[t - 1] = p.gates[t - 5]
            trackOn[t - 1] = true
        }
        steps = st
        lengths[createPattern - 1] = l
        gates[createPattern - 1] = g
        if !p.arp.isEmpty {
            arpStyle = p.arpStyle
            arpRate = p.arpRate
            arpOctaves = p.arpOctaves
            arpOn = true
        }
        if presetTempo { setBPM(Double(p.bpm)) }
        presetName = p.name
        presetBPM = p.bpm
        logText("melodia pronta: \(p.name)")
    }

    /// Rimette il pattern com'era prima dell'ultima sequenza pronta.
    func undoPreset() {
        guard let u = presetUndo else { return }
        steps = u.steps
        lengths[createPattern - 1] = u.lengths
        gates[createPattern - 1] = u.gates
        drumPick = u.drumPick
        trackOn = u.trackOn
        arpStyle = u.arpStyle
        arpRate = u.arpRate
        arpOctaves = u.arpOctaves
        arpOn = u.arpOn
        if presetTempo { setBPM(u.bpm) }
        presetName = u.name
        presetUndo = nil
        canUndoPreset = false
        logText("sequenza pronta annullata")
    }

    /// Le note tenute dal vivo, per traccia (1-8): restano giù finché non le lasci.
    @Published private(set) var liveHeld: [Int: Set<Int>] = [:]

    func isHeld(_ note: Int) -> Bool { liveHeld[createTrack]?.contains(note) ?? false }

    /// Metà di sotto del tasto nota: tieni / lascia. Sull'arp con l'arpeggio acceso le note tenute
    /// diventano l'accordo che Bobina arpeggia, a tempo (se il ritmo è fermo, parte).
    func toggleLiveHold(_ note: Int) {
        let tr = createTrack
        var set = liveHeld[tr] ?? []
        let arpLive = tr == 7 && arpOn
        if set.contains(note) {
            set.remove(note)
            if !arpLive { send(OPZ.noteOff(note, channel: tr)) }
        } else {
            set.insert(note)
            pick = note
            if arpLive {
                if !running { toggleRun() }
            } else {
                send(OPZ.noteOn(note, channel: tr))
            }
        }
        liveHeld[tr] = set.isEmpty ? nil : set
        sequencer.update(makePlan())
    }

    /// Lascia tutte le note tenute dal vivo.
    func releaseLiveAll() {
        var bytes: [UInt8] = []
        for (tr, notes) in liveHeld where !(tr == 7 && arpOn) {
            for n in notes { bytes += OPZ.noteOff(n, channel: tr) }
        }
        liveHeld = [:]
        if !bytes.isEmpty { send(bytes) }
        sequencer.update(makePlan())
    }

    /// Suona il suono scelto subito, per sentirlo prima di metterlo.
    func audition(_ note: Int) {
        pick = note
        send(OPZ.noteOn(note, channel: createTrack))
        io.send(OPZ.noteOff(note, channel: createTrack), at: ms(250))
    }

    // MARK: effetti di Bobina

    /// Metà di sopra: l'effetto per una battuta.
    func creaFxTap(_ f: CreaFx) {
        if fxHeld.contains(f) && fxTapped[f] == nil { fxHeld.remove(f); return }
        fxHeld.insert(f)
        let token = (fxTapped[f] ?? 0) + 1
        fxTapped[f] = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 4 * 60 / max(40, bpm)) { [weak self] in
            guard let self = self, self.fxTapped[f] == token else { return }
            self.fxTapped[f] = nil
            self.fxHeld.remove(f)
        }
    }

    /// Metà di sotto: resta finché non lo ritocchi.
    func creaFxToggle(_ f: CreaFx) {
        fxTapped[f] = nil
        if fxHeld.contains(f) { fxHeld.remove(f) } else { fxHeld.insert(f) }
    }

    func creaFxReleaseAll() {
        fxTapped = [:]
        fxHeld = []
    }

    /// Mette o toglie l'effetto scelto in un passo del pattern che scrivi.
    /// Quanti passi dura un effetto messo nei passi: un effetto in un passo solo spesso non fa in tempo a sentirsi.
    @Published var fxLength = 4 { didSet { save() } }

    /// Tocca un passo: l'effetto scelto parte lì e dura `fxLength` passi (gira oltre il 16 e ricomincia dall'1).
    /// Se il passo ha già quell'effetto, si toglie tutto il tratto di fila.
    func toggleFxStep(_ i: Int) {
        var row = fxSteps[createPattern - 1]
        if row[i] == fxPick {
            let f = fxPick
            var j = i
            let n = patternLength
            while row[j] == f { row[j] = nil; j = (j + 1) % n; if j == i { break } }
            j = (i + n - 1) % n
            while row[j] == f { row[j] = nil; j = (j + n - 1) % n; if j == i { break } }
        } else {
            let n = patternLength
            for k in 0..<max(1, min(n, fxLength)) { row[(i + k) % n] = fxPick }
        }
        fxSteps[createPattern - 1] = row
    }

    // MARK: automazione a passi

    @Published var autom: [[OPZLane]] = Array(repeating: OPZLane.empty, count: 16) { didSet { save() } }
    /// La riga che si scrive (0-3) e il livello che si mette nei passi (1-8).
    @Published var laneIndex = 0
    @Published var autoLevel = 8

    var lane: OPZLane {
        get { autom[createPattern - 1][laneIndex] }
        set { autom[createPattern - 1][laneIndex] = newValue }
    }

    func toggleAutoStep(_ i: Int) {
        var l = lane
        guard l.values.indices.contains(i) else { return }
        l.values[i] = l.values[i] == autoLevel ? nil : autoLevel
        lane = l
    }

    func clearLane() { lane.values = Array(repeating: nil, count: 32) }

    func clearFxSteps() { fxSteps[createPattern - 1] = Array(repeating: nil, count: 32) }

    // MARK: catena

    func chainAdd(_ pattern: Int) {
        guard chain.count < 64 else { return }
        chain.append(OPZChainStep(pattern: max(0, min(15, pattern - 1)), times: chainTimes))
    }

    func chainRemoveLast() { if !chain.isEmpty { chain.removeLast() } }
    func chainClear() { chain = []; chainOn = false }

    // MARK: mixer di Crea

    /// Volume di una traccia: 4 passi del CC relativo (CC 47) in un pacchetto solo.
    func volumeNudge(_ track: Int, up: Bool) {
        send((0..<4).flatMap { _ in OPZ.cc(16 + 31, up ? 1 : 127, channel: track) })
    }

    /// Un guadagno (il volume) si muove solo a passi piccoli: 2 passi relativi per tocco, mai un valore assoluto.
    func gainNudge(_ cc: Int, up: Bool, track: Int) {
        send((0..<2).flatMap { _ in OPZ.cc(cc + 31, up ? 1 : 127, channel: track) })
    }

    /// Solo questa traccia suona in Crea; ritoccata, suonano tutte.
    func soloCrea(_ track: Int) {
        let only = trackOn.enumerated().allSatisfy { $0.element == ($0.offset == track - 1) }
        trackOn = only ? Array(repeating: true, count: 8) : (0..<8).map { $0 == track - 1 }
    }

    // MARK: arpeggio (traccia 7, CC 9-12)

    /// L'arpeggio di Bobina: a tempo con la sua griglia. Acceso, spegne l'arpeggio dell'OP-Z (velocità a sinistra).
    @Published var arpOn = false {
        didSet {
            if arpOn && !oldValue && !loading { send(OPZ.cc(9, 0, channel: 7)) }
            save()
        }
    }
    @Published var arpStyle = OPZArpStyle.up { didSet { save() } }
    @Published var arpRate = 2 { didSet { save() } }
    @Published var arpOctaves = 1 { didSet { save() } }

    /// Le scelte dell'arpeggio fatte da Bobina (l'OP-Z non le dice): velocità, pattern, stile, estensione.
    @Published private(set) var arp: [Int?] = [nil, nil, nil, nil]
    static let arpChoices: [(cc: Int, name: String, labels: [String])] = [
        (9, "velocità", ["spento", "2", "3", "4", "5", "6", "7", "8"]),
        (10, "pattern", ["manual", "up", "down", "up/down", "down/up", "random"]),
        (11, "stile", ["1", "2", "3", "4", "5", "6"]),
        (12, "estensione", ["1", "2", "3", "4"]),
    ]

    /// Manda il centro della fetta scelta: le soglie vere non sono scritte da nessuna parte (da misurare).
    func setArp(_ row: Int, _ k: Int) {
        let c = OPZEngine.arpChoices[row]
        let v = Int((Double(k) + 0.5) * 128 / Double(c.labels.count))
        arp[row] = k
        send(OPZ.cc(c.cc, min(127, v), channel: 7))
    }

    // MARK: progetti di Crea

    /// Il progetto di Crea aperto (1-16): ognuno ha i suoi 16 pattern, la catena, le lunghezze, gli effetti nei passi e l'arpeggio.
    @Published private(set) var creaProject = max(1, min(16, UserDefaults.standard.integer(forKey: "bobina.opz.crea.progetto")))
    /// I progetti che hanno almeno una nota.
    @Published private(set) var projectsUsed: Set<Int> = []
    /// Il progetto copiato, da incollare.
    @Published private(set) var copiedProject: CreaProject?

    private static func projectKey(_ n: Int) -> String { "bobina.opz.crea.\(n)" }

    private func snapshot() -> CreaProject {
        CreaProject(patterns: patterns, lengths: lengths, gates: gates, fxSteps: fxSteps, autom: autom, chain: chain, chainLoop: chainLoop,
                    trackOn: trackOn, arpOn: arpOn, arpStyle: arpStyle, arpRate: arpRate, arpOctaves: arpOctaves,
                    fxEvery: fxEvery, fxLength: fxLength)
    }

    private func apply(_ c: CreaProject) {
        loading = true
        patterns = c.patterns
        lengths = c.lengths
        gates = c.gates
        fxSteps = c.fxSteps
        autom = c.autom ?? Array(repeating: OPZLane.empty, count: 16)
        chain = c.chain
        chainLoop = c.chainLoop
        trackOn = c.trackOn
        arpOn = c.arpOn
        arpStyle = c.arpStyle
        arpRate = c.arpRate
        arpOctaves = c.arpOctaves
        fxEvery = c.fxEvery
        fxLength = c.fxLength
        loading = false
    }

    private static func loadProject(_ n: Int) -> CreaProject? {
        guard let d = UserDefaults.standard.data(forKey: projectKey(n)) else { return nil }
        return try? JSONDecoder().decode(CreaProject.self, from: d)
    }

    private func refreshProjectsUsed() {
        projectsUsed = Set((1...16).filter { n in
            guard let c = OPZEngine.loadProject(n) else { return false }
            return c.patterns.contains { $0.contains { $0.contains { !$0.isEmpty } } }
        })
    }

    /// Apre un altro progetto. Quello di prima resta salvato com'è. Se il ritmo gira, continua col progetto nuovo.
    func openProject(_ n: Int) {
        let n = max(1, min(16, n))
        guard n != creaProject else { return }
        save()
        apply(OPZEngine.loadProject(n) ?? CreaProject())
        creaProject = n
        UserDefaults.standard.set(n, forKey: "bobina.opz.crea.progetto")
        createPattern = 1
        chainOn = false
        releaseLiveAll()
        save()
        refreshProjectsUsed()
        sequencer.update(makePlan())
        logText("progetto \(n) aperto")
    }

    func copyProject() {
        copiedProject = snapshot()
        logText("progetto \(creaProject) copiato")
    }

    func pasteProject() {
        guard let c = copiedProject else { return }
        apply(c)
        save()
        refreshProjectsUsed()
        logText("incollato nel progetto \(creaProject)")
    }

    /// Ricomincia da zero: tutti i pattern, le lunghezze, le durate, gli effetti nei passi e la catena di Crea.
    /// Non tocca l'OP-Z, le impostazioni di collegamento né le altre macchine.
    func resetCrea() {
        if running { toggleRun() }
        createOn = false
        chainOn = false
        chain = []
        patterns = Array(repeating: OPZEngine.emptyPattern, count: 16)
        lengths = Array(repeating: Array(repeating: 16, count: 8), count: 16)
        gates = Array(repeating: [1, 1, 1, 1, 1, 1, 0, 0], count: 16)
        fxSteps = Array(repeating: Array(repeating: nil, count: 32), count: 16)
        autom = Array(repeating: OPZLane.empty, count: 16)
        trackOn = Array(repeating: true, count: 8)
        fxHeld = []
        createPattern = 1
        createTrack = 1
        pick = OPZ.keyboardF
        copied = nil
        logText("Crea ricominciato da zero")
    }

    func copyPattern() {
        copied = steps
        copiedFx = fxSteps[createPattern - 1]
        copiedAutom = autom[createPattern - 1]
        copiedLength = lengths[createPattern - 1]
        copiedGates = gates[createPattern - 1]
        logText("pattern \(createPattern) copiato")
    }

    func pastePattern() {
        guard let c = copied else { return }
        steps = c
        if let f = copiedFx { fxSteps[createPattern - 1] = f }
        if let a = copiedAutom { autom[createPattern - 1] = a }
        if let l = copiedLength { lengths[createPattern - 1] = l }
        if let g = copiedGates { gates[createPattern - 1] = g }
        logText("incollato nel pattern \(createPattern)")
    }

    func hasNotes(pattern n: Int) -> Bool { patterns[n - 1].contains { $0.contains { !$0.isEmpty } } }

    func clearTrack() { steps[createTrack - 1] = Array(repeating: [], count: 32) }
    func clearAll() { steps = OPZEngine.emptyPattern }

    /// Un ritmo pronto da cui partire: cassa in quattro, rullante sul 2 e sul 4, perc in levare.
    func starter() {
        var s = steps
        s[0] = (0..<32).map { $0 % 4 == 0 ? [53] : [] }
        s[1] = (0..<32).map { $0 % 8 == 4 ? [53] : [] }
        s[2] = (0..<32).map { $0 % 4 == 2 ? [53] : [] }
        steps = s
    }

    /// Un giro solo dei passi, dalla battuta dopo: con il record lock acceso sull'OP-Z (Ele: REC + PLAY)
    /// l'OP-Z dovrebbe scriverli nel suo pattern. Se l'OP-Z è fermo, prima lo fa partire.
    /// Quante battute scrivere sull'OP-Z (1, 2, 4) e da quale suo pattern (1-16).
    @Published var writeBars = 1
    @Published var writeFirst = 1

    func writeOnce() {
        // il giro si ferma da solo solo se Crea non suona per conto suo
        createOn = false
        writing = true
        let first = min(writeFirst, 17 - writeBars)
        sequencer.playOnce(bars: writeBars, firstPattern: first)
        pattern = first
        if !running { toggleRun() }
        logText("giro per l'OP-Z dalla battuta dopo")
    }

    // MARK: effetti punch-in (traccia 13)

    private func punchNote(_ i: Int) -> Int { OPZ.punchF + i + (punchHigh ? 12 : 0) }

    /// Metà di sopra del tasto: l'effetto per un momento.
    func punchTap(_ i: Int, length: Double = 500) {
        if punchHeld.contains(i) { punchRelease(i); return }
        let n = punchNote(i)
        let pre = punchPrefix()
        if !pre.isEmpty { send(pre) }
        io.send(OPZ.noteOn(n, channel: 13), at: ms(pre.isEmpty ? 0 : 30))
        note(OPZ.noteOn(n, channel: 13), incoming: false)
        io.send(OPZ.noteOff(n, channel: 13), at: ms(length + 30))
    }

    /// Metà di sotto: l'effetto resta finché non lo ritocchi.
    func punchToggle(_ i: Int) {
        if punchHeld.contains(i) { punchRelease(i) } else {
            punchHeld.insert(i)
            let pre = punchPrefix()
            if !pre.isEmpty { send(pre) }
            io.send(OPZ.noteOn(punchNote(i), channel: 13), at: ms(pre.isEmpty ? 0 : 30))
            note(OPZ.noteOn(punchNote(i), channel: 13), incoming: false)
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
        p.patterns = patterns
        p.createPattern = createPattern - 1
        p.fxLive = fxHeld
        p.fxTrack = fxAll ? nil : createTrack
        p.fxSteps = fxSteps
        p.autom = autom
        p.lengths = lengths
        p.gates = gates
        p.arpOn = arpOn
        p.arpStyle = arpStyle
        p.arpRate = arpRate
        p.arpOctaves = arpOctaves
        p.liveArp = arpOn ? Array(liveHeld[7] ?? []) : []
        p.chainOn = chainOn
        p.chain = chain
        p.chainLoop = chainLoop
        p.fxEvery = fxEvery
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
        var patterns: [[[[Int]]]]?
        var fxSteps: [[CreaFx?]]?
        var fxAll: Bool?
        var fxEvery: Int?
        var fxLength: Int?
        var lengths: [Int]?
        var trackLengths: [[Int]]?
        var gates: [[Int]]?
        var arpOn: Bool?
        var arpStyle: OPZArpStyle?
        var arpRate: Int?
        var arpOctaves: Int?
        var chain: [OPZChainStep]?
        var chainLoop: Bool?
    }

    private func save() {
        guard !loading else { return }
        let s = Saved(sync: sync, clockAlways: clockAlways, leadMs: leadMs, swing: swing, project: project,
                      onTheBar: onTheBar, song: song, songBars: songBars, audioOnly: audioOnly, scenes: scenes,
                      punchHigh: punchHigh, steps: nil, trackOn: trackOn, patterns: patterns, fxSteps: fxSteps, fxAll: fxAll, fxEvery: fxEvery, fxLength: fxLength, lengths: nil, trackLengths: lengths, gates: gates, arpOn: arpOn, arpStyle: arpStyle, arpRate: arpRate, arpOctaves: arpOctaves, chain: chain, chainLoop: chainLoop)
        if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: "bobina.opz") }
        // il progetto di Crea aperto si salva anche nel suo posto
        if let data = try? JSONEncoder().encode(snapshot()) {
            UserDefaults.standard.set(data, forKey: OPZEngine.projectKey(creaProject))
        }
        let used = patterns.contains { $0.contains { $0.contains { !$0.isEmpty } } }
        if used != projectsUsed.contains(creaProject) {
            if used { projectsUsed.insert(creaProject) } else { projectsUsed.remove(creaProject) }
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: "bobina.opz"),
              let s = try? JSONDecoder().decode(Saved.self, from: data),
              s.scenes.count == 4 else { return }
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
        // fino al 4/10/2026 i pattern avevano 16 passi: si allungano a 32 con passi vuoti
        func pad(_ t: [[Int]]) -> [[Int]] { t.count >= 32 ? Array(t.prefix(32)) : t + Array(repeating: [], count: 32 - t.count) }
        if let ps = s.patterns, ps.count == 16, ps.allSatisfy({ $0.count == 8 }) {
            patterns = ps.map { $0.map(pad) }
        } else if let st = s.steps, st.count == 8 {
            patterns[0] = st.map(pad)   // i passi di prima della 4/10 diventano il pattern 1
        }
        if let on = s.trackOn, on.count == 8 { trackOn = on }
        if let f = s.fxSteps, f.count == 16 {
            fxSteps = f.map { $0.count >= 32 ? Array($0.prefix(32)) : $0 + Array(repeating: nil, count: 32 - $0.count) }
        }
        if let l = s.trackLengths, l.count == 16, l.allSatisfy({ $0.count == 8 }) {
            lengths = l
        } else if let l = s.lengths, l.count == 16 {
            lengths = l.map { Array(repeating: $0, count: 8) }   // prima del 4/10 sera: una lunghezza per pattern
        }
        if let g = s.gates, g.count == 16, g.allSatisfy({ $0.count == 8 }) { gates = g }
        if let c = s.chain { chain = c }
        if let a = s.arpOn { arpOn = a }
        if let a = s.arpStyle { arpStyle = a }
        if let a = s.arpRate { arpRate = a }
        if let a = s.arpOctaves { arpOctaves = a }
        if let c = s.chainLoop { chainLoop = c }
        if let a = s.fxAll { fxAll = a }
        if let e = s.fxEvery { fxEvery = e }
        if let l = s.fxLength { fxLength = l }
        loading = false
    }
}

/// Un progetto di Crea: tutto quello che serve per rifare la musica, salvato nel telefono.
struct CreaProject: Codable {
    var patterns: [[[[Int]]]] = Array(repeating: OPZEngine.emptyPattern, count: 16)
    var lengths: [[Int]] = Array(repeating: Array(repeating: 16, count: 8), count: 16)
    var gates: [[Int]] = Array(repeating: [1, 1, 1, 1, 1, 1, 0, 0], count: 16)
    var fxSteps: [[CreaFx?]] = Array(repeating: Array(repeating: nil, count: 32), count: 16)
    /// Facoltativo: i progetti salvati prima del 7/10/2026 non ce l'hanno (senza «?» non si aprirebbero più).
    var autom: [[OPZLane]]? = Array(repeating: OPZLane.empty, count: 16)
    var chain: [OPZChainStep] = []
    var chainLoop = true
    var trackOn: [Bool] = Array(repeating: true, count: 8)
    var arpOn = false
    var arpStyle = OPZArpStyle.up
    var arpRate = 2
    var arpOctaves = 1
    var fxEvery = 1
    var fxLength = 4
}

/// Cosa scrive un tocco sulla tastiera delle note di Crea.
enum OPZChord: String, CaseIterable, Identifiable {
    case single = "nota", major = "maggiore", minor = "minore", seventh = "settima", minor7 = "min 7", sus4 = "sus4", fifth = "quinta", octave = "ottava"

    var id: String { rawValue }

    func notes(_ root: Int) -> [Int] {
        let iv: [Int]
        switch self {
        case .single: iv = [0]
        case .major: iv = [0, 4, 7]
        case .minor: iv = [0, 3, 7]
        case .seventh: iv = [0, 4, 7, 10]
        case .minor7: iv = [0, 3, 7, 10]
        case .sus4: iv = [0, 5, 7]
        case .fifth: iv = [0, 7]
        case .octave: iv = [0, 12]
        }
        return iv.map { root + $0 }
    }
}

/// Cosa fa un tocco sulla tastiera: scrive nel passo del cursore, suona soltanto, o tiene la nota (sull'arp: l'arpeggio).
enum OPZNoteMode: String, CaseIterable, Identifiable {
    case write = "scrivi", play = "suona", hold = "tieni"
    var id: String { rawValue }
}
