import XCTest
@testable import OBDCore

final class ParsingTests: XCTestCase {

    func testDecodeMode01() {
        XCTAssertEqual(OBDParse.decode(pid: 0x0C, [0x0C, 0x34]), 781)
        XCTAssertEqual(OBDParse.decode(pid: 0x0D, [0x48]), 72)
        XCTAssertEqual(OBDParse.decode(pid: 0x05, [0x7B]), 83)
        XCTAssertEqual(OBDParse.decode(pid: 0x0E, [0x90]), 8)
        XCTAssertEqual(OBDParse.decode(pid: 0x04, [0xFF]), 100)
        XCTAssertEqual(OBDParse.decode(pid: 0x5E, [0x00, 0x14]), 1)
        XCTAssertNil(OBDParse.decode(pid: 0x0C, [0x0C]))
    }

    func testPidsReply() {
        // order of Channel.polled: rpm, speed, load, throttle, coolant, iat, timing, fuelRate
        let r = LiveDecode.readings("0C34,00,36,,7B,40,90,")
        XCTAssertEqual(r?[.rpm], 781)
        XCTAssertEqual(r?[.speed], 0)
        XCTAssertNil(r?[.throttle])
        XCTAssertEqual(r?[.coolant], 83)
        XCTAssertEqual(r?[.iat], 24)
        XCTAssertNil(r?[.fuelRate])
        XCTAssertNil(LiveDecode.readings("N/A"))
        XCTAssertNil(LiveDecode.readings("0C34,00"))
    }

    func testStoredCodesCANSingleFrame() {
        XCTAssertEqual(OBDParse.troubleCodes("03;4302042001710000", service: 0x43), ["P0420", "P0171"])
        XCTAssertEqual(OBDParse.troubleCodes("4300", service: 0x43), [])
        XCTAssertEqual(OBDParse.troubleCodes("NODATA", service: 0x43), [])
    }

    func testStoredCodesCANMultiFrame() {
        let reply = "00A;0:430404200171;1:0300C001000000"
        XCTAssertEqual(OBDParse.troubleCodes(reply, service: 0x43), ["P0420", "P0171", "P0300", "U0001"])
    }

    func testStoredCodesISO() {
        XCTAssertEqual(OBDParse.troubleCodes("43042001710000;43013300000000", service: 0x43), ["P0420", "P0171", "P0133"])
    }

    func testPendingCodesFilterByService() {
        XCTAssertEqual(OBDParse.troubleCodes("47010171", service: 0x47), ["P0171"])
        XCTAssertEqual(OBDParse.troubleCodes("47010171", service: 0x43), [])
    }

    func testDTCLetters() {
        XCTAssertEqual(OBDParse.dtcString(0x41, 0x23), "C0123")
        XCTAssertEqual(OBDParse.dtcString(0x92, 0x34), "B1234")
        XCTAssertEqual(OBDParse.dtcString(0xC1, 0x00), "U0100")
    }

    func testMonitorStatus() {
        // MIL on, 2 codes; misfire/fuel/components supported, components incomplete; spark: catalyst, evap, O2, O2 heater supported, catalyst and O2 incomplete
        let s = OBDParse.monitorStatus("0101;41018247656100")!
        XCTAssertTrue(s.milOn)
        XCTAssertEqual(s.storedCount, 2)
        XCTAssertEqual(s.monitors.map(\.name), ["Misfire", "Fuel system", "Components", "Catalyst", "Evaporative system", "O2 sensor", "O2 sensor heater"])
        XCTAssertEqual(s.monitors.map(\.complete), [true, true, false, false, true, false, false])
        XCTAssertNil(OBDParse.monitorStatus("N/A"))
    }

    func testMonitorStatusIncomplete() {
        let s = OBDParse.monitorStatus("4101000765A1")!
        XCTAssertFalse(s.milOn)
        XCTAssertEqual(s.monitors.first { $0.name == "Catalyst" }?.complete, false)
        XCTAssertEqual(s.monitors.first { $0.name == "O2 sensor" }?.complete, false)
        XCTAssertEqual(s.monitors.first { $0.name == "Evaporative system" }?.complete, true)
    }

    func testFreezeFrame() {
        XCTAssertEqual(OBDParse.freezeFrameData("020C00;420C00217", pid: 0x0C), nil) // odd length line is ignored
        XCTAssertEqual(OBDParse.freezeFrameData("420C002170", pid: 0x0C), [0x21, 0x70])
        let f = LiveDecode.freezeField(pid: 0x0C, label: "RPM", bytes: [0x21, 0x70], units: .metric)
        XCTAssertEqual(f, FreezeField(k: "RPM", v: "2140"))
        XCTAssertEqual(LiveDecode.freezeField(pid: 0x06, label: "STFT", bytes: [0x83], units: .metric), FreezeField(k: "STFT", v: "+2.3 %"))
        XCTAssertEqual(LiveDecode.freezeField(pid: 0x0D, label: "Speed", bytes: [72], units: .imperial), FreezeField(k: "Speed", v: "45 mph"))
    }

