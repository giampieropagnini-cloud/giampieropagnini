// Prova dell'orologio unico sul Mac, senza macchine.
// 1. Il TX-6 parte, poi un'altra sezione si aggancia: deve cadere su un inizio di battuta del TX-6.
// 2. A metà un'altra sezione cambia il bpm (da un altro filo): i passi del TX-6 non devono saltare.
// 3. «Segui il TX-6»: arriva un clock a 125 bpm col tremolio del bluetooth (±4 ms);
//    la griglia di Bobina deve restare vicina al clock vero.
//
//   cd bobina/Bobina && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -O \
//     MIDI.swift TX6.swift BobinaClock.swift TX6Sequencer.swift ../strumenti/prova-orologio/main.swift -o /tmp/orologio && /tmp/orologio
import Foundation
import CoreMIDI

var client = MIDIClientRef()
MIDIClientCreateWithBlock("prova" as CFString, &client, nil)
var dest = MIDIEndpointRef()
let lock = NSLock()
var got: [(UInt64, [UInt8])] = []
MIDIDestinationCreateWithBlock(client, "prova-tx6" as CFString, &dest) { list, _ in
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
plan.beatsOn = true
plan.beats[0] = (0..<16).map { $0 == 0 }          // traccia 1: solo il primo passo della battuta
plan.beats[1] = Array(repeating: true, count: 16)  // traccia 2: tutti i passi
seq.update(plan)

func run(_ seconds: Double) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }

// 1 e 2
BobinaClock.shared.setBPM(120, at: io.now())
seq.start(at: io.now() + io.ticks(ms: 30))
run(1.3)
let (line, first) = BobinaClock.shared.join(.po, at: io.now() + io.ticks(ms: 150))
let joinTime = line.time(ofBeat: first)
run(0.9)
DispatchQueue.global().async { BobinaClock.shared.setBPM(150) }
run(1.5)
seq.stop(sendStop: false)
BobinaClock.shared.leave(.po)
run(0.3)

lock.lock(); let all = got; got.removeAll(); lock.unlock()
let steps = all.filter { $0.1.contains { (0x90...0x96).contains($0) } }.map { $0.0 }
let barStarts = all.filter { pkt in
    // il primo passo della battuta ha due note on (tracce 1 e 2)
    pkt.1.enumerated().filter { (0x90...0x96).contains($0.element) }.count == 2
}.map { $0.0 }
let nearest = barStarts.map { t in t > joinTime ? io.ms(ticks: t - joinTime) : io.ms(ticks: joinTime - t) }.min() ?? -1
print(String(format: "1. l'altra sezione entra al battito %.0f: il più vicino inizio di battuta del TX-6 è a %.3f ms", first, nearest))
let gaps = zip(steps.dropFirst(), steps).map { io.ms(ticks: $0 - $1) }
let at120 = gaps.filter { abs($0 - 125) < 1 }.count
let at150 = gaps.filter { abs($0 - 100) < 1 }.count
let odd = gaps.filter { abs($0 - 125) >= 1 && abs($0 - 100) >= 1 }
print("2. passi a 125 ms: \(at120), a 100 ms: \(at150), altri: " + odd.map { String(format: "%.2f", $0) }.joined(separator: " "))

// 3: segui il TX-6
plan.follow = true
plan.beatsOn = false
seq.update(plan)
run(0.1)
let tickMs = 60_000.0 / 125 / 24
let t0 = io.now() + io.ticks(ms: 20)
var truth: [(Int, UInt64)] = []
seq.realtime(0xFA, t0)
var worst = 0.0
for k in 0..<(24 * 16) {
    let ideal = t0 + io.ticks(ms: Double(k) * tickMs)
    let jitter = Double.random(in: -4...4)
    let stamp = jitter >= 0 ? ideal + io.ticks(ms: jitter) : ideal - io.ticks(ms: -jitter)
    seq.realtime(0xF8, stamp)
    if k % 24 == 0 { truth.append((k / 24, ideal)) }
    usleep(1000)
}
run(0.2)
let l = BobinaClock.shared.snapshot()
// la griglia deve prevedere bene i quarti che devono ancora venire: è lì che i PO mettono i passi
for beat in 16...19 {
    let ideal = t0 + io.ticks(ms: Double(beat) * 480)
    let predicted = l.time(ofBeat: Double(beat))
    worst = max(worst, predicted > ideal ? io.ms(ticks: predicted - ideal) : io.ms(ticks: ideal - predicted))
}
_ = truth
print(String(format: "3. segui il TX-6: bpm misurato %.3f (vero 125), errore sui prossimi 4 quarti al massimo %.2f ms, chi dà il tempo: %@",
             l.bpm, worst, l.followedBy?.rawValue ?? "nessuno"))
print("   il bpm si può cambiare da Bobina mentre segue?", { let b = l.bpm; BobinaClock.shared.setBPM(90, at: io.now()); return BobinaClock.shared.bpm != b ? "sì (sbagliato)" : "no (giusto)" }())
seq.realtime(0xFC, io.now())
run(0.1)
print("   dopo lo stop: suona ancora?", BobinaClock.shared.snapshot().running, "· segue ancora?", BobinaClock.shared.snapshot().followedBy?.rawValue ?? "no")
