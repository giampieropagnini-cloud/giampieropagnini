import Foundation

// MARK: - Le batterie pronte di Crea (rifatte l'8/10/2026 dai dischi veri, suoni rifatti il 9/10)
//
// Giampiero: «non sono assolutamente trip hop, non sono hip hop»; artisti di riferimento Portishead, Massive Attack,
// Tricky, Nas, Gang Starr, Guru, Snoop Dogg, e i DJ di elettronica e dance. Ogni ritmo viene da una trascrizione
// (lezioni di batteria, Songsterr fatto a mano, Attack Magazine «Beat Dissected», Pocket Operations, Frane 2017
// sullo swing dei breakbeat): «documentato» o «ricostruito» è scritto accanto. Il TX-6 suona una batteria
// sintetizzata, non i breakbeat campionati dei dischi: ritmo, tempo, swing e accordatura sì, il suono identico no.
//
// 9/10/2026, sera, Giampiero: «le ultime file non suonano, hai usato quasi sempre lo stesso sound design; devono
// avere sempre quattro strumenti: un kick, uno snare, un hi-hat almeno, e per l'elettronica e la dance un clap».
// Quindi ogni batteria ha il suo kit (i suoni sono scritti qui, non presi dai preset di suono) e sempre:
// riga 1 cassa (KICK), riga 2 rullante (SNARE), riga 3 il quarto strumento (battimani in elettronica e dance;
// aperto, piatto, tom o battimani nel trip hop e nell'hip hop), riga 4 charleston (HIHAT). Nessuna riga vuota.
// Charleston senza filtro: col filtro abbassato (56) in Teardrop le righe 3 e 4 non si sentivano.
// Solo i quattro motori di batteria: niente bip di onde corte, niente tamburello acuto in sedicesimi.
//
// Una riga di 16 caratteri per traccia, «x» = colpo, «.» = niente. Le tracce 5 e 6 (basso e melodia) non si
// toccano. Lo swing è quello delle MPC: 0,5 dritto, 0,66 terzina.

struct TX6DrumPreset: Identifiable {
    let name: String
    let group: String
    let bpm: Int
    /// cassa, rullante, quarto strumento, charleston: 16 caratteri ciascuna.
    let rows: [String]
    /// I suoni delle quattro righe, fatti per questa batteria.
    let kit: [TX6Preset]
    /// Lo swing come sulle MPC (0,5 dritto, 0,66 terzina).
    var swing: Double = 0.5
    /// Da dove viene: artista, disco, anno.
    var ref: String = ""
    var id: String { name }

    func steps(_ row: Int) -> [Bool] { rows[row].map { $0 == "x" } }

    static let groups = ["trip hop", "hip hop", "elettronica", "dance"]

