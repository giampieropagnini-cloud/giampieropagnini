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
enum TP7Tables {
    static let all: [TableSection] = [
        TableSection(
            title: "cosa capisce · dal telefono al TP-7",
            intro: "Tabella ufficiale della guida teenage engineering. I valori acceso/spento: 0-63 spento, 64-127 acceso.",
            rows: [
                TableRow(key: "note on / off", what: "cue: ogni nota 0-127 è un cue", more: "Con il CC 16 acceso (o tenendo ● sulla macchina) la nota segna il cue dove passa il nastro; spento lo richiama. Serve l'opzione MIDI dei cue sul TP-7."),
                TableRow(key: "pitch bend", what: "velocità di riproduzione", more: "Da ×0,25 (−8192) a ×2 (+8191). Solo mentre suona; il display non la mostra e si moltiplica con la SPD della macchina."),
                TableRow(key: "cc 7 · ch 1-6", what: "volume della traccia (il canale è la traccia)", more: "Torna al massimo quando un cue o un loop cambia traccia."),
                TableRow(key: "cc 120 · ch 1-6", what: "muto della traccia", more: "Il CC 120 è anche il «panico» di molti programmi: un panico toglie o mette i muti."),
                TableRow(key: "cc 9 · ch 1-3", what: "guadagno dell'ingresso 1-3, da 0 a 42 dB"),
                TableRow(key: "cc 14", what: "arma la registrazione", more: "Solo arma: la registrazione parte dalla macchina."),
                TableRow(key: "cc 16", what: "modo «segna cue»"),
                TableRow(key: "cc 17", what: "loop: 1 inizio, 2 fine, 0 spento", more: "Sempre in quest'ordine: senza l'inizio la fine non fa niente, e a loop acceso si può solo spegnere.", community: true),
                TableRow(key: "cc 18", what: "la leva (avanti e indietro)", more: "Vedi la tabella della leva qui sotto.")
            ]
        ),
        TableSection(
            title: "la leva · cc 18",
            intro: "Prove della community sul firmware 1.1.11. La leva finta ha due comportamenti diversi: da fermo e mentre suona.",
            rows: [
                TableRow(key: "da fermo · 0", what: "indietro velocissimo", community: true),
                TableRow(key: "da fermo · 1-59", what: "indietro, più piano man mano che sale", community: true),
                TableRow(key: "da fermo · 60", what: "indietro a velocità normale", community: true),
                TableRow(key: "da fermo · 61-63", what: "indietro piano", community: true),
                TableRow(key: "da fermo · 64", what: "fermo (leva al centro)", community: true),
                TableRow(key: "da fermo · 65-67", what: "avanti piano", community: true),
                TableRow(key: "da fermo · 68", what: "avanti a velocità normale: il «play» che al MIDI manca", community: true),
                TableRow(key: "da fermo · 69-127", what: "avanti sempre più veloce", community: true),
                TableRow(key: "mentre suona · 64", what: "lascia suonare normalmente", community: true),
                TableRow(key: "mentre suona · 0-60", what: "tira indietro, fino al contrario veloce", community: true),
                TableRow(key: "mentre suona · 61-127", what: "spinge avanti", community: true),
                TableRow(key: "mentre suona · 60 + pb +708", what: "fermo: è l'unico modo di fermarlo via MIDI", community: true)
            ]
        ),
        TableSection(
            title: "velocità · pitch bend",
            intro: "Sotto lo zero va da ×1 a ×0,25, sopra da ×1 a ×2: non è simmetrico.",
            rows: [
                TableRow(key: "−8192", what: "×0,25", community: true),
                TableRow(key: "−5461", what: "×0,50", community: true),
                TableRow(key: "0", what: "×1", community: true),
                TableRow(key: "+708", what: "×1,09 · il compenso dello stop", community: true),
                TableRow(key: "+4096", what: "×1,50", community: true),
                TableRow(key: "+8191", what: "×2", community: true)
            ]
        ),
        TableSection(
            title: "cosa manda · dal TP-7 (modalità ctrl)",
            intro: "Tutto sul canale 1. I tasti mandano 127 quando li premi e 0 quando li lasci. In ctrl i comandi non muovono più il nastro.",
            rows: [
                TableRow(key: "cc 20 · cc 21", what: "▲ su · ▼ giù (tasti sul fianco destro)"),
                TableRow(key: "cc 22 · 23 · 24", what: "● rec · ▶ play · ■ stop"),
                TableRow(key: "cc 25 · cc 26", what: "− · + (nella guida left e right)"),
                TableRow(key: "cc 27", what: "M memo"),
                TableRow(key: "cc 28", what: "mode", more: "Non è nella tabella ufficiale.", community: true),
                TableRow(key: "cc 30", what: "bobina, relativa", more: "1-63 un verso, 65-127 l'altro (complemento a due). Circa 60 messaggi al secondo mentre giri."),
                TableRow(key: "pitch bend", what: "leva, da −8192 a +8191", more: "Torna a 0 quando la lasci.")
            ]
        ),
        TableSection(
            title: "le strade",
            rows: [
                TableRow(key: "USB-C", what: "MIDI e scheda audio 6×6, 24 bit / 96 kHz, senza driver", more: "Su Mac e iPhone il MIDI compare col nome TP-7."),
                TableRow(key: "bluetooth LE", what: "solo MIDI, niente audio", more: "Menu BLE: accept (aspetta), scan (si collega al dispositivo più vicino), off. Sul Mac compare come TP-7 Bluetooth.", community: true),
                TableRow(key: "minijack", what: "solo audio: niente MIDI sui tre jack"),
                TableRow(key: "sysex TE", what: "saluto e versione del firmware, passaggio ai file (MTP)", more: "F0 00 20 76 19 40 60 01 01 F7 chiede il saluto; la risposta dice firmware e seriale.", community: true)
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
