// Prova sul Mac (9/10/2026): «lasciato suonare, dopo un po' si blocca e suona una traccia sola». Quando Bobina va in
// secondo piano iOS la ferma a metà nota; al ritorno il sequencer mandava tutti i passi persi in un colpo.
// 1. Il filo del sequencer fermo 3 secondi (come un'app sospesa): al ritorno niente raffica di passi vecchi.
// 2. suspend() (Bobina va in secondo piano) con una nota tenuta: la nota si spegne subito, nessuna resta accesa.
//
//   cd bobina/Bobina && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -O \
//     MIDI.swift TX6.swift BobinaClock.swift TX6Sequencer.swift ../strumenti/prova-sospesa/main.swift -o /tmp/prova && /tmp/prova
import Foundation
import CoreMIDI

var client = MIDIClientRef()
MIDIClientCreateWithBlock("prova" as CFString, &client, nil)
var dest = MIDIEndpointRef()
let lock = NSLock()
var got: [(UInt64, UInt64, [UInt8])] = []   // arrivo, marca temporale, byte
MIDIDestinationCreateWithBlock(client, "prova-sospesa" as CFString, &dest) { list, _ in
    for packet in list.unsafeSequence() {
        let length = Int(packet.pointee.length)
        let bytes = withUnsafeBytes(of: packet.pointee.data) { Array($0.prefix(length)) }
        lock.lock(); got.append((mach_absolute_time(), packet.pointee.timeStamp, bytes)); lock.unlock()
    }
}
let io = MIDIIO()
io.use(destination: dest, source: 0)
let seq = TX6Sequencer(io: io)
var plan = TX6Sequencer.Plan()
plan.bpm = 120
plan.beatsOn = true
plan.beats[0] = (0..<16).map { $0 % 4 == 0 }
plan.beats[3] = (0..<16).map { $0 % 2 == 0 }
plan.melodyOn = true
var bass = [Int?](repeating: nil, count: 32)
bass[0] = 2; bass[16] = 10
plan.melodies[4] = bass
plan.melodyOctaves[4] = 2
plan.melodyGates = [1, 1, 1, 1, 0, 1]
seq.update(plan)
seq.start(at: io.now() + io.ticks(ms: 30))
RunLoop.main.run(until: Date().addingTimeInterval(1.0))

var ok = 0, total = 0
func check(_ name: String, _ cond: Bool) { total += 1; if cond { ok += 1 }; print(cond ? "OK" : "NO", "·", name) }

// 1. il filo fermo 3 secondi: al ritorno, quante note in 150 ms?
lock.lock(); let before = got.count; lock.unlock()
seq.blockForTest(3000)
RunLoop.main.run(until: Date().addingTimeInterval(3.3))
lock.lock(); let after = Array(got[before...]); lock.unlock()
let wake = after.first?.0 ?? 0
let burst = after.filter { $0.0 < wake + io.ticks(ms: 150) }.reduce(0) { $0 + $1.2.filter { $0 & 0xF0 == 0x90 }.count }
check("dopo 3 s fermo, nei primi 150 ms al massimo 4 note (\(burst)), non la raffica dei 24 passi persi", burst <= 4)

// 2. in secondo piano: la nota tenuta del basso si spegne subito
RunLoop.main.run(until: Date().addingTimeInterval(1.0))
seq.suspend()
RunLoop.main.run(until: Date().addingTimeInterval(0.6))
lock.lock(); let all = got; lock.unlock()
var on = Set<String>()
for (_, _, b) in all.sorted(by: { $0.1 < $1.1 }) {
    var i = 0
    while i < b.count {
        let st = b[i]
        let len = st >= 0xF8 ? 1 : (0xC0...0xDF).contains(st) ? 2 : 3
        if len == 3 && i + 2 < b.count {
            let key = "\(st & 0x0F)-\(b[i + 1])"
            if st & 0xF0 == 0x90 { on.insert(key) } else if st & 0xF0 == 0x80 { on.remove(key) }
        }
        i += len
    }
}
check("in secondo piano nessuna nota resta accesa (\(on.count))", on.isEmpty)
lock.lock(); let n1 = got.count; lock.unlock()
RunLoop.main.run(until: Date().addingTimeInterval(1.0))
lock.lock(); let n2 = got.count; lock.unlock()
check("e in pausa non parte più niente (\(n2 - n1) pacchetti in 1 s)", n2 == n1)
print("prova sospesa: \(ok)/\(total) giuste")