    static let all: [TX6DrumPreset] = [

        // TRIP HOP
        // documentato: drumstheword.com e Songsterr (a mano); il break è Smokey Brooks «Spin It Jig»
        TX6DrumPreset(name: "Sour Times", group: "trip hop", bpm: 92,
                      rows: ["x.xx...xx..x...x", "....x.......x...", "..........x.....", "x.x.x.x.x.x.x.x."],
                      kit: [.kick(34, 58, comp: 40, flt: 60), .snare(62, 50), .open(74, 65), .hat(82, 20)],
                      swing: 0.54, ref: "Portishead · Sour Times (1994)"),
        // documentato: Songsterr a mano; il giro è Isaac Hayes «Ike's Rap II». Cassa lunga e rullante grosso, aperto in fondo alla battuta
        TX6DrumPreset(name: "Glory Box", group: "trip hop", bpm: 60,
                      rows: ["x......xx.......", "....x.......x...", "..............x.", "x.x.x.x.x.x.x.x."],
                      kit: [.kick(29, 95, comp: 30), .snare(55, 85, comp: 55), .open(70, 85), .hat(78, 24)],
                      swing: 0.64, ref: "Portishead · Glory Box (1994)"),
        // documentato: Songsterr a mano e il file MIDI di BitMidi coincidono; sul 2 e sul 4 un rullante corto, quasi un colpo sul cerchio
        TX6DrumPreset(name: "Teardrop", group: "trip hop", bpm: 77,
                      rows: ["xx.x....xx.x....", "....x.......x...", "..x.......x.....", "x.x.x.x.x.x.x.x."],
                      kit: [.kick(31, 70, comp: 45, flt: 60), .snare(68, 28, comp: 30), .open(76, 55), .hat(84, 18)],
                      swing: 0.5, ref: "Massive Attack · Teardrop (1998)"),
        // documentato: Songsterr (rivisto da un moderatore); a metà tempo, rullante sul 3, un piatto sull'1
        TX6DrumPreset(name: "Angel", group: "trip hop", bpm: 107,
                      rows: ["x..............x", "........x.......", "x...............", "x.x.x.x.x...x.x."],
                      kit: [.kick(33, 85, comp: 70), .snare(53, 90, comp: 65), .crash(62, 120), .hat(80, 22)],
                      swing: 0.5, ref: "Massive Attack · Angel (1998)"),
        // ricostruito; lo swing 1,6:1 del break è misurato (Frane 2017). Un tom basso sulle «a», al posto del tamburello
        TX6DrumPreset(name: "Aftermath", group: "trip hop", bpm: 81,
                      rows: ["x.....x.x.....x.", "....x.......x...", "...x.........x..", "x.x.x.x.x.x.x.x."],
                      kit: [.kick(36, 55, flt: 60), .snare(60, 62), .tom(52, 40), .hat(76, 26)],
                      swing: 0.61, ref: "Tricky · Aftermath (1995)"),

        // HIP HOP
        // documentato: drummingtips.com e Songsterr; il rullante in più sul 3e (passo 10) è la firma di Premier
        TX6DrumPreset(name: "NY State", group: "hip hop", bpm: 84,
                      rows: ["x.x.......x.....", "....x....x..x...", "..........x.....", "x.x.x.x.x.x.x.x."],
                      kit: [.kick(38, 48, comp: 70), .snare(58, 48, comp: 50), .open(74, 60), .hat(86, 16)],
                      swing: 0.57, ref: "Nas · N.Y. State of Mind (1994, DJ Premier)"),
        // documentato: trascrizione di Dean McCormick; due casse subito dopo ogni rullante, aperto sul 2e e sul 4e
        TX6DrumPreset(name: "Mass Appeal", group: "hip hop", bpm: 96,
                      rows: ["x.....xx..x...xx", "....x.......x...", "......x.......x.", "x.x.x.x.x.x.x.x."],
                      kit: [.kick(41, 40, comp: 80), .snare(64, 40, comp: 60), .open(72, 50), .hat(82, 18)],
                      swing: 0.54, ref: "Gang Starr · Mass Appeal (1994, DJ Premier)"),
        // documentato: trascrizione a mano di 4 battute; chiuso sui battiti, aperto sui «e»
        TX6DrumPreset(name: "The World", group: "hip hop", bpm: 87,
                      rows: ["x.x.....x.x.....", "....x.......x...", "..x...x...x...x.", "x...x...x...x..."],
                      kit: [.kick(34, 65, comp: 60), .snare(60, 55, comp: 50), .open(70, 45), .hat(84, 20)],
                      swing: 0.58, ref: "Nas · The World Is Yours (1994, Pete Rock)"),
        // documentato: trascrizione a mano del 2011; cassa lunga del G-funk, aperto sul 2a
        TX6DrumPreset(name: "Gin & Juice", group: "hip hop", bpm: 95,
                      rows: ["x.........x.....", "....x.......x...", ".......x........", "x.x.x.x.x.x.x.x."],
                      kit: [.kick(31, 90, comp: 40), .snare(57, 65, comp: 55), .open(76, 70), .hat(80, 20)],
                      swing: 0.55, ref: "Snoop Doggy Dogg · Gin and Juice (1993, Dr. Dre)"),
        // documentato: due trascrizioni a mano e un MIDI coincidono; rullante e battimani insieme sul 2 e sul 4, come nel G-funk
        TX6DrumPreset(name: "G Thang", group: "hip hop", bpm: 95,
                      rows: ["x.....x.x.....x.", "....x.......x...", "....x.......x...", "x.x.x.x.x.x.x.x."],
                      kit: [.kick(28, 105, comp: 30), .snare(59, 55, comp: 50), .clap(64, 60), .hat(86, 16)],
                      swing: 0.55, ref: "Dr. Dre & Snoop Dogg · Nuthin' but a 'G' Thang (1992)"),

        // ELETTRONICA
        // documentato: Attack Magazine e MusicRadar; 909 spinta, battimani sul 2 e sul 4, colpi di rullante in fondo alla battuta, aperto sui controtempi
        TX6DrumPreset(name: "The Bells", group: "elettronica", bpm: 137,
                      rows: ["x...x...x...x...", "...........x..x.", "....x.......x...", "..x...x...x...x."],
                      kit: [.kick(40, 55, comp: 80), .snare(66, 28), .clap(64, 45, comp: 40), .open(78, 50)],
                      swing: 0.5, ref: "Jeff Mills · The Bells (1997), techno di Detroit"),
        // documentato: Pocket Operations; la cassa 1·7·11·14 dell'electro, rullante e battimani della 808 insieme
        TX6DrumPreset(name: "Planet Rock", group: "elettronica", bpm: 127,
                      rows: ["x.....x...x..x..", "....x.......x...", "....x.......x...", "x.xxx.xxx.xxxxxx"],
                      kit: [.kick(27, 100, comp: 30), .snare(62, 42), .clap(66, 50), .hat(84, 14)],
                      swing: 0.5, ref: "Afrika Bambaataa · Planet Rock (1982), electro"),
        // documentato: Native Instruments; cassa profonda, battimani lunghi, rullante che rotola in fondo alla battuta
        TX6DrumPreset(name: "Afterlife", group: "elettronica", bpm: 122,
                      rows: ["x...x...x...x...", "..............xx", "....x.......x...", "..x...x...x...x."],
                      kit: [.kick(34, 80, comp: 80, flt: 60), .snare(60, 35, comp: 30), .clap(60, 85), .open(72, 60)],
                      swing: 0.5, ref: "Tale Of Us / Afterlife, techno melodica"),
        // documentato: Native Instruments (Adam Beyer, Charlotte de Witte, Amelie Lens); charleston fitti fra le casse
        TX6DrumPreset(name: "Peak time", group: "elettronica", bpm: 135,
                      rows: ["x...x...x...x...", ".x.....x..x.....", "....x.......x...", ".xxx.xxx.xxx.xxx"],
                      kit: [.kick(36, 72, comp: 90), .snare(68, 26), .clap(66, 40, comp: 50), .hat(80, 16)],
                      swing: 0.5, ref: "Amelie Lens / Charlotte de Witte, techno di oggi"),
        // documentato: Attack Magazine «Sub-Zero Minimal Techno»; lo swing fa il groove
        TX6DrumPreset(name: "Minimal", group: "elettronica", bpm: 127,
                      rows: ["x...x...x...x...", "...x..x..x......", "....x.......x...", "..x...xx..x...x."],
                      kit: [.kick(42, 42, comp: 60), .snare(70, 24, comp: 20), .clap(68, 35), .hat(80, 16)],
                      swing: 0.6, ref: "Richie Hawtin / Plastikman, minimal"),

        // DANCE
        // documentato: Pocket Operations «Deep House»; 909 morbida, rullante e battimani insieme, aperto sui controtempi
        TX6DrumPreset(name: "Deep house", group: "dance", bpm: 120,
                      rows: ["x...x...x...x...", "....x.......x...", "....x.......x...", "..x...x...x...x."],
                      kit: [.kick(39, 62, flt: 60), .snare(62, 35, comp: 30), .clap(60, 60), .open(74, 55)],
                      swing: 0.54, ref: "Larry Heard (Mr. Fingers) · Can You Feel It (1986)"),
        // documentato: Attack Magazine «80s Chicago House»; charleston in sedicesimi e il rullante in più sul 4a
        TX6DrumPreset(name: "Chicago", group: "dance", bpm: 122,
                      rows: ["x...x...x...x.x.", "....x.......x..x", "....x.......x...", "xxxxxxxxxxxxxxxx"],
                      kit: [.kick(40, 58, comp: 60), .snare(64, 40, comp: 50), .clap(66, 48), .hat(78, 12)],
                      swing: 0.54, ref: "Frankie Knuckles · Your Love, house di Chicago"),
        // documentato: Attack Magazine «Raw French House» (il beat di Homework); cassa filtrata e compressa, swing forte
        TX6DrumPreset(name: "French", group: "dance", bpm: 124,
                      rows: ["x...x...x...x...", "....x.......x...", "....x.......x...", "..x...x...x...x."],
                      kit: [.kick(37, 66, comp: 70, flt: 56), .snare(60, 50, comp: 60), .clap(62, 55, comp: 40), .open(76, 55)],
                      swing: 0.62, ref: "Daft Punk · Homework (1997), French house"),
        // documentato: Attack Magazine (Classmatic «Catuca»); cassa lunga e bassa, charleston fitti senza aperti
        TX6DrumPreset(name: "Tech house", group: "dance", bpm: 125,
                      rows: ["x...x...x...x...", "....x.......x..x", "....x.......x...", "xx.x.x.xxx.xxx.x"],
                      kit: [.kick(30, 90), .snare(66, 30), .clap(64, 50, comp: 40), .hat(82, 14)],
                      swing: 0.5, ref: "Classmatic / Fisher, tech house"),
        // documentato: Pocket Operations «UK Garage»; il 2-step vuole lo swing in terzina
        TX6DrumPreset(name: "UK garage", group: "dance", bpm: 132,
                      rows: ["x.........x.....", "....x.......x...", "....x.......x...", "..xx..x...x...xx"],
                      kit: [.kick(41, 45, comp: 60), .snare(66, 38), .clap(64, 40), .hat(82, 16)],
                      swing: 0.66, ref: "MJ Cole / Artful Dodger, UK garage 2-step"),
    ]
}

