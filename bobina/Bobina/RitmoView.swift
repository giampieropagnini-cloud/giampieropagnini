import SwiftUI

/// Il tempo di Bobina e i giochi a tempo: sequencer di cue, cancello, pompa.
struct RitmoView: View {
    @EnvironmentObject var engine: Engine
    @State private var brush: Int? = 0

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 8)

    var body: some View {
        Page(title: "Ritmo") {
            Card(title: "tempo", note: "Il metronomo lo tiene Bobina. Oppure metti il TP-7 su MIDI → sync, collegalo col cavo e accendi «segui il TP-7»: i passi li detta il nastro, al tempo del file, anche quando lo rallenti o lo acceleri. Col bluetooth il TP-7 il tempo non lo manda: lì usa tap. In sync però i pad non funzionano (servono in cue): vanno cancello, pompa e deriva.") {
                Toggle("segui il TP-7 (MIDI → sync)", isOn: $engine.followClock)
                if engine.followClock && engine.overBluetooth {
                    Text("col bluetooth il tempo del TP-7 non arriva: collegalo col cavo, oppure spegni e usa tap")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.rec)
                }
                HStack(spacing: 10) {
                    Chip(text: "−") { engine.bpm = max(40, engine.bpm - 1) }
                    Text("\(Int(engine.bpm))")
                        .font(.system(size: 34, weight: .medium, design: .monospaced))
                        .frame(minWidth: 80)
                    Chip(text: "+") { engine.bpm = min(240, engine.bpm + 1) }
                    Spacer()
                    Chip(text: "tap") { engine.tap() }
                }
                Slider(value: $engine.bpm, in: 40...240, step: 1)
                if let c = engine.clockBPM {
                    Button(String(format: "usa il clock che arriva: %.1f bpm", c)) { engine.bpm = c.rounded() }
                        .font(.footnote)
                }
                if !engine.followClock {
                    Chip(text: engine.running ? "■ ferma il tempo" : "▶ fai partire il tempo", on: engine.running) {
                        engine.toggleRun()
                    }
                } else {
                    Text(engine.clockBPM == nil ? "aspetto il clock: premi play sul TP-7" : "segue il TP-7")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.accent)
                }
            }

            Card(title: "sequencer di nastro", note: "Sedici passi: ogni passo fa saltare il nastro a un cue. Con dei cue segnati su una registrazione qualsiasi, diventa una drum machine fatta di nastro. Scegli il pennello e tocca i passi.") {
                Toggle("acceso", isOn: $engine.seqOn)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Chip(text: "vuoto", on: brush == nil) { brush = nil }
                        ForEach(0..<16, id: \.self) { p in
                            Chip(text: "\(p + 1)", on: brush == p) { brush = p }
                        }
                    }
                }
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(0..<16, id: \.self) { i in
                        PulseStepCell(label: engine.seq[i].map { "\($0 + 1)" } ?? "·",
                                 filled: engine.seq[i] != nil,
                                 index: i, pulse: engine.pulse, pulsing: engine.pulsing) {
                            engine.seq[i] = (engine.seq[i] == brush) ? nil : brush
                        }
                    }
                }
            }

            Card(title: "cancello", note: "Il trucco del transformer: a ogni passo spento le tracce scelte vanno in muto. Più passi spenti, più il suono si fa a pezzi.") {
                Toggle("acceso", isOn: $engine.gateOn)
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(0..<16, id: \.self) { i in
                        PulseStepCell(label: engine.gate[i] ? "■" : "·",
                                 filled: engine.gate[i],
                                 index: i, pulse: engine.pulse, pulsing: engine.pulsing) {
                            engine.gate[i].toggle()
                        }
                    }
                }
                TrackPicker(tracks: $engine.gateTracks)
            }

            Card(title: "pompa", note: "A ogni quarto il volume delle tracce scelte cala e risale: l'effetto sidechain della musica elettronica, fatto col mixer del TP-7.") {
                Toggle("acceso", isOn: $engine.pumpOn)
                ValueSlider(name: "quanto", value: $engine.pumpDepth, range: 0...1, shown: "\(Int(engine.pumpDepth * 100))%")
                ValueSlider(name: "risalita", value: $engine.pumpRelease, range: 0.1...1, shown: "\(Int(engine.pumpRelease * 100))%")
                TrackPicker(tracks: $engine.pumpTracks)
            }
        }
    }
}

/// Una casella del TP-7: guarda il passo in Pulse, così a ogni sedicesimo si ridisegna solo lei.
struct PulseStepCell: View {
    let label: String
    let filled: Bool
    let index: Int
    @ObservedObject var pulse: Pulse
    let pulsing: Bool
    let action: () -> Void

    var body: some View {
        StepCell(label: label, filled: filled, current: pulsing && pulse.step == index, action: action)
    }
}

struct StepCell: View {
    let label: String
    let filled: Bool
    let current: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(.subheadline, design: .monospaced))
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(filled ? Palette.accent.opacity(0.85) : Color(white: 0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(current ? Color.white : Color.clear, lineWidth: 2)
                )
                .foregroundStyle(filled ? Color.black : Color.white)
        }
        .buttonStyle(.plain)
    }
}
