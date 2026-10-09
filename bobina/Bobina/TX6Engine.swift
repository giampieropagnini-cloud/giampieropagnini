import Foundation
import CoreMIDI
import CoreMotion
import UIKit
import QuartzCore

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

/// Un pattern: batteria, melodie, passi con manopola, cancello, i suoni delle sei tracce e il tempo.
struct TX6Pattern: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var beats: [[Bool]]
    var melodies: [[Int?]]
    var melodyOctaves: [Int]
    var melodyLength: Int
    var locks: [Int?]
    var lockTrack: Int
    var lockParam: TX6.Param
    var gate: [Bool]
    /// Per ogni traccia: suono, frequenza, lunghezza, detune (valori MIDI).
    var sounds: [[Int]]
    var bpm: Double
    /// Lo swing (0,5 dritto … 0,66 terzina); nei pattern salvati prima non c'è.
    var swing: Double? = nil

    /// I parametri di suono che un pattern si porta dietro, in quest'ordine.
    static let soundParams: [TX6.Param] = [.sound, .freq, .length, .detune]

    /// Gli stili pronti. Tracce: 1 cassa, 2 rullante, 3 battimani, 4 charleston, 5 basso, 6 melodia.
    static let styles: [TX6Pattern] = [
        style("house", bpm: 124, kick: [0, 4, 8, 12], clap: [4, 12], hat: [2, 6, 10, 14],
              bass: [(2, 9), (6, 9), (10, 9), (14, 7)], lead: [(0, 12), (8, 7)], length: 1),
        style("techno", bpm: 130, kick: [0, 4, 8, 12], clap: [4, 12], hat: [0, 2, 4, 6, 8, 10, 12, 14],
              bass: [1, 2, 3, 5, 6, 7, 9, 10, 11, 13, 14, 15].map { ($0, 0) }, length: 1),
        style("hip hop", bpm: 90, kick: [0, 7, 10], snare: [4, 12], hat: [0, 2, 4, 6, 8, 10, 12, 14],
              bass: [(0, 0), (7, 0), (10, 3)], lead: [(0, 7), (4, 3), (8, 5), (12, 3)], length: 2),
        style("reggaeton", bpm: 95, kick: [0, 4, 8, 12], snare: [3, 6, 11, 14], hat: [0, 2, 4, 6, 8, 10, 12, 14],
              bass: [(0, 0), (4, 0), (8, 5), (12, 7)], length: 1),
        style("drum'n'bass", bpm: 172, kick: [0, 10], snare: [4, 12], hat: [0, 2, 4, 6, 8, 10, 12, 14],
              bass: [(0, 4), (10, 4)], length: 4),
        style("electro", bpm: 128, kick: [0, 6, 10], snare: [4, 12], hat: [2, 6, 10, 14],
              bass: [(0, 0), (3, 0), (6, 3), (10, 5), (13, 3)], length: 1),
        style("ambient", bpm: 80, hat: [0, 8], bass: [(0, 0), (8, 5)], lead: [(0, 0), (4, 4), (8, 7), (12, 11)],
              length: 4, bassSound: 0, leadSound: 1)
    ]

    private static func style(_ name: String, bpm: Double, kick: [Int] = [], snare: [Int] = [], clap: [Int] = [], hat: [Int] = [],
                              bass: [(Int, Int)] = [], lead: [(Int, Int)] = [], length: Int,
                              bassSound: Int = 2, leadSound: Int = 3) -> TX6Pattern {
        func row(_ steps: [Int]) -> [Bool] { (0..<16).map { steps.contains($0) } }
        func line(_ notes: [(Int, Int)]) -> [Int?] {
            var r = [Int?](repeating: nil, count: 16)
            for (step, semi) in notes { r[step] = semi }
            return r
        }
        let empty = [Bool](repeating: false, count: 16)
        let silent = [Int?](repeating: nil, count: 16)
        let sounds = [4, 5, 6, 7, bassSound, leadSound].map { [TX6.soundValue($0), 64, 64, 64] }
        return TX6Pattern(name: name,
                          beats: [row(kick), row(snare), row(clap), row(hat), empty, empty],
                          melodies: [silent, silent, silent, silent, line(bass), line(lead)],
                          melodyOctaves: [4, 4, 4, 4, 2, 4],
                          melodyLength: length,
                          locks: Array(repeating: nil, count: 16), lockTrack: 1, lockParam: .freq,
                          gate: Array(repeating: true, count: 16),
                          sounds: sounds, bpm: bpm)
    }
}

/// Un preset per una traccia: il suono e le sue manopole (frequenza, lunghezza, detune, filtro, compressore).
/// I valori sono numeri MIDI 0-127: come il TX-6 li traduce in note e millisecondi è ancora da misurare,
/// quindi i preset pronti sono un punto di partenza da ritoccare a orecchio.
struct TX6Preset: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var group: String
    var sound: Int
    var freq: Int
    var length: Int
    var detune: Int
    var filter: Int
    var comp: Int

    static let params: [TX6.Param] = [.freq, .length, .detune, .filter, .comp]

    static let groups = ["cassa", "rullante", "battimani", "charleston", "percussioni", "basso", "melodia", "tappeti"]

    private static func p(_ g: String, _ n: String, _ sound: Int, freq: Int, len: Int, det: Int = 64, flt: Int = 64, comp: Int = 0) -> TX6Preset {
        TX6Preset(name: n, group: g, sound: sound, freq: freq, length: len, detune: det, filter: flt, comp: comp)
    }

    /// Suoni: 0 SIN · 1 TRI · 2 SQR · 3 SAW · 4 KICK · 5 SNARE · 6 CLAP · 7 HIHAT.
    static let builtIn: [TX6Preset] = [
        p("cassa", "cassa house", 4, freq: 40, len: 60, comp: 50),
        p("cassa", "cassa corta", 4, freq: 48, len: 30, comp: 70),
        p("cassa", "808 lunga", 4, freq: 28, len: 110, comp: 30),
        p("cassa", "cassa techno", 4, freq: 36, len: 75, flt: 52, comp: 90),
        p("cassa", "cassa sorda", 4, freq: 32, len: 45, flt: 40),
        p("cassa", "cassa lontana", 4, freq: 26, len: 100, flt: 36),
        p("cassa", "battito", 4, freq: 22, len: 25, flt: 40),
        // per le batterie pronte (8/10/2026): accordate a ogni genere, da ritoccare a orecchio sul TX-6
        p("cassa", "cassa trip hop", 4, freq: 30, len: 70, flt: 46, comp: 30),
        p("cassa", "cassa boom bap", 4, freq: 44, len: 45, comp: 90),
        p("cassa", "cassa g-funk", 4, freq: 34, len: 70, comp: 60),
        p("cassa", "cassa 909", 4, freq: 40, len: 62, comp: 80),
        p("rullante", "rullante secco", 5, freq: 64, len: 35, comp: 40),
        p("rullante", "rullante pieno", 5, freq: 54, len: 70, comp: 60),
        p("rullante", "rimshot", 5, freq: 96, len: 15),
        p("rullante", "rullante scuro", 5, freq: 44, len: 55, flt: 48),
        p("rullante", "rullante lontano", 5, freq: 40, len: 100, flt: 40),
        p("rullante", "frusta", 5, freq: 110, len: 10),
        p("rullante", "rullante trip hop", 5, freq: 46, len: 75, flt: 48, comp: 40),
        p("rullante", "rullante boom bap", 5, freq: 58, len: 50, comp: 70),
        // il rullante di N.Y. State of Mind: accordato basso e smorzato, «quasi un tom»
        p("rullante", "rullante sordo", 5, freq: 40, len: 40, flt: 44, comp: 30),
        // le note fantasma: corte e scure, così si sentono piano anche senza velocity
        p("rullante", "fantasma", 5, freq: 70, len: 6, flt: 38),
        p("battimani", "battimani", 6, freq: 64, len: 50),
        p("battimani", "battimani lunghi", 6, freq: 58, len: 95),
        p("battimani", "schiocco", 6, freq: 90, len: 20, flt: 76),
        p("charleston", "chiuso", 7, freq: 80, len: 15),
        p("charleston", "aperto", 7, freq: 76, len: 80),
        p("charleston", "shaker", 7, freq: 100, len: 30, flt: 84),
        p("charleston", "piatto", 7, freq: 60, len: 120),
        p("charleston", "fruscio", 7, freq: 110, len: 50, flt: 90),
        p("charleston", "charleston polvere", 7, freq: 72, len: 12, flt: 46),
        p("charleston", "charleston secco", 7, freq: 86, len: 10),
        p("charleston", "chiuso 909", 7, freq: 84, len: 14),
        p("charleston", "aperto 909", 7, freq: 78, len: 70),
        p("charleston", "aperto morbido", 7, freq: 70, len: 60, flt: 50),
        p("charleston", "tamburello", 7, freq: 104, len: 20, flt: 80),
        p("charleston", "ride", 7, freq: 92, len: 45),
        p("percussioni", "tom basso", 0, freq: 36, len: 50),
        p("percussioni", "tom alto", 0, freq: 52, len: 40),
        p("percussioni", "cowbell", 2, freq: 78, len: 25, det: 72),
        p("percussioni", "blip", 1, freq: 96, len: 10),
        p("percussioni", "conga", 1, freq: 58, len: 35, det: 60),
        // la cassa alta suona come un tamburo grande: da film
        p("percussioni", "taiko", 4, freq: 60, len: 90, comp: 60),
        p("percussioni", "metallo", 7, freq: 30, len: 100, flt: 50),
        p("percussioni", "legno", 1, freq: 90, len: 8),
        p("basso", "sub", 0, freq: 24, len: 80),
        p("basso", "basso quadro", 2, freq: 30, len: 60, flt: 50),
        p("basso", "acid", 3, freq: 32, len: 40, det: 70, flt: 40, comp: 40),
        p("basso", "basso pieno", 3, freq: 28, len: 90, det: 76, flt: 46),
        p("melodia", "flauto", 1, freq: 72, len: 70),
        p("melodia", "lead quadro", 2, freq: 76, len: 60, det: 70),
        p("melodia", "lead sega", 3, freq: 80, len: 55, det: 74, flt: 72),
        p("melodia", "pluck", 3, freq: 72, len: 20, flt: 58),
        p("tappeti", "drone dolce", 0, freq: 48, len: 127, det: 70),
        p("tappeti", "tappeto largo", 3, freq: 60, len: 127, det: 88, flt: 44),
        p("tappeti", "organo", 2, freq: 60, len: 127, det: 66),
    ]
}

