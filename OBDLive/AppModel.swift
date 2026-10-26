import Foundation
import SwiftUI

/// Settings exposed in the iOS Settings app (Settings.bundle); the design's Tweaks panel.
enum SettingsKey {
    static let rpmStyle = "rpmStyle"   // "Dial" | "Bar"
    static let units = "units"         // "Metric" | "Imperial"
    static let demoMode = "demoMode"   // "Parked" | "Driving"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [rpmStyle: "Dial", units: "Metric", demoMode: "Parked"])
    }
}

/// App state for every screen: the connect flow, live readings and history, codes and the CAN log.
/// All mutation happens on the main thread (UI, the 150 ms timer and CoreBluetooth callbacks).
final class AppModel: ObservableObject {

    enum Screen { case connect, app }
    enum Phase { case idle, scanning, connecting }
    enum Source { case demo, device }
    enum Tab: String, CaseIterable { case live, graph, codes, can }
    enum CANFilter: String, CaseIterable { case all, obd, broadcast }

    static let historyLength = 120

    let link = FreematicsLink()

    @Published var screen: Screen = .connect
    @Published var phase: Phase = .idle
    @Published private(set) var source: Source = .demo
    @Published private(set) var connectLog: [(cmd: String, res: String)] = []
    @Published var connectError: String?

    @Published var tab: Tab = .live
    @Published var graphKey: ChannelKey = .rpm
    @Published var paused = false
    @Published var openCode: String? = "P0420"
    @Published var showClear = false
    @Published var canFilter: CANFilter = .all

    @Published private(set) var readings = Readings()
    @Published private(set) var history: [ChannelKey: [Double]] = [:]
    @Published private(set) var extremes: [ChannelKey: (lo: Double, hi: Double)] = [:]
    @Published private(set) var frames: [CANFrame] = []

    @Published private(set) var codes: [TroubleCode] = []
    @Published private(set) var monitors: [Monitor] = []
    @Published private(set) var codesNote: String?
    @Published private(set) var codesLoading = false

    @Published private(set) var vehicleLabel = "OBD-II"
    @Published private(set) var vin: String?
    @Published private(set) var rateHz: Double = 0
    /// The logger answered N/A and reports standby (`ON?` = 0): its OBD side is powered down.
    @Published private(set) var loggerAsleep = false
    /// The BLE link dropped while in the app and is being re-established.
    @Published private(set) var reconnecting = false

    private var timer: Timer?
    private var tickCount = 0
    private var sim = DemoSimulator()
    private var jobs: [() -> Void] = []
    private var polling = false
    private var pollTimes: [Date] = []
    private var lastBattery = Date.distantPast
    private var connectedAt = Date()
    private var frameSeq = 0
    private var linkGeneration = 0
    private var deviceID: UUID?
    private var vinAttempts = 0
    private var lastVINAttempt = Date.distantPast

    init() {
        SettingsKey.registerDefaults()
        link.onDisconnect = { [weak self] error in
            guard let self, self.source == .device else { return }
            if self.screen == .app && self.deviceID != nil {
                self.reconnect(attempt: 1)
            } else {
                self.reset(error: (error as? LocalizedError)?.errorDescription ?? "Lost connection to the logger.")
            }
        }
        let t = Timer(timeInterval: DemoSimulator.tick, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    var units: UnitSystem { UnitSystem(rawValue: UserDefaults.standard.string(forKey: SettingsKey.units) ?? "") ?? .metric }
    var driveMode: DriveMode { DriveMode(rawValue: UserDefaults.standard.string(forKey: SettingsKey.demoMode) ?? "") ?? .parked }

    func select(_ tab: Tab) {
        self.tab = tab
        if tab == .codes && !codesLoading { refreshCodes() }
    }

    // MARK: Connect flow

    func startScan() {
        connectError = nil
        phase = .scanning
        link.startScan()
    }

    func connectDemo() {
        link.stopScan()
        connectError = nil
        source = .demo
        phase = .connecting
        connectLog = []
        tickCount = 0
    }

    func connect(_ device: FreematicsLink.Discovered) {
        source = .device
        phase = .connecting
        connectLog = []
        connectError = nil
        deviceID = device.id
        vinAttempts = 0
        linkGeneration += 1
        let gen = linkGeneration
        link.connect(device.id) { [weak self] result in
            guard let self, gen == self.linkGeneration else { return }
            switch result {
            case .success: self.handshake(gen)
            case .failure(let e): self.reset(error: (e as? LocalizedError)?.errorDescription ?? e.localizedDescription)
            }
        }
    }

    func disconnect() {
        deviceID = nil
        link.disconnect()
        reset(error: nil)
    }

    /// The logger restarts when the car is started or after a firmware wake-up; reconnect and carry on
    /// polling without leaving the app screen. Gives up after three attempts.
    private func reconnect(attempt: Int) {
        guard let id = deviceID else { return }
        linkGeneration += 1
        let gen = linkGeneration
        polling = false
        jobs = []
        codesLoading = false
        rateHz = 0
        reconnecting = true
        link.connect(id) { [weak self] result in
            guard let self, gen == self.linkGeneration else { return }
            switch result {
            case .success:
                self.link.send("ATE0") { [weak self] _ in
                    guard let self, gen == self.linkGeneration else { return }
                    self.reconnecting = false
                    self.startPolling(gen)
                    self.refreshCodes()
                }
            case .failure(let e):
                if attempt < 3 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                        guard let self, gen == self.linkGeneration else { return }
                        self.reconnect(attempt: attempt + 1)
                    }
                } else {
                    self.reset(error: "Lost connection to the logger. \((e as? LocalizedError)?.errorDescription ?? e.localizedDescription)")
                }
            }
        }
    }

