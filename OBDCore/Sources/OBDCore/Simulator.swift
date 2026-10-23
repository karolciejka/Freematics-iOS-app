import Foundation

/// The latest value of every reading, in metric units. Missing keys are readings the car didn't answer.
struct Readings: Equatable {
    var values: [ChannelKey: Double] = [:]
    /// 0 = neutral / unknown.
    var gear = 0

    subscript(_ key: ChannelKey) -> Double? {
        get { values[key] }
        set { values[key] = newValue }
    }
}

/// One row on the CAN screen.
struct CANFrame: Identifiable, Equatable {
    let id: Int
    let ts: String
    let canId: String
    let data: String
    let dlc: String
    let obd: Bool
}

enum DriveMode: String { case parked = "Parked", driving = "Driving" }

/// The design's demo data: a parked car idling with the odd rev, or a drive cycle. Advance with `step()` every 150 ms.
struct DemoSimulator {
    static let tick = 0.15

    private(set) var t = 0.0
    private(set) var readings = Readings(values: [.rpm: 780, .speed: 0, .load: 21, .throttle: 0, .coolant: 84, .iat: 24, .volt: 14.1, .timing: 8, .fuelRate: 0.8], gear: 0)
    private var blip = 0.0
    private var frameSeq = 0
    var random: () -> Double = { Double.random(in: 0..<1) }

    private func clamp(_ v: Double, _ a: Double, _ b: Double) -> Double { max(a, min(b, v)) }

    mutating func step(mode: DriveMode) {
        t += DemoSimulator.tick
        var v = readings.values
        let rnd = random
        let n = { rnd() - 0.5 }
        let driving = mode == .driving
        var g = 0
        if driving {
            let target = 55 + 28 * sin(t / 9) + 12 * sin(t / 2.3), accel = target - v[.speed]!
            v[.speed] = clamp(v[.speed]! + accel * 0.12, 0, 180)
            let speed = v[.speed]!
            g = speed < 18 ? 1 : speed < 32 ? 2 : speed < 48 ? 3 : speed < 68 ? 4 : speed < 90 ? 5 : 6
            v[.rpm] = clamp(speed * [0, 105, 62, 43, 33, 27, 23][g] + accel * 40 + n() * 40, 850, 6800)
            v[.throttle] = clamp(14 + accel * 3.2 + n() * 3, 0, 100)
        } else {
            v[.speed] = 0
            if blip <= 0 && random() < 0.02 { blip = 1 }
            let target = blip > 0 ? 780 + blip * (2400 + 1600 * sin(t)) : 780
            let rpm = v[.rpm]!
            v[.rpm] = rpm + (target - rpm) * (target > rpm ? 0.55 : 0.18) + n() * 25
            blip = max(0, blip - 0.09)
            v[.throttle] = blip > 0.3 ? clamp(blip * 45 + n() * 4, 0, 100) : 0.4
        }
        let throttle = v[.throttle]!
        v[.load] = clamp((throttle > 1 ? throttle * 0.8 + 18 : 21) + n() * 2, 0, 100)
        v[.coolant]! += (91 - v[.coolant]!) * 0.004 + n() * 0.1
        v[.iat]! += ((driving ? 28 : 33) - v[.iat]!) * 0.01 + n() * 0.1
        v[.volt] = (v[.rpm]! > 1200 ? 14.35 : 14.05) + n() * 0.05
        v[.timing] = clamp((v[.load]! > 40 ? 14 : 8) + v[.rpm]! / 600 + n() * 1.2, -5, 38)
        v[.fuelRate] = clamp(v[.rpm]! * v[.load]! / 100 * 0.0016 + 0.4 + n() * 0.1, 0.3, 20)
        readings = Readings(values: v, gear: g)
    }

    /// The frames seen on the bus during the last step, newest first: one OBD request/reply pair plus broadcast traffic.
    mutating func frames() -> [CANFrame] {
        let v = readings.values
        let ts = String(format: "%07.3f", t.truncatingRemainder(dividingBy: 1000))
        let rnd = random
        let r = { UInt8(Int(rnd() * 256) & 0xFF) }
        let rpm4 = Int((v[.rpm]! * 4).rounded())
        func byte(_ x: Double) -> UInt8 { UInt8(clamping: Int(x.rounded())) }
        let pids: [(UInt8, [UInt8])] = [
            (0x0C, [UInt8((rpm4 >> 8) & 255), UInt8(rpm4 & 255)]),
            (0x0D, [byte(v[.speed]!)]),
            (0x05, [byte(v[.coolant]! + 40)]),
            (0x04, [byte(v[.load]! * 2.55)]),
            (0x11, [byte(v[.throttle]! * 2.55)]),
            (0x0E, [byte(v[.timing]! * 2 + 128)]),
        ]
        let (pid, data) = pids[Int((t / DemoSimulator.tick).rounded(.down)) % pids.count]
        var raw: [(String, Bool, [UInt8])] = []
        raw.append(("7DF", true, [2, 1, pid, 0x55, 0x55, 0x55, 0x55, 0x55]))
        raw.append(("7E8", true, Array(([UInt8(2 + data.count), 0x41, pid] + data + [0, 0, 0, 0, 0]).prefix(8))))
        raw.append(("280", false, [0x49, 0x0E, UInt8(rpm4 & 255), UInt8((rpm4 >> 8) & 255), r() & 15, 0x1B, byte(v[.throttle]! * 2.5), 0]))
        if random() < 0.6 { raw.append(("1A0", false, [0x18, UInt8(Int(v[.speed]!.rounded()) & 255), 0, 0, 0xFE, 0xFE, 0, r()])) }
        if random() < 0.3 { raw.append(("5A0", false, [0xFF, r(), r(), 0, 0, 0, 0, r()])) }
        var out: [CANFrame] = []
        for (id, obd, bytes) in raw.reversed() {
            frameSeq += 1
            out.append(CANFrame(id: frameSeq, ts: ts, canId: id, data: OBDParse.hex(bytes), dlc: String(bytes.count), obd: obd))
        }
        return out
    }
}

