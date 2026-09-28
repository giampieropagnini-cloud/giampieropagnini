import Foundation
import CoreMIDI

// Ascolta sul Mac tutte le sorgenti MIDI per 15 minuti e scrive cosa arriva: serve a misurare
// cosa manda davvero una macchina (il TP-7, o altre) senza passare dall'iPhone. Il clock lo conta al secondo.
//
//   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -O \
//     bobina/Bobina/MIDI.swift bobina/strumenti/ascolta/main.swift -o /tmp/ascolta && /tmp/ascolta
let io = MIDIIO()
var connected = Set<MIDIUniqueID>()
var clocks = 0
var lastReport = Date()
var inPorts: [MIDIIO] = []
io.onReceive = { bytes, _ in
    if bytes == [0xF8] { clocks += 1; return }
    print(String(format: "%@  %@  %@", DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium),
                 bytes.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " "), TP7desc(bytes)))
    fflush(stdout)
}
func TP7desc(_ m: [UInt8]) -> String {
    guard let s = m.first else { return "" }
    switch s { case 0xFA: return "start"; case 0xFB: return "continue"; case 0xFC: return "stop"; case 0xF0: return "sysex"; default: break }
    switch s & 0xF0 {
    case 0xB0: return "cc \(m[1]) = \(m.count > 2 ? m[2] : 0) ch \((s & 0x0F) + 1)"
    case 0xE0: return "pitch bend"
    case 0x90: return "nota \(m[1])"
    default: return ""
    }
}
var lastList = ""
func scan() {
    let list = io.sources().map { "\($0.name)#\($0.ref)" }.joined(separator: ", ")
    if list != lastList {
        print(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium), "sorgenti cambiate:", list.isEmpty ? "nessuna" : list); fflush(stdout)
        lastList = list
        inPorts.removeAll(); connected.removeAll()
    }
    for s in io.sources() where !connected.contains(s.id) {
        // ogni sorgente la sua MIDIIO, così le ascolto tutte insieme
        let extra = MIDIIO()
        extra.onReceive = io.onReceive
        extra.use(destination: 0, source: s.ref)
        inPorts.append(extra)
        connected.insert(s.id)
        print("ascolto:", s.name, s.looksLikeTP7 ? "(TP-7)" : ""); fflush(stdout)
    }
}
let t = DispatchSource.makeTimerSource(queue: .main)
t.schedule(deadline: .now(), repeating: 1)
t.setEventHandler {
    scan()
    if clocks > 0 {
        let secs = Date().timeIntervalSince(lastReport)
        print(String(format: "clock: %d impulsi in %.1f s ≈ %.1f BPM", clocks, secs, Double(clocks) / 24 / secs * 60)); fflush(stdout)
    }
    clocks = 0; lastReport = Date()
}
t.resume()
DispatchQueue.main.asyncAfter(deadline: .now() + 900) { print("fine ascolto"); exit(0) }
RunLoop.main.run()
