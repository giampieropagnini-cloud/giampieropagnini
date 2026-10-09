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
        let velluto = TX6MelodyPreset.all.first { $0.name == "Velluto" }!
        let neon = TX6MelodyPreset.all.first { $0.name == "Neon" }!

        // i preset pronti: ogni suono che nominano esiste, ogni melodia ha due battute e note nel registro giusto
        let names = Set(TX6Preset.builtIn.map(\.name))
        check("20 batterie pronte, ogni suono esiste", TX6DrumPreset.all.count == 20 && TX6DrumPreset.all.allSatisfy { $0.sounds.allSatisfy(names.contains) })
        check("20 melodie pronte, ogni suono esiste", TX6MelodyPreset.all.count == 20 && TX6MelodyPreset.all.allSatisfy { $0.sounds.allSatisfy(names.contains) })
        check("ogni melodia pronta: basso e melodia di 32 passi", TX6MelodyPreset.all.allSatisfy { $0.parts.allSatisfy { $0.steps.count == 32 && $0.steps.contains { $0 != nil } } })
        check("le batterie pronte usano solo i motori di batteria", TX6DrumPreset.all.allSatisfy { d in
            d.sounds.allSatisfy { n in TX6Preset.builtIn.first { $0.name == n }.map { (4...7).contains($0.sound) } ?? false } })
        let v = velluto.parts
        check("Velluto: il basso parte dal re (re2) e la melodia dal la (la4)",
              v[0].steps[0].map { 12 * (v[0].octave + 1) + $0 } == 38 && v[1].steps[2].map { 12 * (v[1].octave + 1) + $0 } == 69)

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
        step(0.1) { tx.applyMelody(velluto) }
        step(0.3) {
            plan { p in
                check("melodia pronta Velluto: basso sulla 5, melodia sulla 6", p.melodies[4] == v[0].steps && p.melodies[5] == v[1].steps)
                check("due battute e note tenute", p.melodies[4].count == 32 && p.melodyGates[4] == 0 && p.melodyGates[5] == 0)
                check("melodia accesa", p.melodyOn)
            }
        }
        step(0.1) { tx.applyMelody(neon) }
        step(0.3) {
            plan { p in
                check("Neon dopo Velluto: arpeggio in sedicesimi", p.melodies[5] == neon.parts[1].steps && p.melodyGates[5] == 1)
            }
        }
        step(0.1) { tx.setMelodyBars(6, 1) }
        step(0.3) { plan { p in check("una battuta sola", p.melodies[5].count == 16) } }
        step(0.1) { tx.setMelodyBars(6, 2) }
        step(0.3) { plan { p in check("e di nuovo due, come prima", p.melodies[5] == neon.parts[1].steps) } }
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
        // a 84 bpm (NY State) una battuta dura 2,86 s: si aspetta di più
        step(3.3) { check("lo stile è entrato", tx.pendingPatternName == nil && tx.currentPatternID == TX6Pattern.styles[0].id) }
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
