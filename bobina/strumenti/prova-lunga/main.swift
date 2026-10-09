// Prova sul Mac (9/10/2026, «lo lascio suonare e dopo un po' si blocca col synth fisso»): un minuto di Sour Times e
// Periferia (batteria fitta, basso e melodia di due battute), col filo del sequencer che ogni tanto resta fermo
// 60-400 ms (come un telefono sotto sforzo). Alla fine nessuna nota accesa, e su basso e melodia mai due note
// insieme né uno spegnimento prima della sua nota.
//
//   cd bobina/Bobina && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -O \
//     MIDI.swift TX6.swift BobinaClock.swift TX6Sequencer.swift ../strumenti/prova-lunga/main.swift -o /tmp/prova && /tmp/prova
import Foundation
import CoreMIDI

var client = MIDIClientRef()
MIDIClientCreateWithBlock("prova" as CFString, &client, nil)
var dest = MIDIEndpointRef()
let lock = NSLock()
var got: [[UInt8]] = []
MIDIDestinationCreateWithBlock(client, "prova-lunga" as CFString, &dest) { list, _ in
    for packet in list.unsafeSequence() {
        let length = Int(packet.pointee.length)
        let bytes = withUnsafeBytes(of: packet.pointee.data) { Array($0.prefix(length)) }
        lock.lock(); got.append(bytes); lock.unlock()
    }
}
func row(_ s: String) -> [Bool] { s.map { $0 == "x" } }
func notes(_ s: String, base: Int) -> [Int?] {
    let names: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
    return s.split(separator: " ").map { t -> Int? in
        guard let f = t.first, let b = names[f] else { return nil }
        var r = t.dropFirst(); var k = b
        if r.first == "#" { k += 1; r = r.dropFirst() } else if r.first == "b" { k -= 1; r = r.dropFirst() }
        guard let o = Int(r) else { return nil }
        return 12 * (o + 1) + k - base
    }
}
let io = MIDIIO()
io.use(destination: dest, source: 0)
let seq = TX6Sequencer(io: io)
var plan = TX6Sequencer.Plan()
plan.bpm = 92
plan.swing = 0.54
plan.beatsOn = true
plan.beats[0] = row("x.xx...xx..x...x")
plan.beats[1] = row("....x.......x...")
plan.beats[2] = row("..........x.....")
plan.beats[3] = row("x.x.x.x.x.x.x.x.")
plan.melodyOn = true
plan.melodies[4] = notes("D2 . . . . . . . . . D2 . . . . . D2 . . . . . . . . . A1 . . . . .", base: 36)
plan.melodies[5] = notes("D5 . . A4 . . G#4 . G4 . . F4 . . E4 . D5 . . A4 . . G#4 . G4 . . Bb4 . . A4 .", base: 60)
plan.melodyOctaves[4] = 2
plan.melodyOctaves[5] = 4
plan.melodyGates = [1, 1, 1, 1, 4, 2]
seq.update(plan)
seq.start(at: io.now() + io.ticks(ms: 30))
var stalls = 0
let end = Date().addingTimeInterval(60)
while Date() < end {
    RunLoop.main.run(until: Date().addingTimeInterval(Double.random(in: 0.5...2.0)))
    seq.blockForTest(Double.random(in: 60...400))
    stalls += 1
    // ogni tanto un cambio di suono sulle tracce 5 e 6, come cambiando pronta
    if Bool.random() { seq.sendPaced([[0xB4, 3, 28], [0xB5, 3, 14]], releasing: [5, 6]) }
}
seq.stop(sendStop: false)
RunLoop.main.run(until: Date().addingTimeInterval(0.6))
lock.lock(); let all = got; lock.unlock()

var on: [UInt8: Set<UInt8>] = [:]
var monoErrors = 0, orphanOffs = 0, ons = 0
for b in all {
    var i = 0
    while i < b.count {
        let st = b[i]
        let len = st >= 0xF8 ? 1 : (0xC0...0xDF).contains(st) ? 2 : 3
        if len == 3 && i + 2 < b.count {
            let ch = st & 0x0F, n = b[i + 1]
            if st & 0xF0 == 0x90 {
                ons += 1
                if (ch == 4 || ch == 5) && !(on[ch] ?? []).isEmpty { monoErrors += 1 }
                on[ch, default: []].insert(n)
            } else if st & 0xF0 == 0x80 {
                if on[ch]?.remove(n) == nil { orphanOffs += 1 }
            }
        }
        i += len
    }
}
let stuck = on.values.reduce(0) { $0 + $1.count }
print("un minuto, \(stalls) fermate del filo, \(ons) note")
print(stuck == 0 ? "OK · nessuna nota rimasta accesa" : "NO · note rimaste accese: \(stuck) \(on)")
print(monoErrors == 0 ? "OK · basso e melodia mai due note insieme" : "NO · due note insieme su basso o melodia: \(monoErrors) volte")
print("spegnimenti senza nota accesa (innocui, dopo i salti): \(orphanOffs)")