/// Fixed content for demo mode, as in the design.
enum DemoData {
    static let vin = "WVWZZZAUZKW124821"

    private static func fields(_ pairs: [(String, String)]) -> [FreezeField] {
        pairs.map { FreezeField(k: $0.0, v: $0.1) }
    }

    static let codes: [TroubleCode] = [
        TroubleCode(code: "P0420", status: .stored, description: "Catalyst system efficiency below threshold, bank 1",
                    hint: "Often a worn catalytic converter or a failing downstream O2 sensor.",
                    freezeFrame: fields([("RPM", "2140"), ("Speed", "72 km/h"), ("Coolant", "90 °C"), ("Load", "41 %"), ("STFT", "+2.3 %"), ("LTFT", "+4.7 %")])),
        TroubleCode(code: "P0171", status: .pending, description: "System too lean, bank 1",
                    hint: "Seen on one drive cycle. Check for vacuum leaks or a dirty MAF sensor.",
                    freezeFrame: fields([("RPM", "780"), ("Speed", "0 km/h"), ("Coolant", "88 °C"), ("Load", "22 %"), ("STFT", "+11.7 %"), ("LTFT", "+9.4 %")])),
        TroubleCode(code: "P0302", status: .stored, description: "Cylinder 2 misfire",
                    hint: "Swap the coil or plug with another cylinder to see if the misfire follows.",
                    freezeFrame: fields([("RPM", "1860"), ("Speed", "54 km/h"), ("Coolant", "91 °C"), ("Load", "63 %"), ("STFT", "+4.7 %"), ("LTFT", "+3.1 %")])),
        TroubleCode(code: "P0300", status: .stored, description: "Random or multiple cylinder misfire",
                    hint: "Check spark plugs, coils, injectors and for vacuum leaks.", freezeFrame: []),
        TroubleCode(code: "P0128", status: .stored, description: "Coolant below thermostat regulating temperature",
                    hint: "Usually a thermostat stuck open.", freezeFrame: []),
        TroubleCode(code: "P0442", status: .stored, description: "Evaporative emission system small leak",
                    hint: "Check the fuel cap and the EVAP hoses for cracks.", freezeFrame: []),
        TroubleCode(code: "P0299", status: .stored, description: "Turbocharger underboost",
                    hint: "Look for boost leaks, a sticking wastegate or a worn turbo.", freezeFrame: []),
        TroubleCode(code: "P0562", status: .stored, description: "System voltage low",
                    hint: "Test the battery and the alternator output.", freezeFrame: []),
        TroubleCode(code: "C0035", status: .stored, description: "Left front wheel speed sensor circuit",
                    hint: "Check the ABS sensor, its wiring and the tone ring for damage.", freezeFrame: []),
        TroubleCode(code: "U0100", status: .stored, description: "Lost communication with engine control module",
                    hint: "Check the ECM power, ground and CAN bus wiring.", freezeFrame: []),
        TroubleCode(code: "P0507", status: .pending, description: "Idle speed higher than expected",
                    hint: "Look for vacuum leaks or a dirty throttle body.", freezeFrame: []),
        TroubleCode(code: "P0135", status: .pending, description: "O2 sensor heater circuit, bank 1 sensor 1",
                    hint: "Check the heater fuse and the sensor's heater resistance.", freezeFrame: []),
    ]

    static let monitorNames = ["Misfire", "Fuel system", "Components", "Catalyst", "Heated catalyst", "Evaporative system", "O2 sensor", "O2 sensor heater", "EGR / VVT"]

    static func monitors(cleared: Bool) -> [Monitor] {
        monitorNames.enumerated().map { i, name in Monitor(name: name, complete: cleared ? i < 3 : (i != 3 && i != 6)) }
    }

    static let connectLog: [(String, String)] = [
        ("ATZ", "ELM327 v1.5 (ONE+ coprocessor)"), ("ATE0", "OK"), ("ATSP0", "OK · auto protocol"), ("0100", "SEARCHING…"),
        ("", "ISO 15765-4 CAN 11 bit 500k"), ("0902", "VIN \(vin)"),
    ]
}
