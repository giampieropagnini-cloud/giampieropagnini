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

            Card(title: "pattern di Bobina", note: "16 pattern tutti di Bobina. Tocca un numero: lo scrivi qui sotto e suona dall'inizio della battuta dopo. Il bordo bianco è quello che sta suonando, il puntino dice che non è vuoto.") {
                OPZCreaPatterns(live: opz.live)
                HStack(spacing: 6) {
                    GridChip(text: "copia il \(opz.createPattern)") { opz.copyPattern() }
                    GridChip(text: "incolla nel \(opz.createPattern)") { opz.pastePattern() }
                        .disabled(opz.copied == nil)
                }
                HStack(spacing: 5) {
                    Text("passi")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                    ForEach(OPZEngine.lengthChoices, id: \.self) { l in
                        GridChip(text: "\(l)", on: opz.length == l) { opz.length = l }
                            .accessibilityLabel("\(l) passi")
                    }
                }
            }

            OPZChainCard()

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
                OPZStepCells(live: opz.live, length: opz.length, count: { opz.steps[opz.createTrack - 1][$0].count },
                             has: { opz.hasStep($0) }, color: OPZ.color(opz.createTrack),
                             tap: { opz.toggleStep($0) })
            }

            Card(title: "effetti di Bobina", note: "Lavorano sulle note di Crea, a tempo. Sopra: l'effetto per una battuta. Sotto: resta finché non tocchi «lascia».") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 8) {
                    ForEach(CreaFx.allCases) { f in
                        OPZCreaFxKey(fx: f, held: opz.fxHeld.contains(f))
                    }
                }
                HStack(spacing: 6) {
                    GridChip(text: "su tutte", on: opz.fxAll) { opz.fxAll = true }
                    GridChip(text: "solo \(OPZ.track(opz.createTrack).short)", on: !opz.fxAll) { opz.fxAll = false }
                    GridChip(text: "lascia tutti") { opz.creaFxReleaseAll() }
                }
            }

            Card(title: "effetti nei passi · pattern \(opz.createPattern)", note: "Scegli un effetto e quanto dura, poi tocca il passo dove comincia. Ritocca un passo dell'effetto per toglierlo tutto.") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3), spacing: 5) {
                    ForEach(CreaFx.allCases) { f in
                        Button { opz.fxPick = f } label: {
                            Text(f.name)
                                .font(.system(.footnote, design: .monospaced).weight(opz.fxPick == f ? .bold : .regular))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(RoundedRectangle(cornerRadius: 8).fill(opz.fxPick == f ? f.color : f.dark))
                                .foregroundStyle(opz.fxPick == f ? Color.black : Color.white)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("scegli \(f.name)")
                        .accessibilityAddTraits(opz.fxPick == f ? .isSelected : [])
                    }
                }
                HStack(spacing: 6) {
                    Text("dura")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                    ForEach([1, 2, 4, 8, 16], id: \.self) { l in
                        GridChip(text: "\(l)", on: opz.fxLength == l) { opz.fxLength = l }
                            .accessibilityLabel(l == 1 ? "dura un passo" : "dura \(l) passi")
                    }
                }
                OPZFxStepCells(live: opz.live, cells: Array(opz.fxSteps[opz.createPattern - 1].prefix(opz.length)), tap: { opz.toggleFxStep($0) })
                HStack(spacing: 6) {
                    Text("ogni")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                    ForEach([1, 2, 4, 8], id: \.self) { e in
                        GridChip(text: e == 1 ? "battuta" : "\(e)", on: opz.fxEvery == e) { opz.fxEvery = e }
                            .accessibilityLabel(e == 1 ? "ogni battuta" : "ogni \(e) battute")
                    }
                }
                GridChip(text: "togli gli effetti dai passi") { opz.clearFxSteps() }
            }

            Card(title: "scrivi sull'OP-Z", note: "Per mettere questi passi dentro il pattern dell'OP-Z: Ele accende il record lock (tiene REC e preme PLAY). Poi tocca qui: Bobina suona i passi per una battuta sola, dall'inizio della battuta dopo. Da provare: è la prima volta.") {
                GridChip(text: opz.writing ? "sto scrivendo…" : "scrivi una battuta sull'OP-Z", on: opz.writing) { opz.writeOnce() }
                    .disabled(opz.writing)
            }
        }
    }
}

/// Un effetto di Bobina diviso in due: sopra una battuta, sotto tieni / lascia.
struct OPZCreaFxKey: View {
    @EnvironmentObject var opz: OPZEngine
    let fx: CreaFx
    let held: Bool

