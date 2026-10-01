#if DEBUG
import Foundation
import Combine
import QuartzCore

/// Solo nella versione di prova: una riga al secondo nel registro (devicectl --console) con quanto resta
/// bloccato il filo dello schermo, quante volte cambiano le sezioni e si ridisegnano le pagine, quanti
/// pacchetti MIDI partono e arrivano per ogni macchina. Serve a capire, sul telefono vero, cosa rallenta.
final class Diagnostics {
    static let shared = Diagnostics()

    private let lock = NSLock()
    private var counts: [String: Int] = [:]
    private var sums: [String: Double] = [:]
    private var maxLag = 0.0
    private var stalls = 0
    private var cancellables: [AnyCancellable] = []
    private let queue = DispatchQueue(label: "bobina.diagnosi", qos: .utility)
    private var timers: [DispatchSourceTimer] = []
    private var started = false

    func count(_ key: String, _ n: Int = 1) {
        lock.lock()
        counts[key, default: 0] += n
        lock.unlock()
    }

    /// Somma millisecondi (o altro) da scrivere nella riga del secondo.
    func add(_ key: String, _ value: Double) {
        lock.lock()
        sums[key, default: 0] += value
        lock.unlock()
    }

    /// `watch`: gli oggetti di cui contare i cambiamenti (ognuno fa ridisegnare chi lo guarda).
    func start(watch objects: [(String, ObservableObjectPublisher)]) {
        guard !started else { return }
        started = true
        for (name, publisher) in objects {
            publisher.sink { [weak self] _ in self?.count("cambi " + name) }.store(in: &cancellables)
        }
        // ogni 50 ms si chiede al filo dello schermo di rispondere, e si misura quanto ci mette
        let ping = DispatchSource.makeTimerSource(queue: queue)
        ping.schedule(deadline: .now() + 1, repeating: .milliseconds(50))
        ping.setEventHandler { [weak self] in
            let sent = CACurrentMediaTime()
            DispatchQueue.main.async {
                let lag = (CACurrentMediaTime() - sent) * 1000
                guard let self = self else { return }
                self.lock.lock()
                if lag > self.maxLag { self.maxLag = lag }
                if lag > 50 { self.stalls += 1 }
                self.lock.unlock()
            }
        }
        ping.resume()
        let report = DispatchSource.makeTimerSource(queue: queue)
        report.schedule(deadline: .now() + 1, repeating: 1)
        report.setEventHandler { [weak self] in self?.report() }
        report.resume()
        timers = [ping, report]
    }

    private func report() {
        lock.lock()
        let c = counts
        let sm = sums
        let lag = maxLag
        let st = stalls
        counts = [:]
        sums = [:]
        maxLag = 0
        stalls = 0
        lock.unlock()
        let parts = (c.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }
                     + sm.sorted { $0.key < $1.key }.map { String(format: "%@ %.1f", $0.key, $0.value) }).joined(separator: " · ")
        print(String(format: "[diagnosi] schermo: ritardo max %.0f ms, blocchi oltre 50 ms %d · ", lag, st) + parts)
        fflush(stdout)
    }
}
#endif