/// Una melodia pronta: una linea su una traccia, o un accordo su tre tracce (la scelta e le due dopo).
/// Le note sono semitoni sopra il do dell'ottava della traccia (0 = do … 12 = do sopra), come nella melodia a passi.
struct TX6MelodyPreset: Identifiable {
    var id: String { name }
    let name: String
    /// «bassi», «melodie» o «accordi».
    let group: String
    let chord: Bool
    let voices: [[Int?]]
    let octaves: [Int]
    /// Quanti sedicesimi dura ogni nota (vale per tutte le melodie).
    let length: Int
    /// Il preset di suono da mettere sulle tracce usate.
    let sound: String

    static let groups = ["bassi", "melodie", "accordi"]

    private static func line(_ notes: [(Int, Int)]) -> [Int?] {
        var r = [Int?](repeating: nil, count: 16)
        for (step, semi) in notes { r[step] = semi }
        return r
    }

    private static func lineP(_ name: String, _ group: String, oct: Int, len: Int, sound: String, _ notes: [(Int, Int)]) -> TX6MelodyPreset {
        TX6MelodyPreset(name: name, group: group, chord: false, voices: [line(notes)], octaves: [oct], length: len, sound: sound)
    }

    /// Sedici note di fila, una per passo.
    private static func run(_ notes: [Int]) -> [(Int, Int)] { Array(zip(0..<16, notes)) }

    /// Accordi di quattro quarti: per ogni quarto le tre note (basso, medio, alto).
    private static func chords(_ name: String, octaves: [Int] = [2, 3, 4], sound: String = "tappeto largo", _ seq: [(Int, Int, Int)]) -> TX6MelodyPreset {
        let steps = [0, 4, 8, 12]
        let voices = (0..<3).map { v in line(seq.enumerated().map { (steps[$0.offset], [$0.element.0, $0.element.1, $0.element.2][v]) }) }
        return TX6MelodyPreset(name: name, group: "accordi", chord: true, voices: voices, octaves: octaves, length: 4, sound: sound)
    }

    /// Venti melodie scure da film, semplici e fatte per stare insieme (rifatte l'8/10/2026, Giampiero: «dark
    /// cinematico, non cose strane, che si possano agganciare»). Tutte in do minore e quasi tutte sullo stesso
    /// giro, un accordo per quarto: do minore · la bemolle · fa minore · sol (0 3 7 · 8 0 3 · 5 8 0 · 7 11 2).
    /// Basso, accordi e melodia si possono suonare insieme; e ognuna finisce sul sol, che porta al do della
    /// battuta dopo: messe una dopo l'altra si legano.
    static let all: [TX6MelodyPreset] = [
        // bassi, sulle radici del giro
        lineP("pulsazione", "bassi", oct: 2, len: 1, sound: "basso pieno",
              [(0, 0), (2, 0), (4, 8), (6, 8), (8, 5), (10, 5), (12, 7), (14, 7)]),
        lineP("radici", "bassi", oct: 1, len: 4, sound: "sub",
              [(0, 0), (4, 8), (8, 5), (12, 7)]),
        lineP("quinte", "bassi", oct: 2, len: 1, sound: "basso quadro",
              [(0, 0), (2, 7), (4, 8), (6, 3), (8, 5), (10, 0), (12, 7), (14, 2)]),
        // il galoppo dei film d'azione: lungo-corto-corto su ogni radice
        lineP("galoppo", "bassi", oct: 2, len: 1, sound: "basso pieno",
              [(0, 0), (2, 0), (3, 0), (4, 8), (6, 8), (7, 8), (8, 5), (10, 5), (11, 5), (12, 7), (14, 7), (15, 7)]),
        lineP("pedale", "bassi", oct: 1, len: 2, sound: "sub",
              [(0, 0), (2, 0), (4, 0), (6, 0), (8, 0), (10, 0), (12, 0), (14, 7)]),
        // melodie
        lineP("arpeggio", "melodie", oct: 3, len: 1, sound: "pluck",
              run([0, 3, 7, 3, 8, 12, 8, 3, 5, 8, 12, 8, 7, 11, 2, 11])),
        lineP("ostinato", "melodie", oct: 3, len: 1, sound: "pluck",
              run([0, 7, 0, 7, 8, 3, 8, 3, 5, 12, 5, 12, 7, 2, 7, 2])),
        // il sesto bemolle che scende sul quinto: il sospiro scuro dei film
        lineP("sospiro", "melodie", oct: 4, len: 4, sound: "lead quadro",
              [(0, 7), (4, 8), (8, 8), (12, 7)]),
        lineP("campana", "melodie", oct: 5, len: 2, sound: "pluck",
              [(0, 7), (4, 3), (8, 0), (12, 2), (14, 11)]),
        lineP("tema", "melodie", oct: 4, len: 2, sound: "lead sega",
              [(0, 7), (2, 3), (4, 8), (6, 12), (8, 5), (10, 8), (12, 11), (14, 7)]),
        lineP("eco", "melodie", oct: 4, len: 2, sound: "pluck",
              [(0, 12), (2, 7), (4, 12), (6, 8), (8, 12), (10, 5), (12, 11), (14, 7)]),
        lineP("orologio", "melodie", oct: 4, len: 1, sound: "pluck",
              [(0, 7), (2, 7), (4, 8), (6, 8), (8, 8), (10, 8), (12, 7), (14, 7)]),
        lineP("cuore", "melodie", oct: 3, len: 1, sound: "pluck",
              [(0, 0), (1, 0), (4, 0), (5, 0), (8, 0), (9, 0), (12, 11), (13, 11)]),
        lineP("sospeso", "melodie", oct: 4, len: 4, sound: "tappeto largo",
              [(0, 12), (8, 12), (12, 11)]),
        lineP("discesa", "melodie", oct: 4, len: 2, sound: "flauto",
              [(0, 12), (2, 10), (4, 8), (6, 7), (8, 5), (10, 3), (12, 2), (14, 11)]),
        // accordi, sulle tracce scelte e le due dopo
        chords("tensione", [(0, 3, 7), (8, 0, 3), (5, 8, 0), (7, 11, 2)]),
        chords("epico", [(0, 3, 7), (8, 0, 3), (3, 7, 10), (7, 11, 2)]),
        // il basso che scende do-sib-lab-sol, il lamento
        chords("lamento", [(12, 3, 7), (10, 3, 7), (8, 0, 3), (7, 11, 2)]),
        chords("attesa", [(0, 3, 7), (5, 8, 0), (0, 3, 7), (7, 11, 2)]),
        chords("cattedrale", sound: "organo", [(0, 3, 7), (8, 0, 3), (10, 2, 5), (7, 11, 2)]),
    ]
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

/// Quello che cambia molte volte al secondo (il passo, i lampi dei pad, l'inclinazione, lo specchio):
/// sta a parte, così a ogni passo si ridisegnano solo i quadratini e non tutta la pagina.
final class TX6Live: ObservableObject {
    /// Il passo che suona: cambia una volta per sedicesimo, e i pad della batteria si accendono da qui.
    @Published var step = 0
    /// I pad toccati a mano.
    @Published var flash: Set<Int> = []
}

/// Il resto di quello che cambia spesso, ma non a ogni passo: inclinazione, scene che sfumano, specchio di CTRL OUT.
/// Sta a parte da `TX6Live`, così il passo che avanza non ridisegna anche questi.
final class TX6Side: ObservableObject {
    @Published var tilt = 0.0
    @Published var morphProgress: Double?
    @Published var faders: [Int?] = Array(repeating: nil, count: 6)
    @Published var knobs: [[Int?]] = Array(repeating: Array(repeating: nil, count: 6), count: 3)
    @Published var pressed: Set<String> = []
    @Published var encoderSteps = 0
    @Published var lastControl = "—"
}

/// La sezione TX-6 di Bobina. Come per il TP-7: vive sul main thread, i passi a tempo partono
/// in anticipo con la marca temporale di CoreMIDI. Il TX-6 non racconta com'è messo:
/// tutto quello che Bobina sa è quello che gli ha mandato.
final class TX6Engine: ObservableObject {