/// I suoni per i kit delle batterie pronte: frequenza (come le note: 36 ≈ do2, 64 ≈ mi4), lunghezza, compressore,
/// filtro (64 = spento). Detune sempre a 64.
extension TX6Preset {
    private static func drum(_ name: String, _ sound: Int, _ f: Int, _ l: Int, _ comp: Int, _ flt: Int) -> TX6Preset {
        TX6Preset(name: name, group: "pronte", sound: sound, freq: f, length: l, detune: 64, filter: flt, comp: comp)
    }
    static func kick(_ f: Int, _ l: Int, comp: Int = 50, flt: Int = 64) -> TX6Preset { drum("cassa", 4, f, l, comp, flt) }
    /// Una cassa accordata alta è un tom.
    static func tom(_ f: Int, _ l: Int, comp: Int = 30, flt: Int = 64) -> TX6Preset { drum("tom", 4, f, l, comp, flt) }
    static func snare(_ f: Int, _ l: Int, comp: Int = 40, flt: Int = 64) -> TX6Preset { drum("rullante", 5, f, l, comp, flt) }
    static func clap(_ f: Int, _ l: Int, comp: Int = 30, flt: Int = 64) -> TX6Preset { drum("battimani", 6, f, l, comp, flt) }
    static func hat(_ f: Int, _ l: Int, comp: Int = 0, flt: Int = 64) -> TX6Preset { drum("charleston", 7, f, l, comp, flt) }
    static func open(_ f: Int, _ l: Int, comp: Int = 0, flt: Int = 64) -> TX6Preset { drum("aperto", 7, f, l, comp, flt) }
    /// Un charleston lunghissimo e basso fa da piatto.
    static func crash(_ f: Int, _ l: Int, comp: Int = 0, flt: Int = 64) -> TX6Preset { drum("piatto", 7, f, l, comp, flt) }
}