    private func reset(error: String?) {
        linkGeneration += 1
        screen = .connect
        phase = .idle
        connectLog = []
        connectError = error
        polling = false
        jobs = []
        rateHz = 0
        loggerAsleep = false
        reconnecting = false
    }

    /// Wake the logger and read who we're talking to, logging each exchange on the connect screen.
    private func handshake(_ gen: Int) {
        let steps: [(String, (String?) -> String)] = [
            ("ATE0", { $0 ?? "no reply" }),
            ("UPTIME", { r in r.flatMap { Double($0) }.map { "up \(Int($0 / 1000)) s" } ?? (r ?? "no reply") }),
            ("BATT", { r in r.flatMap(OBDParse.battery).map { "\(ReadingFormat.fixed($0, 2)) V" } ?? (r ?? "no reply") }),
            ("VIN", { r in r.flatMap(OBDParse.vin).map { "VIN \($0)" } ?? "VIN not cached by the logger" }),
            // only sent when the logger had no VIN: ask the car directly (mode 09 PID 02)
            ("RAW0902", { r in
                if let v = r.flatMap(OBDParse.vinFromMode09) { return "VIN \(v)" }
                if r == "N/A" { return "OBD not ready yet · will retry" }
                return "VIN not reported by the car (\(r.map { String($0.prefix(40)) } ?? "no reply"))"
            }),
            ("RAW0100", { r in
                guard let r else { return "no reply" }
                if r == "N/A" { return "OBD not ready · switch the ignition on" }
                return OBDParse.ecuResponds(r) ? "ECU responding" : "no ECU reply"
            }),
        ]
        var vin: String?
        func run(_ i: Int) {
            guard gen == linkGeneration else { return }
            guard i < steps.count else {
                self.vin = vin
                vehicleLabel = VINInfo.vehicle(vin: vin, currentYear: Calendar.current.component(.year, from: Date()))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    guard let self, gen == self.linkGeneration else { return }
                    self.enterApp()
                    self.startPolling(gen)
                    self.refreshCodes()
                }
                return
            }
            let (cmd, describe) = steps[i]
            if cmd == "RAW0902" && vin != nil { return run(i + 1) }
            link.send(cmd) { [weak self] reply in
                guard let self, gen == self.linkGeneration else { return }
                if cmd == "BATT", let v = reply.flatMap(OBDParse.battery) { self.readings[.volt] = v }
                if cmd == "VIN" { vin = reply.flatMap(OBDParse.vin) }
                if cmd == "RAW0902" { vin = reply.flatMap(OBDParse.vinFromMode09) }
                self.connectLog.append((cmd, describe(reply)))
                if reply == nil && i == 0 {
                    self.link.disconnect()
                    self.reset(error: "The logger didn't answer. Check that the firmware has ENABLE_BLE set.")
                    return
                }
                run(i + 1)
            }
        }
        run(0)
    }

    private func enterApp() {
        screen = .app
        tab = .live
        paused = false
        history = [:]
        extremes = [:]
        frames = []
        showClear = false
        connectedAt = Date()
        if source == .demo {
            sim = DemoSimulator()
            readings = sim.readings
            vin = DemoData.vin
            vehicleLabel = VINInfo.vehicle(vin: DemoData.vin, currentYear: Calendar.current.component(.year, from: Date()))
            codes = DemoData.codes
            monitors = DemoData.monitors(cleared: false)
            openCode = "P0420"
            codesNote = nil
        } else {
            readings = Readings(values: readings.values.filter { $0.key == .volt })
            codes = []
            monitors = []
            openCode = nil
            codesNote = nil
        }
    }

    // MARK: Timer

    private func tick() {
        tickCount += 1
        if screen == .connect {
            if phase == .connecting && source == .demo && tickCount % 4 == 0 {
                if connectLog.count < DemoData.connectLog.count {
                    connectLog.append(DemoData.connectLog[connectLog.count])
                } else {
                    enterApp()
                }
            }
            return
        }
        if source == .demo {
            sim.step(mode: driveMode)
            readings = sim.readings
            if !paused { frames = Array((sim.frames() + frames).prefix(60)) }
        }
        var mm = extremes
        for (k, v) in readings.values {
            let m = mm[k] ?? (lo: v, hi: v)
            mm[k] = (lo: min(m.lo, v), hi: max(m.hi, v))
        }
        extremes = mm
        if !paused {
            var h = history
            for (k, v) in readings.values {
                var a = h[k] ?? []
                a.append(v)
                if a.count > AppModel.historyLength { a.removeFirst(a.count - AppModel.historyLength) }
                h[k] = a
            }
            history = h
        }
    }

    // MARK: Device polling

    private func startPolling(_ gen: Int) {
        polling = true
        pollTimes = []
        poll(gen)
    }

    private func poll(_ gen: Int) {
        guard polling, gen == linkGeneration, link.isConnected else { return }
        let next = { [weak self] in DispatchQueue.main.async { self?.poll(gen) } }
        if !jobs.isEmpty {
            let job = jobs.removeFirst()
            job()
            return
        }
        if Date().timeIntervalSince(lastBattery) > 2 {
            lastBattery = Date()
            link.send("BATT") { [weak self] reply in
                if let v = reply.flatMap(OBDParse.battery) { self?.readings[.volt] = v }
                next()
            }
            return
        }
        let pids = Channel.polled.compactMap { $0.info.obdPID }
        let cmd = FreematicsBLE.pids(pids)
        link.send(cmd) { [weak self] reply in
            guard let self, gen == self.linkGeneration else { return }
            if let reply, let values = LiveDecode.readings(reply) {
                var r = Readings(values: values)
                r[.volt] = self.readings[.volt]
                r.gear = LiveDecode.estimatedGear(rpm: r[.rpm], speed: r[.speed])
                self.readings = r
                self.loggerAsleep = false
                self.retryVINIfMissing(gen)
                self.logTraffic(pids: pids, reply: reply)
                let now = Date()
                self.pollTimes = Array((self.pollTimes + [now]).suffix(10))
                if let first = self.pollTimes.first, self.pollTimes.count > 1 {
                    self.rateHz = Double(self.pollTimes.count - 1) / max(now.timeIntervalSince(first), 0.001)
                }
            } else if reply == "N/A" {
                // ignition off / ECU asleep: keep the battery reading, drop stale engine values
                self.readings = Readings(values: self.readings.values.filter { $0.key == .volt })
                self.rateHz = 0
                // tell "logger in standby" apart from "car not answering"
                self.link.send("ON?") { [weak self] on in
                    guard let self, gen == self.linkGeneration else { return }
                    self.loggerAsleep = on == "0"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.poll(gen) }
                }
                return
            }
            next()
        }
    }

    /// The VIN is read during the connect exchange, which can run before the logger's OBD side is up
    /// (e.g. right after the app woke it from standby). Once live values flow, ask again: first the
    /// logger's cached VIN, then the car directly (mode 09 PID 02). Up to 3 attempts, 15 s apart.
    private func retryVINIfMissing(_ gen: Int) {
        guard vin == nil, vinAttempts < 3, Date().timeIntervalSince(lastVINAttempt) > 15 else { return }
        vinAttempts += 1
        lastVINAttempt = Date()
        enqueue(gen) { [weak self] done in
            guard let self else { return done() }
            self.link.send("VIN") { reply in
                if let v = reply.flatMap(OBDParse.vin) {
                    self.setVIN(v, gen)
                    return done()
                }
                self.raw("0902") { reply in
                    if let v = reply.flatMap(OBDParse.vinFromMode09) { self.setVIN(v, gen) }
                    done()
                }
            }
        }
    }

    private func setVIN(_ v: String, _ gen: Int) {
        guard gen == linkGeneration else { return }
        vin = v
        vehicleLabel = VINInfo.vehicle(vin: v, currentYear: Calendar.current.component(.year, from: Date()))
    }

    /// Queue work between polls so it never interleaves with a PIDS exchange; `done` must resume polling.
    private func enqueue(_ gen: Int, _ job: @escaping (_ done: @escaping () -> Void) -> Void) {
        jobs.append { [weak self] in
            job { DispatchQueue.main.async { self?.poll(gen) } }
        }
    }

    /// Sends a RAW request, logs it on the CAN screen and returns the reply.
    private func raw(_ request: String, _ completion: @escaping (String?) -> Void) {
        link.send(FreematicsBLE.raw(request)) { [weak self] reply in
            if let self, let req = OBDParse.hexBytes(request) {
                let replies = reply.map { OBDParse.messages($0).filter { $0.first == req[0] | 0x40 } } ?? []
                // show why there was no answer (N/A = OBD not ready, NODATA = ECU silent) instead of a bare request
                self.appendTraffic(request: req, replies: replies, note: replies.isEmpty ? (reply ?? "no reply") : nil)
            }
            completion(reply)
        }
    }

    private func logTraffic(pids: [UInt8], reply: String) {
        guard let parts = OBDParse.pidsReply(reply, count: pids.count) else { return }
        for (pid, data) in zip(pids, parts) {
            appendTraffic(request: [0x01, pid], replies: data.map { [[0x41, pid] + $0] } ?? [])
        }
    }

    private func appendTraffic(request: [UInt8], replies: [[UInt8]], note: String? = nil) {
        guard !paused else { return }
        let ts = String(format: "%07.3f", Date().timeIntervalSince(connectedAt).truncatingRemainder(dividingBy: 1000))
        var rows: [CANFrame] = []
        func row(_ id: String, _ bytes: [UInt8]) {
            frameSeq += 1
            rows.append(CANFrame(id: frameSeq, ts: ts, canId: id, data: OBDParse.hex(bytes), dlc: String(bytes.count), obd: true))
        }
        row("TX", request)
        for r in replies { row("RX", r) }
        if let note {
            frameSeq += 1
            rows.append(CANFrame(id: frameSeq, ts: ts, canId: "RX", data: note, dlc: "0", obd: true))
        }
        frames = Array((rows.reversed() + frames).prefix(60))
    }

    // MARK: Codes

    func refreshCodes() {
        guard source == .device, link.isConnected else { return }
        let gen = linkGeneration
        codesLoading = true
        enqueue(gen) { [weak self] done in
            guard let self else { return done() }
            var stored: [String] = [], pending: [String] = [], status: MonitorStatus?, obdReady = true
            self.raw("0101") { r in
                status = r.flatMap(OBDParse.monitorStatus)
                obdReady = r != "N/A"
                self.raw("03") { r in
                    stored = r.map { OBDParse.troubleCodes($0, service: 0x43) } ?? []
                    self.raw("07") { r in
                        pending = (r.map { OBDParse.troubleCodes($0, service: 0x47) } ?? []).filter { !stored.contains($0) }
                        var list = stored.map { DTCLibrary.describe($0, status: .stored) } + pending.map { DTCLibrary.describe($0, status: .pending) }
                        self.readFreezeFrame(into: list) { withFrame in
                            list = withFrame
                            guard gen == self.linkGeneration else { return done() }
                            self.codes = list
                            self.monitors = status?.monitors ?? []
                            self.codesNote = obdReady ? nil : "OBD isn't ready. Switch the ignition on to read codes."
                            if let o = self.openCode, !list.contains(where: { $0.code == o }) { self.openCode = nil }
                            if self.openCode == nil { self.openCode = list.first { !$0.freezeFrame.isEmpty }?.code }
                            self.codesLoading = false
                            done()
                        }
                    }
                }
            }
        }
    }

    /// Mode 02 frame 0 belongs to the code that triggered it (PID 02); read its values.
    private func readFreezeFrame(into list: [TroubleCode], _ completion: @escaping ([TroubleCode]) -> Void) {
        guard !list.isEmpty else { return completion(list) }
        raw("020200") { [weak self] r in
            guard let self, let r, let d = OBDParse.freezeFrameData(r, pid: 0x02), d.count >= 2, d[0] != 0 || d[1] != 0,
                  let idx = list.firstIndex(where: { $0.code == OBDParse.dtcString(d[0], d[1]) }) else { return completion(list) }
            var fields: [FreezeField] = []
            let units = self.units
            func next(_ i: Int) {
                guard i < LiveDecode.freezeFramePIDs.count else {
                    var out = list
                    out[idx].freezeFrame = fields
                    return completion(out)
                }
                let (pid, label) = LiveDecode.freezeFramePIDs[i]
                self.raw(String(format: "02%02X00", pid)) { r in
                    if let b = r.flatMap({ OBDParse.freezeFrameData($0, pid: pid) }),
                       let f = LiveDecode.freezeField(pid: pid, label: label, bytes: b, units: units) { fields.append(f) }
                    next(i + 1)
                }
            }
            next(0)
        }
    }

    func clearCodes() {
        showClear = false
        if source == .demo {
            codes = []
            monitors = DemoData.monitors(cleared: true)
            return
        }
        guard link.isConnected else { return }
        let gen = linkGeneration
        codesLoading = true
        enqueue(gen) { [weak self] done in
            guard let self else { return done() }
            self.raw("04") { r in
                let ok = r.map { OBDParse.messages($0).contains { $0.first == 0x44 } } ?? false
                self.codesNote = ok ? nil : "The ECU didn't confirm the clear. Try again with the ignition on and the engine off."
                self.codesLoading = false
                done()
                if ok { self.refreshCodes() }
            }
        }
    }
}
