import SwiftUI

/// Le sei tracce del TP-7 e i tre ingressi.
struct MixerView: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        Page(title: "Mixer") {
            Card(title: "tracce", note: "Volume e muto delle sei tracce stereo di un multitraccia (il canale MIDI è la traccia). Il TP-7 li rimette a posto da solo quando cambi traccia con un cue o col loop.") {
                ForEach(1...6, id: \.self) { t in
                    TrackRow(track: t)
                }
            }

            Card(title: "deriva", note: "I volumi delle tracce scelte vagano piano e ognuno per conto suo: sei tracce della stessa registrazione diventano un paesaggio che cambia sempre, alla Basinski o alla Eno.") {
                Toggle("accesa", isOn: $engine.driftOn)
                ValueSlider(name: "quanto", value: $engine.driftAmount, range: 0.1...1, shown: "\(Int(engine.driftAmount * 100))%")
                TrackPicker(tracks: $engine.driftTracks)
            }

            Card(title: "ingressi", note: "Guadagno dei tre minijack, da 0 a +42 dB, un dB alla volta: niente scatti grandi, per non rompere casse e cuffie con un comando capito male. Microfono interno e USB hanno il guadagno fisso.") {
                ForEach(1...3, id: \.self) { i in
                    let db = Int((Double(engine.gains[i - 1]) * 42 / 127).rounded())
                    HStack(spacing: 10) {
                        Text("in \(i)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Palette.dim)
                            .frame(width: 34, alignment: .leading)
                        Chip(text: "−") { engine.setGain(i, gainValue(db - 1)) }
                        Text("+\(db) dB")
                            .font(.system(.body, design: .monospaced))
                            .frame(minWidth: 70)
                        Chip(text: "+") { engine.setGain(i, gainValue(db + 1)) }
                        Spacer()
                    }
                }
            }

            Card(title: "registrazione", note: "«Registra» arma e parte: nasce sempre un file nuovo, e ■ nella scheda Nastro chiude la ripresa. «Arma» soltanto prepara, e parti tu dalla macchina.") {
                HStack(spacing: 8) {
                    Chip(text: engine.recording ? "● registra…" : "● registra", on: engine.recording, color: Palette.rec) {
                        engine.record()
                    }
                    Chip(text: engine.armed ? "armato" : "arma", on: engine.armed && !engine.recording, color: Palette.rec) {
                        engine.toggleArm()
                    }
                    Chip(text: "■") { engine.stop() }
                }
            }
        }
    }
}

/// Da dB (0-42) al valore del cc 9 (0-127).
private func gainValue(_ db: Int) -> Int {
    Int((Double(max(0, min(42, db))) * 127 / 42).rounded())
}

struct TrackRow: View {
    @EnvironmentObject var engine: Engine
    let track: Int

    var body: some View {
        let value = Binding<Double>(
            get: { Double(engine.volumes[track - 1]) },
            set: { engine.setVolume(track, Int($0.rounded())) }
        )
        HStack(spacing: 10) {
            Text("tr \(track)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
                .frame(width: 34, alignment: .leading)
            Slider(value: value, in: 0...127)
            Text("\(engine.volumes[track - 1])")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 32, alignment: .trailing)
            Chip(text: "M", on: engine.mutes[track - 1], color: Palette.rec) {
                engine.toggleMute(track)
            }
        }
    }
}
