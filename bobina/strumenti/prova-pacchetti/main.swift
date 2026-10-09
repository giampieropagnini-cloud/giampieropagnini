// Prova sul Mac (9/10/2026): col bluetooth il TX-6 si ingolfava con pacchetti grossi (cambi di pronta, passi pieni)
// e alcune tracce restavano mute fino a spegnerlo. Qui: un passo con tutte e sei le righe e due melodie, e un
// cambio di suoni di 24 comandi. Nessun pacchetto deve superare 24 byte, nessun messaggio va tagliato a metà,
// i cambi di suono partono a gruppi distanziati e prima lasciano la nota tenuta.
//
//   cd bobina/Bobina && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -O \
//     MIDI.swift TX6.swift BobinaClock.swift TX6Sequencer.swift ../strumenti/prova-pacchetti/main.swift -o /tmp/prova && /tmp/prova
import Foundation
import CoreMIDI

var client = MIDIClientRef()
MIDIClientCreateWithBlock("prova" as CFString, &client, nil)
var dest = MIDIEndpointRef()
let lock = NSLock()
var got: [(UInt64, [UInt8])] = []
MIDIDestinationCreateWithBlock(client, "prova-pacchetti" as CFString, &dest) { list, _ in
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
plan.beats = Array(repeating: Array(repeating: true, count: 16), count: 6)
plan.melodyOn = true
plan.melodies[4] = (0..<32).map { $0 % 2 == 0 ? 2 : 9 }
plan.melodies[5] = (0..<32).map { [0, 3, 7, 10][$0 % 4] }
plan.melodyGates = [1, 1, 1, 1, 0, 0]
seq.update(plan)
seq.start(at: io.now() + io.ticks(ms: 30))
RunLoop.main.run(until: Date().addingTimeInterval(1.0))
// un cambio di pronta a metà: 24 comandi (4 tracce × 6) e la nota tenuta della traccia 6 da lasciare
var cc: [[UInt8]] = []
for t in 1...4 { for n: UInt8 in [3, 89, 90, 95, 74, 93] { cc.append([0xB0 | UInt8(t - 1), n, 64]) } }
let mark = io.now()
seq.sendPaced(cc, releasing: [6])
RunLoop.main.run(until: Date().addingTimeInterval(1.0))
seq.stop(sendStop: true)
RunLoop.main.run(until: Date().addingTimeInterval(0.5))
lock.lock(); let all = got; lock.unlock()

var ok = 0, total = 0
func check(_ name: String, _ cond: Bool) { total += 1; if cond { ok += 1 }; print(cond ? "OK" : "NO", "·", name) }

let biggest = all.map { $0.1.count }.max() ?? 0
check("nessun pacchetto oltre 24 byte (il più grosso: \(biggest))", biggest <= 24)
// ogni pacchetto comincia con un byte di stato e ha messaggi interi
func whole(_ b: [UInt8]) -> Bool {
    var i = 0
    while i < b.count {
        let st = b[i]
        guard st >= 0x80 else { return false }
        let len = st >= 0xF8 ? 1 : (0xC0...0xDF).contains(st) ? 2 : 3
        i += len
    }
    return i == b.count
}
check("nessun messaggio tagliato a metà", all.allSatisfy { whole($0.1) })
// il cambio di suoni: i pacchetti con dentro i 24 comandi, distanziati di almeno 18 ms
let ccPackets = all.filter { $0.0 >= mark && $0.1.contains(where: { $0 & 0xF0 == 0xB0 }) && $0.1.contains(89) }
let ccCount = ccPackets.reduce(0) { $0 + $1.1.filter { $0 & 0xF0 == 0xB0 }.count }
check("i 24 comandi arrivano tutti (\(ccCount)) in \(ccPackets.count) pacchetti", ccCount == 24 && ccPackets.count >= 3)
let gaps = zip(ccPackets.dropFirst(), ccPackets).map { io.ms(ticks: $0.0 - $1.0) }
check("fra un gruppo e l'altro almeno 18 ms (\(gaps.map { String(format: "%.0f", $0) }.joined(separator: " ")))", gaps.allSatisfy { $0 >= 18 })
// nessuna nota rimasta accesa dopo lo stop
var on = Set<String>()
for (_, b) in all.sorted(by: { $0.0 < $1.0 }) {
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
check("nessuna nota rimasta accesa (\(on.count))", on.isEmpty)
print("prova pacchetti: \(ok)/\(total) giuste")
