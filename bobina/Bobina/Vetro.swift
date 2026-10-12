import SwiftUI

// MARK: - Vetro: la skin di vetro di OP-Z, M8, NTS-1 e Pocket Operator (12/10/2026)
//
// Cambia solo l'aspetto: ogni tasto resta dov'era, con le stesse misure (frame, minHeight, spacing, padding),
// lo stesso nome e lo stesso accessibilityLabel. Giampiero usa Controllo Vocale e QuadStick: un tasto spostato
// è un tasto perso. I pezzi comuni (Card, Chip, SmallKey, GridChip in Components e TX6Views) non si toccano:
// qui ci sono i loro gemelli di vetro, con gli stessi parametri, e le sezioni li usano al posto di quelli.

/// I colori di una macchina: il suo colore e le due luci che lo accompagnano sullo sfondo.
struct VetroTheme {
    let color: Color
    let second: Color
    let third: Color

    static let opz = VetroTheme(color: OPZ.tint,
                                second: Color(red: 0.48, green: 0.45, blue: 0.98),
                                third: Color(red: 0.62, green: 0.70, blue: 0.95))
    static let m8 = VetroTheme(color: M8.color,
                               second: Color(red: 0.95, green: 0.32, blue: 0.78),
                               third: Color(red: 0.32, green: 0.48, blue: 1.0))
    static let nts1 = VetroTheme(color: NTS1.color,
                                 second: Color(red: 0.30, green: 0.50, blue: 1.0),
                                 third: Color(red: 0.55, green: 0.95, blue: 0.62))
    static func po(_ color: Color) -> VetroTheme {
        VetroTheme(color: color,
                   second: Color(red: 1.0, green: 0.62, blue: 0.28),
                   third: Color(red: 1.0, green: 0.45, blue: 0.70))
    }
}

private struct VetroThemeKey: EnvironmentKey {
    static let defaultValue = VetroTheme(color: Palette.accent, second: Palette.accent, third: Palette.accent)
}

extension EnvironmentValues {
    /// Il colore della macchina per i tasti di vetro: lo mette la pagina della sezione.
    var vetro: VetroTheme {
        get { self[VetroThemeKey.self] }
        set { self[VetroThemeKey.self] = newValue }
    }
}

// MARK: sfondo

/// Lo sfondo della pagina: scuro, con tre grandi luci sfocate nel colore della macchina
/// (in alto a sinistra forte, a destra a metà, in basso a sinistra più tenue).
/// Gradienti radiali e non cerchi sfocati: stessa luce, e il telefono non deve ricalcolare una sfocatura.
struct VetroBackground: View {
    let theme: VetroTheme

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Color(red: 0.035, green: 0.04, blue: 0.055)
                blob(theme.color, 0.55, at: CGPoint(x: w * 0.08, y: h * 0.06), radius: w * 0.95)
                blob(theme.second, 0.42, at: CGPoint(x: w * 0.98, y: h * 0.48), radius: w * 0.85)
                blob(theme.third, 0.30, at: CGPoint(x: w * 0.05, y: h * 0.93), radius: w * 0.80)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func blob(_ c: Color, _ strength: Double, at p: CGPoint, radius: CGFloat) -> some View {
        RadialGradient(colors: [c.opacity(strength), c.opacity(strength * 0.35), c.opacity(0)],
                       center: .center, startRadius: 0, endRadius: radius)
            .frame(width: radius * 2, height: radius * 2)
            .position(p)
    }
}

extension View {
    /// La pagina di una sezione in Vetro: lo sfondo con le luci, il colore della macchina per i tasti e i controlli.
    func vetroPage(_ theme: VetroTheme) -> some View {
        self
            .scrollContentBackground(.hidden)
            .background { VetroBackground(theme: theme) }
            .environment(\.vetro, theme)
            .tint(theme.color)
    }
}

// MARK: pannelli

/// Il fondo di un pannello o di una card: vetro chiaro (bianco 7%), bordo bianco 12%, riflesso sottile in alto.
struct VetroPanelBackground: View {
    var radius: CGFloat = 26

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(Color.white.opacity(0.07))
            shape.fill(LinearGradient(colors: [Color.white.opacity(0.10), Color.white.opacity(0)],
                                      startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.22)))
            shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
        .environment(\.colorScheme, .dark)
    }
}