// MARK: - Le melodie pronte di Crea (rifatte il 9/10/2026, prendendo il metodo dalla sezione OP-Z)
//
// Giampiero: «20 melodie dark cinematiche, semplici, che si possano agganciare tra di loro»; poi «fanno cagare,
// guarda quelle dell'OP-Z». Dall'OP-Z il metodo, non le note: ogni melodia pronta è un pezzo intero (basso sulla
// traccia 5, melodia o arpeggio sulla 6), lunga due battute, con un accordo per battuta o per mezza, e la sua
// durata delle note per traccia («tenuta» = fino alla nota dopo, così il basso e le note lunghe cantano).
// Il TX-6 suona una nota per traccia: niente accordi, l'armonia la fanno basso e melodia insieme (e gli arpeggi).
//
// Tutte in re minore e tutte chiudono su una nota che riporta al re (la, do#, mib, do): cambiandole mentre suonano
// non stonano mai, e si mettono una dopo l'altra. I gruppi sono quelli delle batterie, per abbinarle.
//
// Un gettone per passo, separati da spazi: «.» = niente, «D2» = una nota (do centrale = C4, «Bb1» si bemolle,
// «C#4» do diesis). 32 gettoni = due battute.

struct TX6MelodyPreset: Identifiable {
    /// Quello che va su una traccia: le note (semitoni dal do dell'ottava), l'ottava, la durata, il suono.
    struct Part {
        let steps: [Int?]
        let octave: Int
        let gate: Int
        let sound: String
    }

