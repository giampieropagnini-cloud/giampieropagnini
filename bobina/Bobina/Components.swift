import SwiftUI

enum Palette {
    static let accent = Color(red: 1.0, green: 0.54, blue: 0.31)
    static let rec = Color(red: 0.85, green: 0.20, blue: 0.17)
    static let card = Color(white: 0.13)
    static let cardEdge = Color(white: 0.22)
    static let dim = Color(white: 0.6)
    static let alu = Color(white: 0.78)
}

/// Il contenitore di ogni blocco: titolo, una riga di spiegazione, il contenuto.
struct Card<Content: View>: View {
    let title: String
    var note: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.headline, design: .rounded))
            if let note = note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(Palette.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.cardEdge, lineWidth: 1))
    }
}

/// Una pagina che scorre, con la striscia del collegamento in cima.
struct Page<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    StatusStrip()
                    content()
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 24)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Verde se Bobina parla con qualcuno, rosso se no.
struct StatusStrip: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(engine.connected ? Color.green : Palette.rec)
                .frame(width: 8, height: 8)
            Text(engine.connected ? "collegato a \(engine.connectedName)" : "TP-7 non collegato · vai su Collega")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
                .lineLimit(1)
            Spacer()
            if engine.running {
                Text("\(Int(engine.bpm)) bpm")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.accent)
            }
        }
        .padding(.top, 6)
    }
}

/// Un tasto che agisce quando lo tocchi (non quando lo lasci) e sa quando lo lasci.
struct PressPad<Label: View>: View {
    var lit = false
    var onPress: () -> Void
    var onRelease: () -> Void = {}
    @ViewBuilder var label: () -> Label
    @State private var down = false

    var body: some View {
        label()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(down || lit ? Palette.accent : Color(white: 0.18))
            )
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.cardEdge, lineWidth: 1))
            .foregroundStyle(down || lit ? Color.black : Color.white)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !down {
                            down = true
                            onPress()
                        }
                    }
                    .onEnded { _ in
                        down = false
                        onRelease()
                    }
            )
    }
}

/// Un bottone semplice, pieno se acceso.
struct Chip: View {
    let text: String
    var on = false
    var color: Color = Palette.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(.subheadline, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minWidth: 44)
                .background(RoundedRectangle(cornerRadius: 9).fill(on ? color : Color(white: 0.18)))
                .foregroundStyle(on ? Color.black : Color.white)
        }
        .buttonStyle(.plain)
    }
}

/// Uno slider con nome e valore scritto.
struct ValueSlider: View {
    let name: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let shown: String

    var body: some View {
        HStack(spacing: 10) {
            Text(name)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
                .frame(width: 70, alignment: .leading)
            Slider(value: $value, in: range)
            Text(shown)
                .font(.system(.caption, design: .monospaced))
                .frame(width: 58, alignment: .trailing)
        }
    }
}

/// Scelta delle tracce 1-6 per gli effetti a tempo.
struct TrackPicker: View {
    @Binding var tracks: Set<Int>

    var body: some View {
        HStack(spacing: 6) {
            Text("tracce")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
            ForEach(1...6, id: \.self) { t in
                Chip(text: "\(t)", on: tracks.contains(t)) {
                    if tracks.contains(t) { tracks.remove(t) } else { tracks.insert(t) }
                }
            }
        }
    }
}
