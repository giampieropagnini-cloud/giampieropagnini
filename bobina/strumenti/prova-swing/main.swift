// Prova sul Mac: lo swing sposta in avanti i sedicesimi dispari e lascia il clock dritto.
// A 120 bpm un sedicesimo dura 125 ms; con swing 0,62 i passi dispari arrivano 0,24 × 125 = 30 ms dopo.
//
//   cd bobina/Bobina && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -O \
//     MIDI.swift TX6.swift BobinaClock.swift TX6Sequencer.swift ../strumenti/prova-swing/main.swift -o /tmp/prova && /tmp/prova
import Foundation
import CoreMIDI

var client = MIDIClientRef()
MIDIClientCreateWithBlock("prova" as CFString, &client, nil)
var dest = MIDIEndpointRef()
let lock = NSLock()
var got: [(UInt64, [UInt8])] = []
MIDIDestinationCreateWithBlock(client, "prova-swing" as CFString, &dest) { list, _ in
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
plan.swing = 0.62
plan.beatsOn = true
plan.beats[0] = Array(repeating: true, count: 16)
seq.update(plan)
seq.start(at: io.now() + io.ticks(ms: 30))
RunLoop.main.run(until: Date().addingTimeInterval(2.2))
seq.stop(sendStop: false)
RunLoop.main.run(until: Date().addingTimeInterval(0.4))
lock.lock(); let all = got; lock.unlock()

// istanti dei colpi della traccia 1 (sul canale 7: 0x96) e degli impulsi di clock (0xF8), in ms dalla prima nota
var notes: [Double] = []
var clocks: [Double] = []
for (t, b) in all {
    var k = 0
    while k < b.count {
        let st = b[k]
        if st == 0xF8 || st == 0xFA || st == 0xFC { if st == 0xF8 { clocks.append(io.ms(ticks: t)) }; k += 1; continue }
        if st == 0x96 && k + 2 < b.count && b[k + 2] > 0 { notes.append(io.ms(ticks: t)) }
        k += 3
    }
}
guard let first = notes.first, notes.count >= 9 else { print("troppo poche note: \(notes.count)"); exit(1) }
let gaps = zip(notes.dropFirst(), notes).map { $0 - $1 }
print("intervalli fra i passi (ms):", gaps.prefix(8).map { String(format: "%.1f", $0) }.joined(separator: " "))
// atteso: pari→dispari 155, dispari→pari 95 (125 ± 30)
let ok = gaps.prefix(8).enumerated().allSatisfy { i, g in abs(g - (i % 2 == 0 ? 155 : 95)) < 3 }
let cgaps = zip(clocks.dropFirst(), clocks).map { $0 - $1 }.filter { $0 > 1 }
let clockStraight = cgaps.prefix(40).allSatisfy { abs($0 - 125.0 / 6) < 2 }
print("clock:", cgaps.prefix(8).map { String(format: "%.1f", $0) }.joined(separator: " "))
print(ok && clockStraight ? "OK: dispari 30 ms dopo, clock dritto" : "NO", "(prima nota a \(String(format: "%.0f", first)) ms)")
exit(ok && clockStraight ? 0 : 1)