extension View {
    func vetroPanel(radius: CGFloat = 26) -> some View {
        background(VetroPanelBackground(radius: radius))
    }
}

// MARK: tasti

/// Come appare un tasto di vetro.
enum VetroLook {
    /// spento: vetro scuro (nero 24%), riflesso in alto, bordo bianco 10%
    case off
    /// spento ma su un tempo forte (il primo di ogni quattro passi): appena più chiaro
    case offBeat
    /// acceso: dal bianco in alto al colore, con l'alone del colore
    case on(Color)
    /// rosso: silenzio, ferma, cancella
    case red
    /// vetro colorato: i tasti che hanno un loro colore (faccia M8, modelli PO, tracce OP-Z, effetti)
    case glass(Color)
    /// metà: i salti fino al valore attuale, un passo con un altro suono, un tasto nero della tastiera
    case half(Color)
    /// «tieni»: vetro tinto del colore al 18%, il testo va nel colore
    case tinted(Color)
    /// tenuto: bianco
    case white

    /// Il colore del testo che ci va sopra.
    var text: Color {
        switch self {
        case .off, .offBeat, .half: return .white
        case .red: return .white
        case .tinted(let c): return c
        case .on, .glass, .white: return Color(white: 0.06)
        }
    }

    /// Acceso, rosso, colorato o tenuto: il testo va in grassetto.
    var strong: Bool {
        switch self {
        case .off, .offBeat, .half, .tinted: return false
        default: return true
        }
    }
}

struct VetroKeyBackground: View {
    let look: VetroLook
    var radius: CGFloat = 12

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let shine = LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0)],
                                   startPoint: .top, endPoint: .center)
        switch look {
        case .off, .offBeat:
            let beat: Bool = { if case .offBeat = look { return true } else { return false } }()
            ZStack {
                shape.fill(Color.black.opacity(0.24))
                if beat { shape.fill(Color.white.opacity(0.07)) }
                shape.fill(shine)
                shape.strokeBorder(Color.white.opacity(beat ? 0.16 : 0.10), lineWidth: 1)
            }
        case .on(let c):
            ZStack {
                shape.fill(LinearGradient(stops: [.init(color: Color.white, location: 0),
                                                  .init(color: c, location: 0.78)],
                                          startPoint: .top, endPoint: .bottom))
                shape.strokeBorder(Color.white.opacity(0.45), lineWidth: 1)
            }
            .shadow(color: c.opacity(0.55), radius: 9)
        case .red:
            ZStack {
                shape.fill(LinearGradient(colors: [Color(red: 1.0, green: 0.46, blue: 0.42), Palette.rec],
                                          startPoint: .top, endPoint: .bottom))
                shape.fill(shine)
                shape.strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
            }
            .shadow(color: Palette.rec.opacity(0.6), radius: 9)
        case .glass(let c):
            ZStack {
                shape.fill(LinearGradient(colors: [c.opacity(0.90), c.opacity(0.62)],
                                          startPoint: .top, endPoint: .bottom))
                shape.fill(shine)
                shape.strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
            }
        case .half(let c):
            ZStack {
                shape.fill(LinearGradient(colors: [c.opacity(0.60), c.opacity(0.40)],
                                          startPoint: .top, endPoint: .bottom))
                shape.fill(shine)
                shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            }
        case .tinted(let c):
            ZStack {
                shape.fill(c.opacity(0.18))
                shape.fill(shine)
                shape.strokeBorder(c.opacity(0.45), lineWidth: 1)
            }
        case .white:
            ZStack {
                shape.fill(LinearGradient(colors: [Color.white, Color(white: 0.86)], startPoint: .top, endPoint: .bottom))
                shape.strokeBorder(Color.white, lineWidth: 1)
            }
            .shadow(color: Color.white.opacity(0.45), radius: 8)
        }
    }
}

extension View {
    /// Il fondo di vetro di un tasto, col colore del testo che ci va sopra. Non cambia le misure.
    func vetroKey(_ look: VetroLook, radius: CGFloat = 12) -> some View {
        self
            .background(VetroKeyBackground(look: look, radius: radius))
            .foregroundStyle(look.text)
    }
}

