import AVFoundation
import UIKit

/// L'M8 col cavo è anche una scheda audio: appena si collega, l'iPhone prende il suo ingresso come
/// microfono e il Controllo Vocale non sente più niente. Qui Bobina chiede di tenere il microfono
/// dell'iPhone finché c'è un ingresso USB. L'uscita non si tocca.
final class M8Mic: ObservableObject {
    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "bobina.m8.microfono")
            apply()
        }
    }
    /// Il microfono che l'iPhone sta usando adesso, per mostrarlo.
    @Published private(set) var inputName = ""
    @Published private(set) var usbPresent = false
    @Published private(set) var problem: String?

    private let session = AVAudioSession.sharedInstance()
    private var active = false
    private var observers: [NSObjectProtocol] = []

    init() {
        enabled = UserDefaults.standard.object(forKey: "bobina.m8.microfono") as? Bool ?? true
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.apply()
        })
        observers.append(nc.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.apply()
        })
        apply()
    }

    /// Guarda gli ingressi e, se c'è un USB, rimette quello dell'iPhone.
    func apply() {
        let usb = (session.availableInputs ?? []).contains { $0.portType == .usbAudio }
            || session.currentRoute.inputs.contains { $0.portType == .usbAudio }
        if usbPresent != usb { usbPresent = usb }

        if enabled && usb {
            AVAudioApplication.requestRecordPermission { [weak self] ok in
                DispatchQueue.main.async { self?.hold(granted: ok) }
            }
        } else if active {
            active = false
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            trace("M8 microfono: lascio la sessione")
        }
        refreshName()
    }

    private func hold(granted: Bool) {
        guard granted else {
            problem = "Bobina non ha il permesso del microfono: Impostazioni → Bobina → Microfono."
            return
        }
        do {
            if session.category != .playAndRecord {
                try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .allowBluetoothA2DP])
            }
            try session.setActive(true)
            active = true
            if let mic = session.availableInputs?.first(where: { $0.portType == .builtInMic }),
               session.currentRoute.inputs.first?.portType != .builtInMic {
                try session.setPreferredInput(mic)
            }
            problem = nil
            trace("M8 microfono: ingresso " + session.currentRoute.inputs.map { $0.portName }.joined(separator: ", ")
                  + " · uscita " + session.currentRoute.outputs.map { $0.portName }.joined(separator: ", "))
        } catch {
            problem = "iOS non lascia scegliere il microfono: \(error.localizedDescription)"
            trace("M8 microfono: errore \(error)")
        }
        refreshName()
    }

    private func refreshName() {
        let name = session.currentRoute.inputs.first.map { $0.portType == .builtInMic ? "iPhone" : $0.portName } ?? "nessuno"
        if inputName != name { inputName = name }
    }
}