    func testVIN() {
        XCTAssertEqual(OBDParse.vin("WVWZZZAUZKW124821"), "WVWZZZAUZKW124821")
        XCTAssertNil(OBDParse.vin("N/A"))
        XCTAssertEqual(VINInfo.modelYear("WVWZZZAUZKW124821", currentYear: 2026), 2019)
        XCTAssertEqual(VINInfo.modelYear("WVWZZZAUZ7W124821", currentYear: 2026), 2007)
        XCTAssertEqual(VINInfo.kicker(vin: "WVWZZZAUZKW124821", currentYear: 2026), "2019 Volkswagen · VIN …4821")
        XCTAssertEqual(VINInfo.kicker(vin: nil, currentYear: 2026), "OBD-II · VIN unavailable")
    }
}

final class ProtocolTests: XCTestCase {

    func testCommands() {
        XCTAssertEqual(FreematicsBLE.pids(Channel.polled.compactMap { $0.info.obdPID }), "PIDS0C0D0411050F0E5E")
        XCTAssertEqual(FreematicsBLE.timeout(for: "RAW03"), 12)
        XCTAssertEqual(FreematicsBLE.timeout(for: "BATT"), 3)
    }

    func testLineAssembler() {
        var a = LineAssembler()
        XCTAssertEqual(a.feed(Array("0C3".utf8)), [])
        XCTAssertEqual(a.feed(Array("4,00\rOK\r".utf8)), ["0C34,00", "OK"])
        XCTAssertEqual(a.feed(Array("\r\n".utf8)), [])
    }

    func testReplyRouterDropsLateReply() {
        var r = ReplyRouter()
        r.commandTimedOut()
        XCTAssertNil(r.route("late"))
        XCTAssertEqual(r.route("current"), "current")
    }
}

final class FormatTests: XCTestCase {

    func testFormatting() {
        let m = ReadingFormat(units: .metric), i = ReadingFormat(units: .imperial)
        XCTAssertEqual(m.value(.rpm, 2144), "2,140")
        XCTAssertEqual(m.value(.rpm, 785), "790")
        XCTAssertEqual(m.value(.volt, 14.05), "14.05")
        XCTAssertEqual(m.value(.timing, -0.01), "0.0")
        XCTAssertEqual(i.value(.coolant, 100), "212")
        XCTAssertEqual(i.unit(.speed), "mph")
        XCTAssertEqual(m.value(.speed, nil), "—")
        XCTAssertTrue(m.isWarning(.coolant, 106))
        XCTAssertTrue(m.isWarning(.volt, 12.0))
        XCTAssertFalse(m.isWarning(.volt, nil))
    }

    func testGearEstimate() {
        XCTAssertEqual(LiveDecode.estimatedGear(rpm: 2100, speed: 20), 1)
        XCTAssertEqual(LiveDecode.estimatedGear(rpm: 2300, speed: 100), 6)
        XCTAssertEqual(LiveDecode.estimatedGear(rpm: 800, speed: 0), 0)
        XCTAssertEqual(LiveDecode.estimatedGear(rpm: 4000, speed: 20), 0)
    }

    func testRateLabel() {
        XCTAssertEqual(LiveDecode.rateLabel(25), "25 Hz")
        XCTAssertEqual(LiveDecode.rateLabel(4.24), "4.2 Hz")
    }
}

final class SimulatorTests: XCTestCase {

    func testParkedIdlesAndDrivingMoves() {
        var sim = DemoSimulator()
        sim.random = { 0.5 }
        for _ in 0..<50 { sim.step(mode: .parked) }
        XCTAssertEqual(sim.readings[.speed], 0)
        XCTAssertEqual(sim.readings.gear, 0)
        XCTAssertEqual(sim.readings[.rpm]!, 780, accuracy: 1)
        for _ in 0..<200 { sim.step(mode: .driving) }
        XCTAssertGreaterThan(sim.readings[.speed]!, 20)
        XCTAssertGreaterThan(sim.readings.gear, 0)
    }

    func testDemoCodes() {
        let codes = DemoData.codes
        XCTAssertEqual(codes.count, 12)
        XCTAssertEqual(Set(codes.map(\.code)).count, codes.count)
        XCTAssertEqual(codes.first?.code, "P0420")
        XCTAssertTrue(codes.contains { $0.status == .pending })
    }

    func testFramesIncludeOBDPair() {
        var sim = DemoSimulator()
        sim.random = { 0.9 }
        sim.step(mode: .parked)
        let f = sim.frames()
        XCTAssertEqual(f.map(\.canId), ["280", "7E8", "7DF"])
        XCTAssertTrue(f[2].data.hasPrefix("02 01 "))
        XCTAssertEqual(Set(f.map(\.id)).count, 3)
    }
}
