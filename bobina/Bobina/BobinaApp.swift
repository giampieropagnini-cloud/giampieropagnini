import SwiftUI

@main
struct BobinaApp: App {
    @StateObject private var engine = Engine()
    @StateObject private var tx6 = TX6Engine()
    @StateObject private var po = POEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
                .environmentObject(tx6)
                .environmentObject(po)
                .preferredColorScheme(.dark)
                .tint(Palette.accent)
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = true
                    tx6.tp7 = engine
                }
        }
    }
}

/// La sezione della macchina scelta: TP-7, TX-6 o Pocket Operator (il tasto in alto a destra le scambia).
struct ContentView: View {
    @AppStorage("bobina.macchina") private var machine = "tp7"

    var body: some View {
        switch machine {
        case "tx6": TX6Tabs()
        case "po": POTabs()
        default: TP7Tabs()
        }
    }
}

struct TP7Tabs: View {
    var body: some View {
        TabView {
            NastroView()
                .tabItem { Label("Nastro", systemImage: "record.circle") }
            PadView()
                .tabItem { Label("Pad", systemImage: "square.grid.3x3.fill") }
            RitmoView()
                .tabItem { Label("Ritmo", systemImage: "metronome") }
            MixerView()
                .tabItem { Label("Mixer", systemImage: "slider.horizontal.3") }
            CollegaView()
                .tabItem { Label("Collega", systemImage: "cable.connector") }
        }
    }
}
