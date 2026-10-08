#if DEBUG
import Foundation

/// Prova automatica di Crea, nel simulatore o sul telefono (8/10/2026, Giampiero: «devi ricontrollarlo tu e vedere
/// se funziona»). Fa quello che farebbe lui, un passo alla volta, e controlla il piano che il sequencer suona davvero:
/// batteria pronta col ritmo che gira, una cella tolta, svuota tutta la batteria, batteria spenta e riaccesa,
/// melodia pronta, melodia spenta, svuota tutto, un pattern che entra alla battuta e poi una modifica.
/// Si accende lanciando l'app con l'argomento `-bobina.prova.crea YES` (vale solo per quel lancio, per esempio
/// `xcrun simctl launch --console-pty <simulatore> com.giampieropagnini.bobina -bobina.prova.crea YES`) e scrive
/// le righe «[bobina] prova …» che si leggono dal Mac.
enum TX6SelfTest {
    static func run(_ tx: TX6Engine) {
        var ok = 0
        var total = 0
        func check(_ name: String, _ cond: Bool) {
            total += 1
            if cond { ok += 1 }
            trace("prova \(cond ? "OK" : "NO") · \(name)")
        }
        func plan(_ f: @escaping (TX6Sequencer.Plan) -> Void) { tx.sequencer.debugEffectivePlan(f) }
        func row(_ s: String) -> [Bool] { s.map { $0 == "x" } }

        // la catena dei passi: ognuno dopo il precedente, con il tempo per arrivare al sequencer (piano ogni 40 ms)
        var steps: [(Double, () -> Void)] = []
        func step(_ wait: Double, _ f: @escaping () -> Void) { steps.append((wait, f)) }
        func go(_ i: Int) {
            guard i < steps.count else {
                trace("prova FINE · \(ok)/\(total) giusti")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + steps[i].0) {
                steps[i].1()
                go(i + 1)
            }
        }

        let ny = TX6DrumPreset.all.first { $0.name == "NY State" }!
        let arp = TX6MelodyPreset.all.first { $0.name == "arpeggio" }!

        step(0.2) {
            trace("prova INIZIO")
            tx.clockMode = .own
            tx.bpm = 120
            if !tx.running {
                tx.beatsOn = true
                tx.melodyOn = true
                tx.toggleRun()
            }
        }
        step(0.4) { check("il ritmo gira", tx.running) }
        step(0.1) { tx.playDrums(ny) }
        step(0.3) {
            plan { p in
                check("batteria pronta NY State nel sequencer, subito", (0..<4).allSatisfy { p.beats[$0] == row(ny.rows[$0]) })
                check("bpm della batteria pronta", abs(tx.bpm - Double(ny.bpm)) < 0.01)
                check("swing della batteria pronta", abs(p.swing - ny.swing) < 0.001)
            }
        }
        step(0.3) { tx.beats[0][0] = false }
        step(0.3) { plan { p in check("una cella tolta arriva al sequencer", p.beats[0][0] == false) } }
        step(0.1) { tx.clearDrums() }
        step(0.3) { plan { p in check("svuota tutta la batteria", p.beats.allSatisfy { $0.allSatisfy { !$0 } }) } }
        step(0.1) { tx.playDrums(ny) }
        step(0.3) { tx.beatsOn = false }
        step(0.3) { plan { p in check("batteria spenta", p.beatsOn == false) } }
        step(0.1) { tx.beatsOn = true }
        step(0.3) { plan { p in check("batteria riaccesa", p.beatsOn == true) } }
        step(0.1) { tx.applyMelody(arp, from: 5) }
        step(0.3) {
            plan { p in
                check("melodia pronta arpeggio sulla traccia 5", p.melodies[4] == arp.voices[0])
                check("melodia accesa", p.melodyOn)
            }
        }
        step(0.1) { tx.melodyOn = false }
        step(0.3) { plan { p in check("melodia spenta", p.melodyOn == false) } }
        step(0.1) {
            tx.melodyOn = true
            tx.clearMelodies()
        }
        step(0.3) { plan { p in check("svuota tutte le melodie", p.melodies.allSatisfy { $0.allSatisfy { $0 == nil } }) } }
        // un pattern (stile) entra alla battuta: poi una modifica deve valere
        step(0.1) { tx.play(TX6Pattern.styles[0]) }
        step(0.1) { check("lo stile aspetta la battuta", tx.pendingPatternName != nil) }
        step(2.6) { check("lo stile è entrato", tx.pendingPatternName == nil && tx.currentPatternID == TX6Pattern.styles[0].id) }
        step(0.1) { tx.clearDrums() }
        step(0.3) { plan { p in check("dopo lo stile, svuota la batteria arriva al sequencer", p.beats.allSatisfy { $0.allSatisfy { !$0 } }) } }
        // uno stile in coda e subito una batteria pronta: vale la batteria pronta
        step(0.1) { tx.play(TX6Pattern.styles[1]) }
        step(2.4) { tx.playDrums(ny) }
        step(0.3) { plan { p in check("batteria pronta dopo uno stile appena entrato", (0..<4).allSatisfy { p.beats[$0] == row(ny.rows[$0]) }) } }
        step(0.1) { tx.clearDrums() }
        step(0.3) { plan { p in check("e poi svuota arriva lo stesso", p.beats.allSatisfy { $0.allSatisfy { !$0 } }) } }
        step(0.1) { if tx.running { tx.toggleRun() } }
        go(0)
    }
}
#endif
