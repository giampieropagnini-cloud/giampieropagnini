import Foundation

// MARK: - Le batterie pronte di Crea (rifatte l'8/10/2026 dai dischi veri)
//
// Giampiero: «non sono assolutamente trip hop, non sono hip hop»; artisti di riferimento Portishead, Massive Attack,
// Tricky, Nas, Gang Starr, Guru, Snoop Dogg, e i DJ di elettronica e dance. Ogni ritmo viene da una trascrizione
// (lezioni di batteria, Songsterr fatto a mano, Attack Magazine «Beat Dissected», Pocket Operations, Frane 2017
// sullo swing dei breakbeat): «documentato» o «ricostruito» è scritto accanto. Il TX-6 suona una batteria
// sintetizzata, non i breakbeat campionati dei dischi: ritmo, tempo, swing e accordatura sì, il suono identico no.
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
                      rows: ["x.xx...xx..x...x", "....x.......x...", ".x.....x.x.....x", "x.x.x.x.x.x.x.x."],
                      sounds: ["cassa trip hop", "rullante secco", "fantasma", "charleston polvere"],
                      swing: 0.54, ref: "Portishead · Sour Times (1994)"),
        // documentato: Songsterr a mano; il giro è Isaac Hayes «Ike's Rap II» (anche Tricky, «Hell Is Round the Corner»)
        TX6DrumPreset(name: "Glory Box", group: "trip hop", bpm: 60,
                      rows: ["x......xx.......", "....x.......x...", "................", "x.x.x.x.x.x.x.x."],
                      sounds: ["cassa trip hop", "rullante trip hop", "fantasma", "charleston polvere"],
                      swing: 0.64, ref: "Portishead · Glory Box (1994)"),
        // documentato: Songsterr a mano e il file MIDI di BitMidi coincidono; rullante = colpo sul cerchio
        TX6DrumPreset(name: "Teardrop", group: "trip hop", bpm: 77,
                      rows: ["xx.x....xx.x....", "....x.......x...", "..x.......x.....", "x.x.x.x.x.x.x.x."],
                      sounds: ["cassa trip hop", "rimshot", "aperto morbido", "charleston polvere"],
                      swing: 0.5, ref: "Massive Attack · Teardrop (1998)"),
        // documentato: Songsterr (rivisto da un moderatore); a metà tempo, rullante sul 3
        TX6DrumPreset(name: "Angel", group: "trip hop", bpm: 104,
                      rows: ["x..............x", "........x.......", "..........x.....", "x.x.x.x.x...x.x."],
                      sounds: ["cassa lontana", "rullante pieno", "aperto morbido", "charleston polvere"],
                      swing: 0.5, ref: "Massive Attack · Angel (1998)"),
        // ricostruito (trascrizione automatica); lo swing 1,6:1 del break è misurato (Frane 2017)
        TX6DrumPreset(name: "Aftermath", group: "trip hop", bpm: 81,
                      rows: ["x.....x.x.....x.", "....x.......x...", "xxxxxxxxxxxxxxxx", "x.x.x.x.x.x.x.x."],
                      sounds: ["cassa trip hop", "rullante trip hop", "tamburello", "charleston polvere"],
                      swing: 0.61, ref: "Tricky · Aftermath (1995)"),

        // HIP HOP
        // documentato: drummingtips.com e Songsterr; il rullante in più sul 3e (passo 10) è la firma di Premier
        TX6DrumPreset(name: "NY State", group: "hip hop", bpm: 84,
                      rows: ["x.x.......x.....", "....x....x..x...", "..........x.....", "x.x.x.x.x.x.x.x."],
                      sounds: ["cassa boom bap", "rullante sordo", "aperto morbido", "charleston secco"],
                      swing: 0.57, ref: "Nas · N.Y. State of Mind (1994, DJ Premier)"),
        // documentato: trascrizione di Dean McCormick; due casse subito dopo ogni rullante
        TX6DrumPreset(name: "Mass Appeal", group: "hip hop", bpm: 96,
                      rows: ["x.....xx..x...xx", "....x.......x...", ".......x.......x", "x.x.x.x.x.x.x.x."],
                      sounds: ["cassa boom bap", "rullante boom bap", "fantasma", "charleston secco"],
                      swing: 0.54, ref: "Gang Starr · Mass Appeal (1994, DJ Premier)"),
        // documentato: trascrizione a mano di 4 battute; campanaccio del ride sui «e»
        TX6DrumPreset(name: "The World", group: "hip hop", bpm: 88,
                      rows: ["x.x.....x.x.....", "....x.......x...", "..x...x...x...x.", "x.x.x.x.x.x.x.x."],
                      sounds: ["cassa boom bap", "rullante boom bap", "ride", "charleston secco"],
                      swing: 0.58, ref: "Nas · The World Is Yours (1994, Pete Rock)"),
        // documentato: trascrizione a mano del 2011; tamburello in ottavi, charleston aperto sul 2a
        TX6DrumPreset(name: "Gin & Juice", group: "hip hop", bpm: 95,
                      rows: ["x.........x.....", "....x.......x...", ".......x........", "x.x.x.x.x.x.x.x."],
                      sounds: ["cassa g-funk", "rullante pieno", "aperto morbido", "tamburello"],
                      swing: 0.55, ref: "Snoop Doggy Dogg · Gin and Juice (1993, Dr. Dre)"),
        // documentato: due trascrizioni a mano e un MIDI coincidono; tamburello in sedicesimi
        TX6DrumPreset(name: "G Thang", group: "hip hop", bpm: 95,
                      rows: ["x.....x.x.....x.", "....x.......x...", "xxxxxxxxxxxxxxxx", "x.x.x.x.x.x.x.x."],
                      sounds: ["cassa g-funk", "battimani", "tamburello", "charleston secco"],
                      swing: 0.55, ref: "Dr. Dre & Snoop Dogg · Nuthin' but a 'G' Thang (1992)"),

        // ELETTRONICA
        // documentato: Attack Magazine e MusicRadar; 909 spinta, charleston aperto lungo, ride in ottavi
        TX6DrumPreset(name: "The Bells", group: "elettronica", bpm: 137,
                      rows: ["x...x...x...x...", "....x.......x...", "..x...x...x...x.", "x.x.x.x.x.x.x.x."],
                      sounds: ["cassa 909", "battimani", "aperto 909", "chiuso 909"],
                      swing: 0.5, ref: "Jeff Mills · The Bells (1997), techno di Detroit"),
        // documentato: Pocket Operations; la cassa 1·7·11·14 dell'electro, il campanaccio della 808
        TX6DrumPreset(name: "Planet Rock", group: "elettronica", bpm: 127,
                      rows: ["x.....x...x..x..", "....x.......x...", "x.x.x.xx.x.xx.x.", "x.xxx.xxx.xxxxxx"],
                      sounds: ["808 lunga", "battimani", "cowbell", "chiuso 909"],
                      swing: 0.5, ref: "Afrika Bambaataa · Planet Rock (1982), electro"),
        // documentato: Native Instruments, ogni passo scritto; techno melodica dell'etichetta Afterlife
        TX6DrumPreset(name: "Afterlife", group: "elettronica", bpm: 122,
                      rows: ["x...x...x...x...", "....x.......x...", "...xxx....x.xxx.", "x.xxxxx.x..xxxxx"],
                      sounds: ["cassa techno", "battimani", "shaker", "chiuso 909"],
                      swing: 0.5, ref: "Tale Of Us / Afterlife, techno melodica"),
        // documentato: Native Instruments (Adam Beyer, Charlotte de Witte, Amelie Lens)
        TX6DrumPreset(name: "Peak time", group: "elettronica", bpm: 135,
                      rows: ["x...x...x...x...", "....x.......x...", "..x...x...x...x.", "xx..xx..xx..xx.."],
                      sounds: ["cassa techno", "battimani", "aperto 909", "chiuso 909"],
                      swing: 0.5, ref: "Amelie Lens / Charlotte de Witte, techno di oggi"),
        // documentato: Attack Magazine «Sub-Zero Minimal Techno»; lo swing fa il groove
        TX6DrumPreset(name: "Minimal", group: "elettronica", bpm: 127,
                      rows: ["x...x...x...x...", "....x.......x..x", "...x..x..x......", "..x...xx..x...x."],
                      sounds: ["cassa 909", "rullante secco", "rimshot", "chiuso 909"],
                      swing: 0.6, ref: "Richie Hawtin / Plastikman, minimal"),

        // DANCE
        // documentato: Pocket Operations «Deep House»; il disco è fatto con 909 e Juno-60
        TX6DrumPreset(name: "Deep house", group: "dance", bpm: 119,
                      rows: ["x...x...x...x...", "....x.......x...", "..x...x...x...x.", ".x.....x.x......"],
                      sounds: ["cassa house", "battimani", "aperto 909", "chiuso 909"],
                      swing: 0.54, ref: "Larry Heard (Mr. Fingers) · Can You Feel It (1986)"),
        // documentato: Attack Magazine «80s Chicago House»; il rimshot fa il «jack»
        TX6DrumPreset(name: "Chicago", group: "dance", bpm: 120,
                      rows: ["x...x...x...x.x.", "....x.......x..x", ".x.....x..x..x..", "xxxxxxxxxxxxxxxx"],
                      sounds: ["cassa house", "battimani", "rimshot", "chiuso 909"],
                      swing: 0.54, ref: "Frankie Knuckles · Your Love, house di Chicago"),
        // documentato: Attack Magazine «Raw French House» (il beat di Homework); swing forte
        TX6DrumPreset(name: "French", group: "dance", bpm: 124,
                      rows: ["x...x...x...x...", "....x.......x...", "..x...x...x...x.", "xxxxxxxxxxxxxxxx"],
                      sounds: ["cassa sorda", "battimani", "aperto 909", "chiuso 909"],
                      swing: 0.62, ref: "Daft Punk · Homework (1997), French house"),
        // documentato: Attack Magazine (Classmatic «Catuca»); la tech house dei club di oggi
        TX6DrumPreset(name: "Tech house", group: "dance", bpm: 128,
                      rows: ["x...x...x...x...", "....x.......x..x", "..x...x...x...x.", "xx.x.x.xxx.xxx.x"],
                      sounds: ["808 lunga", "battimani", "aperto 909", "chiuso 909"],
                      swing: 0.5, ref: "Classmatic / Fisher, tech house"),
        // documentato: Pocket Operations «UK Garage»; il 2-step vuole lo swing in terzina
        TX6DrumPreset(name: "UK garage", group: "dance", bpm: 130,
                      rows: ["x.........x.....", "....x.......x...", ".x.....x.....x..", "..xx..x...x...xx"],
                      sounds: ["cassa corta", "battimani", "rimshot", "chiuso 909"],
                      swing: 0.66, ref: "MJ Cole / Artful Dodger, UK garage 2-step"),
    ]
}