    let io = MIDIIO()
    let live = TX6Live()
    let side = TX6Side()
    /// Il ritmo, su un filo tutto suo.
    private(set) lazy var sequencer = TX6Sequencer(io: io)
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
    /// Col bluetooth ogni pacchetto costa: Bobina ne manda meno.
    private(set) var viaBluetooth = false

    // MARK: il mixer come lo ricorda Bobina

    @Published private(set) var values: [[Int]] = Array(repeating: TX6.Param.allCases.map { $0.initial }, count: 6)
    @Published private(set) var mutes = Array(repeating: false, count: 6)
    /// Il suono mandato a ogni traccia (nil = Bobina non l'ha mai mandato, quindi non lo sa). Resta salvato:
    /// così i nomi delle tracce in «crea» sono quelli veri anche dopo una chiusura.
    @Published private(set) var sentSounds: [Int?] = {
        let saved = UserDefaults.standard.array(forKey: "bobina.tx6.suoni") as? [Int] ?? []
        return saved.count == 6 ? saved.map { $0 < 0 ? nil : $0 } : Array(repeating: nil, count: 6)
    }()

    /// Il nome del suono della traccia, o «?» se Bobina non lo sa.
    func soundName(_ t: Int) -> String {
        sentSounds[t - 1].map { TX6.sounds[TX6.soundIndex($0)] } ?? "?"
    }

    private func rememberSound(_ t: Int, _ v: Int) {
        sentSounds[t - 1] = v
        UserDefaults.standard.set(sentSounds.map { $0 ?? -1 }, forKey: "bobina.tx6.suoni")
    }

    /// Le tracce in solo: se ce n'è almeno una, le altre tacciono (volume a zero, fatto da Bobina).
    @Published private(set) var solos: Set<Int> = []
    /// main, aux, cue
    @Published private(set) var master = [100, 100, 100]
    @Published private(set) var localOff = false

    // MARK: effetti

    @Published private(set) var fxOn = [false, false]
    /// Se Bobina ha già detto al TX-6 acceso o spento: il TX-6 non dice com'è, e i suoi tasti FX lo cambiano.
    @Published private(set) var fxKnown = [false, false]
    /// FX I spento da Bobina: il ritorno resta a zero (cc 7 canale 8) finché non si riaccende. Così l'effetto
    /// tace anche con le mandate delle tracce alzate (8/10/2026: spegnendolo si sentiva ancora).
    private var fx1Silenced: Bool { fxKnown[0] && !fxOn[0] }
    /// L'effetto scelto da Bobina e i suoi parametri: restano salvati, così riaprendo si vedono i preset giusti.
    @Published private(set) var fxEngine: [Int?] = {
        let saved = UserDefaults.standard.array(forKey: "bobina.tx6.effetti") as? [Int] ?? []
        return saved.count == 2 ? saved.map { $0 < 0 ? nil : $0 } : [nil, nil]
    }()
    @Published private(set) var fxParams: [[Int]] = {
        let saved = UserDefaults.standard.array(forKey: "bobina.tx6.effetti.parametri") as? [[Int]] ?? []
        return saved.count == 2 && saved.allSatisfy({ $0.count == 3 }) ? saved : [[64, 64, 64], [64, 64, 64]]
    }()
    /// Se Bobina ha già mandato un parametro: prima di allora il 64 di partenza è solo un'ipotesi e nessun preset si accende.
    private(set) var fxParamsKnown = UserDefaults.standard.array(forKey: "bobina.tx6.effetti.parametri") != nil
    @Published private(set) var fxReturn = 100
    @Published private(set) var fx2Place: Int?

    // MARK: suonare

    @Published var keyTrack = 1
    @Published var octave = 4
    @Published var chord = TX6Chord.single
    /// L'ottava delle note do-la sul canale 7 (da misurare: la guida non la dice).
    /// Misurato il 6/10/2026: con do4 (60) le casse suonavano alte come tom, una o due ottave sotto sono giuste.
    /// Di fabbrica do2 (36); la scelta resta salvata.
    @Published var padBase = UserDefaults.standard.object(forKey: "bobina.tx6.ottavaPad") as? Int ?? 36 {
        didSet { UserDefaults.standard.set(padBase, forKey: "bobina.tx6.ottavaPad") }
    }
    @Published private(set) var heldKeys: Set<Int> = []

    // MARK: tempo

    /// Il tempo vero sta in BobinaClock (lo stesso dei PO): qui lo si mostra e lo si cambia.
    @Published var bpm: Double = BobinaClock.shared.bpm {
        didSet { if oldValue != bpm && clockMode != .follow { BobinaClock.shared.setBPM(bpm) } }
    }
    @Published private(set) var running = false
    @Published var clockMode = TX6ClockMode.own {
        didSet {
            if oldValue == .follow && clockMode != .follow { sequencer.clockLost() }
            if oldValue != clockMode && running { toggleRun() }
        }
    }
    @Published private(set) var clockBPM: Double?
    /// Il TX-6 manda il clock ma Bobina non lo segue: col bluetooth sono 48 messaggi al secondo sprecati.
    @Published private(set) var strayClock = false

    var pulsing: Bool { running || (clockMode == .follow && clockBPM != nil) }

    // MARK: giochi a tempo

    @Published var beatsOn = false
    @Published var beats: [[Bool]] = Array(repeating: Array(repeating: false, count: 16), count: 6) { didSet { save() } }
    /// Passi con manopola: a ogni passo un valore diverso per un parametro di una traccia.
    @Published var lockOn = false { didSet { if !lockOn && oldValue && pulsing { restoreLock() } } }
    @Published var lockTrack = 1 { didSet { save() } }
    /// Mai il guadagno: un valore a passi lo farebbe saltare (vedi stepGain).
    @Published var lockParam = TX6.Param.freq { didSet { if lockParam == .gain { lockParam = .freq }; save() } }
    @Published var locks: [Int?] = Array(repeating: nil, count: 16) { didSet { save() } }

    /// Melodia a passi: per ogni traccia sedici passi, ognuno una nota (0 = do … 12 = do sopra) o niente.
    @Published var melodyOn = false { didSet { if !melodyOn { sequencer.melodyOffNow() } } }
    @Published var melodies: [[Int?]] = Array(repeating: Array(repeating: nil, count: 16), count: 6) { didSet { save() } }
    @Published var melodyOctaves: [Int] = Array(repeating: 4, count: 6) { didSet { save() } }
    /// Quanti sedicesimi dura ogni nota.
    @Published var melodyLength = 1 { didSet { save() } }
    /// Lo swing dei passi, come sulle MPC: 0,5 dritto, 0,54-0,58 leggero, 0,62-0,66 pesante. Resta salvato.
    @Published var swing: Double = UserDefaults.standard.object(forKey: "bobina.tx6.swing") as? Double ?? 0.5 {
        didSet { UserDefaults.standard.set(swing, forKey: "bobina.tx6.swing") }
    }
    /// Scrittura in fila, come NTS-1 e M8: il passo dove va la prossima nota della melodia…
    @Published var melodyCursor = 0
    /// …e quello dove va il prossimo valore dei passi con manopola.
    @Published var lockCursor = 0

