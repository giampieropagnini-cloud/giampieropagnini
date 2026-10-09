// Prova sul Mac: melodie di due battute e note tenute (9/10/2026). Traccia 6 a 32 passi con «tenuta»:
// ogni nota resta giù fino alla nota dopo, e si spegne nello stesso pacchetto, prima della nota nuova.
// Traccia 5 a 16 passi con note fitte e durata lunga: una traccia del TX-6 suona una nota alla volta, quindi
// non deve mai restare giù più di una nota, e ogni spegnimento deve essere quello della nota accesa.
//
//   cd bobina/Bobina && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -O \
//     MIDI.swift TX6.swift BobinaClock.swift TX6Sequencer.swift ../strumenti/prova-tenuta/main.swift -o /tmp/prova && /tmp/prova
import Foundation
import CoreMIDI

var client = MIDIClientRef()
MIDIClientCreateWithBlock("prova" as CFString, &client, nil)
var dest = MIDIEndpointRef()
let lock = NSLock()
var got: [(UInt64, [UInt8])] = []
MIDIDestinationCreateWithBlock(client, "prova-tenuta" as CFString, &dest) { list, _ in
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
// traccia 6: re (0) · fa (12) | la (16) · sol (28), ottava 4, tenuta
var lead = [Int?](repeating: nil, count: 32)
lead[0] = 2; lead[12] = 5; lead[16] = 9; lead[28] = 7
plan.melodies[5] = lead
plan.melodyOctaves[5] = 4
// traccia 5: la stessa nota ogni due passi e una diversa in mezzo, durata 1/2 (8 passi): si accavallerebbero
plan.melodies[4] = (0..<16).map { $0 % 2 == 0 ? ($0 % 4 == 0 ? 2 : 9) : nil }
plan.melodyOctaves[4] = 2
plan.melodyGates = [1, 1, 1, 1, 8, 0]
seq.update(plan)
let t0 = io.now() + io.ticks(ms: 30)
seq.start(at: t0)
RunLoop.main.run(until: Date().addingTimeInterval(4.5))
seq.stop(sendStop: false)
RunLoop.main.run(until: Date().addingTimeInterval(0.5))
lock.lock(); let all = got; lock.unlock()

// (istante, ordine nel pacchetto, stato, nota) in ordine di arrivo
var events: [(UInt64, Int, UInt8, UInt8)] = []
for (t, b) in all {
    var k = 0, order = 0
    while k < b.count {
        let st = b[k]
        if st >= 0xF8 { k += 1; continue }
        if (0x80...0x9F).contains(st) && k + 2 < b.count + 1 { events.append((t, order, st, b[k + 1])); order += 1 }
        k += 3
    }
}
events.sort { ($0.0, $0.1) < ($1.0, $1.1) }
let stepTicks = Double(io.ticks(ms: 125))
func step(_ t: UInt64) -> Int { Int((Double(t &- t0) / stepTicks).rounded()) }

var ok = 0, total = 0
func check(_ name: String, _ cond: Bool) { total += 1; if cond { ok += 1 }; print(cond ? "OK" : "NO", "·", name) }

// traccia 6 (canale 6): accensioni e spegnimenti per passo
let ch6 = events.filter { $0.2 & 0x0F == 5 }
let ons6 = ch6.filter { $0.2 & 0xF0 == 0x90 }.map { (step($0.0), Int($0.3)) }
let offs6 = ch6.filter { $0.2 & 0xF0 == 0x80 }.map { (step($0.0), Int($0.3)) }
print("traccia 6, accese:", ons6.map { "\($0.0):\($0.1)" }.joined(separator: " "))
print("traccia 6, spente:", offs6.map { "\($0.0):\($0.1)" }.joined(separator: " "))
let first = ons6.first?.0 ?? 0
let rel = ons6.map { ($0.0 - first, $0.1) }
check("la seconda battuta suona (la4 al passo 16)", rel.contains { $0.0 == 16 && $0.1 == 69 })
check("re4 tenuto fino al passo 12, poi fa4", offs6.contains { $0.0 - first == 12 && $0.1 == 62 })
check("sol4 tenuto fino al giro dopo (passo 32)", offs6.contains { $0.0 - first == 32 && $0.1 == 67 } || rel.allSatisfy { $0.0 < 32 })
// nello stesso pacchetto lo spegnimento viene prima della nota nuova
var sameOrder = true
for e in ch6 where e.2 & 0xF0 == 0x90 {
    if let off = ch6.first(where: { $0.2 & 0xF0 == 0x80 && $0.0 == e.0 }), off.1 > e.1 { sameOrder = false }
}
check("lo spegnimento parte prima della nota nuova, nello stesso pacchetto", sameOrder)

// una nota alla volta per traccia, e ogni spegnimento è della nota accesa
func mono(_ ch: UInt8) -> (Bool, Int) {
    var on: Int? = nil
    var bad = 0
    for e in events where e.2 & 0x0F == ch {
        if e.2 & 0xF0 == 0x90 {
            if on != nil { bad += 1 }
            on = Int(e.3)
        } else {
            if on != Int(e.3) { bad += 1 }
            on = nil
        }
    }
    return (bad == 0 && on == nil, bad)
}
let (m5, bad5) = mono(4)
let (m6, bad6) = mono(5)
check("traccia 5 con note fitte e lunghe: mai due note insieme, nessuna rimasta accesa (\(bad5) errori)", m5)
check("traccia 6: mai due note insieme, nessuna rimasta accesa (\(bad6) errori)", m6)
print("prova tenuta: \(ok)/\(total) giuste")
