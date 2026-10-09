import SwiftUI

/// Suona: tastiera e pad insieme, gli strumenti con i loro preset, i campioni. Una parte alla volta, in uno schermo.
struct TX6SuonaView: View {
    @EnvironmentObject var tx: TX6Engine
    @AppStorage("bobina.tx6.suona.parte2") private var part = 0

    static let parts = ["suona", "strumenti", "campioni"]

    var body: some View {
        TX6Screen(title: "Suona") {
            TX6Parts(items: Self.parts, selection: $part)
            switch part {
            case 1: TX6InstrumentPanel()
            case 2: TX6SamplerPanel()
            default: TX6PlayPanel(live: tx.live)
            }
        }
    }
}

/// La tastiera sulla traccia scelta (con gli accordi le sei tracce diventano sei voci) e i sei pad.
struct TX6PlayPanel: View {
    @EnvironmentObject var tx: TX6Engine
    @ObservedObject var live: TX6Live

    private let names = ["do", "do#", "re", "re#", "mi", "fa", "fa#", "sol", "sol#", "la", "la#", "si", "do"]
    private let black: Set<Int> = [1, 3, 6, 8, 10]
    private let seven = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let three = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        TX6Box {
            TX6TrackRow(selected: tx.keyTrack, label: { "\($0) \(tx.soundName($0))" }) { tx.keyTrack = $0 }
            HStack(spacing: 4) {
                TX6Mini(text: "ott −") { tx.octave = max(0, tx.octave - 1) }
                    .accessibilityLabel("ottava meno")
                Text("do\(tx.octave)")
                    .font(.system(.footnote, design: .monospaced))
                    .frame(minWidth: 40)
                TX6Mini(text: "ott +") { tx.octave = min(8, tx.octave + 1) }
                    .accessibilityLabel("ottava più")
            }
            HStack(spacing: 4) {
                ForEach(TX6Chord.allCases) { c in
                    TX6Mini(text: c.rawValue, on: tx.chord == c, color: Color(white: 0.75)) { tx.chord = c }
                        .accessibilityLabel("accordo \(c.rawValue)")
                }
            }
            LazyVGrid(columns: seven, spacing: 4) {
                ForEach(0..<13, id: \.self) { k in
                    PressPad(lit: tx.heldKeys.contains(k), onPress: { tx.keyDown(k) }, onRelease: { tx.keyUp(k) }) {
                        Text(names[k])
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(black.contains(k) && !tx.heldKeys.contains(k) ? Palette.dim : Color.white)
                    }
                    .frame(height: 50)
                    .accessibilityLabel("tasto \(names[k])")
                }
            }
            TX6Label("Serve MIDI → NOTE on e il synth su play.")
        }
        TX6Box {
            LazyVGrid(columns: three, spacing: 6) {
                ForEach(1...6, id: \.self) { t in
                    PressPad(lit: live.flash.contains(t) || (tx.pulsing && tx.beatsOn && tx.beats[t - 1][live.step]), onPress: { tx.hitPad(t) }) {
                        VStack(spacing: 2) {
                            Text("traccia \(t)").font(.system(.subheadline, design: .monospaced))
                            Text(tx.soundName(t)).font(.system(.caption, design: .monospaced))
                        }
                    }
                    .frame(height: 58)
                    .accessibilityLabel("pad traccia \(t)")
                }
            }
            TX6Label("Pad e batteria suonano ogni traccia alla sua frequenza: si accorda in strumenti → frequenza.")
        }
    }
}

/// Ogni traccia è uno strumento: il suono, le sue manopole, e i preset (pronti o tuoi) al posto delle manopole.
struct TX6InstrumentPanel: View {
    @EnvironmentObject var tx: TX6Engine
    @AppStorage("bobina.tx6.strumenti.traccia") private var track = 1
    @AppStorage("bobina.tx6.strumenti.pronti") private var showPresets = false
    @AppStorage("bobina.tx6.strumenti.gruppo") private var group = "cassa"

