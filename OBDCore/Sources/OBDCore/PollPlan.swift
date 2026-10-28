import Foundation

extension OBDParse {
    /// Data length of the mode 01 PIDs the app polls; needed to split a combined (multi-PID) reply.
    static let mode01Length: [UInt8: Int] = [0x04: 1, 0x05: 1, 0x0C: 2, 0x0D: 1, 0x0E: 1, 0x0F: 1, 0x11: 1, 0x5E: 2]

    /// PIDs listed as supported by a `0100` / `0120` / `0140` reply (`41 <base> A B C D`, bit 7 of A = base+1).
    /// Several ECUs may answer; their lists are merged. Nil when no ECU sent the list.
    static func supportedPIDs(_ reply: String, base: UInt8) -> Set<UInt8>? {
        let lists = messages(reply).filter { $0.count >= 6 && $0[0] == 0x41 && $0[1] == base }
        guard !lists.isEmpty else { return nil }
        var out = Set<UInt8>()
        for m in lists {
            for (i, byte) in m[2..<6].enumerated() {
                for bit in 0..<8 where byte & (0x80 >> bit) != 0 {
                    out.insert(base + UInt8(i * 8 + bit) + 1)
                }
            }
        }
        return out
    }

    /// Data bytes per PID from a mode 01 reply to one or several PIDs (`41 0C 0C 18 0D 00 …`).
    /// Stops at a PID whose length isn't known, since the rest can't be split reliably.
    static func mode01Values(_ reply: String) -> [UInt8: [UInt8]] {
        var out: [UInt8: [UInt8]] = [:]
        for m in messages(reply) where m.first == 0x41 {
            var i = 1
            while i < m.count, let len = mode01Length[m[i]], i + 1 + len <= m.count {
                out[m[i]] = Array(m[(i + 1)...(i + len)])
                i += 1 + len
            }
        }
        return out
    }
}

/// Which PIDs to ask for and how: only the ones the car supports, combined up to 6 per request when
/// the ECU handles that, and dropping PIDs the car stops answering (each miss costs a timeout).
struct PollPlan: Equatable {
    static let maxPerRequest = 6
    static let missesBeforeDrop = 3

    private(set) var active: [UInt8]
    private(set) var combined: Bool
    /// The car's supported-PID lists have been read (successfully).
    private(set) var discovered = false
    private var misses: [UInt8: Int] = [:]

    init(pids: [UInt8], combined: Bool) {
        active = pids
        self.combined = combined
    }

    /// The requests for one cycle: chunks of up to 6 PIDs when combined, otherwise one list for `PIDS`.
    var requests: [[UInt8]] {
        guard combined else { return [active] }
        return stride(from: 0, to: active.count, by: PollPlan.maxPerRequest).map {
            Array(active[$0..<min($0 + PollPlan.maxPerRequest, active.count)])
        }
    }

    /// Keep only PIDs the car lists as supported; ignored if that would leave nothing to poll.
    mutating func apply(supported: Set<UInt8>) {
        discovered = true
        let kept = active.filter { supported.contains($0) }
        if !kept.isEmpty { active = kept }
    }

    /// Probe for combined-request support: rpm + speed, which every ECU answering OBD supports.
    static let probe: [UInt8] = [0x0C, 0x0D]
    /// The probe got an answer (until then the ECU may simply not be awake yet).
    private(set) var probed = false

    /// An ECU that answers only the first PID of a combined request doesn't support them; poll one
    /// PID per request instead. An empty answer (car off) decides nothing.
    /// `refused`: the ECU answered with a negative response (`7F 01 …`), e.g. 7F 01 12 on a 2012 VW Polo.
    mutating func recordProbe(answered: Set<UInt8>, refused: Bool = false) {
        if refused {
            probed = true
            combined = false
            return
        }
        guard !answered.isEmpty else { return }
        probed = true
        if !answered.isSuperset(of: PollPlan.probe) { combined = false }
    }

    /// A combined request was refused while polling: poll one PID per request from now on.
    mutating func combinedRefused() { combined = false }

    /// Record a full cycle. PIDs unanswered three cycles in a row are dropped, but only while other
    /// PIDs are answered (when nothing answers, the car is off rather than lacking those PIDs).
    /// `unknown`: PIDs whose request failed as a whole (refused or unanswered combined request), which
    /// says nothing about the PIDs themselves, so they don't count as misses.
    mutating func recordCycle(answered: Set<UInt8>, unknown: Set<UInt8> = []) {
        guard !answered.isEmpty else { return }
        for pid in active where !unknown.contains(pid) {
            misses[pid] = answered.contains(pid) ? 0 : (misses[pid] ?? 0) + 1
        }
        let dropped = active.filter { (misses[$0] ?? 0) >= PollPlan.missesBeforeDrop }
        if !dropped.isEmpty && dropped.count < active.count {
            active.removeAll { dropped.contains($0) }
        }
    }
}
