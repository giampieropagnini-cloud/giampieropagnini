// Prova sul Mac (9/10/2026, «si mette il synth fisso»): una pronta cambia il suono della traccia 6 mentre la sua
// nota tenuta è già preparata ma non ancora partita (fino a 150 ms avanti). Lo spegnimento deve arrivare DOPO la
// nota: prima arrivava prima, la nota partiva dopo e restava accesa per sempre.
//
//   cd bobina/Bobina && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -O \
//     MIDI.swift TX6.swift BobinaClock.swift TX6Sequencer.swift ../strumenti/prova-salvagente/main.swift -o /tmp/prova && /tmp/prova
import Foundation
import CoreMIDI

var client = MIDIClientRef()
MIDIClientCreateWithBlock("prova" as CFString, &client, nil)
var dest = MIDIEndpointRef()
let lock = NSLock()
var got: [(UInt64, [UInt8])] = []
MIDIDestinationCreateWithBlock(client, "prova-salvagente" as CFString, &dest) { list, _ in
    for packet in list.unsafeSequence() {
        let length = Int(packet.pointee.length)
        let bytes = withUnsafeBytes(of: packet.pointee.data) { Array($0.prefix(length)) }
        lock.lock(); got.append((mach_absolute_time(), bytes)); lock.unlock()
    }
}
let io = MIDIIO()
io.use(destination: dest, source: 0)
let seq = TX6Sequencer(io: io)
var plan = TX6Sequencer.Plan()
plan.bpm = 120
plan.melodyOn = true
var lead = [Int?](repeating: nil, count: 32)
lead[0] = 9            // un la tenuto, uno solo in due battute
plan.melodies[5] = lead
plan.melodyOctaves[5] = 4
plan.melodyGates = [1, 1, 1, 1, 1, 0]
seq.update(plan)
seq.start(at: io.now() + io.ticks(ms: 80))
// la nota è preparata (fra 80 ms) ma non ancora partita: arriva il cambio di suono della pronta
RunLoop.main.run(until: Date().addingTimeInterval(0.02))
seq.sendPaced([[0xB5, 3, 14], [0xB5, 90, 110]], releasing: [6])
RunLoop.main.run(until: Date().addingTimeInterval(1.0))
seq.stop(sendStop: false)
RunLoop.main.run(until: Date().addingTimeInterval(0.5))
lock.lock(); let all = got; lock.unlock()

var on = Set<String>()
var order: [String] = []
for (_, b) in all {   // in ordine di arrivo
    var i = 0
    while i < b.count {
        let st = b[i]
        let len = st >= 0xF8 ? 1 : (0xC0...0xDF).contains(st) ? 2 : 3
        if len == 3 && i + 2 < b.count && (st & 0xF0 == 0x90 || st & 0xF0 == 0x80) {
            let key = "\(st & 0x0F)-\(b[i + 1])"
            order.append((st & 0xF0 == 0x90 ? "acceso " : "spento ") + key)
            if st & 0xF0 == 0x90 { on.insert(key) } else { on.remove(key) }
        }
        i += len
    }
}
print("in ordine di arrivo:", order.joined(separator: " · "))
print(on.isEmpty ? "OK · nessuna nota rimasta accesa" : "NO · note rimaste accese: \(on.sorted())")
