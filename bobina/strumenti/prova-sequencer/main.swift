// Prova del sequencer del TX-6 sul Mac, senza macchina: suona verso una porta MIDI finta e intanto
// blocca il filo principale 300 ms ogni 500 ms, come quando si scorre lo schermo. I passi devono
// restare a 125 ms esatti (120 bpm) e il clock a 20,83 ms.
//
//   cd bobina/Bobina && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -O \
//     MIDI.swift TX6.swift BobinaClock.swift TX6Sequencer.swift ../strumenti/prova-sequencer/main.swift -o /tmp/prova && /tmp/prova
import Foundation
import CoreMIDI

// Una porta MIDI finta: registra la marca temporale di ogni pacchetto che il sequencer manda.
var client = MIDIClientRef()
MIDIClientCreateWithBlock("prova" as CFString, &client, nil)
var dest = MIDIEndpointRef()
let lock = NSLock()
var got: [(UInt64, [UInt8])] = []
MIDIDestinationCreateWithBlock(client, "prova-tx6" as CFString, &dest) { list, _ in
    for packet in list.unsafeSequence() {
        let length = Int(packet.pointee.length)
        let bytes = withUnsafeBytes(of: packet.pointee.data) { Array($0.prefix(length)) }
        lock.lock(); got.append((packet.pointee.timeStamp, bytes)); lock.unlock()
    }
}
let io = MIDIIO()
io.use(destination: dest, source: 0)
let seq = TX6Sequencer(io: io)
var plan = TX6Sequencer.Plan()
plan.bpm = 120
plan.sendClock = true
plan.beatsOn = true
plan.beats[0] = Array(repeating: true, count: 16)
plan.beats[1] = (0..<16).map { $0 % 2 == 0 }
plan.beats[2] = (0..<16).map { $0 % 4 == 0 }
seq.update(plan)
seq.start(at: io.now() + io.ticks(ms: 30))
// lo «schermo» si blocca 300 ms ogni 500 ms, come quando si scorre
let end = Date().addingTimeInterval(4)
while Date() < end {
    usleep(300_000)
    RunLoop.main.run(until: Date().addingTimeInterval(0.2))
}
seq.stop(sendStop: true)
RunLoop.main.run(until: Date().addingTimeInterval(0.3))

lock.lock(); let all = got; lock.unlock()
func stats(_ name: String, _ ts: [UInt64], expect: Double) {
    let ms = zip(ts.dropFirst(), ts).map { io.ms(ticks: $0 - $1) }
    guard let lo = ms.min(), let hi = ms.max() else { print(name, "niente"); return }
    print(String(format: "%@: %d, intervallo atteso %.2f ms, min %.2f, max %.2f", name, ts.count, expect, lo, hi))
}
stats("passi (note on)", all.filter { $0.1.contains(0x96) }.map { $0.0 }, expect: 125)
stats("clock", all.filter { $0.1.contains(0xF8) }.map { $0.0 }, expect: 500.0 / 24)
let steps = all.filter { $0.1.contains(0x96) }
print("note per passo (tre tracce insieme = un pacchetto):", Set(steps.map { $0.1.count / 3 }).sorted())
print("start:", all.contains { $0.1.contains(0xFA) }, "stop:", all.contains { $0.1.contains(0xFC) })
let t0 = all.first?.0 ?? 0
for (t, b) in all.prefix(12) { print(String(format: "%8.2f ms", io.ms(ticks: t &- t0)), b.map { String(format: "%02x", $0) }.joined(separator: " ")) }
let clocks = all.filter { $0.1.contains(0xF8) }.map { $0.0 }
for (i, pair) in zip(clocks.dropFirst(), clocks).enumerated() where io.ms(ticks: pair.0 - pair.1) > 30 { print("buco dopo il clock", i, String(format: "a %.1f ms", io.ms(ticks: pair.1 &- t0))) }
