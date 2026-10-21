import CoreBluetooth
import Foundation

/// CoreBluetooth transport to a Freematics ONE+ running the telelogger firmware with ENABLE_BLE.
/// Commands are queued and sent one at a time; every callback runs on the main queue.
final class FreematicsLink: NSObject, ObservableObject {

    enum RadioState { case unknown, poweredOff, unauthorized, unsupported, ready }

    struct Discovered: Identifiable, Equatable {
        let id: UUID
        let name: String
        var rssi: Int
    }

    enum LinkError: LocalizedError {
        case bluetoothUnavailable, notFound, connectTimeout, serviceMissing, disconnected(Error?)
        var errorDescription: String? {
            switch self {
            case .bluetoothUnavailable: return "Bluetooth is off or not allowed for this app."
            case .notFound: return "The logger is no longer in range."
            case .connectTimeout: return "The logger didn't answer. Check that it's powered and not connected to another phone."
            case .serviceMissing: return "This device doesn't offer the Freematics BLE service. Enable ENABLE_BLE in the telelogger firmware."
            case .disconnected(let e): return e?.localizedDescription ?? "Lost connection to the logger."
            }
        }
    }

    @Published private(set) var radio: RadioState = .unknown
    @Published private(set) var discovered: [Discovered] = []
    @Published private(set) var scanning = false

    /// Called once when an established link drops (not after `disconnect()`).
    var onDisconnect: ((Error?) -> Void)?

    private let serviceUUID = CBUUID(string: FreematicsBLE.serviceUUID)
    private let commandUUID = CBUUID(string: FreematicsBLE.commandUUID)
    private let replyUUID = CBUUID(string: FreematicsBLE.replyUUID)

    private var central: CBCentralManager!
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var peripheral: CBPeripheral?
    private var commandChar: CBCharacteristic?
    private var connectCompletion: ((Result<Void, Error>) -> Void)?
    private var connectTimer: DispatchWorkItem?
    private var scanTimer: DispatchWorkItem?
    private var pendingScan = false
    private var ready = false

    private var queue: [(command: String, completion: (String?) -> Void)] = []
    private var inFlight: (command: String, completion: (String?) -> Void)?
    private var replyTimer: DispatchWorkItem?
    private var assembler = LineAssembler()
    private var router = ReplyRouter()

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    var isConnected: Bool { ready }

    // MARK: Scanning

    func startScan(duration: TimeInterval = 15) {
        discovered = []
        guard radio == .ready else {
            pendingScan = radio == .unknown
            return
        }
        scanning = true
        central.scanForPeripherals(withServices: [serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        scanTimer?.cancel()
        let t = DispatchWorkItem { [weak self] in self?.stopScan() }
        scanTimer = t
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: t)
    }

    func stopScan() {
        pendingScan = false
        scanTimer?.cancel()
        if central.state == .poweredOn { central.stopScan() }
        scanning = false
    }

    // MARK: Connection

    func connect(_ id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        stopScan()
        guard radio == .ready else { return completion(.failure(LinkError.bluetoothUnavailable)) }
        guard let p = peripherals[id] ?? central.retrievePeripherals(withIdentifiers: [id]).first else {
            return completion(.failure(LinkError.notFound))
        }
        teardown()
        peripheral = p
        p.delegate = self
        connectCompletion = completion
        central.connect(p)
        let t = DispatchWorkItem { [weak self] in
            guard let self, let p = self.peripheral else { return }
            self.central.cancelPeripheralConnection(p)
            self.finishConnect(.failure(LinkError.connectTimeout))
        }
        connectTimer = t
        DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: t)
    }

    func disconnect() {
        if let p = peripheral { central.cancelPeripheralConnection(p) }
        teardown()
    }

    private func finishConnect(_ result: Result<Void, Error>) {
        connectTimer?.cancel()
        let c = connectCompletion
        connectCompletion = nil
        if case .failure = result { teardown() }
        c?(result)
    }

