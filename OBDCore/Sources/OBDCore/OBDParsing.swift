import Foundation

/// Parsers for the replies of the telelogger BLE commands (`PIDS`, `RAW…`, `VIN`, `BATT`).
/// `RAW` replies arrive with spaces removed and lines joined by ';', e.g. `0101;41018207E100`.
enum OBDParse {

    static func hexBytes<S: StringProtocol>(_ s: S) -> [UInt8]? {
        let chars = Array(s.utf8)
        guard chars.count % 2 == 0 else { return nil }
        var out: [UInt8] = []
        out.reserveCapacity(chars.count / 2)
        var i = 0
        while i < chars.count {
            guard let hi = nibble(chars[i]), let lo = nibble(chars[i + 1]) else { return nil }
            out.append(hi << 4 | lo)
            i += 2
        }
        return out
    }

    private static func nibble(_ c: UInt8) -> UInt8? {
        switch c {
        case 0x30...0x39: return c - 0x30
        case 0x41...0x46: return c - 0x41 + 10
        case 0x61...0x66: return c - 0x61 + 10
        default: return nil
        }
    }

    static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    // MARK: - Mode 01 values

    /// Decodes the data bytes (after `41 <pid>`) of a mode 01 reply into metric units.
    static func decode(pid: UInt8, _ d: [UInt8]) -> Double? {
        func a() -> Double? { d.count >= 1 ? Double(d[0]) : nil }
        func ab() -> Double? { d.count >= 2 ? Double(d[0]) * 256 + Double(d[1]) : nil }
        switch pid {
        case 0x0C: return ab().map { $0 / 4 }
        case 0x0D: return a()
        case 0x04, 0x11: return a().map { $0 * 100 / 255 }
        case 0x05, 0x0F: return a().map { $0 - 40 }
        case 0x0E: return a().map { $0 / 2 - 64 }
        case 0x5E: return ab().map { $0 / 20 }
        case 0x06, 0x07, 0x08, 0x09: return a().map { ($0 - 128) * 100 / 128 }
        default: return a()
        }
    }

    /// Parses a `PIDS…` reply into one entry per requested PID: the reply's data bytes, or nil when
    /// the ECU did not answer. Returns nil for `N/A` (OBD not ready) or a malformed reply.
    static func pidsReply(_ reply: String, count: Int) -> [[UInt8]?]? {
        let parts = reply.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == count else { return nil }
        return parts.map { $0.isEmpty ? nil : hexBytes($0) }
    }

    // MARK: - RAW replies

    /// Splits a compacted `RAW` reply into ECU messages. Multi-frame ISO 15765 replies
    /// (`00A;0:430404200171;1:0300C001000000`) are reassembled and trimmed to their byte count.
    static func messages(_ reply: String) -> [[UInt8]] {
        var out: [[UInt8]] = []
        var multi: [UInt8]? = nil
        var multiLength = 0
        func flush() {
            if let m = multi { out.append(Array(m.prefix(multiLength))) }
            multi = nil
        }
        for line in reply.split(separator: ";") {
            if line.count == 3, let len = Int(line, radix: 16) {
                flush()
                multi = []
                multiLength = len
            } else if line.count > 2, line[line.index(line.startIndex, offsetBy: 1)] == ":", line.first!.isHexDigit {
                if multi == nil {
                    multi = []
                    multiLength = Int.max
                }
                if let b = hexBytes(line.dropFirst(2)) { multi!.append(contentsOf: b) }
            } else if let b = hexBytes(line), !b.isEmpty {
                flush()
                out.append(b)
            }
        }
        flush()
        return out
    }

    /// Diagnostic trouble codes from a mode 03 (stored) or 07 (pending) reply.
    static func troubleCodes(_ reply: String, service: UInt8) -> [String] {
        var codes: [String] = []
        for m in messages(reply) where m.first == service {
            var body: ArraySlice<UInt8>
            if m.count % 2 == 0, m.count >= 2 {
                // CAN: service byte, code count, then two bytes per code
                body = m[2...].prefix(Int(m[1]) * 2)
            } else {
                // ISO 9141 / KWP: three code slots per line, zero-padded
                body = m[1...]
            }
            while body.count >= 2 {
                let hi = body[body.startIndex], lo = body[body.startIndex + 1]
                body = body.dropFirst(2)
                if hi == 0 && lo == 0 { continue }
                let code = dtcString(hi, lo)
                if !codes.contains(code) { codes.append(code) }
            }
        }
        return codes
    }

    static func dtcString(_ hi: UInt8, _ lo: UInt8) -> String {
        let letter = ["P", "C", "B", "U"][Int(hi >> 6)]
        return letter + String(format: "%d%X%02X", (hi >> 4) & 0x3, hi & 0x0F, lo)
    }

