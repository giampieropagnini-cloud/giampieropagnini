import AVFoundation
import UIKit

/// L'M8 col cavo è anche una scheda audio: appena si collega, l'iPhone prende il suo ingresso come
/// microfono e il Controllo Vocale non sente più niente. Qui Bobina chiede di tenere il microfono
/// giusto finché c'è l'M8: un altro microfono USB se c'è, se no quello dell'iPhone. L'uscita non si tocca.
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
    /// L'iPhone sta ascoltando l'ingresso dell'M8.
    @Published private(set) var onM8 = false
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

    /// Guarda gli ingressi e, se c'è l'M8, rimette il microfono giusto.
    func apply() {
        // gli ingressi USB compaiono solo con una categoria che registra: impostarla non accende niente
        if enabled && session.category != .playAndRecord {
            try? session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .allowBluetoothA2DP])
        }
        // conta solo l'M8: un microfono USB da solo non è un problema
        let usb = (session.availableInputs ?? []).contains(where: M8Mic.isM8)
            || session.currentRoute.inputs.contains(where: M8Mic.isM8)
        if usbPresent != usb { usbPresent = usb }
        trace("M8 microfono · ingressi: " + (session.availableInputs ?? []).map { "\($0.portName) [\($0.portType.rawValue)]" }.joined(separator: " · ")
              + " · adesso: " + session.currentRoute.inputs.map { $0.portName }.joined(separator: ", "))

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
            // un microfono USB vero (es. il CM-15 sull'hub) vince su quello dell'iPhone; l'M8 mai
            let inputs = session.availableInputs ?? []
            let wanted = inputs.first(where: { $0.portType == .usbAudio && !M8Mic.isM8($0) })
                ?? inputs.first(where: { $0.portType == .builtInMic })
            if let mic = wanted, session.currentRoute.inputs.first?.uid != mic.uid {
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

    static func isM8(_ p: AVAudioSessionPortDescription) -> Bool {
        let n = p.portName.lowercased()
        return p.portType == .usbAudio && (n.contains("m8") || n.contains("dirtywave"))
    }

    private func refreshName() {
        let name = session.currentRoute.inputs.first.map { $0.portType == .builtInMic ? "iPhone" : $0.portName } ?? "nessuno"
        if inputName != name { inputName = name }
        let m8 = session.currentRoute.inputs.contains(where: M8Mic.isM8)
        if onM8 != m8 { onM8 = m8 }
    }
}
