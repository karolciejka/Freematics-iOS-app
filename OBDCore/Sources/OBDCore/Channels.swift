import Foundation

/// The readings shown on Live and Graph, in the design's order.
enum ChannelKey: String, CaseIterable, Identifiable {
    case rpm, speed, load, throttle, coolant, iat, volt, timing, fuelRate
    var id: String { rawValue }
    var info: Channel { Channel.table[self]! }
}

enum UnitSystem: String { case metric = "Metric", imperial = "Imperial" }

struct Channel {
    let label: String
    /// Freematics PID label as printed in the UI (0x100 + OBD PID, 0x24 = logger battery).
    let pidLabel: String
    let unit: String
    let imperialUnit: String?
    let toImperial: ((Double) -> Double)?
    let min: Double
    let max: Double
    let decimals: Int
    let warnAbove: Double?
    let warnBelow: Double?
    let description: String
    /// Mode 01 PID polled over BLE; nil for readings that come from the logger itself.
    let obdPID: UInt8?

    static let table: [ChannelKey: Channel] = [
        .rpm: Channel(label: "Engine speed", pidLabel: "0x10C", unit: "rpm", imperialUnit: nil, toImperial: nil, min: 0, max: 7000, decimals: 0, warnAbove: nil, warnBelow: nil,
                      description: "Crankshaft revolutions per minute, from PID 0C: ((A×256)+B)/4.", obdPID: 0x0C),
        .speed: Channel(label: "Speed", pidLabel: "0x10D", unit: "km/h", imperialUnit: "mph", toImperial: { $0 * 0.6214 }, min: 0, max: 180, decimals: 0, warnAbove: nil, warnBelow: nil,
                        description: "Vehicle speed reported by the ECU from the wheel or gearbox sensors.", obdPID: 0x0D),
        .load: Channel(label: "Load", pidLabel: "0x104", unit: "%", imperialUnit: nil, toImperial: nil, min: 0, max: 100, decimals: 0, warnAbove: nil, warnBelow: nil,
                       description: "Calculated engine load: current airflow as a share of peak airflow at this rpm.", obdPID: 0x04),
        .throttle: Channel(label: "Throttle", pidLabel: "0x111", unit: "%", imperialUnit: nil, toImperial: nil, min: 0, max: 100, decimals: 0, warnAbove: nil, warnBelow: nil,
                           description: "Absolute throttle plate position.", obdPID: 0x11),
        .coolant: Channel(label: "Coolant", pidLabel: "0x105", unit: "°C", imperialUnit: "°F", toImperial: { $0 * 1.8 + 32 }, min: 60, max: 115, decimals: 0, warnAbove: 105, warnBelow: nil,
                          description: "Engine coolant temperature. The normal operating range is about 85–100 °C.", obdPID: 0x05),
        .iat: Channel(label: "Intake air", pidLabel: "0x10F", unit: "°C", imperialUnit: "°F", toImperial: { $0 * 1.8 + 32 }, min: 0, max: 70, decimals: 0, warnAbove: nil, warnBelow: nil,
                      description: "Air temperature in the intake manifold.", obdPID: 0x0F),
        .volt: Channel(label: "Battery", pidLabel: "0x24", unit: "V", imperialUnit: nil, toImperial: nil, min: 11.5, max: 15, decimals: 2, warnAbove: nil, warnBelow: 12.2,
                       description: "Supply voltage measured by the logger. 13.8–14.6 V with the engine running means the alternator is charging.", obdPID: nil),
        .timing: Channel(label: "Timing adv.", pidLabel: "0x10E", unit: "°", imperialUnit: nil, toImperial: nil, min: -10, max: 40, decimals: 1, warnAbove: nil, warnBelow: nil,
                         description: "Ignition timing advance for cylinder 1, degrees before top dead centre.", obdPID: 0x0E),
        .fuelRate: Channel(label: "Fuel rate", pidLabel: "0x15E", unit: "L/h", imperialUnit: "gal/h", toImperial: { $0 * 0.264 }, min: 0, max: 20, decimals: 1, warnAbove: nil, warnBelow: nil,
                           description: "Engine fuel rate, as reported by PID 5E.", obdPID: 0x5E),
    ]

    /// The eight reading cells on the Live screen.
    static let cells: [ChannelKey] = [.speed, .load, .throttle, .coolant, .iat, .volt, .timing, .fuelRate]

    /// Channels polled with a single `PIDS` command, in request order.
    static let polled: [ChannelKey] = ChannelKey.allCases.filter { $0.info.obdPID != nil }
}

/// Unit conversion and number formatting shared by every screen.
struct ReadingFormat {
    let units: UnitSystem

    func convert(_ key: ChannelKey, _ value: Double) -> Double {
        if units == .imperial, let f = key.info.toImperial { return f(value) }
        return value
    }

    func unit(_ key: ChannelKey) -> String {
        units == .imperial ? (key.info.imperialUnit ?? key.info.unit) : key.info.unit
    }

    /// Formats a value that is already in display units.
    func number(_ key: ChannelKey, _ displayValue: Double) -> String {
        if key == .rpm { return ReadingFormat.grouped((displayValue / 10).rounded() * 10) }
        return ReadingFormat.fixed(displayValue, key.info.decimals)
    }

    /// Converts and formats a raw (metric) value; "—" when the reading is unavailable.
    func value(_ key: ChannelKey, _ raw: Double?) -> String {
        guard let raw else { return "—" }
        return number(key, convert(key, raw))
    }

    func isWarning(_ key: ChannelKey, _ raw: Double?) -> Bool {
        guard let raw else { return false }
        let c = key.info
        if let w = c.warnAbove, raw >= w { return true }
        if let l = c.warnBelow, raw < l { return true }
        return false
    }

    static func fixed(_ v: Double, _ decimals: Int) -> String {
        let s = String(format: "%.\(decimals)f", v)
        // avoid "-0" / "-0.0" for values that round to zero
        if s.hasPrefix("-"), Double(s) == 0 { return String(s.dropFirst()) }
        return s
    }

    static func grouped(_ v: Double) -> String {
        let n = Int(v.rounded())
        let digits = String(abs(n))
        var out = ""
        for (i, ch) in digits.enumerated() {
            if i > 0 && (digits.count - i) % 3 == 0 { out.append(",") }
            out.append(ch)
        }
        return n < 0 ? "-" + out : out
    }
}
