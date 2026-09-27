import SwiftUI

/// Una riga di tabella: il messaggio, cosa fa, e una nota facoltativa.
struct TableRow: Identifiable {
    let id = UUID()
    let key: String
    let what: String
    var more: String? = nil
    var community = false
}

struct TableSection: Identifiable {
    let id = UUID()
    let title: String
    var intro: String? = nil
    let rows: [TableRow]
}

/// Tutte le tabelle MIDI del TP-7 (firmware 1.1.11), da tenere in tasca.
/// «community» = misurato da chi l'ha provato, non scritto nella guida.
enum TP7Tables {
    static let all: [TableSection] = [
        TableSection(
            title: "le modalità · tieni mode → MIDI",
            intro: "Quattro voci. Di fabbrica è off.",
            rows: [
                TableRow(key: "off", what: "ascolta i comandi: cc, pitch bend, start/continue/stop", more: "Non manda niente.", community: true),
                TableRow(key: "cue", what: "ascolta i comandi e le note diventano cue", more: "La modalità per i pad.", community: true),
                TableRow(key: "sync", what: "ascolta i comandi e manda il suo clock", more: "Clock a 24 impulsi per quarto, solo mentre il nastro gira, al tempo del file per la velocità reale. Il clock in arrivo lo ignora. Le note qui non fanno cue.", community: true),
                TableRow(key: "ctrl", what: "diventa un controller: manda i suoi tasti, non ascolta niente", more: "Entrando si ferma. Resta così anche scollegato; il memo da spento registra lo stesso.", community: true)
            ]
        ),
        TableSection(
            title: "trasporto · messaggi in tempo reale",
            intro: "Non sono nella tabella ufficiale, ma funzionano su off, cue e sync.",
            rows: [
                TableRow(key: "FA · start", what: "riavvolge all'inizio e suona", community: true),
                TableRow(key: "FB · continue", what: "suona da dove si trova", more: "Rimette anche la leva a velocità normale.", community: true),
                TableRow(key: "FC · stop", what: "si ferma dov'è", more: "Un secondo stop da fermo riavvolge all'inizio. Toglie anche l'armamento.", community: true),
                TableRow(key: "cc 14 = 127, poi FB", what: "registra: nasce un file nuovo; FC chiude la ripresa", community: true),
                TableRow(key: "F8 · clock", what: "ignorato: il TP-7 non segue il tempo di nessuno", community: true)
            ]
        ),
        TableSection(
            title: "cosa capisce · controlli",
            intro: "Tabella ufficiale della guida, con le misure della community. Acceso/spento: 0-63 spento, 64-127 acceso.",
            rows: [
                TableRow(key: "note on 0-127", what: "cue: la nota si lega al punto dove la segni, poi lo richiama", more: "Per segnare: MIDI su cue e ● tenuto sulla macchina (o cc 16 acceso). Per richiamare: la stessa nota. Il salto fa partire il nastro. Via MIDI i cue non si cancellano."),
                TableRow(key: "note off", what: "nella tabella ufficiale, ma nessuno ha visto un effetto"),
                TableRow(key: "pitch bend", what: "velocità da ×0,5 a ×2 (vedi sotto)", more: "Solo mentre suona; resta anche dopo stop e play, si moltiplica con la SPD della macchina e il display non la mostra."),
                TableRow(key: "cc 7 · ch 1-6", what: "volume della traccia: il canale è la traccia", more: "Si vede nel MIX della macchina. Torna al massimo quando un cue o un loop cambia traccia."),
                TableRow(key: "cc 120 · ch 1-6", what: "muto della traccia: 127 muto, 0 acceso", more: "Assoluto, non un interruttore. Attenzione: per il resto del mondo il cc 120 è «panico» (all sound off)."),
                TableRow(key: "cc 9 · ch 1-3", what: "guadagno del minijack 1-3: dB = valore × 42 / 127", more: "Prima del mixer, solo per quello che entra dal vivo. I canali 4-6 non fanno niente."),
                TableRow(key: "cc 14", what: "arma la registrazione (lampeggia rosso)", more: "Da sola non registra: serve FB."),
                TableRow(key: "cc 16", what: "modo «segna cue»", more: "Nelle misure della community non ha fatto niente di visibile: tenere ● sulla macchina è la strada sicura.", community: true),
                TableRow(key: "cc 17", what: "loop: 1 inizio, 2 fine, 0 spento", more: "Solo con la schermata LOOP aperta sulla macchina. Senza l'inizio la fine è ignorata; a loop acceso si può solo spegnere.", community: true),
                TableRow(key: "cc 18", what: "la leva: 64 centro, si somma al nastro", more: "Vedi la tabella della leva.")
            ]
        ),
        TableSection(
            title: "la leva · cc 18",
            intro: "Misurata: ogni passo dal centro aggiunge circa ×0,26 alla velocità del nastro, avanti o indietro. Agli estremi parte il riavvolgimento velocissimo.",
            rows: [
                TableRow(key: "da fermo · 64", what: "fermo", community: true),
                TableRow(key: "da fermo · 68", what: "avanti ×1 circa (misurato ×1,04)", community: true),
                TableRow(key: "da fermo · 72 · 76", what: "avanti ×2 · ×3 circa", community: true),
                TableRow(key: "da fermo · 60", what: "indietro ×1", community: true),
                TableRow(key: "0 · 127", what: "riavvolge o manda avanti a ×250-300, dopo 2 secondi di rincorsa", community: true),
                TableRow(key: "suona · 64", what: "non cambia niente: il nastro continua (non si ferma)", community: true),
                TableRow(key: "suona · 70", what: "circa ×2,4", community: true),
                TableRow(key: "suona · 61", what: "quasi fermo in avanti (×0,2)", community: true),
                TableRow(key: "suona · 60 + pb +708", what: "fermo come sotto il dito", more: "Byte: B0 12 3C e E0 44 45.", community: true),
                TableRow(key: "suona · 56 + pb 9700", what: "indietro esatto a ×1", more: "Byte: B0 12 38 e E0 64 4B.", community: true)
            ]
        ),
        TableSection(
            title: "velocità · pitch bend",
            intro: "Misurato: velocità ≈ 2 elevato a (bend / 8192). Un'ottava sotto, un'ottava sopra. Non fa niente a nastro fermo.",
            rows: [
                TableRow(key: "−8192", what: "×0,5", community: true),
                TableRow(key: "−4096", what: "×0,7", community: true),
                TableRow(key: "0", what: "×1", community: true),
                TableRow(key: "+4096", what: "×1,4", community: true),
                TableRow(key: "+8191", what: "×2", community: true)
            ]
        ),
        TableSection(
            title: "cosa manda · modalità ctrl",
            intro: "Tutto sul canale 1. Tasti: 127 quando li premi, 0 quando li lasci, niente ripetizione. A riposo è muto.",
            rows: [
                TableRow(key: "cc 20 · cc 21", what: "▲ · ▼ (fianco destro)"),
                TableRow(key: "cc 22 · 23 · 24", what: "● · ▶ · ■"),
                TableRow(key: "cc 25 · cc 26", what: "− · + (nella guida left e right)"),
                TableRow(key: "cc 27", what: "M memo (in ctrl non registra)"),
                TableRow(key: "cc 28", what: "mode", more: "Non è nella tabella ufficiale.", community: true),
                TableRow(key: "cc 30", what: "bobina, relativa: 1, 2, 3 in un verso · 127, 126, 125 nell'altro", more: "Più giri veloce, più alto il numero. Circa 60 messaggi al secondo. Mandato al TP-7 non fa niente."),
                TableRow(key: "pitch bend", what: "leva, da −8192 a +8191", more: "Non è la posizione ma una rampa morbida: 0 → massimo in 240 ms, torna a 0 in 290 ms quando la lasci.", community: true)
            ]
        ),
        TableSection(
            title: "ricette in byte",
            intro: "Dalle misure della community, in esadecimale.",
            rows: [
                TableRow(key: "FB", what: "play da dove sei", community: true),
                TableRow(key: "FA", what: "da capo", community: true),
                TableRow(key: "B0 12 40 · FC · E0 00 40", what: "stop pulito (solo se sta suonando)", community: true),
                TableRow(key: "B0 0E 7F · FB … FC", what: "registra una ripresa", community: true),
                TableRow(key: "B1 78 7F", what: "muta la traccia 2", community: true),
                TableRow(key: "B0 09 40", what: "minijack 1 a +21 dB", community: true),
                TableRow(key: "B0 11 01 … B0 11 02 … B0 11 00", what: "loop (schermata LOOP aperta)", community: true)
            ]
        ),
        TableSection(
            title: "sysex teenage engineering",
            intro: "F0 00 20 76 19 40 … F7. Il TP-7 è il numero 19 (TE025).",
            rows: [
                TableRow(key: "F0 7E 7F 06 01 F7", what: "chi sei? risponde con la famiglia 19", community: true),
                TableRow(key: "F0 00 20 76 19 40 60 01 01 F7", what: "saluto: risponde firmware, seriale, codice", community: true),
                TableRow(key: "F0 00 20 76 19 40 60 05 04 00 01 03 F7", what: "passa ai file (MTP): la scheda audio sparisce finché dura", community: true),
                TableRow(key: "comando 03", what: "aggiornamento firmware: non mandarlo mai", community: true)
            ]
        ),
        TableSection(
            title: "le strade",
            rows: [
                TableRow(key: "USB-C", what: "MIDI e scheda audio 6×6 (3 coppie stereo), 24 bit / 96 kHz, senza driver", more: "Il MIDI si chiama TP-7. Codici USB 2367:0019, e 2367:8019 per l'audio dalle ultime versioni."),
                TableRow(key: "bluetooth LE", what: "solo MIDI: accept (aspetta), scan (si collega da solo), off", more: "Si fa trovare solo col menu BLE aperto; un collegamento già fatto resta.", community: true),
                TableRow(key: "minijack", what: "solo audio: niente MIDI sui tre jack"),
                TableRow(key: "file", what: "MTP: cartelle recordings, library, memo", more: "Nomi data_ora.wav. Nei WAV il tempo sta nel pezzo «acid» (110 bpm se non lo cambi) e i cue nel pezzo «cue».", community: true)
            ]
        ),
        TableSection(
            title: "provati, non fanno niente",
            rows: [
                TableRow(key: "tutto in ctrl", what: "ignorato", community: true),
                TableRow(key: "cc 30 mandato", what: "la bobina non si muove", community: true),
                TableRow(key: "pitch bend da fermo", what: "il nastro resta fermo", community: true),
                TableRow(key: "clock in arrivo", what: "non lo segue", community: true),
                TableRow(key: "FC durante la leva", what: "la leva continua a portarlo", community: true),
                TableRow(key: "mai provati", what: "program change, MMC, song position, altri cc", community: true)
            ]
        )
    ]
}

struct TabelleView: View {
    var body: some View {
        List {
            ForEach(TP7Tables.all) { section in
                Section {
                    if let intro = section.intro {
                        Text(intro)
                            .font(.footnote)
                            .foregroundStyle(Palette.dim)
                    }
                    ForEach(section.rows) { row in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(row.key)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundStyle(Palette.accent)
                                if row.community {
                                    Text("community")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(Palette.dim)
                                        .padding(.horizontal, 4)
                                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Palette.dim, lineWidth: 0.5))
                                }
                            }
                            Text(row.what)
                                .font(.subheadline)
                            if let more = row.more {
                                Text(more)
                                    .font(.footnote)
                                    .foregroundStyle(Palette.dim)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text(section.title)
                }
            }
        }
        .navigationTitle("Tabelle MIDI")
        .navigationBarTitleDisplayMode(.inline)
    }
}
