import Foundation
import CoreBluetooth
import CoreMIDI

/// Collega il TX-6 col bluetooth senza il pannello di Apple (9/10/2026, Giampiero: «ogni volta devo riandare nel
/// menu»). È la strada che Apple descrive in MIDIBluetoothConnection.h: si cerca il servizio MIDI bluetooth,
/// ci si collega con CoreBluetooth, si chiama MIDIBluetoothDriverActivateAllConnections e il TX-6 compare in
/// CoreMIDI come col pannello; poi CoreBluetooth lascia la connessione a CoreMIDI.
/// Si collega solo a un apparecchio che si chiama TX-6: gli altri (TP-7, PO, OP-Z) non si toccano.
/// Sul TX-6 serve il bluetooth in ascolto: shift + select → BLE → ACCEPT.
final class TX6Bluetooth: NSObject, CBCentralManagerDelegate {
    /// Il servizio MIDI bluetooth (lo stesso per tutti gli apparecchi).
    static let midiService = CBUUID(string: "03B80E5A-EDE8-4B33-A751-6CE34EC4C700")

    /// Cosa sta facendo, da mostrare in cima alla pagina (nil = niente).
    var onState: ((String?) -> Void)?
    /// Dopo il collegamento: c'è il TX-6 fra le porte di CoreMIDI?
    var isRegistered: (() -> Bool)?

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var wantScan = false
    private var giveUp: DispatchWorkItem?
    private var seconds = 30.0

    /// Cerca un TX-6 per `seconds` secondi e lo collega appena lo trova.
    func connect(for seconds: Double = 30) {
        self.seconds = seconds
        wantScan = true
        if let c = central {
            if c.state == .poweredOn { scan() }
        } else {
            central = CBCentralManager(delegate: self, queue: .main)
        }
    }

    func centralManagerDidUpdateState(_ c: CBCentralManager) {
        switch c.state {
        case .poweredOn:
            if wantScan { scan() }
        case .poweredOff:
            onState?("il bluetooth dell'iPhone è spento")
        case .unauthorized:
            onState?("Bobina non ha il permesso del bluetooth: Impostazioni → Bobina → Bluetooth")
        default:
            break
        }
    }

    private func scan() {
        guard let c = central, c.state == .poweredOn else { return }
        wantScan = false
        onState?("cerco il TX-6 col bluetooth…")
        c.scanForPeripherals(withServices: [Self.midiService])
        giveUp?.cancel()
        let w = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.central?.stopScan()
            if self.isRegistered?() != true {
                self.onState?("TX-6 non trovato: sul TX-6 shift + select → BLE → ACCEPT, poi tocca qui")
            }
        }
        giveUp = w
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: w)
    }

    func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        let name = ((advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? p.name ?? "").lowercased()
        guard name.contains("tx-6") || name.contains("tx6") || name.contains("tx–6") else { return }
        c.stopScan()
        giveUp?.cancel()
        peripheral = p
        onState?("collego il TX-6…")
        trace("TX-6 bluetooth: trovato «\(name)», mi collego")
        c.connect(p)
    }

    func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) {
        let status = MIDIBluetoothDriverActivateAllConnections()
        trace("TX-6 bluetooth: collegato, CoreMIDI attivato (\(status))")
        // CoreMIDI ci mette un attimo a farlo comparire: poi CoreBluetooth gli lascia la connessione (passo 6 di Apple)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            if self.isRegistered?() == true {
                c.cancelPeripheralConnection(p)
                self.peripheral = nil
                self.onState?(nil)
            } else {
                self.onState?(status == noErr ? "collegato col bluetooth, ma CoreMIDI non lo vede ancora: tocca qui" : "il TX-6 non si collega (errore \(status)): tocca qui")
            }
        }
    }

    func centralManager(_ c: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        peripheral = nil
        onState?("il TX-6 non si collega: tocca qui per riprovare")
    }
}
