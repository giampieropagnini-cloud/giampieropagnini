import Foundation

// MARK: - Le batterie pronte di Crea (rifatte l'8/10/2026 dai dischi veri, suoni rifatti il 9/10)
//
// Giampiero: «non sono assolutamente trip hop, non sono hip hop»; artisti di riferimento Portishead, Massive Attack,
// Tricky, Nas, Gang Starr, Guru, Snoop Dogg, e i DJ di elettronica e dance. Ogni ritmo viene da una trascrizione
// (lezioni di batteria, Songsterr fatto a mano, Attack Magazine «Beat Dissected», Pocket Operations, Frane 2017
// sullo swing dei breakbeat): «documentato» o «ricostruito» è scritto accanto. Il TX-6 suona una batteria
// sintetizzata, non i breakbeat campionati dei dischi: ritmo, tempo, swing e accordatura sì, il suono identico no.
//
// 9/10/2026, Giampiero: «fanno cagare… a volte fai degli snare che non c'entrano e cose super fastidiose». Ogni riga
// suona ora con uno dei quattro motori di batteria (cassa, rullante, battimani, charleston), accordato nella sua zona:
// niente bip di legno e campanaccio, niente tamburello acuto in sedicesimi, niente rullanti accordati come tom.
//
// Una riga di 16 caratteri per traccia, «x» = colpo, «.» = niente. Le righe sono le tracce 1-4 del TX-6: cassa,
// rullante, percussione, charleston. I suoni sono i preset di suono (TX6Preset.builtIn) per nome; le tracce 5 e 6
// (basso e melodia) non si toccano. Lo swing è quello delle MPC: 0,5 dritto, 0,66 terzina.