    private let five = Array(repeating: GridItem(.flexible(), spacing: 4), count: 5)
    private let three = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    var body: some View {
        let t = min(6, max(1, track))
        TX6Box {
            TX6TrackRow(selected: t, label: { "\($0) \(tx.soundName($0))" }) { track = $0 }
            HStack(spacing: 4) {
                TX6Mini(text: "manopole", on: !showPresets) { showPresets = false }
                TX6Mini(text: "preset", on: showPresets) { showPresets = true }
                TX6Mini(text: "prova") { tx.hitPad(t) }
                    .accessibilityLabel("prova la traccia \(t)")
            }
            if showPresets {
                LazyVGrid(columns: five, spacing: 4) {
                    ForEach(TX6Preset.groups + ["miei"], id: \.self) { g in
                        TX6Mini(text: g, on: group == g, color: Color(white: 0.75)) { group = g }
                            .accessibilityLabel("gruppo \(g)")
                    }
                }
                if group == "miei" {
                    if tx.myPresets.isEmpty {
                        TX6Label("Ancora nessun preset tuo: regola la traccia con le manopole e tocca «salva come mio».")
                    }
                    ForEach(tx.myPresets) { p in
                        HStack(spacing: 4) {
                            TX6Mini(text: p.name, height: 38) {
                                tx.apply(p, to: t)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { tx.hitPad(t) }
                            }
                            .accessibilityLabel("preset \(p.name)")
                            TX6ConfirmMini(text: "✕") { tx.deletePreset(p) }
                                .frame(width: 60)
                                .accessibilityLabel("cancella \(p.name)")
                        }
                    }
                } else {
                    LazyVGrid(columns: three, spacing: 4) {
                        ForEach(TX6Preset.builtIn.filter { $0.group == group }) { p in
                            TX6Mini(text: p.name, height: 40) {
                                tx.apply(p, to: t)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { tx.hitPad(t) }
                            }
                            .accessibilityLabel("preset \(p.name)")
                        }
                    }
                }
                TX6Mini(text: "salva la traccia \(t) come mio preset", height: 38) { tx.savePreset(from: t); group = "miei" }
            } else {
                LazyVGrid(columns: five, spacing: 4) {
                    ForEach(TX6DrumPanel.soundOrder, id: \.self) { i in
                        TX6Mini(text: TX6.sounds[i], on: TX6.soundIndex(tx.value(t, .sound)) == i) {
                            tx.setSound(t, i)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { tx.hitPad(t) }
                        }
                        .accessibilityLabel("suono \(TX6.sounds[i])")
                    }
                }
                ForEach([TX6.Param.volume, .freq, .length, .detune, .filter]) { p in
                    TX6KnobRow(name: p.name, value: tx.value(t, p), shown: p.shown(tx.value(t, p)), jumps: TX6Jump.of(p)) { tx.set(t, p, $0) }
                }
                TX6Mini(text: "salva come mio preset", height: 38) { tx.savePreset(from: t); group = "miei"; showPresets = true }
                    .accessibilityLabel("salva la traccia \(t) come mio preset")
            }
        }
    }
}

/// Campionatore e looper del TX-6. Registrare si fa sulla macchina (il MIDI non ha comandi per farlo);
/// da qui si mettono le tracce sul suono SAMPLE e si suonano i campioni a tempo, intonati.
struct TX6SamplerPanel: View {
    @EnvironmentObject var tx: TX6Engine
    @AppStorage("bobina.tx6.campioni.traccia") private var track = 1
    @State private var showSteps = false

    private let sampleIndex = 8

    var body: some View {
        let t = min(6, max(1, track))
        TX6Box {
            TX6Label("Sei campioni da 5,5 s (uno per traccia) e un loop da 22 s. Si registrano sul TX-6; da qui si suonano.")
            TX6TrackRow(selected: t, label: { "\($0) \(tx.soundName($0))" }) { track = $0 }
            HStack(spacing: 4) {
                TX6Mini(text: "suona il suo campione", on: TX6.soundIndex(tx.value(t, .sound)) == sampleIndex, height: 40) {
                    tx.set(t, .sound, TX6.soundValue(sampleIndex))
                }
                .accessibilityLabel("traccia \(t) suona il suo campione")
                TX6Mini(text: "prova", height: 40) { tx.hitPad(t) }
                    .accessibilityLabel("prova la traccia \(t)")
            }
            TX6Mini(text: "tutte e sei sui campioni", height: 40) {
                for n in 1...6 { tx.set(n, .sound, TX6.soundValue(sampleIndex)) }
            }
            TX6Label("Intonati: tastiera e melodia suonano il campione a note diverse. Lunghezza e frequenza in strumenti.")
            TX6Mini(text: showSteps ? "nascondi come si registra" : "come si registra sul TX-6", on: showSteps, color: Color(white: 0.75), height: 38) { showSteps.toggle() }
            if showSteps {
                VStack(alignment: .leading, spacing: 4) {
                    Text("campione: shift + select → SAMPLE · FX II modo registrazione · gira select per la traccia sorgente · tieni il tasto traccia (al massimo 5,5 s) · FX I per suonarlo")
                    Text("loop: shift + select → LOOP · gira select per la traccia · tieni FX II (al massimo 22 s) · FX I suona, FX II ferma")
                    Text("si cancellano allo spegnimento: con una chiavetta USB-C shift + FX II salva, shift + FX I carica")
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
