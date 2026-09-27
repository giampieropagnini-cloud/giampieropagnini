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

            Card(title: "ingressi", note: "Guadagno dei tre minijack, da 0 a +42 dB. Microfono interno e USB hanno il guadagno fisso.") {
                ForEach(1...3, id: \.self) { i in
                    let value = Binding<Double>(
                        get: { Double(engine.gains[i - 1]) },
                        set: { engine.setGain(i, Int($0.rounded())) }
                    )
                    ValueSlider(name: "in \(i)", value: value, range: 0...127,
                                shown: "+\(Int((Double(engine.gains[i - 1]) / 127 * 42).rounded())) dB")
                }
            }

            Card(title: "registrazione", note: "Arma soltanto: la registrazione la fai partire sulla macchina, col ▶.") {
                Chip(text: engine.armed ? "● armato" : "● arma", on: engine.armed, color: Palette.rec) {
                    engine.toggleArm()
                }
            }
        }
    }
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
