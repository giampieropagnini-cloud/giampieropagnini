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

            OPZProjectCard()

            Card(title: "Bobina suona l'OP-Z", note: "Scrivi i passi qui: Bobina li suona sull'OP-Z a tempo, insieme a TX-6 e Pocket Operator. Meglio un pattern vuoto sull'OP-Z, se no suonano anche i suoi passi.") {
                Toggle("Crea suona", isOn: $opz.createOn)
                OPZResetRow()
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
            }

            OPZChainCard()

            Card(title: "traccia", note: "Sotto: accesa o spenta in Crea (i passi restano).") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(OPZ.tracks.prefix(8)) { t in
                        VStack(spacing: 3) {
                            Button { opz.createTrack = t.number } label: {
                                Text((opz.steps[t.number - 1].contains { !$0.isEmpty } ? "\(t.short)•" : t.short) + " \(opz.lengths[opz.createPattern - 1][t.number - 1])")
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

            OPZInstrumentHelp(track: opz.createTrack)

            Card(title: opz.createTrack <= 4 ? "suono" : "nota", note: opz.createTrack <= 4 ? "I 24 suoni del kit di questa traccia. Toccane uno: lo senti e diventa quello che metti nei passi." : "Due ottave, come la tastiera dell'OP-Z. Toccane una: la senti e diventa quella che metti nei passi.") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 6), spacing: 8) {
                    ForEach(OPZ.keyboardF...(OPZ.keyboardF + 23), id: \.self) { n in
                        let held = opz.isHeld(n)
                        let spoken = opz.createTrack <= 4 ? "suono \(n - OPZ.keyboardF + 1)" : "nota \(label(n))"
                        VStack(spacing: 3) {
                            GridChip(text: label(n), on: opz.pick == n) { opz.audition(n) }
                                .accessibilityLabel(spoken)
                            Button { opz.toggleLiveHold(n) } label: {
                                Text(held ? "lascia" : "tieni")
                                    .font(.system(.caption2, design: .monospaced).weight(held ? .bold : .regular))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .frame(maxWidth: .infinity, minHeight: 34)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(held ? Color.white : Color(white: 0.12)))
                                    .foregroundStyle(held ? Color.black : Color.white.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(held ? "lascia \(spoken)" : "tieni \(spoken)")
                            .accessibilityAddTraits(held ? .isSelected : [])
                        }
                    }
                }
                GridChip(text: "lascia tutte le note") { opz.releaseLiveAll() }
            }

            if opz.createTrack == 7 {
                Card(title: "arpeggio", note: "Sempre a tempo con la battuta di Bobina. Metti 2-4 note in un passo dell'arp: Bobina le suona una alla volta con la figura scelta, finché arriva un altro passo pieno. L'arpeggio dell'OP-Z resta spento, se no si sovrappone.") {
                    Toggle("arpeggio acceso", isOn: $opz.arpOn)
                    Text("figura")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3), spacing: 5) {
                        ForEach(OPZArpStyle.allCases) { st in
                            GridChip(text: st.name, on: opz.arpStyle == st) { opz.arpStyle = st }
                                .accessibilityLabel("figura \(st.name)")
                        }
                    }
                    Text("velocità")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                    HStack(spacing: 5) {
                        ForEach([(1, "1/32"), (2, "1/16"), (4, "1/8"), (8, "1/4")], id: \.0) { r in
                            GridChip(text: r.1, on: opz.arpRate == r.0) { opz.arpRate = r.0 }
                                .accessibilityLabel("velocità \(r.1)")
                        }
                    }
                    Text("ottave")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                    HStack(spacing: 5) {
                        ForEach(1...3, id: \.self) { o in
                            GridChip(text: "\(o)", on: opz.arpOctaves == o) { opz.arpOctaves = o }
                                .accessibilityLabel("\(o) ottave")
                        }
                    }
                }
            }

            Card(title: "passi · \(OPZ.track(opz.createTrack).name)", note: "Tocca un passo per mettere o togliere «\(label(opz.pick))». Il numero piccolo dice quante note ci sono.") {
                HStack(spacing: 8) {
                    Text("passi di \(OPZ.track(opz.createTrack).short)")
                        .font(.system(.subheadline, design: .monospaced))
                    Spacer()
                    SmallKey(text: "−") { opz.length -= 1 }
                        .accessibilityLabel("un passo in meno")
                    Text("\(opz.length)")
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                        .frame(minWidth: 40)
                    SmallKey(text: "+") { opz.length += 1 }
                        .accessibilityLabel("un passo in più")
                }
                HStack(spacing: 5) {
                    ForEach([3, 4, 5, 7, 8, 12, 16, 32], id: \.self) { l in
                        GridChip(text: "\(l)", on: opz.length == l) { opz.length = l }
                            .accessibilityLabel("\(l) passi")
                    }
                }
                GridChip(text: "\(opz.length) passi a tutte le tracce") { opz.setAllLengths(opz.length) }
                Text("durata delle note di \(OPZ.track(opz.createTrack).short)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.dim)
                HStack(spacing: 5) {
                    ForEach([(1, "1"), (2, "2"), (4, "4"), (8, "8"), (0, "tenuta")], id: \.0) { g in
                        GridChip(text: g.1, on: opz.gate == g.0) { opz.gate = g.0 }
                            .accessibilityLabel(g.0 == 0 ? "nota tenuta fino alla prossima" : "nota lunga \(g.1) passi")
                    }
                }
                OPZStepCells(live: opz.live, length: opz.length, count: { opz.steps[opz.createTrack - 1][$0].count },
                             has: { opz.hasStep($0) }, color: OPZ.color(opz.createTrack),
                             tap: { opz.toggleStep($0) })
                GridChip(text: "svuota \(OPZ.track(opz.createTrack).short)") { opz.clearTrack() }
                    .accessibilityLabel("svuota tutti i passi di \(OPZ.track(opz.createTrack).name)")
            }

            OPZCreaMixerCard()

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
                OPZFxStepCells(live: opz.live, cells: Array(opz.fxSteps[opz.createPattern - 1].prefix(opz.patternLength)), tap: { opz.toggleFxStep($0) })
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

            OPZAutomCard()

            if opz.recordLockReminder {
                VStack(spacing: 8) {
                    Text("Registrazione finita")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    Text("Ele: sull'OP-Z premi REC per togliere il record lock, se no registra anche quello che suoni dopo.")
                        .font(.system(.body, design: .rounded))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { opz.recordLockReminder = false } label: {
                        Text("fatto, tolto")
                            .font(.system(.headline, design: .monospaced))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                            .foregroundStyle(Color.black)
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.rec))
                .foregroundStyle(Color.white)
            }

            Card(title: "scrivi sull'OP-Z", note: "Per mettere questi passi dentro il pattern dell'OP-Z: Ele accende il record lock (tiene REC e preme PLAY). Poi tocca qui con «Crea suona» spento: Bobina suona quello che c'è in Crea (anche la catena), una battuta per pattern dell'OP-Z, e alla fine ferma tutto. Un pattern dell'OP-Z ha al massimo 16 passi: per suonarli in fila c'è la canzone a pattern in Suona.") {
                HStack(spacing: 5) {
                    Text("battute")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                    ForEach([1, 2, 4], id: \.self) { b in
                        GridChip(text: "\(b) · \(b * 16) passi", on: opz.writeBars == b) { opz.writeBars = b }
                            .accessibilityLabel("\(b) battute")
                    }
                }
                Text("nei pattern dell'OP-Z da \(min(opz.writeFirst, 17 - opz.writeBars)) a \(min(opz.writeFirst, 17 - opz.writeBars) + opz.writeBars - 1)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.dim)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 8), spacing: 5) {
                    ForEach(1...16, id: \.self) { n in
                        GridChip(text: "\(n)", on: opz.writeFirst == n) { opz.writeFirst = n }
                            .accessibilityLabel("comincia dal pattern \(n) dell'OP-Z")
                    }
                }
                GridChip(text: opz.writing ? "sto scrivendo…" : "scrivi \(opz.writeBars) battut\(opz.writeBars == 1 ? "a" : "e") sull'OP-Z", on: opz.writing) { opz.writeOnce() }
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
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(live.step >= 0 && live.step % cells.count == i ? Color.white : Color.clear, lineWidth: 3))
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

/// Il mixer di Crea: le tracce che suonano e il loro volume. I muti dell'OP-Z (Live) toccano solo il suo
/// sequencer: qui una traccia spenta è Bobina che smette di mandarle le note.
struct OPZCreaMixerCard: View {
    @EnvironmentObject var opz: OPZEngine

    var body: some View {
        Card(title: "mixer di Crea", note: "Suona / muta e solo li fa Bobina. − e + muovono il volume della traccia sull'OP-Z.") {
            ForEach(OPZ.tracks.prefix(8)) { t in
                let on = opz.trackOn[t.number - 1]
                HStack(spacing: 6) {
                    Text(t.short)
                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        .foregroundStyle(OPZ.color(t.number))
                        .frame(width: 58, alignment: .leading)
                    Button { opz.trackOn[t.number - 1].toggle() } label: {
                        Text(on ? "suona" : "muta")
                            .font(.system(.footnote, design: .monospaced).weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(RoundedRectangle(cornerRadius: 8).fill(on ? OPZ.color(t.number) : Color(white: 0.12)))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(OPZ.color(t.number), lineWidth: on ? 0 : 2))
                            .foregroundStyle(on ? Color.black : OPZ.color(t.number))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(on ? "muta \(t.name)" : "fai suonare \(t.name)")
                    GridChip(text: "solo") { opz.soloCrea(t.number) }
                        .frame(width: 54)
                        .accessibilityLabel("solo \(t.name)")
                    Button { opz.volumeNudge(t.number, up: false) } label: {
                        Text("−").font(.system(.title3, design: .monospaced))
                            .frame(width: 44, height: 40)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.18)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("volume \(t.name) meno")
                    Button { opz.volumeNudge(t.number, up: true) } label: {
                        Text("+").font(.system(.title3, design: .monospaced))
                            .frame(width: 44, height: 40)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.18)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("volume \(t.name) più")
                }
                .foregroundStyle(Color.white)
            }
            GridChip(text: "tutte suonano") { opz.trackOn = Array(repeating: true, count: 8) }
        }
    }
}

/// I 16 progetti di Crea, come i progetti di un synth: ognuno con i suoi 16 pattern.
struct OPZProjectCard: View {
    @EnvironmentObject var opz: OPZEngine

    var body: some View {
        Card(title: "progetto \(opz.creaProject)", note: "16 progetti, ognuno con i suoi 16 pattern, la catena e l'arpeggio. Si salvano da soli. Il puntino dice che non è vuoto.") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                ForEach(1...16, id: \.self) { n in
                    let open = opz.creaProject == n
                    Button { opz.openProject(n) } label: {
                        Text(opz.projectsUsed.contains(n) ? "\(n)•" : "\(n)")
                            .font(.system(.subheadline, design: .monospaced).weight(open ? .bold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(RoundedRectangle(cornerRadius: 8).fill(open ? Palette.accent : Color(white: 0.18)))
                            .foregroundStyle(open ? Color.black : Color.white)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("progetto \(n)")
                    .accessibilityAddTraits(open ? .isSelected : [])
                }
            }
            HStack(spacing: 6) {
                GridChip(text: "copia il progetto \(opz.creaProject)") { opz.copyProject() }
                GridChip(text: "incolla nel \(opz.creaProject)") { opz.pasteProject() }
                    .disabled(opz.copiedProject == nil)
            }
        }
    }
}

/// «ricomincia da zero» chiede conferma con un secondo tasto: cancella tutto Crea.
struct OPZResetRow: View {
    @EnvironmentObject var opz: OPZEngine
    @State private var asking = false

    var body: some View {
        if asking {
            HStack(spacing: 6) {
                Button { opz.resetCrea(); asking = false } label: {
                    Text("sì, cancella tutto")
                        .font(.system(.subheadline, design: .monospaced).weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Palette.rec))
                        .foregroundStyle(Color.white)
                }
                .buttonStyle(.plain)
                GridChip(text: "no, lascia stare") { asking = false }
            }
        } else {
            Button { asking = true } label: {
                Text("ricomincia da zero")
                    .font(.system(.subheadline, design: .monospaced))
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(RoundedRectangle(cornerRadius: 9).stroke(Palette.rec, lineWidth: 2))
                    .foregroundStyle(Palette.rec)
            }
            .buttonStyle(.plain)
            .accessibilityHint("cancella tutti i pattern, gli effetti e la catena del progetto aperto")
        }
    }
}

/// L'automazione a passi: Bobina gira una manopola dell'OP-Z a ogni passo, a tempo. Salvata nel progetto.
struct OPZAutomCard: View {
    @EnvironmentObject var opz: OPZEngine

    private static let short = ["par 1", "par 2", "filtro", "riso", "att", "dec", "sus", "rel",
                                "lfo prof", "lfo vel", "lfo dest", "lfo forma", "fx 1", "fx 2", "pan", "vol"]

    var body: some View {
        let lane = opz.lane
        Card(title: "automazione · pattern \(opz.createPattern)", note: "Bobina gira una manopola dell'OP-Z a ogni passo, a tempo. 4 righe per pattern: scegli la riga, la traccia, la manopola, poi il livello e i passi. Fra un passo e l'altro la manopola resta dov'è.") {
            HStack(spacing: 5) {
                Text("riga")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.dim)
                ForEach(0..<4, id: \.self) { r in
                    let l = opz.autom[opz.createPattern - 1][r]
                    GridChip(text: "\(r + 1)\(l.values.contains { $0 != nil } ? "•" : "")", on: opz.laneIndex == r) { opz.laneIndex = r }
                        .accessibilityLabel("riga \(r + 1)")
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 4), spacing: 5) {
                ForEach(OPZ.tracks.prefix(8)) { t in
                    GridChip(text: t.short, on: lane.track == t.number) { opz.lane.track = t.number }
                        .accessibilityLabel("automazione su \(t.name)")
                }
            }
            Text("manopola")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 4), spacing: 5) {
                ForEach(1...16, id: \.self) { cc in
                    GridChip(text: OPZAutomCard.short[cc - 1], on: lane.cc == cc) { opz.lane.cc = cc }
                        .accessibilityLabel("manopola \(OPZ.paramName(OPZ.params[cc - 1], track: lane.track))")
                }
            }
            Text("livello: 1 = minimo, 8 = massimo")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
            HStack(spacing: 5) {
                ForEach(1...8, id: \.self) { v in
                    GridChip(text: "\(v)", on: opz.autoLevel == v) { opz.autoLevel = v }
                        .accessibilityLabel("livello \(v)")
                }
            }
            OPZAutoCells(live: opz.live, values: Array(lane.values.prefix(opz.patternLength)), tap: { opz.toggleAutoStep($0) })
            GridChip(text: "svuota la riga \(opz.laneIndex + 1)") { opz.clearLane() }
        }
    }
}

