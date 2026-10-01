import SwiftUI

/// Sedici cue come i pad di un campionatore: segna i punti buoni di una registrazione, poi suonali.
struct PadView: View {
    @EnvironmentObject var engine: Engine

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    /// In sedicesimi: 0,5 = trentaduesimi.
    private let divisions: [Double] = [4, 2, 1, 0.5]
    private let divisionNames = ["1/4", "1/8", "1/16", "1/32"]

    var body: some View {
        Page(title: "Pad") {
            Card(title: "cue", note: engine.markMode
                 ? "SEGNA: fai suonare il TP-7 e tocca i pad nei punti buoni: ogni pad lega la sua nota al punto dove passa il nastro. Serve MIDI → cue e la schermata CUE aperta (▲). Se non segna, tieni premuto ● sulla macchina mentre tocchi il pad: è il modo ufficiale."
                 : "RICHIAMA: ogni pad fa saltare il nastro al suo cue e suona da lì. I pad segnati sono bordati d'arancio. Dopo ogni salto Bobina rimanda al TP-7 volumi e muti, che lui azzererebbe.") {
                Picker("modo", selection: $engine.markMode) {
                    Text("richiama").tag(false)
                    Text("segna").tag(true)
                }
                .pickerStyle(.segmented)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(0..<16, id: \.self) { i in
                        FlashingPad(pulse: engine.pulse, index: i, onPress: { engine.hitPad(i) }, label: {
                            VStack(spacing: 2) {
                                Text("\(i + 1)").font(.system(.title3, design: .monospaced))
                                Text("nota \(TP7.padBase + i)").font(.system(size: 9, design: .monospaced)).opacity(0.6)
                            }
                        })
                        .frame(height: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Palette.accent, lineWidth: engine.padsSet.contains(i) ? 2 : 0)
                        )
                    }
                }
                HStack {
                    Spacer()
                    Button("dimentica i segni") { engine.forgetPads() }
                        .font(.footnote)
                }
            }

            Card(title: "trasporto in cue", note: "Gli stessi tasti della scheda Nastro, qui sotto i pad: ▶ fa correre il nastro, ■ lo ferma, ● arma (la ripresa parte dal ▶ della macchina), ⏮ ⏭ canzone passano al segno prima o dopo.") {
                CueTransportControls()
            }

            Card(title: "balbettio", note: "Tieni premuto: l'ultimo pad si ripete a tempo, come un beat repeat. Il tempo è quello della scheda Ritmo.") {
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { k in
                        PressPad(lit: engine.stutter == divisions[k],
                                 onPress: { engine.beginStutter(divisions[k]) },
                                 onRelease: { engine.endStutter() },
                                 label: {
                                     Text(divisionNames[k]).font(.system(.headline, design: .monospaced))
                                 })
                        .frame(height: 54)
                    }
                }
            }

            Card(title: "collage", note: "Ogni tanto il nastro salta a un pad segnato a caso: un taglia e cuci che non si ripete mai. Parte da solo col tempo della scheda Ritmo.") {
                Toggle("acceso", isOn: Binding(get: { engine.collageOn }, set: { engine.setCollage($0) }))
                Picker("ogni", selection: $engine.collageEvery) {
                    Text("1/16").tag(1)
                    Text("1/8").tag(2)
                    Text("1/4").tag(4)
                    Text("1/2").tag(8)
                    Text("battuta").tag(16)
                }
                .pickerStyle(.segmented)
                ValueSlider(name: "probabilità", value: $engine.collageChance, range: 0...1, shown: "\(Int(engine.collageChance * 100))%")
            }

            Card(title: "loop", note: "Funziona solo con la schermata LOOP aperta sul TP-7 (▲, poi scegli loop). Premi inizio quando il nastro passa dove comincia, fine dove finisce; poi si può solo spegnere. «A tempo» lo apre alla prossima battuta e lo chiude da solo, come un OB-4.") {
                HStack(spacing: 8) {
                    Chip(text: "inizio", on: engine.loop != .off) { engine.loopStart() }
                        .disabled(engine.loop != .off)
                    Chip(text: "fine", on: engine.loop == .on) { engine.loopEnd() }
                        .disabled(engine.loop != .started)
                    Chip(text: "spegni") { engine.loopOff() }
                }
                HStack(spacing: 8) {
                    Text("a tempo")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                    Chip(text: "½ batt.") { engine.loopInTime(bars: 0.5) }
                    Chip(text: "1 batt.") { engine.loopInTime(bars: 1) }
                    Chip(text: "2 batt.") { engine.loopInTime(bars: 2) }
                }
            }
        }
    }
}

/// Il pad che lampeggia quando il sequencer lo suona: guarda Pulse, così si ridisegna solo lui.
struct FlashingPad<Label: View>: View {
    @ObservedObject var pulse: Pulse
    let index: Int
    let onPress: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        PressPad(lit: pulse.flashPad == index, onPress: onPress, label: label)
    }
}