    private func teardown() {
        ready = false
        peripheral = nil
        commandChar = nil
        replyTimer?.cancel()
        assembler.reset()
        router.reset()
        let pending = (inFlight.map { [$0] } ?? []) + queue
        inFlight = nil
        queue = []
        pending.forEach { $0.completion(nil) }
    }

    // MARK: Commands

    /// Sends a text command; the completion gets the reply line, or nil on timeout or disconnect.
    func send(_ command: String, completion: @escaping (String?) -> Void) {
        guard ready else { return completion(nil) }
        queue.append((command, completion))
        pump()
    }

    private func pump() {
        guard inFlight == nil, !queue.isEmpty, let p = peripheral, let ch = commandChar else { return }
        let next = queue.removeFirst()
        inFlight = next
        let type: CBCharacteristicWriteType = ch.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        p.writeValue(Data(next.command.utf8), for: ch, type: type)
        let t = DispatchWorkItem { [weak self] in
            guard let self, let cur = self.inFlight else { return }
            self.inFlight = nil
            self.router.commandTimedOut()
            cur.completion(nil)
            self.pump()
        }
        replyTimer = t
        DispatchQueue.main.asyncAfter(deadline: .now() + FreematicsBLE.timeout(for: next.command), execute: t)
    }

    private func receive(_ line: String) {
        guard let reply = router.route(line), let cur = inFlight else { return }
        replyTimer?.cancel()
        inFlight = nil
        cur.completion(reply)
        pump()
    }
}

extension FreematicsLink: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: radio = .ready
        case .poweredOff: radio = .poweredOff
        case .unauthorized: radio = .unauthorized
        case .unsupported: radio = .unsupported
        default: radio = .unknown
        }
        if radio == .ready && pendingScan {
            pendingScan = false
            startScan()
        } else if radio != .ready {
            scanning = false
            if ready || connectCompletion != nil {
                let wasReady = ready
                finishConnect(.failure(LinkError.bluetoothUnavailable))
                teardown()
                if wasReady { onDisconnect?(LinkError.bluetoothUnavailable) }
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let rssi = RSSI.intValue
        guard rssi < 0 else { return } // 127 = unavailable
        peripherals[peripheral.identifier] = peripheral
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? FreematicsBLE.advertisedName
        if let i = discovered.firstIndex(where: { $0.id == peripheral.identifier }) {
            // smooth the RSSI so the list doesn't flicker
            if abs(discovered[i].rssi - rssi) > 3 { discovered[i].rssi = rssi }
        } else {
            discovered.append(Discovered(id: peripheral.identifier, name: name, rssi: rssi))
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        finishConnect(.failure(error ?? LinkError.connectTimeout))
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard peripheral == self.peripheral else { return }
        if connectCompletion != nil {
            finishConnect(.failure(LinkError.disconnected(error)))
        } else {
            let wasReady = ready
            teardown()
            if wasReady { onDisconnect?(LinkError.disconnected(error)) }
        }
    }
}

extension FreematicsLink: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
            central.cancelPeripheralConnection(peripheral)
            return finishConnect(.failure(LinkError.serviceMissing))
        }
        peripheral.discoverCharacteristics([commandUUID, replyUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let chars = service.characteristics ?? []
        guard let cmd = chars.first(where: { $0.uuid == commandUUID }), let reply = chars.first(where: { $0.uuid == replyUUID }) else {
            central.cancelPeripheralConnection(peripheral)
            return finishConnect(.failure(LinkError.serviceMissing))
        }
        commandChar = cmd
        peripheral.setNotifyValue(true, for: reply)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == replyUUID, connectCompletion != nil else { return }
        if let error {
            central.cancelPeripheralConnection(peripheral)
            return finishConnect(.failure(error))
        }
        ready = true
        finishConnect(.success(()))
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == replyUUID, let data = characteristic.value else { return }
        for line in assembler.feed([UInt8](data)) { receive(line) }
    }
}