// MARK: i gemelli di vetro dei pezzi comuni (stessi parametri, stesse misure)

/// Come `Card`: titolo, una riga di spiegazione, il contenuto. Su vetro.
struct VetroCard<Content: View>: View {
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
        .vetroPanel()
    }
}

/// Come `Chip`: acceso = dal bianco al colore della macchina; col colore rosso diventa il tasto rosso.
struct VetroChip: View {
    @Environment(\.vetro) private var theme
    let text: String
    var on = false
    var color: Color? = nil
    /// Silenzio: rosso anche quando non è acceso (solo aspetto, il tasto resta quello).
    var red = false
    let action: () -> Void

    var body: some View {
        let look = red ? VetroLook.red : vetroLook(on: on, color: color, theme: theme)
        Button(action: action) {
            Text(text)
                .font(.system(.subheadline, design: .monospaced).weight(look.strong ? .bold : .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minWidth: 44)
                .vetroKey(look)
        }
        .buttonStyle(.plain)
    }
}

/// Come `SmallKey`: − e +, 34 × 30.
struct VetroSmallKey: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .frame(width: 34, height: 30)
                .vetroKey(.off, radius: 10)
        }
        .buttonStyle(.plain)
    }
}

/// Come `GridChip`: riempie la sua colonna, alto 38.
struct VetroGridChip: View {
    @Environment(\.vetro) private var theme
    let text: String
    var on = false
    /// Solo aspetto: `Palette.rec` per «cancella» e «svuota» quando chiedono conferma.
    var color: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(.footnote, design: .monospaced).weight(on ? .bold : .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 38)
                .vetroKey(vetroLook(on: on, color: color, theme: theme))
        }
        .buttonStyle(.plain)
    }
}

/// Come `ConfirmChip`: il primo tocco chiede conferma, il secondo (entro 4 secondi) cancella.
struct VetroConfirmChip: View {
    let text: String
    let action: () -> Void
    @State private var armed = false

    var body: some View {
        VetroChip(text: armed ? "sicuro? tocca di nuovo" : text, on: armed, color: Palette.rec) {
            if armed {
                armed = false
                action()
            } else {
                armed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { armed = false }
            }
        }
    }
}

/// Il fondo giusto per un tasto che si accende: spento = vetro scuro; acceso = colore della macchina,
/// o rosso se il suo colore è il rosso, o vetro colorato se ha un suo colore.
func vetroLook(on: Bool, color: Color?, theme: VetroTheme) -> VetroLook {
    guard on else { return .off }
    guard let c = color else { return .on(theme.color) }
    if c == Palette.rec { return .red }
    if c == Palette.accent { return .on(theme.color) }
    return .on(c)
}

// MARK: barre

/// Il disegno di una barra (manopola per il QuadStick): binario di vetro, riempimento col colore e alone,
/// pomello bianco lucido. Solo il disegno: misure e gesti restano nella barra che lo usa.
struct VetroTrack: View {
    let tint: Color
    /// da 0 a 1
    let fraction: CGFloat
    let knob: CGFloat
    let width: CGFloat
    var height: CGFloat = 10

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.black.opacity(0.30))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                .frame(height: height)
            Capsule()
                .fill(LinearGradient(colors: [tint.opacity(0.75), tint], startPoint: .leading, endPoint: .trailing))
                .frame(width: knob / 2 + (width - knob) * fraction, height: height)
                .shadow(color: tint.opacity(0.6), radius: 6)
            Circle()
                .fill(RadialGradient(colors: [Color.white, Color(white: 0.82)], center: UnitPoint(x: 0.35, y: 0.3),
                                     startRadius: 0, endRadius: knob * 0.7))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.35), radius: 3, y: 1)
                .shadow(color: tint.opacity(0.45), radius: 6)
                .frame(width: knob, height: knob)
                .offset(x: (width - knob) * fraction)
        }
    }
}

/// Come `StepCell` (in RitmoView, del TP-7): un passo, pieno col colore della macchina, bordo bianco su quello che suona.
struct VetroStepCell: View {
    @Environment(\.vetro) private var theme
    let label: String
    let filled: Bool
    let current: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: 40)
                .vetroKey(filled ? .glass(theme.color) : .off, radius: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(current ? Color.white : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }
}
