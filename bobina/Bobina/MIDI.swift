import Foundation
import CoreMIDI

/// Una porta MIDI vista dal telefono: il TP-7 col cavo USB-C, il TP-7 via bluetooth, o altro.
struct MIDIPort: Identifiable, Hashable {
    let id: MIDIUniqueID
    let ref: MIDIEndpointRef
    let name: String

    var looksLikeTP7: Bool {
        let n = name.lowercased()
        return n.contains("tp-7") || n.contains("tp7") || n.contains("tp–7")
    }
}

/// Righe di controllo che si leggono dal Mac (devicectl --console). Solo nella versione di prova.
func trace(_ text: @autoclosure () -> String) {
    #if DEBUG
    print("[bobina] " + text())
    #endif
}

/// Il filo col mondo MIDI. Col cavo e col bluetooth il TP-7 compare allo stesso modo:
/// come una sorgente (quello che manda) e una destinazione (quello che riceve).
final class MIDIIO {
    private var client = MIDIClientRef()
    private var outPort = MIDIPortRef()
    private var inPort = MIDIPortRef()
    private(set) var destination = MIDIEndpointRef()
    private(set) var source = MIDIEndpointRef()
    private(set) var ready = false
    private var timebase = mach_timebase_info_data_t()

    /// Un messaggio completo arrivato dal TP-7. Chiamata sul main thread.
    var onReceive: (([UInt8], MIDITimeStamp) -> Void)?
    /// Qualcosa si è collegato o scollegato. Chiamata sul main thread.
    var onSetupChanged: (() -> Void)?

    init() {
        mach_timebase_info(&timebase)
        var status = MIDIClientCreateWithBlock("Bobina" as CFString, &client) { [weak self] note in
            trace("notifica \(note.pointee.messageID.rawValue)")
            if note.pointee.messageID == .msgSetupChanged {
                DispatchQueue.main.async { self?.onSetupChanged?() }
            }
        }
        guard status == noErr else { return }
        status = MIDIOutputPortCreate(client, "Bobina uscita" as CFString, &outPort)
        guard status == noErr else { return }
        status = MIDIInputPortCreateWithBlock(client, "Bobina ingresso" as CFString, &inPort) { [weak self] list, _ in
            self?.read(list)
        }
        ready = (status == noErr)
        trace("porta d'ingresso creata: \(status)")
    }

    // MARK: porte

    func destinations() -> [MIDIPort] {
        (0..<MIDIGetNumberOfDestinations()).map { describe(MIDIGetDestination($0)) }
    }

    func sources() -> [MIDIPort] {
        (0..<MIDIGetNumberOfSources()).map { describe(MIDIGetSource($0)) }
    }

