// Prova sul Mac (10/10/2026, «col bluetooth il TX-6 rallenta e si pianta, col cavo mai»): il filo leggero per il
// bluetooth (TX6Wire). Venti secondi di Sour Times e Periferia, con un passo con manopola sul rullante, cambi di suono
// e fermate del filo, come in prova-lunga. Col bluetooth: ogni pacchetto ha un canale solo; i colpi dei motori di
// batteria non ricevono lo spegnimento; il cambio del rullante parte prima del colpo; su basso e melodia mai due note
// insieme, mai uno spegnimento prima della sua nota, nessuna nota accesa alla fine. Col cavo tutto come prima.
//
//   cd bobina/Bobina && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -O \
//     MIDI.swift TX6.swift BobinaClock.swift TX6Sequencer.swift ../strumenti/prova-bluetooth/main.swift -o /tmp/prova && /tmp/prova
import Foundation
import CoreMIDI

var client = MIDIClientRef()
MIDIClientCreateWithBlock("prova" as CFString, &client, nil)
var dest = MIDIEndpointRef()
let lock = NSLock()
var got: [(t: MIDITimeStamp, bytes: [UInt8])] = []
MIDIDestinationCreateWithBlock(client, "prova-bluetooth" as CFString, &dest) { list, _ in
    for packet in list.unsafeSequence() {
        let length = Int(packet.pointee.length)
        let bytes = withUnsafeBytes(of: packet.pointee.data) { Array($0.prefix(length)) }
        let t = packet.pointee.timeStamp == 0 ? mach_absolute_time() : packet.pointee.timeStamp
        lock.lock(); got.append((t, bytes)); lock.unlock()
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

func makePlan(bluetooth: Bool) -> TX6Sequencer.Plan {
    var plan = TX6Sequencer.Plan()
    plan.bpm = 92
    plan.swing = 0.54
    plan.beatsOn = true
    plan.beats[0] = row("x.xx...xx..x...x")
    plan.beats[1] = row("....x.......x...")
    plan.beats[2] = row("..........x.....")
    plan.beats[3] = row("x.x.x.x.x.x.x.x.")
    plan.lockOn = true
    plan.lockTrack = 2
    plan.lockCC = 89
    plan.lockBase = 62
    plan.locks[4] = 50
    plan.locks[12] = 80
    plan.melodyOn = true
    plan.melodies[4] = notes("D2 . . . . . . . . . D2 . . . . . D2 . . . . . . . . . A1 . . . . .", base: 36)
    plan.melodies[5] = notes("D5 . . A4 . . G#4 . G4 . . F4 . . E4 . D5 . . A4 . . G#4 . G4 . . Bb4 . . A4 .", base: 60)
    plan.melodyOctaves[4] = 2
    plan.melodyOctaves[5] = 4
    plan.melodyGates = [1, 1, 1, 1, 0, 2]
    plan.bluetooth = bluetooth
    plan.oneShot = [true, true, true, true, false, false]
    return plan
}

func run(bluetooth: Bool, seconds: Double) -> [(t: MIDITimeStamp, bytes: [UInt8])] {
    lock.lock(); got.removeAll(); lock.unlock()
    let seq = TX6Sequencer(io: io)
    seq.update(makePlan(bluetooth: bluetooth))
    seq.start(at: io.now() + io.ticks(ms: 30))
    let end = Date().addingTimeInterval(seconds)
    while Date() < end {
        RunLoop.main.run(until: Date().addingTimeInterval(Double.random(in: 0.5...2.0)))
        seq.blockForTest(Double.random(in: 60...300))
        if Bool.random() { seq.sendPaced([[0xB4, 3, 28], [0xB4, 89, 38], [0xB5, 3, 14], [0xB5, 89, 62]], releasing: [5, 6]) }
    }
    seq.stop(sendStop: false)
    RunLoop.main.run(until: Date().addingTimeInterval(0.8))
    // il salvagente del ■, come lo manda la pagina
    seq.sendPaced([TX6.noteOff(38, channel: 5), TX6.noteOff(74, channel: 6), TX6.noteOff(24, channel: 7)])
    RunLoop.main.run(until: Date().addingTimeInterval(0.4))
    lock.lock(); defer { lock.unlock() }
    return got
}

var failures = 0
func check(_ ok: Bool, _ yes: String, _ no: String) {
    print(ok ? "OK · \(yes)" : "NO · \(no)")
    if !ok { failures += 1 }
}

// l'aggancio per il Playdate: deve sentire tutte le note che partono
let tapLock = NSLock()
var tapped = 0
TX6Sequencer.noteTap = { _, _, _, _ in tapLock.lock(); tapped += 1; tapLock.unlock() }

// col bluetooth
let bt = run(bluetooth: true, seconds: 20)
let events = bt.enumerated().sorted { ($0.element.t, $0.offset) < ($1.element.t, $1.offset) }.map { $0.element }
var mixed = 0, drumOffs = 0, drumOns = 0, monoErrors = 0, orphanOffs = 0
var on: [UInt8: Set<UInt8>] = [:]
var lockTimes: [MIDITimeStamp] = [], snareTimes: [MIDITimeStamp] = []
for p in events {
    let ms = TX6Wire.messages(p.bytes)
    let kinds = Set(ms.map { $0[0] >= 0xF0 ? 0xF0 : ($0[0] & 0xF0 == 0xB0 ? Int($0[0]) : 0x100 | Int($0[0] & 0x0F)) })
    if kinds.count > 1 { mixed += 1 }
    for m in ms where m.count == 3 {
        let st = m[0], ch = st & 0x0F
        if st == 0xB1 && m[1] == 89 { lockTimes.append(p.t) }
        if ch == 6 && st & 0xF0 == 0x90 {
            drumOns += 1
            if m[1] == 26 { snareTimes.append(p.t) }
        }
        if ch == 6 && st & 0xF0 == 0x80 { drumOffs += 1 }
        guard ch == 4 || ch == 5 else { continue }
        if st & 0xF0 == 0x90 {
            if !(on[ch] ?? []).isEmpty { monoErrors += 1 }
            on[ch, default: []].insert(m[1])
        } else if st & 0xF0 == 0x80 {
            if on[ch]?.remove(m[1]) == nil { orphanOffs += 1 }
        }
    }
}
let stuck = on.values.reduce(0) { $0 + $1.count }
// un colpo di rullante dello stesso passo partito prima del suo cambio di frequenza (entro 50 ms prima del cambio)
let window = io.ticks(ms: 50)
let lockLate = lockTimes.filter { tc in snareTimes.contains { td in td < tc && tc - td < window } }.count
print("bluetooth: \(bt.count) pacchetti, \(drumOns) colpi")
check(mixed == 0, "ogni pacchetto ha un canale solo", "\(mixed) pacchetti con più canali")
check(drumOffs <= 1, "nessuno spegnimento per i colpi di batteria (solo quello del salvagente)", "\(drumOffs) spegnimenti di batteria")
check(lockLate == 0, "il cambio del rullante arriva prima dei colpi", "\(lockLate) colpi prima del loro cambio")
check(monoErrors == 0, "basso e melodia mai due note insieme", "due note insieme \(monoErrors) volte")
check(stuck == 0, "nessuna nota accesa alla fine", "note rimaste accese: \(on)")
print("spegnimenti senza nota accesa (innocui, dopo i salti e il salvagente): \(orphanOffs)")
func isNote(_ m: [UInt8]) -> Bool {
    guard m.count == 3 else { return false }
    let kind = m[0] & 0xF0
    return kind == 0x80 || kind == 0x90
}
let sentNotes = bt.flatMap { TX6Wire.messages($0.bytes) }.filter(isNote).count
tapLock.lock(); let heard = tapped; tapLock.unlock()
check(heard == sentNotes, "l'aggancio del Playdate sente tutte le note (\(heard))", "l'aggancio ne sente \(heard) su \(sentNotes)")
TX6Sequencer.noteTap = nil

// col cavo: un pacchetto per passo e gli spegnimenti della batteria, come prima
let usb = run(bluetooth: false, seconds: 4)
let usbMixed = usb.filter { p in Set(TX6Wire.messages(p.bytes).map { $0[0] & 0x0F }).count > 1 }.count
let usbDrumOffs = usb.flatMap { TX6Wire.messages($0.bytes) }.filter { $0[0] == 0x86 }.count
check(usbMixed > 0 && usbDrumOffs > 0, "col cavo come prima: passi in un pacchetto, colpi spenti (\(usbDrumOffs))",
      "col cavo è cambiato qualcosa (pacchetti misti \(usbMixed), spegnimenti batteria \(usbDrumOffs))")
print(failures == 0 ? "tutto OK" : "\(failures) prove non passate")
exit(failures == 0 ? 0 : 1)