    var body: some View {
        VStack(spacing: 3) {
            Button { opz.creaFxTap(fx) } label: {
                VStack(spacing: 1) {
                    Text(fx.name)
                        .font(.system(.footnote, design: .monospaced).weight(.semibold))
                    Text(fx.hint)
                        .font(.system(size: 9, design: .monospaced))
                        .opacity(0.75)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(RoundedRectangle(cornerRadius: 8).fill(fx.color))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(held ? Color.white : Palette.cardEdge, lineWidth: held ? 3 : 1))
                .foregroundStyle(Color.black)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(fx.name)

            Button { opz.creaFxToggle(fx) } label: {
                Text(held ? "lascia" : "tieni")
                    .font(.system(.caption2, design: .monospaced).weight(held ? .bold : .regular))
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(RoundedRectangle(cornerRadius: 8).fill(held ? Color.white : fx.dark))
                    .foregroundStyle(held ? Color.black : Color.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(held ? "lascia \(fx.name)" : "tieni \(fx.name)")
            .accessibilityAddTraits(held ? .isSelected : [])
        }
    }
}

/// I 16 passi degli effetti: in ognuno il nome corto dell'effetto, o niente. Guarda `live` per il passo che suona.
struct OPZFxStepCells: View {
    @ObservedObject var live: OPZLive
    let cells: [CreaFx?]
    let tap: (Int) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: cells.count > 16 ? 8 : 4), spacing: 5) {
            ForEach(0..<cells.count, id: \.self) { i in
                let f = cells[i]
                Button { tap(i) } label: {
                    VStack(spacing: 0) {
                        Text("\(i + 1)")
                            .font(.system(.caption, design: .monospaced))
                        Text(f?.name ?? "·")
                            .font(.system(size: 10, design: .monospaced).weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(RoundedRectangle(cornerRadius: 8).fill(f?.color ?? Color(white: i % 4 == 0 ? 0.22 : 0.16)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(live.step == i ? Color.white : Color.clear, lineWidth: 3))
                    .foregroundStyle(f == nil ? Color.white : Color.black)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("effetto passo \(i + 1)")
                .accessibilityValue(f?.name ?? "vuoto")
            }
        }
    }
}

/// La catena: i pattern di Bobina uno dopo l'altro, ognuno tot volte, partono da soli.
struct OPZChainCard: View {
    @EnvironmentObject var opz: OPZEngine
    @State private var pick = 1

    var body: some View {
        Card(title: "catena di pattern", note: "Metti i pattern in fila: con «catena accesa» Bobina li suona uno dopo l'altro, ognuno quante volte hai scelto, e ognuno per tutti i suoi passi.") {
            Toggle("catena accesa", isOn: $opz.chainOn)
            OPZChainRow(live: opz.live, chain: opz.chain, on: opz.chainOn && opz.running)
            Text("pattern da aggiungere")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                ForEach(1...16, id: \.self) { n in
                    GridChip(text: opz.hasNotes(pattern: n) ? "\(n)•" : "\(n)", on: pick == n) { pick = n }
                        .accessibilityLabel("aggiungi pattern \(n)")
                }
            }
            HStack(spacing: 5) {
                Text("volte")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.dim)
                ForEach([1, 2, 4, 8], id: \.self) { v in
                    GridChip(text: "×\(v)", on: opz.chainTimes == v) { opz.chainTimes = v }
                        .accessibilityLabel("\(v) volte")
                }
            }
            HStack(spacing: 6) {
                GridChip(text: "aggiungi \(pick) ×\(opz.chainTimes)") { opz.chainAdd(pick) }
                GridChip(text: "togli l'ultimo") { opz.chainRemoveLast() }
                GridChip(text: "svuota") { opz.chainClear() }
            }
            HStack(spacing: 6) {
                GridChip(text: "alla fine: da capo", on: opz.chainLoop) { opz.chainLoop = true }
                GridChip(text: "alla fine: fermati", on: !opz.chainLoop) { opz.chainLoop = false }
            }
        }
    }
}

/// La fila della catena, con la voce che suona accesa. Guarda `live`.
struct OPZChainRow: View {
    @ObservedObject var live: OPZLive
    let chain: [OPZChainStep]
    let on: Bool

    var body: some View {
        if chain.isEmpty {
            Text("catena vuota")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 4) {
                ForEach(chain.indices, id: \.self) { i in
                    let lit = on && live.chainIndex == i
                    Text("\(chain[i].pattern + 1) ×\(chain[i].times)")
                        .font(.system(.footnote, design: .monospaced).weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(RoundedRectangle(cornerRadius: 7).fill(lit ? Palette.accent : Color(white: 0.16)))
                        .foregroundStyle(lit ? Color.black : Color.white)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("catena: " + chain.map { "\($0.pattern + 1) per \($0.times)" }.joined(separator: ", "))
        }
    }
}

/// I 16 pattern di Crea: pieno = quello che scrivi, bordo bianco = quello che suona.
struct OPZCreaPatterns: View {
    @EnvironmentObject var opz: OPZEngine
    @ObservedObject var live: OPZLive

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
            ForEach(1...16, id: \.self) { n in
                let editing = opz.createPattern == n
                let playing = opz.running && opz.createOn && live.createPlaying == n
                Button { opz.createPattern = n } label: {
                    Text(opz.hasNotes(pattern: n) ? "\(n)•" : "\(n)")
                        .font(.system(.subheadline, design: .monospaced).weight(editing ? .bold : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 8).fill(editing ? OPZ.tint : Color(white: 0.18)))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(playing ? Color.white : Color.clear, lineWidth: 3))
                        .foregroundStyle(editing ? Color.black : Color.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("pattern di Bobina \(n)")
                .accessibilityAddTraits(editing ? .isSelected : [])
            }
        }
    }
}

/// Sedici caselle. Guarda solo `live`: quando avanza il passo si ridisegnano queste, non la pagina.
struct OPZStepCells: View {
    @ObservedObject var live: OPZLive
    var length = 16
    let count: (Int) -> Int
    let has: (Int) -> Bool
    let color: Color
    let tap: (Int) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: length > 16 ? 8 : 4), spacing: 5) {
            ForEach(0..<length, id: \.self) { i in
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