    /// Mode 01 PID 01: MIL state, stored code count and readiness monitors.
    static func monitorStatus(_ reply: String) -> MonitorStatus? {
        guard let m = messages(reply).first(where: { $0.count >= 6 && $0[0] == 0x41 && $0[1] == 0x01 }) else { return nil }
        let a = m[2], b = m[3], c = m[4], d = m[5]
        var monitors: [Monitor] = []
        func add(_ name: String, supported: Bool, incomplete: Bool) {
            if supported { monitors.append(Monitor(name: name, complete: !incomplete)) }
        }
        add("Misfire", supported: b & 0x01 != 0, incomplete: b & 0x10 != 0)
        add("Fuel system", supported: b & 0x02 != 0, incomplete: b & 0x20 != 0)
        add("Components", supported: b & 0x04 != 0, incomplete: b & 0x40 != 0)
        let names: [(Int, String)] = b & 0x08 == 0
            ? [(0, "Catalyst"), (1, "Heated catalyst"), (2, "Evaporative system"), (3, "Secondary air"), (5, "O2 sensor"), (6, "O2 sensor heater"), (7, "EGR / VVT")]
            : [(0, "NMHC catalyst"), (1, "NOx / SCR"), (3, "Boost pressure"), (5, "Exhaust gas sensor"), (6, "PM filter"), (7, "EGR / VVT")]
        for (bit, name) in names {
            add(name, supported: c & (1 << bit) != 0, incomplete: d & (1 << bit) != 0)
        }
        return MonitorStatus(milOn: a & 0x80 != 0, storedCount: Int(a & 0x7F), monitors: monitors)
    }

    /// Data bytes of a mode 02 (freeze frame) reply for `pid`, frame 0.
    static func freezeFrameData(_ reply: String, pid: UInt8) -> [UInt8]? {
        guard let m = messages(reply).first(where: { $0.count >= 4 && $0[0] == 0x42 && $0[1] == pid }) else { return nil }
        return Array(m[3...])
    }

    /// Mode 01 PID 00 answered: the ECU is talking.
    static func ecuResponds(_ reply: String) -> Bool {
        messages(reply).contains { $0.count >= 2 && $0[0] == 0x41 && $0[1] == 0x00 }
    }

    // MARK: - Logger replies

    static func battery(_ reply: String) -> Double? {
        Double(reply.trimmingCharacters(in: .whitespaces))
    }

    static func vin(_ reply: String) -> String? {
        let v = reply.trimmingCharacters(in: .whitespaces).uppercased()
        return v.count == 17 && v.allSatisfy({ $0.isLetter || $0.isNumber }) ? v : nil
    }
}

struct Monitor: Equatable {
    let name: String
    let complete: Bool
}

struct MonitorStatus: Equatable {
    let milOn: Bool
    let storedCount: Int
    let monitors: [Monitor]
}

/// Model year and make from a VIN, for the header kicker.
enum VINInfo {
    static func modelYear(_ vin: String, currentYear: Int) -> Int? {
        let codes = Array("ABCDEFGHJKLMNPRSTVWXY123456789")
        let chars = Array(vin)
        guard chars.count == 17, let i = codes.firstIndex(of: chars[9]) else { return nil }
        var year = 1980 + i
        while year + 30 <= currentYear + 1 { year += 30 }
        return year
    }

    static func make(_ vin: String) -> String? {
        let wmi = String(vin.prefix(3))
        if let m = wmis[wmi] { return m }
        return wmis[String(vin.prefix(2))]
    }

    private static let wmis: [String: String] = [
        "WVW": "Volkswagen", "WV1": "Volkswagen", "WV2": "Volkswagen", "1VW": "Volkswagen", "3VW": "Volkswagen",
        "WAU": "Audi", "WUA": "Audi", "TRU": "Audi", "WBA": "BMW", "WBS": "BMW", "WBY": "BMW", "WMW": "Mini",
        "WDB": "Mercedes-Benz", "WDD": "Mercedes-Benz", "W1K": "Mercedes-Benz", "WP0": "Porsche", "WP1": "Porsche",
        "VSS": "Seat", "TMB": "Škoda", "WF0": "Ford", "1FA": "Ford", "1FM": "Ford", "1FT": "Ford",
        "W0L": "Opel", "VF1": "Renault", "VF3": "Peugeot", "VF7": "Citroën", "ZFA": "Fiat", "ZAR": "Alfa Romeo",
        "YV1": "Volvo", "SAL": "Land Rover", "SAJ": "Jaguar", "5YJ": "Tesla", "7SA": "Tesla",
        "JT": "Toyota", "JHM": "Honda", "JN1": "Nissan", "JM1": "Mazda", "JF1": "Subaru", "JS": "Suzuki",
        "KMH": "Hyundai", "KNA": "Kia", "KND": "Kia", "1G1": "Chevrolet", "1GC": "Chevrolet", "2T1": "Toyota",
        "4T1": "Toyota", "5YF": "Toyota", "1HG": "Honda", "SJN": "Nissan", "TMA": "Hyundai", "U5Y": "Kia",
    ]

    /// e.g. "2019 Volkswagen · VIN …4821"
    static func kicker(vin: String?, currentYear: Int) -> String {
        guard let vin else { return "OBD-II · VIN unavailable" }
        let parts = [modelYear(vin, currentYear: currentYear).map { String($0) }, make(vin)].compactMap { $0 }
        let head = parts.isEmpty ? "OBD-II" : parts.joined(separator: " ")
        return "\(head) · VIN …\(vin.suffix(4))"
    }
}
