// Prova sul Mac: se la griglia comune riparte da zero mentre il TX-6 suona (un'altra sezione parte quando
// il TX-6 non risulta più tra chi suona), il sequencer del TX-6 deve continuare a suonare, non aspettare minuti.
//
//   cd bobina/Bobina && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -O \
//     MIDI.swift TX6.swift BobinaClock.swift TX6Sequencer.swift ../strumenti/prova-salto/main.swift -o /tmp/prova && /tmp/prova
import Foundation
import CoreMIDI

var client = MIDIClientRef()
MIDIClientCreateWithBlock("prova" as CFString, &client, nil)
var dest = MIDIEndpointRef()
let lock = NSLock()
var notes: [Double] = []
var onSince: [Int: Double] = [:]
let io = MIDIIO()
MIDIDestinationCreateWithBlock(client, "prova-salto" as CFString, &dest) { list, _ in
    for packet in list.unsafeSequence() {
        let length = Int(packet.pointee.length)
        let bytes = withUnsafeBytes(of: packet.pointee.data) { Array($0.prefix(length)) }
        var k = 0
        while k + 2 < bytes.count + 0 || k + 2 == bytes.count {
            if bytes[k] & 0xF0 == 0x90 && bytes[k + 2] > 0 {
                let now = Date().timeIntervalSince1970
                lock.lock(); notes.append(now); onSince[Int(bytes[k] & 0x0F) << 8 | Int(bytes[k + 1])] = now; lock.unlock()
            } else if bytes[k] & 0xF0 == 0x80 || (bytes[k] & 0xF0 == 0x90 && bytes[k + 2] == 0) {
                lock.lock(); onSince[Int(bytes[k] & 0x0F) << 8 | Int(bytes[k + 1])] = nil; lock.unlock()
            }
            k += (bytes[k] >= 0xF8) ? 1 : 3
            if k >= bytes.count { break }
        }
    }
}
io.use(destination: dest, source: 0)
let seq = TX6Sequencer(io: io)
var plan = TX6Sequencer.Plan()
plan.bpm = 120
plan.beatsOn = true
plan.beats[0] = Array(repeating: true, count: 16)
// una melodia con note lunghe: i loro spegnimenti sono in coda quando la griglia salta
plan.melodyOn = true
// otto note diverse per battuta: una nota appesa resta accesa fino alla battuta dopo (2 s), e si vede
plan.melodies[1] = (0..<16).map { $0 % 2 == 0 ? [0, 2, 3, 5, 7, 8, 10, 12][$0 / 2] : nil }
plan.melodyLength = 2
seq.update(plan)
seq.start(at: io.now() + io.ticks(ms: 30))
// lascia andare 60 passi, così il prossimo passo del TX-6 è lontano dal battito 0
RunLoop.main.run(until: Date().addingTimeInterval(7.5))
// il TX-6 sparisce da chi suona e un'altra sezione parte: la griglia riparte dal battito 0
BobinaClock.shared.leave(.tx6)
BobinaClock.shared.join(.m8, at: io.now())
let jump = Date().timeIntervalSince1970
RunLoop.main.run(until: Date().addingTimeInterval(1.3))
// prima dello stop (che spegne tutto): una nota accesa da più di un secondo è rimasta appesa (le note durano 250 ms)
let check = Date().timeIntervalSince1970
lock.lock(); let stuck = onSince.values.filter { check - $0 > 1.0 }.count; lock.unlock()
seq.stop(sendStop: false)
RunLoop.main.run(until: Date().addingTimeInterval(0.5))
lock.lock(); let after = notes.filter { $0 > jump + 0.2 }.count; lock.unlock()
print("note dopo il salto: \(after) · note rimaste accese: \(stuck)")
let ok = after >= 8 && stuck == 0
print(ok ? "OK: il TX-6 continua a suonare e non lascia note accese" : "NO")
exit(ok ? 0 : 1)