    private func describe(_ endpoint: MIDIEndpointRef) -> MIDIPort {
        var name = "senza nome"
        var cf: Unmanaged<CFString>?
        if MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &cf) == noErr, let s = cf?.takeRetainedValue() {
            name = s as String
        }
        var uid: MIDIUniqueID = 0
        _ = MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uid)
        return MIDIPort(id: uid, ref: endpoint, name: name)
    }

    /// Sceglie a chi parlare e chi ascoltare. 0 = nessuno.
    func use(destination: MIDIEndpointRef, source: MIDIEndpointRef) {
        if self.source != 0 && self.source != source {
            let s = MIDIPortDisconnectSource(inPort, self.source)
            trace("stacco la sorgente \(self.source): \(s)")
        }
        if source != 0 && source != self.source {
            let s = MIDIPortConnectSource(inPort, source, nil)
            trace("attacco la sorgente \(source): \(s)")
        }
        trace("uso: manda a \(destination), ascolta \(source)")
        self.destination = destination
        self.source = source
    }

    // MARK: tempo

    /// L'ora del sistema nelle unità che usa CoreMIDI.
    func now() -> MIDITimeStamp { mach_absolute_time() }

    func ticks(ms: Double) -> MIDITimeStamp {
        MIDITimeStamp(max(0, ms) * 1_000_000 * Double(timebase.denom) / Double(timebase.numer))
    }

    func ms(ticks: MIDITimeStamp) -> Double {
        Double(ticks) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000
    }

    // MARK: invio

    /// Butta via i messaggi già in coda in CoreMIDI col loro orario (i passi preparati in anticipo):
    /// allo stop, se no arrivano dopo i messaggi di stop e li annullano.
    func flushScheduled() {
        guard ready, destination != 0 else { return }
        _ = MIDIFlushOutput(destination)
    }

    /// Manda un messaggio al TP-7. Con `time` diverso da 0 CoreMIDI lo consegna in quell'istante preciso.
    func send(_ bytes: [UInt8], at time: MIDITimeStamp = 0) {
        guard ready, destination != 0, !bytes.isEmpty else { return }
        let size = max(1024, bytes.count + 64)
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 8)
        defer { buffer.deallocate() }
        let list = buffer.bindMemory(to: MIDIPacketList.self, capacity: 1)
        let first = MIDIPacketListInit(list)
        bytes.withUnsafeBufferPointer { b in
            if let base = b.baseAddress {
                _ = MIDIPacketListAdd(list, size, first, time, b.count, base)
            }
        }
        _ = MIDISend(outPort, destination, list)
    }

    // MARK: ricezione

    private func read(_ list: UnsafePointer<MIDIPacketList>) {
        let count = Int(list.pointee.numPackets)
        guard count > 0 else { return }
        let listOffset = MemoryLayout<MIDIPacketList>.offset(of: \MIDIPacketList.packet) ?? 4
        let dataOffset = MemoryLayout<MIDIPacket>.offset(of: \MIDIPacket.data) ?? 10
        var packet = UnsafeRawPointer(list).advanced(by: listOffset).assumingMemoryBound(to: MIDIPacket.self)
        var chunks: [([UInt8], MIDITimeStamp)] = []
        let lengthOffset = MemoryLayout<MIDIPacket>.offset(of: \MIDIPacket.length) ?? 8
        for i in 0..<count {
            // i pacchetti sono impaccati a 4 byte: si leggono i campi senza pretendere l'allineamento
            let base = UnsafeRawPointer(packet)
            let length = Int(base.loadUnaligned(fromByteOffset: lengthOffset, as: UInt16.self))
            let stamp = base.loadUnaligned(fromByteOffset: 0, as: UInt64.self)
            let raw = UnsafeRawBufferPointer(start: base.advanced(by: dataOffset), count: length)
            chunks.append((Array(raw), stamp == 0 ? mach_absolute_time() : stamp))
            if i < count - 1 {
                packet = UnsafePointer(MIDIPacketNext(packet))
            }
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for (bytes, stamp) in chunks { self.split(bytes, stamp) }
        }
    }

    /// Un pacchetto può contenere più messaggi uno dopo l'altro: li separa.
    private func split(_ bytes: [UInt8], _ stamp: MIDITimeStamp) {
        var i = 0
        while i < bytes.count {
            let status = bytes[i]
            if status == 0xF0 {
                var j = i + 1
                while j < bytes.count && bytes[j] != 0xF7 { j += 1 }
                let end = min(j + 1, bytes.count)
                onReceive?(Array(bytes[i..<end]), stamp)
                i = end
                continue
            }
            let length = MIDIIO.length(of: status)
            if length == 0 { i += 1; continue }
            let end = min(i + length, bytes.count)
            onReceive?(Array(bytes[i..<end]), stamp)
            i = end
        }
    }

    static func length(of status: UInt8) -> Int {
        switch status & 0xF0 {
        case 0x80, 0x90, 0xA0, 0xB0, 0xE0: return 3
        case 0xC0, 0xD0: return 2
        case 0xF0:
            switch status {
            case 0xF1, 0xF3: return 2
            case 0xF2: return 3
            default: return 1
            }
        default: return 0
        }
    }
}
