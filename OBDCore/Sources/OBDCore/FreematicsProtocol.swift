import Foundation

/// The telelogger firmware's BLE SPP service (libraries/FreematicsPlus/utility/ble_spp_server.c):
/// text commands are written to 0xFFE1 and each reply is notified on 0xFFE2, terminated by '\r'.
enum FreematicsBLE {
    static let serviceUUID = "ABF0"
    static let commandUUID = "FFE1"
    static let replyUUID = "FFE2"
    static let advertisedName = "FreematicsPlus"

    static func pids(_ pids: [UInt8]) -> String {
        "PIDS" + pids.map { String(format: "%02X", $0) }.joined()
    }

    static func raw(_ request: String) -> String { "RAW" + request }

    /// How long to wait for a reply. Code reads and clears can take the ECU several seconds,
    /// and PIDS waits up to a second for each PID the car doesn't answer.
    static func timeout(for command: String) -> TimeInterval {
        if command.hasPrefix("RAW03") || command.hasPrefix("RAW04") || command.hasPrefix("RAW07") { return 12 }
        if command.hasPrefix("PIDS") { return 10 }
        return 3
    }
}

/// Reassembles '\r'-terminated replies from BLE notifications, which may split or join lines.
struct LineAssembler {
    private var pending: [UInt8] = []

    mutating func feed(_ bytes: [UInt8]) -> [String] {
        var lines: [String] = []
        for b in bytes {
            if b == 0x0D || b == 0x0A {
                if !pending.isEmpty {
                    lines.append(String(decoding: pending, as: UTF8.self).trimmingCharacters(in: .whitespaces))
                    pending.removeAll()
                }
            } else if b != 0 {
                pending.append(b)
            }
        }
        return lines
    }

    mutating func reset() { pending.removeAll() }
}

/// The logger answers commands strictly in order. When a command times out its reply may still
/// arrive later, so it is dropped instead of being taken as the answer to the next command.
struct ReplyRouter {
    private(set) var staleReplies = 0

    mutating func commandTimedOut() { staleReplies += 1 }

    /// Returns the line if it answers the command in flight, nil if it was a late reply to an earlier one.
    mutating func route(_ line: String) -> String? {
        if staleReplies > 0 {
            staleReplies -= 1
            return nil
        }
        return line
    }

    mutating func reset() { staleReplies = 0 }
}