struct TX6DrumPreset: Identifiable {
    let name: String
    let group: String
    let bpm: Int
    /// cassa, rullante, percussione, charleston: 16 caratteri ciascuna.
    let rows: [String]
    /// Il preset di suono di ogni riga.
    let sounds: [String]
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
                      sounds: ["cassa trip hop", "rullante trip hop", "aperto morbido", "charleston polvere"],
                      swing: 0.54, ref: "Portishead · Sour Times (1994)"),
        // documentato: Songsterr a mano; il giro è Isaac Hayes «Ike's Rap II»
        TX6DrumPreset(name: "Glory Box", group: "trip hop", bpm: 60,
                      rows: ["x......xx.......", "....x.......x...", "................", "x.x.x.x.x.x.x.x."],
                      sounds: ["cassa trip hop", "rullante pieno", "aperto morbido", "charleston polvere"],
                      swing: 0.64, ref: "Portishead · Glory Box (1994)"),
        // documentato: Songsterr a mano e il file MIDI di BitMidi coincidono; sul 2 e sul 4 il colpo sul cerchio
        TX6DrumPreset(name: "Teardrop", group: "trip hop", bpm: 77,
                      rows: ["xx.x....xx.x....", "....x.......x...", "..x.......x.....", "x.x.x.x.x.x.x.x."],
                      sounds: ["cassa trip hop", "cerchio", "aperto morbido", "charleston polvere"],
                      swing: 0.5, ref: "Massive Attack · Teardrop (1998)"),
        // documentato: Songsterr (rivisto da un moderatore); a metà tempo, rullante sul 3
        TX6DrumPreset(name: "Angel", group: "trip hop", bpm: 107,
                      rows: ["x..............x", "........x.......", "..........x.....", "x.x.x.x.x...x.x."],
                      sounds: ["cassa g-funk", "rullante pieno", "aperto morbido", "charleston polvere"],
                      swing: 0.5, ref: "Massive Attack · Angel (1998)"),
        // ricostruito; lo swing 1,6:1 del break è misurato (Frane 2017). Il tamburello in sedicesimi è tolto: sul TX-6 era fastidioso
        TX6DrumPreset(name: "Aftermath", group: "trip hop", bpm: 81,
                      rows: ["x.....x.x.....x.", "....x.......x...", "..............x.", "x.x.x.x.x.x.x.x."],
                      sounds: ["cassa trip hop", "rullante trip hop", "aperto morbido", "charleston polvere"],
                      swing: 0.61, ref: "Tricky · Aftermath (1995)"),

        // HIP HOP
        // documentato: drummingtips.com e Songsterr; il rullante in più sul 3e (passo 10) è la firma di Premier
        TX6DrumPreset(name: "NY State", group: "hip hop", bpm: 84,
                      rows: ["x.x.......x.....", "....x....x..x...", "..........x.....", "x.x.x.x.x.x.x.x."],
                      sounds: ["cassa boom bap", "rullante boom bap", "aperto morbido", "charleston secco"],
                      swing: 0.57, ref: "Nas · N.Y. State of Mind (1994, DJ Premier)"),
        // documentato: trascrizione di Dean McCormick; due casse subito dopo ogni rullante
        TX6DrumPreset(name: "Mass Appeal", group: "hip hop", bpm: 96,
                      rows: ["x.....xx..x...xx", "....x.......x...", "................", "x.x.x.x.x.x.x.x."],
                      sounds: ["cassa boom bap", "rullante boom bap", "aperto morbido", "charleston secco"],
                      swing: 0.54, ref: "Gang Starr · Mass Appeal (1994, DJ Premier)"),
        // documentato: trascrizione a mano di 4 battute; il ride dei «e» qui è un charleston aperto morbido
        TX6DrumPreset(name: "The World", group: "hip hop", bpm: 87,
                      rows: ["x.x.....x.x.....", "....x.......x...", "..x...x...x...x.", "x...x...x...x..."],
                      sounds: ["cassa boom bap", "rullante pieno", "aperto morbido", "charleston secco"],
                      swing: 0.58, ref: "Nas · The World Is Yours (1994, Pete Rock)"),
        // documentato: trascrizione a mano del 2011; charleston aperto sul 2a
        TX6DrumPreset(name: "Gin & Juice", group: "hip hop", bpm: 95,
                      rows: ["x.........x.....", "....x.......x...", ".......x........", "x.x.x.x.x.x.x.x."],
                      sounds: ["cassa g-funk", "rullante pieno", "aperto", "chiuso"],
                      swing: 0.55, ref: "Snoop Doggy Dogg · Gin and Juice (1993, Dr. Dre)"),
        // documentato: due trascrizioni a mano e un MIDI coincidono; battimani e rullante insieme sul 2 e sul 4, come nel G-funk
        TX6DrumPreset(name: "G Thang", group: "hip hop", bpm: 95,
                      rows: ["x.....x.x.....x.", "....x.......x...", "....x.......x...", "x.x.x.x.x.x.x.x."],
                      sounds: ["808 lunga", "battimani", "rullante pieno", "chiuso"],
                      swing: 0.55, ref: "Dr. Dre & Snoop Dogg · Nuthin' but a 'G' Thang (1992)"),

        // ELETTRONICA
        // documentato: Attack Magazine e MusicRadar; 909 spinta, aperto sui controtempi
        TX6DrumPreset(name: "The Bells", group: "elettronica", bpm: 137,
                      rows: ["x...x...x...x...", "....x.......x...", "..x...x...x...x.", ".x.x.x.x.x.x.x.x"],
                      sounds: ["cassa 909", "battimani", "aperto 909", "chiuso 909"],
                      swing: 0.5, ref: "Jeff Mills · The Bells (1997), techno di Detroit"),
        // documentato: Pocket Operations; la cassa 1·7·11·14 dell'electro. Il campanaccio della 808 è tolto: sul TX-6 era un bip
        TX6DrumPreset(name: "Planet Rock", group: "elettronica", bpm: 127,
                      rows: ["x.....x...x..x..", "....x.......x...", "....x.......x...", "x.xxx.xxx.xxxxxx"],
                      sounds: ["808 lunga", "battimani", "rullante secco", "chiuso"],
                      swing: 0.5, ref: "Afrika Bambaataa · Planet Rock (1982), electro"),
        // documentato: Native Instruments, ogni passo scritto; lo shaker è un charleston scuro e corto
        TX6DrumPreset(name: "Afterlife", group: "elettronica", bpm: 122,
                      rows: ["x...x...x...x...", "....x.......x...", "..x...x...x...x.", "...xxx....x.xxx."],
                      sounds: ["cassa techno", "battimani lunghi", "aperto morbido", "charleston polvere"],
                      swing: 0.5, ref: "Tale Of Us / Afterlife, techno melodica"),
        // documentato: Native Instruments (Adam Beyer, Charlotte de Witte, Amelie Lens)
        TX6DrumPreset(name: "Peak time", group: "elettronica", bpm: 135,
                      rows: ["x...x...x...x...", "....x.......x...", "..x...x...x...x.", "xx..xx..xx..xx.."],
                      sounds: ["cassa techno", "battimani", "aperto 909", "chiuso 909"],
                      swing: 0.5, ref: "Amelie Lens / Charlotte de Witte, techno di oggi"),
        // documentato: Attack Magazine «Sub-Zero Minimal Techno»; lo swing fa il groove
        TX6DrumPreset(name: "Minimal", group: "elettronica", bpm: 127,
                      rows: ["x...x...x...x...", "....x.......x...", "...x..x..x......", "..x...xx..x...x."],
                      sounds: ["cassa 909", "rullante secco", "cerchio", "chiuso 909"],
                      swing: 0.6, ref: "Richie Hawtin / Plastikman, minimal"),

        // DANCE
        // documentato: Pocket Operations «Deep House»; il disco è fatto con 909 e Juno-60
        TX6DrumPreset(name: "Deep house", group: "dance", bpm: 120,
                      rows: ["x...x...x...x...", "....x.......x...", "..x...x...x...x.", ".x.....x.x......"],
                      sounds: ["cassa house", "battimani", "aperto 909", "chiuso"],
                      swing: 0.54, ref: "Larry Heard (Mr. Fingers) · Can You Feel It (1986)"),
        // documentato: Attack Magazine «80s Chicago House»; il colpo sul cerchio fa il «jack»
        TX6DrumPreset(name: "Chicago", group: "dance", bpm: 120,
                      rows: ["x...x...x...x.x.", "....x.......x..x", ".x.....x..x..x..", "xxxxxxxxxxxxxxxx"],
                      sounds: ["cassa house", "battimani", "cerchio", "charleston secco"],
                      swing: 0.54, ref: "Frankie Knuckles · Your Love, house di Chicago"),
        // documentato: Attack Magazine «Raw French House» (il beat di Homework); swing forte
        TX6DrumPreset(name: "French", group: "dance", bpm: 124,
                      rows: ["x...x...x...x...", "....x.......x...", "..x...x...x...x.", "xx.xxx.xxx.xxx.x"],
                      sounds: ["cassa 909", "battimani", "aperto 909", "charleston secco"],
                      swing: 0.62, ref: "Daft Punk · Homework (1997), French house"),
        // documentato: Attack Magazine (Classmatic «Catuca»); la tech house dei club di oggi
        TX6DrumPreset(name: "Tech house", group: "dance", bpm: 125,
                      rows: ["x...x...x...x...", "....x.......x..x", "..x...x...x...x.", "xx.x.x.xxx.xxx.x"],
                      sounds: ["808 lunga", "battimani", "aperto 909", "chiuso 909"],
                      swing: 0.5, ref: "Classmatic / Fisher, tech house"),
        // documentato: Pocket Operations «UK Garage»; il 2-step vuole lo swing in terzina
        TX6DrumPreset(name: "UK garage", group: "dance", bpm: 132,
                      rows: ["x.........x.....", "....x.......x...", ".x.....x.....x..", "..xx..x...x...xx"],
                      sounds: ["cassa house", "battimani", "cerchio", "chiuso"],
                      swing: 0.66, ref: "MJ Cole / Artful Dodger, UK garage 2-step"),
    ]
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
