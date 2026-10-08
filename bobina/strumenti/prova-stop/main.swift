// Prova sul Mac: ferma il sequencer del TX-6 a metà, con note su ogni passo. Ogni nota accesa deve avere
// il suo spegnimento dopo (le note già consegnate a CoreMIDI col loro istante arrivano dopo lo stop).
//
//   cd bobina/Bobina && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -O \
//     MIDI.swift TX6.swift BobinaClock.swift TX6Sequencer.swift ../strumenti/prova-stop/main.swift -o /tmp/prova && /tmp/prova
import Foundation
import CoreMIDI
// Ferma il sequencer a metà con una melodia su ogni passo: ogni nota accesa deve avere il suo spegnimento DOPO.
var client = MIDIClientRef()
MIDIClientCreateWithBlock("prova" as CFString, &client, nil)
var dest = MIDIEndpointRef()
let lock = NSLock()
var got: [(UInt64, [UInt8])] = []
MIDIDestinationCreateWithBlock(client, "prova-stop" as CFString, &dest) { list, _ in
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
plan.melodyOn = true
plan.melodies[0] = Array(repeating: 7, count: 16)
plan.melodyLength = 1
plan.beatsOn = true
plan.beats[1] = Array(repeating: true, count: 16)
seq.update(plan)
seq.start(at: io.now() + io.ticks(ms: 30))
RunLoop.main.run(until: Date().addingTimeInterval(1.07))
seq.stop(sendStop: false)
RunLoop.main.run(until: Date().addingTimeInterval(0.5))
lock.lock(); let all = got; lock.unlock()
// per ogni messaggio note on/off: (istante, stato, nota)
var events: [(UInt64, UInt8, UInt8)] = []
for (t, b) in all { var k = 0; while k + 2 < b.count + 0 && k < b.count { let st = b[k]; if (0x80...0x9F).contains(st) && k + 2 < b.count + 1 { events.append((t, st, b[k+1])); k += 3 } else if st == 0xF8 || st == 0xFA || st == 0xFC { k += 1 } else { k += 3 } } }
var on: [String: UInt64] = [:]
var stuck = 0
for (t, st, n) in events.sorted(by: { $0.0 < $1.0 }) {
    let key = "\(st & 0x0F)-\(n)"
    if st & 0xF0 == 0x90 { on[key] = t } else { on[key] = nil }
}
stuck = on.count
print("note accese rimaste senza spegnimento dopo lo stop:", stuck)
