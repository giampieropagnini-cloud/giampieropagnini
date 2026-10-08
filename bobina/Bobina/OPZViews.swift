import SwiftUI
import CoreMIDI

// MARK: - le cinque schermate dell'OP-Z

/// Suona, Crea, Live (muti ed effetti), Ritmo, Collega. Riapre l'ultima scheda usata.
struct OPZTabs: View {
    @AppStorage("bobina.opz.scheda") private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            OPZSuonaView()
                .tabItem { Label("Suona", systemImage: "play.square.stack") }.tag(0)
            OPZCreaView()
                .tabItem { Label("Crea", systemImage: "square.grid.4x3.fill") }.tag(1)
            OPZLiveView()
                .tabItem { Label("Live", systemImage: "sparkles") }.tag(2)
            OPZRitmoView()
                .tabItem { Label("Ritmo", systemImage: "metronome") }.tag(3)
            OPZCollegaView()
                .tabItem { Label("Collega", systemImage: "cable.connector") }.tag(4)
        }
        .tint(OPZ.tint)
    }
}

/// Come Page, con la fascia dell'OP-Z e la striscia del collegamento.
struct OPZPage<Content: View>: View {
    let title: String
    /// Senza la fascia col nome: per le schede che devono stare in uno schermo.
    var compact = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        #if DEBUG
        let _ = Diagnostics.shared.count("pagina opz " + title)
        #endif
        NavigationStack {
            ScrollView {
                VStack(spacing: compact ? 8 : 12) {
                    if !compact { OPZBanner() }
                    OPZStatusStrip()
                    content()
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 24)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { MachineSwitch() } }
        }
    }
}

/// In cima a ogni scheda: il nome della macchina nel suo colore.
struct OPZBanner: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("OP-Z")
                .font(.system(.title2, design: .rounded).weight(.bold))
            Text("16 tracce")
                .font(.system(.subheadline, design: .monospaced))
                .opacity(0.75)
            Spacer()
        }
        .foregroundStyle(Color.black)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(OPZ.tint))
        .accessibilityElement(children: .combine)
    }
}

struct OPZStatusStrip: View {
    @EnvironmentObject var opz: OPZEngine

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(opz.connected ? Color.green : Palette.rec)
                .frame(width: 8, height: 8)
            Text(opz.connected ? "collegato a \(opz.connectedName)" : "OP-Z non collegato · vai su Collega")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.dim)
                .lineLimit(1)
            Spacer()
            if opz.running || opz.othersRunning {
                Text("\(Int(opz.bpm.rounded())) bpm")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.accent)
            }
        }
        .padding(.top, 6)
    }
}

/// La fila della canzone, con la voce che suona accesa. Guarda `live`.
struct OPZSongRow: View {
    @ObservedObject var live: OPZLive
    let song: [Int]
    let songOn: Bool

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
            ForEach(song.indices, id: \.self) { i in
                Text("\(song[i])")
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .background(RoundedRectangle(cornerRadius: 7).fill(songOn && live.songIndex == i ? Palette.accent : Color(white: 0.16)))
                    .foregroundStyle(songOn && live.songIndex == i ? Color.black : Color.white)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("canzone: " + song.map(String.init).joined(separator: ", "))
    }
}

// MARK: - Muti

/// Un effetto diviso in due: sopra un tocco, sotto tieni / lascia. Ognuno col suo colore.
struct OPZPunchKey: View {
    @EnvironmentObject var opz: OPZEngine
    let index: Int
    let name: String
    let held: Bool

    private var color: Color { Color(hue: Double(index) / 12, saturation: 0.55, brightness: 0.95) }
    private var dark: Color { Color(hue: Double(index) / 12, saturation: 0.6, brightness: 0.45) }

    var body: some View {
        VStack(spacing: 3) {
            Button { opz.punchTap(index) } label: {
                Text(name)
                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 8).fill(color))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(held ? Color.white : Palette.cardEdge, lineWidth: held ? 3 : 1))
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(name)

            Button { opz.punchToggle(index) } label: {
                Text(held ? "lascia" : "tieni")
                    .font(.system(.caption2, design: .monospaced).weight(held ? .bold : .regular))
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(RoundedRectangle(cornerRadius: 8).fill(held ? Color.white : dark))
                    .foregroundStyle(held ? Color.black : Color.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(held ? "lascia \(name)" : "tieni \(name)")
            .accessibilityAddTraits(held ? .isSelected : [])
        }
    }
}

/// Le righe del monitor: guardano solo il loro quaderno, non il motore.
struct OPZMonitorLines: View {
    @ObservedObject var book: OPZLogBook

    var body: some View {
        Card(title: "monitor", note: "→ parte da Bobina · ← arriva dall'OP-Z (le sue note e le sue manopole). Il clock non viene scritto.") {
            HStack {
                Toggle("in pausa", isOn: $book.paused)
                    .font(.footnote)
                Spacer()
                Button("pulisci") { book.clear() }
                    .font(.footnote)
            }
            VStack(alignment: .leading, spacing: 3) {
                ForEach(book.lines.prefix(40)) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(line.incoming ? "←" : "→")
                            .foregroundStyle(Palette.accent)
                        Text(line.text)
                        Spacer(minLength: 4)
                        Text(line.raw)
                            .foregroundStyle(Palette.dim)
                            .lineLimit(1)
                    }
                    .font(.system(size: 11, design: .monospaced))
                }
                if book.lines.isEmpty {
                    Text("ancora niente")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                }
            }
        }
    }
}