    let name: String
    let group: String
    /// A cosa somiglia: si legge sopra le melodie pronte.
    let ref: String
    let bass: String
    let lead: String
    /// Durata delle note di basso e melodia, in sedicesimi (0 = tenuta fino alla nota dopo).
    let gates: [Int]
    /// I preset di suono di basso e melodia.
    let sounds: [String]
    var id: String { name }

    /// Le tracce di basso e melodia.
    static let tracks = [5, 6]
    static let groups = ["trip hop", "hip hop", "elettronica", "cinema"]

    var parts: [Part] {
        [Self.part(bass, gate: gates[0], sound: sounds[0]), Self.part(lead, gate: gates[1], sound: sounds[1])]
    }

    /// Le note del testo, con l'ottava (do-si) che ne tiene di più; a pari merito quella della prima nota, così il re
    /// del basso resta «re» e i tasti scrivono nella stessa ottava. Le note fuori hanno il ↑ o il ↓.
    static func part(_ text: String, gate: Int, sound: String) -> Part {
        let notes = text.split(separator: " ").map { note(String($0)) }
        let all = notes.compactMap { $0 }
        func score(_ o: Int) -> (Int, Int, Int) {
            let range = (12 * (o + 1))..<(12 * (o + 2))
            return (all.filter { range.contains($0) }.count, all.first.map { range.contains($0) ? 1 : 0 } ?? 0, -o)
        }
        let octave = (1...6).max { score($0) < score($1) } ?? 4
        let base = 12 * (octave + 1)
        let steps = notes.map { $0.map { $0 - base } }
        return Part(steps: steps.count == 16 || steps.count == 32 ? steps : Array((steps + Array(repeating: nil, count: 32)).prefix(32)),
                    octave: octave, gate: gate, sound: sound)
    }

