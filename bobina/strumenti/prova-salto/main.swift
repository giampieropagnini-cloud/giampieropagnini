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
let io = MIDIIO()
MIDIDestinationCreateWithBlock(client, "prova-salto" as CFString, &dest) { list, _ in
    for packet in list.unsafeSequence() {
        let length = Int(packet.pointee.length)
        let bytes = withUnsafeBytes(of: packet.pointee.data) { Array($0.prefix(length)) }
        var k = 0
        while k + 2 < bytes.count + 0 || k + 2 == bytes.count {
            if bytes[k] == 0x90 && bytes[k + 2] > 0 { lock.lock(); notes.append(Date().timeIntervalSince1970); lock.unlock() }
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
seq.update(plan)
seq.start(at: io.now() + io.ticks(ms: 30))
// lascia andare 60 passi, così il prossimo passo del TX-6 è lontano dal battito 0
RunLoop.main.run(until: Date().addingTimeInterval(7.5))
// il TX-6 sparisce da chi suona e un'altra sezione parte: la griglia riparte dal battito 0
BobinaClock.shared.leave(.tx6)
BobinaClock.shared.join(.m8, at: io.now())
let jump = Date().timeIntervalSince1970
RunLoop.main.run(until: Date().addingTimeInterval(1.5))
seq.stop(sendStop: false)
lock.lock(); let after = notes.filter { $0 > jump + 0.2 }.count; lock.unlock()
print("note nel secondo e mezzo dopo il salto: \(after)")
print(after >= 8 ? "OK: il TX-6 continua a suonare" : "NO: il TX-6 si è fermato")
exit(after >= 8 ? 0 : 1)
