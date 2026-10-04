import SwiftUI

// MARK: - Crea: Bobina suona l'OP-Z a passi, col suo clock

struct OPZCreaView: View {
    @EnvironmentObject var opz: OPZEngine

    private static let names = ["fa", "fa#", "sol", "sol#", "la", "si♭", "si", "do", "do#", "re", "mi♭", "mi"]

    /// Batteria: il suono 1-24 del kit. Synth: il nome della nota.
    private func label(_ note: Int) -> String {
        let k = note - OPZ.keyboardF
        if opz.createTrack <= 4 { return "\(k + 1)" }
        return OPZCreaView.names[k % 12] + (k >= 12 ? "↑" : "")
    }

    var body: some View {
        OPZPage(title: "Crea") {
            OPZTransport()

            Card(title: "Bobina suona l'OP-Z", note: "Scrivi i passi qui: Bobina li suona sull'OP-Z a tempo, insieme a TX-6 e Pocket Operator. Meglio un pattern vuoto sull'OP-Z, se no suonano anche i suoi passi.") {
                Toggle("Crea suona", isOn: $opz.createOn)
                HStack(spacing: 6) {
                    GridChip(text: "ritmo di partenza") { opz.starter() }
                    GridChip(text: "svuota la traccia") { opz.clearTrack() }
                    GridChip(text: "svuota tutto") { opz.clearAll() }
                }
            }

            Card(title: "traccia", note: "Sotto: accesa o spenta in Crea (i passi restano).") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(OPZ.tracks.prefix(8)) { t in
                        VStack(spacing: 3) {
                            Button { opz.createTrack = t.number } label: {
                                Text(opz.steps[t.number - 1].contains { !$0.isEmpty } ? "\(t.short)•" : t.short)
                                    .font(.system(.footnote, design: .monospaced).weight(opz.createTrack == t.number ? .bold : .regular))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(opz.createTrack == t.number ? OPZ.color(t.number) : OPZ.color(t.number).opacity(0.18)))
                                    .foregroundStyle(opz.createTrack == t.number ? Color.black : OPZ.color(t.number))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("scrivi \(t.name)")
                            .accessibilityAddTraits(opz.createTrack == t.number ? .isSelected : [])
                            Button { opz.trackOn[t.number - 1].toggle() } label: {
                                Text(opz.trackOn[t.number - 1] ? "accesa" : "spenta")
                                    .font(.system(.caption2, design: .monospaced))
                                    .frame(maxWidth: .infinity, minHeight: 32)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(opz.trackOn[t.number - 1] ? Color(white: 0.22) : Color(white: 0.1)))
                                    .foregroundStyle(opz.trackOn[t.number - 1] ? Color.white : Palette.dim)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(opz.trackOn[t.number - 1] ? "spegni \(t.name)" : "accendi \(t.name)")
                        }
                    }
                }
            }

            Card(title: opz.createTrack <= 4 ? "suono" : "nota", note: opz.createTrack <= 4 ? "I 24 suoni del kit di questa traccia. Toccane uno: lo senti e diventa quello che metti nei passi." : "Due ottave, come la tastiera dell'OP-Z. Toccane una: la senti e diventa quella che metti nei passi.") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 6), spacing: 5) {
                    ForEach(OPZ.keyboardF...(OPZ.keyboardF + 23), id: \.self) { n in
                        GridChip(text: label(n), on: opz.pick == n) { opz.audition(n) }
                            .accessibilityLabel(opz.createTrack <= 4 ? "suono \(n - OPZ.keyboardF + 1)" : "nota \(label(n))")
                    }
                }
            }

            Card(title: "passi · \(OPZ.track(opz.createTrack).name)", note: "Tocca un passo per mettere o togliere «\(label(opz.pick))». Il numero piccolo dice quante note ci sono.") {
                OPZStepCells(live: opz.live, count: { opz.steps[opz.createTrack - 1][$0].count },
                             has: { opz.hasStep($0) }, color: OPZ.color(opz.createTrack),
                             tap: { opz.toggleStep($0) })
            }

            Card(title: "scrivi sull'OP-Z", note: "Per mettere questi passi dentro il pattern dell'OP-Z: Ele accende il record lock (tiene REC e preme PLAY). Poi tocca qui: Bobina suona i passi per una battuta sola, dall'inizio della battuta dopo. Da provare: è la prima volta.") {
                GridChip(text: opz.writing ? "sto scrivendo…" : "scrivi una battuta sull'OP-Z", on: opz.writing) { opz.writeOnce() }
                    .disabled(opz.writing)
            }
        }
    }
}

/// Sedici caselle. Guarda solo `live`: quando avanza il passo si ridisegnano queste, non la pagina.
struct OPZStepCells: View {
    @ObservedObject var live: OPZLive
    let count: (Int) -> Int
    let has: (Int) -> Bool
    let color: Color
    let tap: (Int) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 4), spacing: 5) {
            ForEach(0..<16, id: \.self) { i in
                let n = count(i)
                let mine = has(i)
                Button { tap(i) } label: {
                    VStack(spacing: 0) {
                        Text("\(i + 1)")
                            .font(.system(.body, design: .monospaced).weight(mine ? .bold : .regular))
                        Text(n > 0 ? String(repeating: "•", count: n) : " ")
                            .font(.system(.caption2, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(RoundedRectangle(cornerRadius: 8).fill(mine ? color : n > 0 ? color.opacity(0.3) : Color(white: i % 4 == 0 ? 0.22 : 0.16)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(live.step == i ? Color.white : Color.clear, lineWidth: 3))
                    .foregroundStyle(mine ? Color.black : Color.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("passo \(i + 1)")
                .accessibilityValue(mine ? "acceso" : n > 0 ? "altre note" : "vuoto")
            }
        }
    }
}