    /// Una nota come «D2», «Bb1», «C#4» in numero MIDI (do centrale = C4 = 60); «.» o altro = niente.
    static func note(_ t: String) -> Int? {
        let letters: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        guard let first = t.first, let base = letters[first] else { return nil }
        var rest = t.dropFirst()
        var semitone = base
        if rest.first == "#" { semitone += 1; rest = rest.dropFirst() } else if rest.first == "b" { semitone -= 1; rest = rest.dropFirst() }
        guard let octave = Int(rest) else { return nil }
        return 12 * (octave + 1) + semitone
    }

    static let all: [TX6MelodyPreset] = [
        // trip hop
        TX6MelodyPreset(name: "Velluto", group: "trip hop",
                        ref: "Portishead, Roads: il basso che scende re-do-sib-la, la voce che risponde",
                        bass: "D2 . . . . . . . . . . . C2 . . . Bb1 . . . . . . . . . . . A1 . . .",
                        lead: ". . A4 . . . . . F4 . G4 . A4 . . . D5 . . . . . C5 . Bb4 . . . A4 . . .",
                        gates: [0, 0], sounds: ["basso scuro", "voce"]),
        TX6MelodyPreset(name: "Insonnia", group: "trip hop",
                        ref: "Massive Attack, Angel: un giro di basso che minaccia, due rintocchi sopra",
                        bass: "D2 . . D2 . . F2 . G2 . . F2 . . D2 . D2 . . D2 . . F2 . Ab2 . . G2 . . F2 .",
                        lead: ". . . . D5 . . . . . . . A4 . . . . . . . . . . . Bb4 . . . A4 . . .",
                        gates: [2, 4], sounds: ["basso scuro", "campana"]),
        TX6MelodyPreset(name: "Asfalto", group: "trip hop",
                        ref: "Portishead, Sour Times: il giro da film di spie, pizzicato",
                        bass: "D2 . . . . . . . . . . . . . . . Bb1 . . . . . . . A1 . . . . . . .",
                        lead: "D4 . F4 . A4 . . G#4 A4 . . . F4 . . . D4 . F4 . A4 . . Bb4 A4 . . . E4 . . .",
                        gates: [0, 2], sounds: ["basso caldo", "pluck scuro"]),
        TX6MelodyPreset(name: "Lividi", group: "trip hop",
                        ref: "Tricky, blues lento: la quinta abbassata e il basso re-do-sol-la",
                        bass: "D2 . . . . . . . . . . . C2 . . . G1 . . . . . . . . . . . A1 . . .",
                        lead: "D4 . . . F4 . A4 . G#4 . G4 . E4 . . . D4 . . . . . F4 . E4 . . . C#4 . . .",
                        gates: [0, 0], sounds: ["basso caldo", "flauto"]),
        TX6MelodyPreset(name: "Sirene", group: "trip hop",
                        ref: "Massive Attack, Teardrop: un giro ipnotico di ottavi su re, sib, la",
                        bass: "D2 . . . . . . . . . . . . . . . Bb1 . . . . . . . A1 . . . . . . .",
                        lead: "D4 . A4 . F4 . A4 . D4 . A4 . F4 . A4 . D4 . Bb4 . F4 . Bb4 . C#4 . A4 . E4 . A4 .",
                        gates: [0, 2], sounds: ["sub tenuto", "pluck scuro"]),
        // hip hop
        TX6MelodyPreset(name: "Periferia", group: "hip hop",
                        ref: "Nas, N.Y. State of Mind: il piano scuro che scende di semitono",
                        bass: "D2 . . . . . . . . . D2 . . . . . D2 . . . . . . . . . A1 . . . . .",
                        lead: "D5 . . A4 . . G#4 . G4 . . F4 . . E4 . D5 . . A4 . . G#4 . G4 . . Bb4 . . A4 .",
                        gates: [4, 2], sounds: ["basso quadro", "piano scuro"]),
        TX6MelodyPreset(name: "Ruggine", group: "hip hop",
                        ref: "Gang Starr, Guru Jazzmatazz: basso che cammina e vibrafono",
                        bass: "D2 . . . F2 . . . A2 . . . C3 . . . G2 . . . F2 . . . D2 . . . B1 . . .",
                        lead: ". . . . . . E5 F5 . . C5 . A4 . . . . . . . . . B4 C5 . . A4 . F4 . . .",
                        gates: [4, 2], sounds: ["basso caldo", "campana"]),
        TX6MelodyPreset(name: "Vicolo", group: "hip hop",
                        ref: "Mobb Deep, Shook Ones: due note attaccate, che stridono in alto",
                        bass: "D2 . . . . . . . . . . . . . . . D2 . . . . . . . . . . . Eb2 . . .",
                        lead: "D5 . . Eb5 . . D5 . . . . . C5 . . . A4 . . Bb4 . . A4 . . . . . G#4 . . .",
                        gates: [0, 2], sounds: ["sub tenuto", "campana"]),
        TX6MelodyPreset(name: "Cicatrice", group: "hip hop",
                        ref: "Dr. Dre, G-funk: basso funk e il fischio lungo sopra",
                        bass: "D2 . . D2 . . F2 . G2 . . G2 . A2 . . Bb2 . . Bb2 . . A2 . G2 . . F2 . E2 . .",
                        lead: "D5 . . . . . . . . . . . C5 . . . Bb4 . . . . . . . A4 . . . . . . .",
                        gates: [2, 0], sounds: ["basso quadro", "fischio"]),
        TX6MelodyPreset(name: "Binari", group: "hip hop",
                        ref: "Pete Rock, RZA: un giro soul triste, come un campione",
                        bass: "D2 . . . . . D2 . . . C2 . . . . . Bb1 . . . . . Bb1 . . . A1 . . . . .",
                        lead: "A4 . . . . . G4 . F4 . . . E4 . . . F4 . . . . . D4 . . . . . C#4 . . .",
                        gates: [4, 0], sounds: ["basso caldo", "voce"]),
        // elettronica
        TX6MelodyPreset(name: "Neon", group: "elettronica",
                        ref: "Afterlife, Tale Of Us: arpeggio di tre note sui sedicesimi, basso sui controtempi",
                        bass: ". . D2 . . . D2 . . . D2 . . . D2 . . . Bb1 . . . Bb1 . . . A1 . . . A1 .",
                        lead: "D4 F4 A4 D4 F4 A4 D4 F4 A4 D4 F4 A4 D4 F4 A4 D4 D4 F4 Bb4 D4 F4 Bb4 D4 F4 C#4 E4 A4 C#4 E4 A4 C#4 E4",
                        gates: [1, 1], sounds: ["basso corto", "pluck scuro"]),
        TX6MelodyPreset(name: "Campane", group: "elettronica",
                        ref: "Jeff Mills, The Bells: la melodia che gira intorno a un la fisso",
                        bass: "D2 . . . . . . . . . . . . . . . Bb1 . . . . . . . A1 . . . . . . .",
                        lead: "D5 . A4 . F5 . A4 . E5 . A4 . D5 . A4 . C5 . A4 . Bb4 . A4 . C#5 . A4 . E5 . A4 .",
                        gates: [0, 1], sounds: ["sub tenuto", "campana"]),
        TX6MelodyPreset(name: "Radar", group: "elettronica",
                        ref: "Kraftwerk, Afrika Bambaataa: electro staccato",
                        bass: "D2 . . D2 . . D2 . . . D2 . F2 . . . Bb1 . . Bb1 . . Bb1 . . . A1 . A1 . . .",
                        lead: "D5 . D5 . C5 . A4 . . . F4 . G4 . A4 . Bb4 . Bb4 . A4 . F4 . . . D4 . E4 . C#4 .",
                        gates: [1, 1], sounds: ["basso quadro", "carillon"]),
        TX6MelodyPreset(name: "Tunnel", group: "elettronica",
                        ref: "techno di Detroit: basso acido sui sedicesimi, una nota lunga sopra",
                        bass: "D2 D2 D3 D2 . D2 F2 D2 D2 . D3 C3 D2 . F2 G2 D2 D2 D3 D2 . D2 F2 D2 Eb2 . Eb3 D3 Eb2 . C2 C3",
                        lead: "A4 . . . . . . . . . . . . . . . Bb4 . . . . . . . A4 . . . . . . .",
                        gates: [1, 0], sounds: ["acid", "archi"]),
        TX6MelodyPreset(name: "Impulso", group: "elettronica",
                        ref: "Larry Heard, deep house scura: basso sincopato e accordo tenuto",
                        bass: "D2 . . D2 . . D2 . . . F2 . G2 . . . Bb1 . . Bb1 . . Bb1 . . . C2 . A1 . . .",
                        lead: "A4 . . . . . . . C5 . . . A4 . . . D5 . . . . . . . . . C5 . C#5 . . .",
                        gates: [2, 0], sounds: ["basso caldo", "archi"]),
        // cinema
        TX6MelodyPreset(name: "Ombra", group: "cinema",
                        ref: "Hans Zimmer, Il cavaliere oscuro: ostinato in ottavi, archi lunghi",
                        bass: "D2 . D2 . D2 . D2 . D2 . D2 . C2 . C2 . Bb1 . Bb1 . Bb1 . Bb1 . A1 . A1 . A1 . A1 .",
                        lead: "D5 . . . . . . . . . . . C5 . . . Bb4 . . . . . . . A4 . . . . . . .",
                        gates: [1, 0], sounds: ["basso corto", "archi"]),
        TX6MelodyPreset(name: "Requiem", group: "cinema",
                        ref: "Dies irae, il canto gregoriano dei morti (Shining, Berlioz)",
                        bass: "D2 . . . . . . . . . . . . . . . C2 . . . . . . . Bb1 . . . . . . .",
                        lead: "F4 . . . E4 . . . F4 . . . D4 . . . E4 . . . C4 . . . D4 . . . D4 . . .",
                        gates: [0, 4], sounds: ["sub tenuto", "voce"]),
        TX6MelodyPreset(name: "Deserto", group: "cinema",
                        ref: "Dune, Lawrence d'Arabia: il modo frigio, mib che ricade su re",
                        bass: "D2 . . . . . . . . . . . . . . . . . . . . . . . . . . . Eb2 . . .",
                        lead: "D5 . . . Eb5 . . . D5 . . . C5 . . . Bb4 . . . A4 . Bb4 . A4 . . . . . . .",
                        gates: [0, 0], sounds: ["basso scuro", "flauto"]),
        TX6MelodyPreset(name: "Il patto", group: "cinema",
                        ref: "le colonne sonore epiche: re minore, sib, fa, do",
                        bass: "D2 . . . . . . . Bb1 . . . . . . . F2 . . . . . . . C2 . . . . . . .",
                        lead: "A4 . . . D5 . . . F5 . . . D5 . . . C5 . . . A4 . . . G4 . . . E4 . . .",
                        gates: [0, 0], sounds: ["basso pieno", "archi"]),
        TX6MelodyPreset(name: "Ninna nanna", group: "cinema",
                        ref: "il carillon dei film horror (Rosemary's Baby, Halloween)",
                        bass: "D2 . . . . . . . . . . . . . . . A1 . . . . . . . . . . . . . . .",
                        lead: "D5 . F5 . A5 . F5 . E5 . F5 . D5 . . . C#5 . E5 . A5 . G5 . F5 . E5 . C#5 . . .",
                        gates: [0, 1], sounds: ["sub tenuto", "carillon"]),
    ]
}
