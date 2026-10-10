import SwiftUI

// MARK: - la sezione Playdate

/// Una schermata sola: il filo verso il ponte, da quale macchina arrivano le note, il tempo, la prova.
struct PlaydateTabs: View {
    @EnvironmentObject var link: PlaydateLink

    private let grid = [GridItem(.adaptive(minimum: 92), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    PlaydateBanner()
                    PlaydateStatusStrip()

                    Card(title: "le note di Crea",
                         note: "Le tracce del TX-6 su «suono MIDI» suonano sul Playdate, a tempo. Il suono si cambia in Crea → batteria → riga della traccia. Una pronta rimette il suono del TX-6 e il Playdate tace da solo.") {
                        Chip(text: link.creaOn ? "tracce su suono MIDI al Playdate: sì" : "tracce su suono MIDI al Playdate: no",
                             on: link.creaOn, color: Playdate.color) { link.creaOn.toggle() }
                        Text(link.midiTracks.isEmpty ? "nessuna traccia su suono MIDI" : "su suono MIDI adesso: traccia " + link.midiTracks.map(String.init).joined(separator: ", "))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Palette.dim)
                    }

                    Card(title: "da quale macchina",
                         note: "Le note che questa macchina manda a Bobina vanno anche al Playdate. Sul TX-6: una traccia col suono MIDI.") {
                        LazyVGrid(columns: grid, alignment: .leading, spacing: 8) {
                            Chip(text: "nessuna", on: link.sourceName.isEmpty, color: Playdate.color) { link.sourceName = "" }
                            ForEach(link.sources, id: \.self) { name in
                                Chip(text: name, on: link.sourceName == name, color: Playdate.color) { link.sourceName = name }
                            }
                        }
                        if !link.sourceName.isEmpty && !link.sources.contains(where: { $0 == link.sourceName || (PlaydateLink.family(of: $0) != nil && PlaydateLink.family(of: $0) == PlaydateLink.family(of: link.sourceName)) }) {
                            Text("\(link.sourceName) adesso non è collegato: appena torna, Bobina lo riascolta.")
                                .font(.footnote)
                                .foregroundStyle(Palette.dim)
                        }
                    }

                    Card(title: "quale traccia", note: "Sul TX-6 il canale è la traccia: 1-6, e 7 la batteria.") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 8)], alignment: .leading, spacing: 8) {
                            Chip(text: "tutte", on: link.channel == 0, color: Playdate.color) { link.channel = 0 }
                            ForEach(1...7, id: \.self) { c in
                                Chip(text: "\(c)", on: link.channel == c, color: Playdate.color) { link.channel = c }
                            }
                        }
                        .accessibilityElement(children: .contain)
                    }

                    Card(title: "cosa va al Playdate") {
                        LazyVGrid(columns: grid, alignment: .leading, spacing: 8) {
                            Chip(text: link.notesOn ? "note: sì" : "note: no", on: link.notesOn, color: Playdate.color) { link.notesOn.toggle() }
                            Chip(text: link.clockOn ? "tempo: sì" : "tempo: no", on: link.clockOn, color: Playdate.color) { link.clockOn.toggle() }
                        }
                        Text("Il tempo è quello di Bobina: quando il ritmo gira, va al modulo Serial Clock Input.")
                            .font(.footnote)
                            .foregroundStyle(Palette.dim)
                    }

                    Card(title: "prova", note: "Nel gioco: Serial Interface → Serial Note Input, col cavo verso un synth.") {
                        Chip(text: "nota di prova", color: Playdate.color) { link.testNote() }
                        Text(link.sentNotes == 0 ? "nessuna nota mandata" : "note mandate: \(link.sentNotes) · ultima: \(PlaydateTabs.noteName(link.lastNote))")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Palette.dim)
                    }

                    Card(title: "tastiera degli amici",
                         note: "Un amico sul Wi-Fi di casa inquadra il codice QR in fondo alla pagina del Playdate: gli si apre una tastiera. Le note per le macchine passano da qui, quindi Bobina deve restare aperta.") {
                        Chip(text: link.friendsOn ? "gli amici suonano le macchine: sì" : "gli amici suonano le macchine: no",
                             on: link.friendsOn, color: Playdate.color) { link.friendsOn.toggle() }
                        Text(link.friendNotes == 0 ? "nessuna nota dagli amici" : "note dagli amici: \(link.friendNotes) · ultima: \(link.lastFriend)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Palette.dim)
                        Text(link.destinations.isEmpty ? "nessuna macchina collegata a Bobina" : "sulla tastiera: Playdate, " + link.destinations.joined(separator: ", "))
                            .font(.footnote)
                            .foregroundStyle(Palette.dim)
                        Text("Agli amici si offrono solo NTS-1 e OP-Z (tracce 1-8). Attento: se l'OP-Z sta registrando (REC + PLAY), le note degli amici finiscono nel suo pattern.")
                            .font(.footnote)
                            .foregroundStyle(Palette.dim)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Card(title: "dov'è il ponte") {
                        LazyVGrid(columns: grid, alignment: .leading, spacing: 8) {
                            ForEach(Playdate.hosts, id: \.1) { h in
                                Chip(text: h.0, on: link.host == h.1, color: Playdate.color) { link.host = h.1 }
                            }
                        }
                        if let url = URL(string: Playdate.remote) {
                            Link("apri lo schermo del Playdate", destination: url)
                                .font(.system(.subheadline, design: .monospaced))
                        }
                        Text("Lo schermo si apre nel browser. Mentre sei lì Bobina va in secondo piano e le note si fermano: per suonare col TX-6 resta in Bobina.")
                            .font(.footnote)
                            .foregroundStyle(Palette.dim)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 24)
            }
            .navigationTitle("Playdate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { MachineSwitch() } }
        }
        .tint(Playdate.color)
    }

    static func noteName(_ note: UInt8?) -> String {
        guard let n = note else { return "–" }
        let names = ["do", "do♯", "re", "re♯", "mi", "fa", "fa♯", "sol", "sol♯", "la", "la♯", "si"]
        return "\(names[Int(n) % 12])\(Int(n) / 12 - 1)"
    }
}

struct PlaydateBanner: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("Playdate")
                .font(.system(.title2, design: .rounded).weight(.bold))
            Text("Panic · Modular Play")
                .font(.system(.subheadline, design: .monospaced))
                .opacity(0.75)
            Spacer()
        }
        .foregroundStyle(Color.black)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Playdate.color))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Playdate")
    }
}

/// Verde se Bobina parla col ponte, rosso se no.
struct PlaydateStatusStrip: View {
    @EnvironmentObject var link: PlaydateLink

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(link.connected ? Color.green : Palette.rec)
                .frame(width: 8, height: 8)
            Text(link.connected ? "collegato al ponte · \(Playdate.hosts.first { $0.1 == link.host }?.0 ?? link.host)"
                                : "ponte non raggiunto · il Mac è acceso?")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
                .lineLimit(1)
            Spacer()
        }
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
    }
}