    @Published var gateOn = false { didSet { if !gateOn { sequencer.releaseGateNow() } } }
    @Published var gate: [Bool] = [true, false, true, false, true, true, false, true, true, false, true, false, true, true, false, false] { didSet { save() } }
    @Published var gateTracks: Set<Int> = [1] { didSet { save() } }

    @Published var pumpOn = false { didSet { if !pumpOn && oldValue && pulsing { restorePump() } } }
    @Published var pumpDepth = 0.7
    @Published var pumpRelease = 0.6
    @Published var pumpTracks: Set<Int> = [1] { didSet { save() } }

    @Published var waves: [TX6Wave] = [TX6Wave(), TX6Wave(tracks: [2], param: .pan, shape: .triangle, beats: 8, depth: 40)] {
        didSet {
            // mai il guadagno: un'onda lo farebbe salire e scendere da solo
            for i in waves.indices where waves[i].param == .gain { waves[i].param = .filter }
            save()
        }
    }

    @Published var driftOn = false { didSet { if !driftOn { resetDrift() } } }
    @Published var driftAmount = 0.5
    @Published var driftTracks: Set<Int> = [1, 2, 3]
    @Published var driftPan = false

    @Published var tiltOn = false { didSet { if tiltOn { startMotion() } else { stopMotion() } } }
    @Published var tiltParam = TX6.Param.filter { didSet { if tiltParam == .gain { tiltParam = .filter } } }
    @Published var tiltTracks: Set<Int> = [1]

    @Published var scenes: [TX6Scene] = [] { didSet { save() } }

    /// I pattern salvati, quello che suona e quello che entra alla prossima battuta.
    @Published var patterns: [TX6Pattern] = [] { didSet { save() } }

    /// I preset delle tracce salvati da Giampiero.
    @Published var myPresets: [TX6Preset] = [] { didSet { save() } }
    @Published private(set) var currentPatternID: UUID?
    @Published private(set) var currentPatternName: String?
    @Published private(set) var pendingPatternName: String?
    /// Cambiando pattern cambia anche il tempo.
    @Published var patternTempo = true
    @Published var morphBars: Double = 2

    // MARK: quello che arriva dal TX-6 in CTRL OUT

    /// Il TX-6 comanda il TP-7: fader → volumi, tasti traccia → muti, FX I → play/stop.
    @Published var bridgeOn = false

    // MARK: interni

    private var timer: DispatchSourceTimer?
    private var lastTick: MIDITimeStamp = 0
    private var lastPlanAt: MIDITimeStamp = 0
    private var lastBPMShown: MIDITimeStamp = 0
    private var strayTimeout: DispatchWorkItem?
    private var lastSent: [[Int?]] = Array(repeating: Array(repeating: nil, count: TX6.Param.allCases.count), count: 6)
    private var lastModAt: MIDITimeStamp = 0
    private var masterSent: [Int?] = [nil, nil, nil]
    private var fxSent: [[Int?]] = [[nil, nil, nil], [nil, nil, nil]]
    private var fxReturnSent: Int?
    private var driftLevels = Array(repeating: 1.0, count: 6)
    private var driftVelocity = Array(repeating: 0.0, count: 6)
    private var driftPanPos = Array(repeating: 0.0, count: 6)
    private var driftPanVel = Array(repeating: 0.0, count: 6)
    private var waveCycle = [-1, -1]
    private var waveRandom = [0.0, 0.0]
    private var morph: (from: TX6Scene, to: TX6Scene, start: MIDITimeStamp, length: Double)?
    private var clockStamps: [MIDITimeStamp] = []
    private var clockTimeout: DispatchWorkItem?
    private var lastClockAt: MIDITimeStamp = 0
    private var held: [Int: [(track: Int, note: Int)]] = [:]
    private let motion = CMMotionManager()
    private let haptic = UIImpactFeedbackGenerator(style: .rigid)

    init() {
        for t in 0..<6 { if let v = sentSounds[t] { values[t][TX6.Param.sound.rawValue] = v } }
        load()
        io.onSetupChanged = { [weak self] in self?.refreshPorts() }
        io.onReceive = { [weak self] bytes, stamp in self?.received(bytes, stamp) }
        let seq = sequencer
        io.onRealtime = { status, stamp in seq.realtime(status, stamp) }
        seq.onStep = { [weak self] i, t, hit in
            DispatchQueue.main.async { self?.stepped(i, t, hit) }
        }
        seq.onSwitched = { [weak self] id in
            DispatchQueue.main.async { self?.switched(id) }
        }
        // il tempo cambiato da un'altra sezione (i PO): qui si mostra e basta, BobinaClock è già a posto
        NotificationCenter.default.addObserver(forName: .bobinaBPM, object: nil, queue: .main) { [weak self] n in
            guard let self = self, let v = n.object as? Double, self.clockMode != .follow, abs(self.bpm - v) > 0.0001 else { return }
            self.bpm = v
        }
        refreshPorts()
        startTimer()
    }

    // MARK: porte

    func refreshPorts() {
        destinations = io.destinations()
        sources = io.sources()
        trace("TX-6 · destinazioni: " + destinations.map { $0.name }.joined(separator: " · ") + " · sorgenti: " + sources.map { $0.name }.joined(separator: " · "))
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
        viaBluetooth = connectedName.lowercased().contains("bluetooth")
        if dest != io.destination || src != io.source {
            let fresh = dest != 0 && dest != io.destination
            io.use(destination: dest, source: src)
            objectWillChange.send()
            // appena collegato: spegne le note rimaste accese da prima (un'app chiusa a metà nota non manda lo spegnimento)
            if fresh { DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.allNotesOff() } }
        }
    }

