// Prova del cambio di pattern sul Mac, senza macchina: il pattern chiesto a metà battuta deve entrare
// all'inizio della battuta dopo, coi suoni nello stesso pacchetto, e poi andare al suo tempo.
//
//   cd bobina/Bobina && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -O \
//     MIDI.swift TX6.swift BobinaClock.swift TX6Sequencer.swift ../strumenti/prova-pattern/main.swift -o /tmp/prova && /tmp/prova
import Foundation
import CoreMIDI

var client = MIDIClientRef()
MIDIClientCreateWithBlock("prova" as CFString, &client, nil)
var dest = MIDIEndpointRef()
let lock = NSLock()
var got: [(UInt64, [UInt8])] = []
MIDIDestinationCreateWithBlock(client, "prova-pat" as CFString, &dest) { list, _ in
    for packet in list.unsafeSequence() {
        let length = Int(packet.pointee.length)
        let bytes = withUnsafeBytes(of: packet.pointee.data) { Array($0.prefix(length)) }
        lock.lock(); got.append((packet.pointee.timeStamp, bytes)); lock.unlock()
    }
}
let io = MIDIIO()
io.use(destination: dest, source: 0)
let seq = TX6Sequencer(io: io)
var switchedAt: String?
seq.onSwitched = { id in switchedAt = "entrato " + id.uuidString.prefix(4) }
var plan = TX6Sequencer.Plan()
plan.bpm = 120
plan.beatsOn = true
plan.beats[0] = (0..<16).map { $0 % 4 == 0 }     // A: cassa sui quarti, nota 60
seq.update(plan)
let start = io.now() + io.ticks(ms: 30)
seq.start(at: start)
RunLoop.main.run(until: Date().addingTimeInterval(1.3))   // a metà della seconda battuta (2 s a battuta)
var beatsB = Array(repeating: Array(repeating: false, count: 16), count: 6)
beatsB[1] = (0..<16).map { $0 % 8 == 0 }         // B: traccia 2 (nota 62) ogni metà battuta
let partB = TX6Sequencer.Part(id: UUID(), beats: beatsB, melodies: plan.melodies, melodyOctaves: plan.melodyOctaves,
                              melodyLength: 1, locks: plan.locks, lockTrack: 1, lockCC: 89, lockBase: 64,
                              gate: plan.gate, soundBytes: [0xB1, 0x03, 0x46], bpm: 100)
seq.queuePattern(partB)
RunLoop.main.run(until: Date().addingTimeInterval(3.5))
seq.stop(sendStop: false)
RunLoop.main.run(until: Date().addingTimeInterval(0.2))
lock.lock(); let all = got; lock.unlock()
for (t, b) in all where b.contains { (0x90...0x96).contains($0) } || b.contains(0xB1) {
    print(String(format: "%8.1f ms", io.ms(ticks: t &- start)), b.map { String(format: "%02x", $0) }.joined(separator: " "))
}
print(switchedAt ?? "nessun cambio")