/// I passi dell'automazione: in ognuno il livello, con una barretta alta quanto il livello. Guarda `live`.
struct OPZAutoCells: View {
    @ObservedObject var live: OPZLive
    let values: [Int?]
    let tap: (Int) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: values.count > 16 ? 8 : 4), spacing: 5) {
            ForEach(0..<values.count, id: \.self) { i in
                let v = values[i]
                Button { tap(i) } label: {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 8).fill(Color(white: i % 4 == 0 ? 0.22 : 0.16))
                        if let v = v {
                            RoundedRectangle(cornerRadius: 6).fill(OPZ.tint)
                                .frame(height: 46 * CGFloat(v) / 8)
                        }
                        VStack(spacing: 0) {
                            Text("\(i + 1)").font(.system(.caption2, design: .monospaced))
                            Text(v.map { "\($0)" } ?? "·").font(.system(.footnote, design: .monospaced).weight(.bold))
                        }
                        .frame(maxHeight: .infinity)
                        .foregroundStyle(v != nil && v! >= 5 ? Color.black : Color.white)
                    }
                    .frame(height: 50)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(live.step >= 0 && live.step % values.count == i ? Color.white : Color.clear, lineWidth: 3))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("automazione passo \(i + 1)")
                .accessibilityValue(v.map { "livello \($0)" } ?? "vuoto")
            }
        }
    }
}