    /// Silenzio: lo spegnimento di ogni nota (do-1 … sol9) sulle tracce 1-6.
    /// Una nota rimasta accesa sul TX-6 si sente così: una cassa che suona anche alta come un tom, un'onda che
    /// non si spegne più. Succede se Bobina si chiude (o si reinstalla) mentre una nota è giù: lo spegnimento
    /// non parte mai. Qui si mandano tutti, a gruppi di otto ogni 10 ms, per non intasare il bluetooth.
    /// Spegne le note rimaste accese sul TX-6, da solo, quando Bobina si collega: solo quelle che Bobina ha suonato
    /// davvero (TX6PlayedNotes, salvato anche dopo una chiusura brusca), più i colpi e le note delle melodie.
    /// Di solito un pacchetto o due. Il tasto «silenzio» non c'è più: toccato per sbaglio bloccava il TX-6 (9/10/2026).
    func allNotesOff() {
        guard io.destination != 0 else { return }
        var notes = Set<Int>()
        for (ch, n) in TX6PlayedNotes.shared.takeAll() { notes.insert(ch << 8 | n) }
        for t in 1...6 {
            notes.insert(TX6.masterChannel << 8 | TX6.drumNote(t))
            for k in melodies[t - 1].compactMap({ $0 }) { notes.insert(t << 8 | max(0, min(127, melodyNote(t, k)))) }
        }
        var bytes: [UInt8] = []
        for k in notes.sorted() { bytes += TX6.noteOff(k & 0x7F, channel: k >> 8) }
        // niente cc 123 («tutte le note spente»): non è nella tabella del TX-6, e con lui il TX-6 si bloccava
        // (9/10/2026). Il tasto «silenzio» è tolto; questo spegnimento parte solo da solo, al collegamento.
        // a pacchetti piccoli, uno ogni 20 ms
        let chunks = stride(from: 0, to: bytes.count, by: 24).map { Array(bytes[$0..<min(bytes.count, $0 + 24)]) }
        for (i, c) in chunks.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.02) { [weak self] in
                guard let self = self, self.io.destination != 0 else { return }
                self.io.send(c)
            }
        }
        held.removeAll()
        heldKeys.removeAll()
        sequencer.melodyOffNow()
        logText("silenzio: \(notes.count) note spente")
        trace("TX-6: silenzio, \(notes.count) note in \(chunks.count) pacchetti")
    }

    /// Sceglie il suono di una traccia. Una cassa (KICK) con la frequenza ancora a metà (64) suonerebbe come un tom
    /// sul canale 7: la frequenza scende a 36, poi si regola con la leva.
    func setSound(_ track: Int, _ index: Int) {
        set(track, .sound, TX6.soundValue(index))
        if TX6.sounds[index] == "KICK" && value(track, .freq) == 64 { set(track, .freq, 36) }
    }

    // MARK: guadagno

    /// Il guadagno (cc 9, da 0 a +42 dB) si muove solo di un dB alla volta, mai a salti: un «max» sentito male
    /// dal Controllo Vocale porterebbe una traccia a +42 dB e può rompere le casse (regola di Giampiero, 8/10/2026).
    func gainDB(_ track: Int) -> Int { Int((Double(value(track, .gain)) / 127 * 42).rounded()) }

    func stepGain(_ track: Int, by d: Int) {
        let db = max(0, min(42, gainDB(track) + d))
        set(track, .gain, Int((Double(db) * 127 / 42).rounded()))
    }

    // MARK: invio

    func send(_ bytes: [UInt8], at time: MIDITimeStamp = 0, quiet: Bool = false) {
        io.send(bytes, at: time)
        if !quiet {
            note(bytes, incoming: false)
            trace("→ TX-6 " + bytes.map { String(format: "%02x", $0) }.joined(separator: " ") + " · " + TX6.describe(bytes, incoming: false))
        }
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
        if p == .sound { rememberSound(track, v) }
    }

    /// Per la prova dei comandi: un cc solo sul canale 1 (traccia 1), mandato da solo in un pacchetto.
    func probe(_ cc: UInt8, _ value: Int) {
        send(TX6.cc(cc, value, channel: 1))
    }

    /// Rimette la traccia 1 come la crede Bobina, dopo la prova dei comandi.
    func restoreTrack1() {
        mutes[0] = false
        var bytes: [UInt8] = TX6.cc(TX6.ccMute, 0, channel: 1)
        for p in [TX6.Param.volume, .pan, .filter, .eqHigh, .eqMid, .eqLow, .comp, .fx1Send, .auxSend, .aux2Send] {
            let v = output(1, p, io.now())
            bytes += TX6.cc(p.cc, v, channel: 1)
            lastSent[0][p.rawValue] = v
        }
        for k in stride(from: 0, to: bytes.count, by: 3) {
            let msg = Array(bytes[k..<k + 3])
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(k / 3) * 0.03) { [weak self] in self?.io.send(msg) }
        }
        logText("traccia 1 rimessa com'era")
    }

    /// Una traccia tace se è muta, o se qualcun'altra è in solo.
    func silenced(_ t: Int) -> Bool { mutes[t - 1] || (!solos.isEmpty && !solos.contains(t)) }

    /// Il solo, fatto da Bobina: le tracce che non sono in solo vanno a volume zero; togliendolo tornano com'erano.
    /// (Il solo del TX-6 dipende dal menu SOLO della macchina: così invece funziona sempre.)
    func toggleSolo(_ track: Int) {
        if solos.contains(track) { solos.remove(track) } else { solos.insert(track) }
        var bytes: [UInt8] = []
        for t in 1...6 {
            let vol = output(t, .volume, io.now())
            if vol != lastSent[t - 1][TX6.Param.volume.rawValue] {
                bytes += TX6.cc(TX6.Param.volume.cc, vol, channel: t)
                lastSent[t - 1][TX6.Param.volume.rawValue] = vol
            }
        }
        if !bytes.isEmpty { send(bytes, quiet: true) }
        logText(solos.isEmpty ? "solo tolto" : "solo: traccia " + solos.sorted().map { "\($0)" }.joined(separator: " "))
    }

    /// Il muto: il cc 120 del TX-6 e, in più, il volume a zero (lo tiene `output`). Misurato il 6/10/2026:
    /// col synth acceso il cc 120 da solo non zittiva la traccia; il volume a zero la zittisce sempre.
    /// Togliendo il muto il volume torna quello di prima.
    func toggleMute(_ track: Int) {
        mutes[track - 1].toggle()
        let vol = output(track, .volume, io.now())
        lastSent[track - 1][TX6.Param.volume.rawValue] = vol
        send(TX6.cc(TX6.ccMute, mutes[track - 1] ? 127 : 0, channel: track) + TX6.cc(TX6.Param.volume.cc, vol, channel: track))
    }

    /// EQ piatto e filtro spento sulla traccia.
    func flatten(_ track: Int) {
        for p in [TX6.Param.eqHigh, .eqMid, .eqLow, .filter] { set(track, p, 64) }
    }

    // MARK: il generale

    func setMaster(_ i: Int, _ v: Int) {
        let v = max(0, min(127, v))
        guard v != masterSent[i] else { return }
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

    /// Acceso o spento, sempre mandato (cc 82: 0 spento, 127 acceso), qualunque cosa creda Bobina.
    /// FX I spento mette anche il ritorno a zero; riacceso lo rimette dov'era.
    func setFx(_ i: Int, on: Bool) {
        fxOn[i] = on
        fxKnown[i] = true
        var bytes = TX6.cc(TX6.ccFxOn, on ? 127 : 0, channel: TX6.fxChannels[i])
        if i == 0 {
            let r = on ? fxReturn : 0
            bytes += TX6.cc(TX6.ccFxReturn, r, channel: TX6.fxChannels[0])
            fxReturnSent = r
        }
        send(bytes)
    }

    // MARK: tape e freeze (FX II tenuto, rotellina)

    /// Tape e freeze suonano solo finché FX II è tenuto acceso, e intanto la rotellina (select) li muove:
    /// è lo scratch (misurato da Giampiero l'8/10/2026). Qui «tieni»/«lascia», la rotellina (slider, − e +),
    /// FX II tenuto per una durata a tempo, e lo scratch che porta la rotellina avanti e indietro da solo.
    @Published private(set) var fxHolding = false
    /// Dove sta la rotellina, da 0 a 127.
    @Published private(set) var wheel = 64.0
    /// Quale parametro di FX II fa da rotellina (0 = cc 12, 1 = cc 13, 2 = cc 14): da misurare (prova 24).
    @Published var scratchParam = UserDefaults.standard.integer(forKey: "bobina.tx6.scratch.parametro") {
        didSet { UserDefaults.standard.set(scratchParam, forKey: "bobina.tx6.scratch.parametro") }
    }
    private var fxHitID = 0
    private var scratchTimer: DispatchSourceTimer?

    /// La rotellina manda il suo parametro senza salvarlo a ogni passo (lo scratch ne manda 40 al secondo).
    private func sendWheel(_ v: Int) {
        let v = max(0, min(127, v))
        let k = max(0, min(2, scratchParam))
        guard v != fxSent[1][k] else { return }
        fxSent[1][k] = v
        send(TX6.cc(TX6.ccFxParams[k], v, channel: TX6.fxChannels[1]), quiet: true)
    }

    func setWheel(_ v: Double) {
        wheel = max(0, min(127, v))
        sendWheel(Int(wheel.rounded()))
    }

    func holdFx2() {
        stopScratch()
        fxHitID += 1
        setFx(1, on: true)
        fxHolding = true
    }

    func releaseFx2() {
        stopScratch()
        fxHitID += 1
        fxHolding = false
        setFx(1, on: false)
    }

    /// Tiene FX II per tanti quarti, al tempo di Bobina, poi lascia.
    func holdFx2(beats: Double) {
        stopScratch()
        fxHitID += 1
        let id = fxHitID
        setFx(1, on: true)
        fxHolding = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 60 / max(40, bpm) * beats) { [weak self] in
            guard let self = self, self.fxHitID == id else { return }
            self.setFx(1, on: false)
        }
    }

    /// Scratch: tiene FX II per una battuta e porta la rotellina avanti e indietro da 0 a 127, un giro ogni
    /// `every` quarti; alla fine lascia FX II e rimette la rotellina dov'era.
    func scratch(every: Double) {
        stopScratch()
        fxHitID += 1
        let id = fxHitID
        setFx(1, on: true)
        fxHolding = false
        let quarter = 60 / max(40, bpm)
        let total = quarter * 4
        let period = quarter * every
        let base = wheel
        let start = ProcessInfo.processInfo.systemUptime
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(25))
        timer.setEventHandler { [weak self] in
            guard let self = self, self.fxHitID == id else { return }
            let e = ProcessInfo.processInfo.systemUptime - start
            if e >= total {
                self.stopScratch()
                self.setFx(1, on: false)
                self.sendWheel(Int(base.rounded()))
                return
            }
            let ph = (e / period).truncatingRemainder(dividingBy: 1)
            let tri = ph < 0.5 ? ph * 2 : 2 - ph * 2
            self.sendWheel(Int((tri * 127).rounded()))
        }
        scratchTimer = timer
        timer.resume()
    }

    private func stopScratch() {
        scratchTimer?.cancel()
        scratchTimer = nil
    }

    /// Un tocco: FX I e FX II spenti.
    func allFxOff() {
        setFx(0, on: false)
        setFx(1, on: false)
    }

    func setFxEngine(_ i: Int, _ index: Int) {
        fxEngine[i] = index
        // un effetto nuovo ha i suoi valori: il prossimo parametro va mandato anche se è uguale all'ultimo
        fxSent[i] = [nil, nil, nil]
        UserDefaults.standard.set(fxEngine.map { $0 ?? -1 }, forKey: "bobina.tx6.effetti")
        send(TX6.cc(TX6.ccFxEngine, TX6.spread(index, TX6.fxEngines[i].count), channel: TX6.fxChannels[i]))
    }

    func setFxParam(_ i: Int, _ k: Int, _ v: Int) {
        let v = max(0, min(127, v))
        guard v != fxSent[i][k] else { return }
        fxParams[i][k] = v
        fxSent[i][k] = v
        fxParamsKnown = true
        UserDefaults.standard.set(fxParams, forKey: "bobina.tx6.effetti.parametri")
        send(TX6.cc(TX6.ccFxParams[k], v, channel: TX6.fxChannels[i]))
    }

    func setFxReturn(_ v: Int) {
        let v = max(0, min(127, v))
        fxReturn = v
        // con FX I spento il ritorno resta a zero: il valore nuovo parte quando si riaccende
        let out = fx1Silenced ? 0 : v
        guard out != fxReturnSent else { return }
        fxReturnSent = out
        send(TX6.cc(TX6.ccFxReturn, out, channel: TX6.fxChannels[0]))
    }

    func setFx2Place(_ index: Int) {
        fx2Place = index
        send(TX6.cc(TX6.ccFx2Place, TX6.fx2PlaceValue(index), channel: TX6.fxChannels[1]))
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
        for n in playable {
            send(TX6.noteOn(n.note, channel: n.track))
            TX6PlayedNotes.shared.add(n.track, n.note)
        }
        haptic.impactOccurred()
    }

    func keyUp(_ k: Int) {
        guard let list = held.removeValue(forKey: k) else { return }
        heldKeys.remove(k)
        for n in list { send(TX6.noteOff(n.note, channel: n.track), quiet: true) }
    }

    /// Un pad: la nota `padBase` sul canale della traccia. Misurato il 6/10/2026: le note do-la sul canale 7
    /// suonano le tracce sempre alla stessa altezza (le casse sembravano tom), il canale della traccia invece
    /// segue la nota, come la tastiera.
    func hitPad(_ track: Int, at time: MIDITimeStamp = 0, fromUser: Bool = true) {
        // sul canale 7, alla frequenza della traccia (vedi TX6.drumNote)
        let n = TX6.drumNote(track)
        send(TX6.noteOn(n, channel: TX6.masterChannel), at: time, quiet: !fromUser)
        TX6PlayedNotes.shared.add(TX6.masterChannel, n)
        let off = (time == 0 ? io.now() : time) + io.ticks(ms: 40)
        send(TX6.noteOff(n, channel: TX6.masterChannel), at: off, quiet: true)
        if fromUser { haptic.impactOccurred() }
        flash([track], at: time)
    }

    private func flash(_ tracks: Set<Int>, at time: MIDITimeStamp) {
        let delay = time == 0 ? 0 : msUntil(time)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay / 1000) { [weak self] in
            self?.live.flash = tracks
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { [weak self] in
                if self?.live.flash == tracks { self?.live.flash = [] }
            }
        }
    }

    /// La nota MIDI di un passo della melodia.
    func melodyNote(_ track: Int, _ semitone: Int) -> Int { 12 * (melodyOctaves[track - 1] + 1) + semitone }

    /// Quando metti una nota in un passo la senti subito, breve.
    func preview(_ track: Int, _ semitone: Int) {
        let n = melodyNote(track, semitone)
        send(TX6.noteOn(n, channel: track), quiet: true)
        TX6PlayedNotes.shared.add(track, n)
        send(TX6.noteOff(n, channel: track), at: io.now() + io.ticks(ms: 180), quiet: true)
    }

    // MARK: scrittura in fila

    /// Una nota toccata (o una pausa, `nil`) va nel passo del cursore, si sente, e il cursore va avanti di uno.
    func writeNote(_ track: Int, _ semitone: Int?) {
        melodies[track - 1][melodyCursor] = semitone
        if let k = semitone {
            preview(track, k)
            melodyOn = true
        }
        melodyCursor = (melodyCursor + 1) % 16
    }

    func melodyBack() { melodyCursor = (melodyCursor + 15) % 16 }

    /// Toccando un passo il cursore va lì, e si sente la nota che c'è.
    func selectMelodyStep(_ track: Int, _ i: Int) {
        melodyCursor = i
        if let k = melodies[track - 1][i] { preview(track, k) }
    }

    /// Un valore (o un passo vuoto, `nil`) dei passi con manopola nel passo del cursore, poi il cursore va avanti.
    func writeLock(_ v: Int?) {
        locks[lockCursor] = v
        if v != nil { lockOn = true }
        lockCursor = (lockCursor + 1) % 16
    }

    func lockBack() { lockCursor = (lockCursor + 15) % 16 }


    // MARK: pattern

    /// Suona un pattern: se il ritmo gira entra all'inizio della prossima battuta, se no subito.
    func play(_ pat: TX6Pattern) {
        beatsOn = true
        melodyOn = true
        if pulsing {
            var part = makePart(pat)
            if !patternTempo || clockMode == .follow { part.bpm = nil }
            pendingPatternName = pat.name
            sequencer.queuePattern(part)
        } else {
            adopt(pat, sendSounds: true)
        }
    }

    /// L'ultima batteria pronta chiesta, fatta pattern: serve al sequencer per riconoscerla quando entra.
    private var drumPattern: TX6Pattern?

    /// Una batteria pronta: cambia solo le tracce 1-4 (passi e suoni), il resto di quello che suona resta.
    /// Entra come un pattern: se il ritmo gira all'inizio della battuta, se no subito.
    func playDrums(_ d: TX6DrumPreset) {
        var pat = capture(name: d.name)
        var extra: [UInt8] = []
        for r in 0..<4 {
            pat.beats[r] = d.steps(r)
            guard let p = TX6Preset.builtIn.first(where: { $0.name == d.sounds[r] }) else { continue }
            pat.sounds[r] = [TX6.soundValue(p.sound), p.freq, p.length, p.detune]
            // filtro e compressore del preset non stanno nel pattern: partono insieme ai suoni
            for (param, v) in [(TX6.Param.filter, p.filter), (.comp, p.comp)] {
                values[r][param.rawValue] = v
                let out = output(r + 1, param, io.now())
                extra += TX6.cc(param.cc, out, channel: r + 1)
                lastSent[r][param.rawValue] = out
            }
        }
        pat.bpm = Double(d.bpm)
        pat.swing = d.swing
        drumPattern = pat
        beatsOn = true
        // subito, anche col ritmo che gira: entrando alla battuta (fino a 4 secondi a 60 bpm) cancellava le
        // modifiche fatte intanto sulla griglia (8/10/2026, «se voglio svuotare non si svuota»)
        if pulsing { sequencer.cancelPending() }
        pendingPatternName = nil
        send(extra, quiet: true)
        adopt(pat, sendSounds: true)
    }

    func cancelPendingPattern() {
        sequencer.cancelPending()
        pendingPatternName = nil
    }

    /// Salva quello che suona adesso come pattern nuovo.
    func saveNewPattern() {
        var n = patterns.count + 1
        while patterns.contains(where: { $0.name == "pattern \(n)" }) { n += 1 }
        let pat = capture(name: "pattern \(n)")
        patterns.append(pat)
        currentPatternID = pat.id
        currentPatternName = pat.name
    }

    /// Riscrive un pattern con quello che suona adesso.
    func overwrite(_ pat: TX6Pattern) {
        guard let k = patterns.firstIndex(where: { $0.id == pat.id }) else { return }
        var fresh = capture(name: pat.name)
        fresh.id = pat.id
        patterns[k] = fresh
        currentPatternID = pat.id
        currentPatternName = pat.name
    }

    /// Svuota tutta la batteria (le sei righe), lascia melodie e suoni.
    func clearDrums() {
        beats = Array(repeating: Array(repeating: false, count: 16), count: 6)
        logText("batteria svuotata")
    }

    /// Svuota tutte le melodie (le sei tracce) e spegne le note che suonano.
    func clearMelodies() {
        melodies = Array(repeating: Array(repeating: nil, count: 16), count: 6)
        melodyCursor = 0
        sequencer.melodyOffNow()
        logText("melodie svuotate")
    }

    /// Svuota la sequenza per ricominciare: batteria, melodie e passi con manopola. Suoni e tempo restano.
    func clearSequence() {
        beats = Array(repeating: Array(repeating: false, count: 16), count: 6)
        melodies = Array(repeating: Array(repeating: nil, count: 16), count: 6)
        locks = Array(repeating: nil, count: 16)
        melodyCursor = 0
        lockCursor = 0
        sequencer.melodyOffNow()
        currentPatternID = nil
        currentPatternName = nil
        logText("sequenza svuotata")
    }

    /// Una melodia pronta: le note sulla traccia (o, per gli accordi, sulla traccia e le due dopo), le ottave,
    /// la durata e il suono adatto. Accende la melodia.
    func applyMelody(_ m: TX6MelodyPreset, from track: Int) {
        for (k, voice) in m.voices.enumerated() {
            let t = track + k
            guard t <= 6 else { break }
            melodies[t - 1] = voice
            melodyOctaves[t - 1] = m.octaves[k]
            if let p = TX6Preset.builtIn.first(where: { $0.name == m.sound }) { apply(p, to: t) }
        }
        melodyLength = m.length
        melodyOn = true
        let used = min(m.voices.count, 7 - track)
        logText("melodia «\(m.name)» sulla traccia \(track)" + (used > 1 ? "-\(track + used - 1)" : ""))
    }

    /// Mette un preset sulla traccia: suono e manopole, in un pacchetto solo.
    func apply(_ preset: TX6Preset, to track: Int) {
        let pairs: [(TX6.Param, Int)] = [(.sound, TX6.soundValue(preset.sound)), (.freq, preset.freq), (.length, preset.length),
                                         (.detune, preset.detune), (.filter, preset.filter), (.comp, preset.comp)]
        var bytes: [UInt8] = []
        for (p, v) in pairs {
            values[track - 1][p.rawValue] = v
            let out = output(track, p, io.now())
            bytes += TX6.cc(p.cc, out, channel: track)
            lastSent[track - 1][p.rawValue] = out
        }
        send(bytes, quiet: true)
        rememberSound(track, TX6.soundValue(preset.sound))
        logText("traccia \(track): preset «\(preset.name)»")
    }

    /// Salva come preset il suono della traccia così com'è adesso.
    func savePreset(from track: Int) {
        var n = myPresets.count + 1
        while myPresets.contains(where: { $0.name == "mio \(n)" }) { n += 1 }
        let v = values[track - 1]
        myPresets.append(TX6Preset(name: "mio \(n)", group: "miei", sound: TX6.soundIndex(v[TX6.Param.sound.rawValue]),
                                   freq: v[TX6.Param.freq.rawValue], length: v[TX6.Param.length.rawValue],
                                   detune: v[TX6.Param.detune.rawValue], filter: v[TX6.Param.filter.rawValue],
                                   comp: v[TX6.Param.comp.rawValue]))
    }

    func deletePreset(_ p: TX6Preset) { myPresets.removeAll { $0.id == p.id } }

    func deletePattern(_ pat: TX6Pattern) { patterns.removeAll { $0.id == pat.id } }

    private func capture(name: String) -> TX6Pattern {
        TX6Pattern(name: name, beats: beats, melodies: melodies, melodyOctaves: melodyOctaves, melodyLength: melodyLength,
                   locks: locks, lockTrack: lockTrack, lockParam: lockParam, gate: gate,
                   sounds: (0..<6).map { t in TX6Pattern.soundParams.map { values[t][$0.rawValue] } },
                   bpm: bpm, swing: swing)
    }

    private func makePart(_ pat: TX6Pattern) -> TX6Sequencer.Part {
        var bytes: [UInt8] = []
        for t in 1...6 {
            for (k, param) in TX6Pattern.soundParams.enumerated() {
                bytes += TX6.cc(param.cc, pat.sounds[t - 1][k], channel: t)
            }
        }
        // mai il guadagno a passi, neanche da un pattern salvato prima
        let lockParam = pat.lockParam == .gain ? TX6.Param.freq : pat.lockParam
        let lockBase = TX6Pattern.soundParams.firstIndex(of: lockParam).map { pat.sounds[pat.lockTrack - 1][$0] }
            ?? values[pat.lockTrack - 1][lockParam.rawValue]
        return TX6Sequencer.Part(id: pat.id, beats: pat.beats, melodies: pat.melodies, melodyOctaves: pat.melodyOctaves,
                                 melodyLength: pat.melodyLength, locks: pat.locks, lockTrack: pat.lockTrack,
                                 lockCC: lockParam.cc, lockBase: lockBase, gate: pat.gate,
                                 soundBytes: bytes, bpm: pat.bpm, swing: pat.swing)
    }

    /// Il sequencer ha fatto entrare un pattern: la pagina si mette in pari (i suoni sono già partiti).
    private func switched(_ id: UUID) {
        guard let pat = (patterns + TX6Pattern.styles + [drumPattern].compactMap { $0 }).first(where: { $0.id == id }) else { return }
        adopt(pat, sendSounds: false)
    }

    private func adopt(_ pat: TX6Pattern, sendSounds: Bool) {
        beats = pat.beats
        melodies = pat.melodies
        melodyOctaves = pat.melodyOctaves
        melodyLength = pat.melodyLength
        locks = pat.locks
        lockTrack = pat.lockTrack
        lockParam = pat.lockParam
        gate = pat.gate
        var bytes: [UInt8] = []
        for t in 1...6 {
            for (k, param) in TX6Pattern.soundParams.enumerated() {
                let v = pat.sounds[t - 1][k]
                values[t - 1][param.rawValue] = v
                if param == .sound { rememberSound(t, v) }
                lastSent[t - 1][param.rawValue] = v
                bytes += TX6.cc(param.cc, v, channel: t)
            }
        }
        if sendSounds { send(bytes, quiet: true) }
        if patternTempo && clockMode != .follow { bpm = pat.bpm }
        if let sw = pat.swing { swing = sw }
        currentPatternID = pat.id
        currentPatternName = pat.name
        pendingPatternName = nil
        logText("pattern «\(pat.name)»")
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
            side.morphProgress = 0
            return
        }
        morph = nil
        side.morphProgress = nil
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
            let out = fx1Silenced ? 0 : r
            if force || out != fxReturnSent {
                fxReturnSent = out
                send(TX6.cc(TX6.ccFxReturn, out, channel: TX6.fxChannels[0]), quiet: true)
            }
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
            sequencer.stop(sendStop: clockMode == .send)
            if clockMode == .send { note(TX6.stop, incoming: false) }
            // passi con manopola e pompa hanno messaggi già preparati fino a 150 ms (la pompa fino a un battito):
            // si rimette a posto dopo che sono arrivati, se no l'ultimo valore preparato vince
            let tail = TX6Sequencer.tailMs + (pumpOn ? beatMs * pumpRelease : 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + tail / 1000) { [weak self] in
                guard let self = self, !self.running else { return }
                if self.beatsOn && self.lockOn { self.restoreLock() }
                if self.pumpOn { self.restorePump() }
            }
        } else {
            guard clockMode != .follow else { return }
            let start = io.now() + io.ticks(ms: 30)
            // le onde leggono la stessa griglia di BobinaClock: vanno a tempo coi passi
            sequencer.update(makePlan())
            sequencer.start(at: start)
            if clockMode == .send { note(TX6.start, incoming: false) }
            running = true
        }
    }

    /// Tutto quello che il sequencer deve sapere, fotografato adesso.
    private func makePlan() -> TX6Sequencer.Plan {
        var p = TX6Sequencer.Plan()
        p.bpm = max(40, min(300, bpm))
        p.sendClock = clockMode == .send
        p.follow = clockMode == .follow
        p.padBase = padBase
        p.beatsOn = beatsOn
        p.beats = beats
        p.lockOn = lockOn
        p.lockTrack = lockTrack
        p.lockCC = lockParam.cc
        p.lockBase = values[lockTrack - 1][lockParam.rawValue]
        p.locks = locks
        p.melodyOn = melodyOn
        p.melodies = melodies
        p.melodyOctaves = melodyOctaves
        p.melodyLength = melodyLength
        p.gateOn = gateOn
        p.gate = gate
        p.gateTracks = gateTracks.sorted()
        p.mutes = mutes
        p.volumes = (1...6).map { output($0, .volume, io.now()) }
        p.pumpOn = pumpOn
        p.pumpDepth = pumpDepth
        p.pumpRelease = pumpRelease
        p.patternID = currentPatternID
        p.swing = swing
        // il cancello vince sulla pompa: le tracce del cancello non pompano
        p.pumpTops = pumpTracks.sorted().filter { !(gateOn && gateTracks.contains($0)) }.map { tr in
            (track: tr, top: silenced(tr) ? 0 : Double(values[tr - 1][TX6.Param.volume.rawValue]) * (driftOn && driftTracks.contains(tr) ? driftLevels[tr - 1] : 1))
        }
        return p
    }

    /// Un passo è partito: il quadratino e i pad si accendono quando suona davvero.
    private func stepped(_ i: Int, _ t: MIDITimeStamp, _ hit: Set<Int>) {
        let delay = msUntil(t) / 1000
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.live.step = i }
    }

    /// Dove siamo nel battito: la griglia di BobinaClock (quando seguiamo il TX-6, la sposta il suo clock).
    private func beatNow(_ now: MIDITimeStamp) -> Double {
        BobinaClock.shared.snapshot().beat(at: now)
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
        #if DEBUG
        let began = CACurrentMediaTime()
        defer { Diagnostics.shared.add("ms orologio tx6", (CACurrentMediaTime() - began) * 1000) }
        #endif
        let now = io.now()
        let dt = lastTick == 0 ? 0.008 : min(0.1, io.ms(ticks: now &- lastTick) / 1000)
        lastTick = now

        // i passi li suona il sequencer sul suo filo: qui gli si passa solo il piano aggiornato
        if io.ms(ticks: now &- lastPlanAt) >= 40 {
            lastPlanAt = now
            sequencer.update(makePlan())
        }

        driftUpdate(dt)

        if let m = morph {
            let p = min(1, io.ms(ticks: now &- m.start) / m.length)
            apply(m.to, fraction: p, from: m.from)
            let shown = (p * 100).rounded() / 100
            if side.morphProgress != shown { side.morphProgress = shown }
            if p >= 1 { morph = nil; side.morphProgress = nil }
        }

        // le modulazioni continue: al massimo una volta ogni 30 ms (60 col bluetooth), e solo se il valore cambia
        guard io.ms(ticks: now &- lastModAt) >= (viaBluetooth ? 60 : 30) else { return }
        lastModAt = now
        var batch: [UInt8] = []
        for t in 1...6 {
            for p in TX6.Param.allCases where p.continuous {
                if p == .volume && pumpOn && pulsing && pumpTracks.contains(t) { continue }
                // col cancello acceso il volume delle sue tracce lo tiene il sequencer (zero nei passi chiusi)
                if p == .volume && gateOn && pulsing && gateTracks.contains(t) { continue }
                if beatsOn && lockOn && pulsing && t == lockTrack && p == lockParam { continue }
                let out = output(t, p, now)
                let current = lastSent[t - 1][p.rawValue] ?? values[t - 1][p.rawValue]
                if out != current {
                    batch += TX6.cc(p.cc, out, channel: t)
                    lastSent[t - 1][p.rawValue] = out
                }
            }
        }
        if !batch.isEmpty { send(batch, quiet: true) }
    }

    /// Il valore che deve avere adesso un parametro: il tuo, più onde, deriva e inclinazione.
    private func output(_ t: Int, _ p: TX6.Param, _ now: MIDITimeStamp) -> Int {
        if p == .volume && silenced(t) { return 0 }
        var v = Double(values[t - 1][p.rawValue])
        guard p.continuous else { return Int(v) }
        if p == .volume && driftOn && driftTracks.contains(t) { v *= driftLevels[t - 1] }
        if p == .pan && driftOn && driftPan && driftTracks.contains(t) { v += driftPanPos[t - 1] * 50 * driftAmount }
        for (i, w) in waves.enumerated() where w.on && w.param == p && w.tracks.contains(t) {
            v += w.depth * waveValue(i, w, now)
        }
        if tiltOn && tiltParam == p && tiltTracks.contains(t) { v += side.tilt * 63 }
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

    /// Fermati i passi con manopola, il parametro torna al tuo valore.
    private func restoreLock() {
        sendParam(lockTrack, lockParam, output(lockTrack, lockParam, io.now()), quiet: true)
        sequencer.forgetLock()
    }

    /// Fermata la pompa, i volumi tornano al tuo valore.
    private func restorePump() {
        for tr in pumpTracks.sorted() { sendParam(tr, .volume, output(tr, .volume, io.now()), quiet: true) }
    }

    // MARK: movimento

    private func startMotion() {
        guard motion.isDeviceMotionAvailable else { tiltOn = false; return }
        motion.deviceMotionUpdateInterval = 1.0 / 30
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let d = data else { return }
            // inclinato a destra apre, a sinistra chiude: 45° = tutta la corsa
            self.side.tilt = max(-1, min(1, d.attitude.roll / (.pi / 4)))
        }
    }

    private func stopMotion() {
        motion.stopDeviceMotionUpdates()
        side.tilt = 0
    }

    // MARK: ricezione

    private func received(_ m: [UInt8], _ stamp: MIDITimeStamp) {
        guard let status = m.first else { return }
        if status == 0xF8 { clock(stamp); return }
        trace("TX-6 manda " + m.map { String(format: "%02x", $0) }.joined(separator: " "))
        note(m, incoming: true)
        if status == 0xFA || status == 0xFB { return }
        if status == 0xFC {
            if clockMode == .follow {
                if beatsOn && lockOn { restoreLock() }
                if pumpOn { restorePump() }
            }
            return
        }
        guard status == 0xB0, m.count >= 3, let c = TX6.control(m[1]) else { return }
        let v = Int(m[2])
        switch c {
        case .fader(let t): side.faders[t - 1] = v
        case .knob(let r, let t): side.knobs[r - 1][t - 1] = v
        case .encoder: side.encoderSteps += TX6.relative(m[2])
        default:
            if v > 0 { side.pressed.insert(c.name) } else { side.pressed.remove(c.name) }
        }
        if c == .encoder {
            let d = TX6.relative(m[2])
            side.lastControl = "select girato \(d > 0 ? "+" : "")\(d)"
        } else if v > 0 || c.name.hasPrefix("fader") || c.name.hasPrefix("manopola") {
            side.lastControl = "\(c.name) · cc \(m[1]) = \(v)"
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
        if clockMode != .follow {
            if !strayClock { strayClock = true }
            strayTimeout?.cancel()
            let w = DispatchWorkItem { [weak self] in self?.strayClock = false }
            strayTimeout = w
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: w)
        }
        if clockStamps.isEmpty && lastClockAt == 0 { trace("TX-6 manda il clock (porta \(sources.first(where: { $0.id == sourceID })?.name ?? "?"))") }
        // quando il tempo lo dà Bobina, il clock che torna indietro è solo un'eco: si ignora
        guard clockMode != .send else { return }
        clockStamps.append(stamp)
        if clockStamps.count > 49 { clockStamps.removeFirst() }
        if clockStamps.count > 24, let first = clockStamps.first, let last = clockStamps.last, last > first {
            let perTick = io.ms(ticks: last - first) / Double(clockStamps.count - 1)
            let value = (60_000 / (perTick * 24) * 2).rounded() / 2
            // il numero sullo schermo cambia al massimo due volte al secondo: ridisegnare costa
            let now = io.now()
            if (clockBPM.map { abs($0 - value) >= 0.5 } ?? true) && io.ms(ticks: now &- lastBPMShown) > 500 {
                clockBPM = value
                lastBPMShown = now
            }
        }
        lastClockAt = stamp
        if clockMode == .follow, let c = clockBPM, abs(bpm - c) > 0.05 { bpm = max(40, min(300, c)) }
        clockTimeout?.cancel()
        let w = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.clockStamps.removeAll()
            self.clockBPM = nil
            self.lastClockAt = 0
            if self.clockMode == .follow {
                self.sequencer.clockLost()
                self.sequencer.releaseGateNow()
                self.sequencer.melodyOffNow()
                if self.beatsOn && self.lockOn { self.restoreLock() }
                if self.pumpOn { self.restorePump() }
            }
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
        var melodies: [[Int?]]?
        var melodyOctaves: [Int]?
        var melodyLength: Int?
        var patterns: [TX6Pattern]?
        var myPresets: [TX6Preset]?
    }

    private var loading = false

    private func save() {
        guard !loading else { return }
        let s = Saved(beats: beats, gate: gate, gateTracks: gateTracks.sorted(), pumpTracks: pumpTracks.sorted(),
                      locks: locks, lockTrack: lockTrack, lockParam: lockParam, waves: waves, scenes: scenes,
                      melodies: melodies, melodyOctaves: melodyOctaves, melodyLength: melodyLength, patterns: patterns,
                      myPresets: myPresets)
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
        if let m = s.melodies, m.count == 6, m.allSatisfy({ $0.count == 16 }) { melodies = m }
        if let o = s.melodyOctaves, o.count == 6 { melodyOctaves = o }
        if let l = s.melodyLength { melodyLength = l }
        if let mp = s.myPresets { myPresets = mp }
        if let ps = s.patterns {
            patterns = ps.filter { $0.beats.count == 6 && $0.melodies.count == 6 && $0.sounds.count == 6 && $0.gate.count == 16 && $0.locks.count == 16 }
        }
        loading = false
    }
}
