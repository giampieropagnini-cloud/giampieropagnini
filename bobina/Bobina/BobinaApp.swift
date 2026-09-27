import SwiftUI

@main
struct BobinaApp: App {
    @StateObject private var engine = Engine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
                .preferredColorScheme(.dark)
                .tint(Palette.accent)
                .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        }
    }
}

struct ContentView: View {
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
