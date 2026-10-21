import Foundation

/// Turns logger replies into the values the screens show.
enum LiveDecode {

    /// Readings from a `PIDS` reply for the PIDs of `Channel.polled`, nil when OBD isn't ready.
    static func readings(_ reply: String) -> [ChannelKey: Double]? {
        let keys = Channel.polled
        guard let parts = OBDParse.pidsReply(reply, count: keys.count) else { return nil }
        var out: [ChannelKey: Double] = [:]
        for (key, bytes) in zip(keys, parts) {
            if let bytes, let pid = key.info.obdPID, let v = OBDParse.decode(pid: pid, bytes) { out[key] = v }
        }
        return out
    }

    /// Rpm per km/h in each gear (typical small petrol hatchback); OBD-II has no gear PID.
    static let gearRatios: [Double] = [0, 105, 62, 43, 33, 27, 23]

    /// Gear estimated from the rpm/speed ratio; 0 when stopped, coasting or the clutch is slipping.
    static func estimatedGear(rpm: Double?, speed: Double?) -> Int {
        guard let rpm, let speed, speed >= 5, rpm > 0 else { return 0 }
        let ratio = rpm / speed
        var best = 0, bestErr = Double.infinity
        for g in 1..<gearRatios.count {
            let err = abs(ratio - gearRatios[g]) / gearRatios[g]
            if err < bestErr { best = g; bestErr = err }
        }
        return bestErr < 0.2 ? best : 0
    }

    /// Freeze-frame PIDs shown under a trouble code, in display order.
    static let freezeFramePIDs: [(UInt8, String)] = [(0x0C, "RPM"), (0x0D, "Speed"), (0x05, "Coolant"), (0x04, "Load"), (0x06, "STFT"), (0x07, "LTFT")]

    static func freezeField(pid: UInt8, label: String, bytes: [UInt8], units: UnitSystem) -> FreezeField? {
        guard let v = OBDParse.decode(pid: pid, bytes) else { return nil }
        let fmt = ReadingFormat(units: units)
        switch pid {
        case 0x0C: return FreezeField(k: label, v: String(Int(v.rounded())))
        case 0x0D: return FreezeField(k: label, v: "\(ReadingFormat.fixed(fmt.convert(.speed, v), 0)) \(fmt.unit(.speed))")
        case 0x05: return FreezeField(k: label, v: "\(ReadingFormat.fixed(fmt.convert(.coolant, v), 0)) \(fmt.unit(.coolant))")
        case 0x04: return FreezeField(k: label, v: "\(ReadingFormat.fixed(v, 0)) %")
        default: return FreezeField(k: label, v: "\(v > 0 ? "+" : "")\(ReadingFormat.fixed(v, 1)) %")
        }
    }

    /// A short label for the polling rate, e.g. "25 Hz" or "4.2 Hz".
    static func rateLabel(_ hz: Double) -> String {
        hz >= 10 ? "\(Int(hz.rounded())) Hz" : "\(ReadingFormat.fixed(hz, 1)) Hz"
    }
}