/// Promemoria: come si cambia lo strumento della traccia sulla macchina (via MIDI non si può). Dalla guida OP-Z, cap. «track».
struct OPZInstrumentHelp: View {
    let track: Int

    private var what: String {
        switch track {
        case 1...3: return "il kit di batteria"
        case 4: return "il kit di campioni"
        case 7: return "lo strumento dell'arpeggio"
        case 8: return "lo strumento degli accordi"
        default: return "lo strumento"
        }
    }

    var body: some View {
        let name = OPZ.track(track).name
        Card(title: "cambiare \(what) · \(name)", note: "Si fa sulla macchina (via MIDI non si può). Prima la traccia \(name) dev'essere quella attiva.") {
            VStack(alignment: .leading, spacing: 8) {
                OPZHelpRow(n: "1", text: "Traccia attiva: tieni TRACK e premi il tasto \(track) della fila dei numeri.")
                OPZHelpRow(n: "2", text: track <= 4 ? "Altro kit: tieni TRACK e premi i tasti della fila di SOPRA." : "Altro strumento: tieni TRACK e premi i tasti della fila di SOPRA.")
                OPZHelpRow(n: "3", text: "Altro suono dello stesso strumento: tieni TRACK e premi i tasti ACCESI della fila di SOTTO (fino a 14).")
                OPZHelpRow(n: "4", text: "Un suono a caso: tieni TRACK e premi REC.")
                OPZHelpRow(n: "5", text: "Salvare il suono di adesso: tieni TRACK e un tasto della fila di sotto per 2 secondi.")
            }
        }
    }
}

struct OPZHelpRow: View {
    let n: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(n)
                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                .foregroundStyle(OPZ.tint)
                .frame(width: 18)
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
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
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(live.step >= 0 && live.step % length == i ? Color.white : Color.clear, lineWidth: 3))
                    .foregroundStyle(mine ? Color.black : Color.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("passo \(i + 1)")
                .accessibilityValue(mine ? "acceso" : n > 0 ? "altre note" : "vuoto")
            }
        }
    }
}
