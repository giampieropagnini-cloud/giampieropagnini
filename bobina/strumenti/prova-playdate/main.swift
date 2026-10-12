// Prova sul Mac (10/10/2026, «traccia al Playdate»): Sour Times e Periferia col bluetooth leggero, traccia 6 al Playdate.
// Con il Playdate pronto le note della 6 vanno solo a noteTap e il TX-6 non le riceve; se il ponte cade, al passo dopo
// tornano al TX-6; quando torna, di nuovo al Playdate. Mai una nota accesa per sempre, né sul TX-6 né sul Playdate;
// la traccia 5 suona sempre sul TX-6.
//
//   cd bobina/Bobina && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -O \
//     MIDI.swift TX6.swift BobinaClock.swift TX6Sequencer.swift ../strumenti/prova-playdate/main.swift -o /tmp/prova && /tmp/prova
import Foundation
import CoreMIDI

var client = MIDIClientRef()
MIDIClientCreateWithBlock("prova" as CFString, &client, nil)
var dest = MIDIEndpointRef()
let lock = NSLock()
var got: [[UInt8]] = []
MIDIDestinationCreateWithBlock(client, "prova-playdate" as CFString, &dest) { list, _ in
    for packet in list.unsafeSequence() {
        let length = Int(packet.pointee.length)
        let bytes = withUnsafeBytes(of: packet.pointee.data) { Array($0.prefix(length)) }
        lock.lock(); got.append(bytes); lock.unlock()
    }
}
var tapped: [(ch: Int, note: Int, vel: Int)] = []
TX6Sequencer.noteTap = { ch, note, vel, _ in lock.lock(); tapped.append((ch, note, vel)); lock.unlock() }

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
plan.bpm = 120
plan.beatsOn = true
plan.beats[0] = row("x.xx...xx..x...x")
plan.beats[1] = row("....x.......x...")
plan.beats[3] = row("x.x.x.x.x.x.x.x.")
plan.melodyOn = true
plan.melodies[4] = notes("D2 . . . . . . . . . D2 . . . . . D2 . . . . . . . . . A1 . . . . .", base: 36)
plan.melodies[5] = notes("D5 . . A4 . . G#4 . G4 . . F4 . . E4 . D5 . . A4 . . G#4 . G4 . . Bb4 . . A4 .", base: 60)
plan.melodyOctaves[4] = 2
plan.melodyOctaves[5] = 4
plan.melodyGates = [1, 1, 1, 1, 0, 0]
plan.bluetooth = true
plan.oneShot = [true, true, true, true, false, false]
plan.toPlaydate = [6]
seq.update(plan)

func notesAt(_ packets: ArraySlice<[UInt8]>, channel: UInt8) -> (ons: Int, offs: Int) {
    var ons = 0, offs = 0
    for m in packets.flatMap({ TX6Wire.messages($0) }) where m.count == 3 && m[0] & 0x0F == channel {
        if m[0] & 0xF0 == 0x90 && m[2] > 0 { ons += 1 } else if m[0] & 0xF0 == 0x80 || m[0] & 0xF0 == 0x90 { offs += 1 }
    }
    return (ons, offs)
}
func mark() -> Int { lock.lock(); defer { lock.unlock() }; return got.count }

TX6Sequencer.playdateReady = true
seq.start(at: io.now() + io.ticks(ms: 30))
RunLoop.main.run(until: Date().addingTimeInterval(6))
let m1 = mark()
TX6Sequencer.playdateReady = false          // il ponte cade
RunLoop.main.run(until: Date().addingTimeInterval(6))
let m2 = mark()
TX6Sequencer.playdateReady = true           // il ponte torna
RunLoop.main.run(until: Date().addingTimeInterval(6))
seq.stop(sendStop: false)
RunLoop.main.run(until: Date().addingTimeInterval(0.8))
lock.lock(); let all = got; let taps = tapped; lock.unlock()

var failures = 0
func check(_ ok: Bool, _ yes: String, _ no: String) {
    print(ok ? "OK · \(yes)" : "NO · \(no)")
    if !ok { failures += 1 }
}
let six1 = notesAt(all[0..<m1], channel: 5), six2 = notesAt(all[m1..<m2], channel: 5), six3 = notesAt(all[m2...], channel: 5)
let five = notesAt(all[...], channel: 4)
let tapOns6 = taps.filter { $0.ch == 6 && $0.vel > 0 }.count
let tapOffs6 = taps.filter { $0.ch == 6 && $0.vel == 0 }.count
check(six1.ons == 0, "Playdate pronto: il TX-6 non riceve note della traccia 6", "il TX-6 ha ricevuto \(six1.ons) note della 6 col Playdate pronto")
check(six2.ons > 0, "ponte caduto: la traccia 6 torna sul TX-6 (\(six2.ons) note)", "ponte caduto ma la 6 non suona sul TX-6")
check(six3.ons <= 1, "ponte tornato: di nuovo solo al Playdate", "col ponte tornato il TX-6 ha ricevuto \(six3.ons) note della 6")
let sixAll = notesAt(all[...], channel: 5)
check(sixAll.ons <= sixAll.offs, "sul TX-6 ogni nota della 6 è spenta (\(sixAll.ons) accese, \(sixAll.offs) spente)", "sul TX-6 note della 6 rimaste accese: \(sixAll.ons) accese, \(sixAll.offs) spente")
check(tapOns6 > 0 && tapOns6 <= tapOffs6, "sul Playdate ogni nota della 6 è spenta (\(tapOns6) accese, \(tapOffs6) spente)", "sul Playdate note rimaste accese: \(tapOns6) accese, \(tapOffs6) spente")
check(five.ons > 0 && five.ons <= five.offs, "la traccia 5 suona sempre sul TX-6 (\(five.ons) note)", "la traccia 5: \(five.ons) accese, \(five.offs) spente")
TX6Sequencer.noteTap = nil
TX6Sequencer.playdateReady = false
print(failures == 0 ? "tutto OK" : "\(failures) prove non passate")
exit(failures == 0 ? 0 : 1)
