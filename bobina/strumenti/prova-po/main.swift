// Prova del sequencer dei PO sul Mac, senza macchine: due porte MIDI finte, una per il TX-6 e una per l'adattatore.
// 1. Il TX-6 parte, il PO si aggancia: i passi del PO devono cadere sugli stessi istanti di quelli del TX-6,
//    a partire da un inizio di battuta, anche con lo «schermo» bloccato 300 ms ogni 500.
// 2. Passi dal vivo: lo stesso tasto su passi di fila va lasciato 20 ms prima di ripremerlo.
// 3. Effetti a tempo: fx giù 20 ms prima del numero, e intanto i passi dal vivo tacciono.
// 4. Sync out dell'adattatore: clock sempre acceso, start al primo passo, niente impulsi doppi.
// 5. Due PO, due adattatori: partono insieme, stessi istanti; se il primo si ferma il secondo continua.
//
//   cd bobina/Bobina && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -O \
//     MIDI.swift TX6.swift PO.swift BobinaClock.swift TX6Sequencer.swift POSequencer.swift ../strumenti/prova-po/main.swift -o /tmp/prova-po && /tmp/prova-po
import Foundation
import CoreMIDI

// PO.swift usa MIDIPort e TableSection: qui basta una TableSection finta
struct TableRow { let key: String; let what: String; var more: String? = nil; var community = false }
struct TableSection { let title: String; var intro: String? = nil; let rows: [TableRow] }

var client = MIDIClientRef()
MIDIClientCreateWithBlock("prova" as CFString, &client, nil)
let lock = NSLock()
var got: [String: [(UInt64, [UInt8])]] = [:]
func fake(_ name: String) -> MIDIEndpointRef {
    var d = MIDIEndpointRef()
    MIDIDestinationCreateWithBlock(client, name as CFString, &d) { list, _ in
        for packet in list.unsafeSequence() {
            let length = Int(packet.pointee.length)
            let bytes = withUnsafeBytes(of: packet.pointee.data) { Array($0.prefix(length)) }
            lock.lock(); got[name, default: []].append((packet.pointee.timeStamp, bytes)); lock.unlock()
        }
    }
    return d
}
let txIO = MIDIIO(); txIO.use(destination: fake("tx6"), source: 0)
let poIO = MIDIIO(); poIO.use(destination: fake("po"), source: 0)
let tx = TX6Sequencer(io: txIO)
let po = POSequencer(io: poIO)
func ms(_ t: UInt64) -> Double { poIO.ms(ticks: t) }
func run(_ s: Double) { RunLoop.main.run(until: Date().addingTimeInterval(s)) }
func take(_ name: String) -> [(UInt64, [UInt8])] { lock.lock(); defer { got[name] = []; lock.unlock() }; return got[name] ?? [] }
func ons(_ pkts: [(UInt64, [UInt8])], status: UInt8) -> [(UInt64, [UInt8])] { pkts.filter { $0.1.contains(status) } }
func noteOns(_ bytes: [UInt8]) -> [UInt8] {
    var out: [UInt8] = []; var i = 0
    while i + 2 < bytes.count || i < bytes.count {
        let s = bytes[i]
        if s & 0xF0 == 0x90 || s & 0xF0 == 0x80 || s & 0xF0 == 0xB0 { if s & 0xF0 == 0x90, i + 1 < bytes.count { out.append(bytes[i + 1]) }; i += 3 } else { i += 1 }
    }
    return out
}
func noteOffs(_ bytes: [UInt8]) -> [UInt8] {
    var out: [UInt8] = []; var i = 0
    while i < bytes.count {
        let s = bytes[i]
        if s & 0xF0 == 0x90 || s & 0xF0 == 0x80 || s & 0xF0 == 0xB0 { if s & 0xF0 == 0x80, i + 1 < bytes.count { out.append(bytes[i + 1]) }; i += 3 } else { i += 1 }
    }
    return out
}

// ---------- 1. TX-6 e PO sulla stessa griglia
BobinaClock.shared.setBPM(120, at: txIO.now())
var tp = TX6Sequencer.Plan()
tp.beatsOn = true
tp.beats[1] = Array(repeating: true, count: 16)
tx.update(tp)
var pp = POSequencer.Plan()
pp.liveOn = true
pp.live[0] = Array(repeating: true, count: 16)             // tasto 1 su tutti i passi (ripremuto di continuo)
pp.live[8] = (0..<16).map { $0 % 4 == 0 }                  // tasto 9 in battere
po.update(pp)
tx.start(at: txIO.now() + txIO.ticks(ms: 30))
run(0.7)
po.start(at: poIO.now() + poIO.ticks(ms: 30))
let end = Date().addingTimeInterval(3)
while Date() < end {
    usleep(300_000)                                         // lo «schermo» bloccato
    RunLoop.main.run(until: Date().addingTimeInterval(0.2))
}
po.stop(); tx.stop(sendStop: false)
run(0.3)
// traccia 2: dal 54f5618 la batteria del TX-6 suona sul canale della traccia (0x91), non più sul 7
let txSteps = ons(take("tx6"), status: 0x91).map { $0.0 }
let poPkts = take("po")
let poSteps = poPkts.filter { noteOns($0.1).contains(68) }.map { $0.0 }
let offsets = poSteps.map { p in txSteps.map { t in abs(ms(p &- t) * (p >= t ? 1 : -1)) }.min() ?? -1 }
let firstPO = poSteps.first ?? 0
let barStartIndex = txSteps.firstIndex { abs(ms($0 &- firstPO) * ($0 >= firstPO ? 1 : -1)) < 0.5 } ?? -1
let gaps = zip(poSteps.dropFirst(), poSteps).map { ms($0 - $1) }
print(String(format: "1. passi del PO: %d, scarto dai passi del TX-6 al massimo %.3f ms; il primo cade sul passo %d del TX-6 (%@); intervalli %.2f-%.2f ms",
             poSteps.count, offsets.max() ?? -1, barStartIndex, barStartIndex % 16 == 0 ? "inizio di battuta" : "NON inizio di battuta", gaps.min() ?? 0, gaps.max() ?? 0))

// ---------- 2. lo stesso tasto ripremuto
let earlyOffs = poPkts.filter { $0.0 > 0 && noteOffs($0.1).contains(68) && !noteOns($0.1).contains(68) }.map { $0.0 }.sorted()
let lead = poSteps.dropFirst().compactMap { s in earlyOffs.filter { $0 < s }.last.map { ms(s - $0) } }
print(String(format: "2. tasto 1 lasciato prima di ogni nuova pressione: %d volte su %d, %.1f-%.1f ms prima", lead.count, max(0, poSteps.count - 1), lead.min() ?? 0, lead.max() ?? 0))

// ---------- 3. effetti a tempo
pp = POSequencer.Plan()
pp.liveOn = true
pp.live[4] = Array(repeating: true, count: 16)             // tasto 5 su tutti i passi
pp.fxOn = true
pp.fx = (0..<16).map { $0 >= 12 ? 9 : nil }                // fx 9 sugli ultimi quattro passi
po.update(pp)
run(0.2)
po.start(at: poIO.now() + poIO.ticks(ms: 30))
run(2.3)
po.stop()
run(0.3)
let fxPkts = take("po")
let fxOn = fxPkts.filter { noteOns($0.1).contains(80) }.map { $0.0 }
let nineOn = fxPkts.filter { noteOns($0.1).contains(60) }.map { $0.0 }
let fiveDuringFx = fxPkts.filter { p in noteOns(p.1).contains(72) && zip(nineOn, fxPkts.filter { noteOffs($0.1).contains(60) }.map { $0.0 }).contains { p.0 >= $0.0 && p.0 < $0.1 } }.count
let fxLead = zip(nineOn, fxOn).map { ms($0 - $1) }
print(String(format: "3. fx giù %d volte, %.1f ms prima del tasto 9; tasto 5 premuto mentre l'effetto è tenuto: %d volte",
             fxOn.count, fxLead.min() ?? -1, fiveDuringFx))

// ---------- 4. sync out dell'adattatore
pp = POSequencer.Plan()
pp.sync = .adapter
pp.clockAlways = true
po.update(pp)
run(1.0)
po.start(at: poIO.now() + poIO.ticks(ms: 30))
run(1.5)
po.stop()
pp.clockAlways = false
po.update(pp)
run(0.3)
let clk = take("po")
let clocks = clk.filter { $0.1.contains(0xF8) }.map { $0.0 }
let cgaps = zip(clocks.dropFirst(), clocks).map { ms($0 - $1) }
let startAt = clk.first { $0.1.contains(0xFA) }?.0
print(String(format: "4. clock: %d impulsi, intervalli %.2f-%.2f ms (atteso 20,83); start %@; stop %@",
             clocks.count, cgaps.min() ?? 0, cgaps.max() ?? 0, startAt == nil ? "mancante" : "c'è", clk.contains { $0.1.contains(0xFC) } ? "c'è" : "mancante"))
if let s0 = startAt, let i = clk.firstIndex(where: { $0.0 == s0 }) {
    for (t, b) in clk[max(0, i - 3)..<min(clk.count, i + 4)] { print(String(format: "   %8.2f ms", t >= s0 ? ms(t - s0) : -ms(s0 - t)), b.map { String(format: "%02x", $0) }.joined(separator: " ")) }
}
if let s0 = startAt { for (a, b) in zip(clocks.dropFirst(), clocks) where ms(a - b) < 20 || ms(a - b) > 21.7 { print(String(format: "   intervallo storto %.2f ms a %.1f ms dallo start", ms(a - b), a >= s0 ? ms(a - s0) : -ms(s0 - a))) } }

// ---------- 5. due PO insieme
let po2IO = MIDIIO(); po2IO.use(destination: fake("po2"), source: 0)
let po2 = POSequencer(io: po2IO, member: .po2)
var a = POSequencer.Plan(); a.liveOn = true; a.live[0] = (0..<16).map { $0 % 2 == 0 }
var b = POSequencer.Plan(); b.liveOn = true; b.live[8] = (0..<16).map { $0 % 2 == 0 }
po.update(a); po2.update(b)
run(0.1)
_ = take("po"); _ = take("po2")
let t0 = poIO.now() + poIO.ticks(ms: 30)
po.start(at: t0); po2.start(at: t0)
run(1.2)
po.stop()
run(1.2)
let still = BobinaClock.shared.snapshot().running
po2.stop()
run(0.3)
let s1 = take("po").filter { noteOns($0.1).contains(68) }.map { $0.0 }
let s2 = take("po2").filter { noteOns($0.1).contains(60) }.map { $0.0 }
let pairs = zip(s1, s2).map { abs($0.0 >= $0.1 ? ms($0.0 - $0.1) : ms($0.1 - $0.0)) }
print(String(format: "5. PO 1: %d colpi, PO 2: %d colpi; scarto fra i due al massimo %.3f ms; fermato il PO 1 la griglia va ancora: %@",
             s1.count, s2.count, pairs.max() ?? -1, still ? "sì" : "NO"))
