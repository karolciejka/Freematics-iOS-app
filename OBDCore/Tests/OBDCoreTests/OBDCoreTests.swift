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
        XCTAssertEqual(VINInfo.vehicle(vin: "WVWZZZAUZKW124821", currentYear: 2026), "2019 Volkswagen Golf")
        XCTAssertEqual(VINInfo.vehicle(vin: nil, currentYear: 2026), "OBD-II")
    }

    func testVehicleFromVIN() {
        XCTAssertEqual(VINInfo.vehicle(vin: "WVWZZZ6RZCY123456", currentYear: 2026), "2012 Volkswagen Polo")
        XCTAssertEqual(VINInfo.vehicle(vin: "WAUZZZ8V0FA000001", currentYear: 2026), "2015 Audi A3")
        XCTAssertEqual(VINInfo.vehicle(vin: "TMBJJ7NE0K0000001", currentYear: 2026), "2019 Škoda")
        XCTAssertEqual(VINInfo.vehicle(vin: "5YJ3E1EA7KF000001", currentYear: 2026), "2019 Tesla")
        XCTAssertEqual(VINInfo.vehicle(vin: "WVWZZZ6RZZY123456", currentYear: 2026), "Volkswagen Polo")
        XCTAssertNil(VINInfo.model("WBA3A5C50CF000001"))
    }

    func testVINFromMode09() {
        let can = "0902;014;0:490201575657;1:5A5A5A36525A43;2:59313233343536"
        XCTAssertEqual(OBDParse.vinFromMode09(can), "WVWZZZ6RZCY123456")
        // ISO 9141 / KWP: numbered lines of four bytes, possibly out of order
        let lines = "4902035A36525A;49020100000057;49020256575A5A;49020443593132;49020533343536"
        XCTAssertEqual(OBDParse.vinFromMode09(lines), "WVWZZZ6RZCY123456")
        XCTAssertNil(OBDParse.vinFromMode09("49020100000057;49020256575A5A"))
        XCTAssertNil(OBDParse.vinFromMode09("N/A"))
        XCTAssertNil(OBDParse.vinFromMode09("0902;7F0912"))
    }

    func testVINFromUDS() {
        let reply = "22F190;014;0:62F190575657;1:5A5A5A36525A43;2:59313233343536"
        XCTAssertEqual(OBDParse.vinFromUDS(reply), "WVWZZZ6RZCY123456")
        XCTAssertNil(OBDParse.vinFromUDS("7F2231"))
    }

    func testNegativeResponse() {
        XCTAssertEqual(OBDParse.negativeResponse("0902;7F0912", service: 0x09), 0x12)
        XCTAssertNil(OBDParse.negativeResponse("7F0912", service: 0x22))
        XCTAssertEqual(OBDParse.negativeResponseText(0x12), "not supported by this ECU")
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

final class PollPlanTests: XCTestCase {

    func testSupportedPIDs() {
        // 0100 -> BE 3E B8 11: 01,03-07,0B-0F,11,13,15,1C,20 ... bits set
        let s = OBDParse.supportedPIDs("0100;4100BE3EB811", base: 0x00)!
        XCTAssertTrue(s.isSuperset(of: [0x04, 0x05, 0x0C, 0x0D, 0x0E, 0x0F, 0x11]))
        XCTAssertFalse(s.contains(0x02))
        XCTAssertTrue(s.contains(0x20)) // next list available
        XCTAssertEqual(OBDParse.supportedPIDs("4140FED00400", base: 0x40)?.contains(0x5E), false)
        XCTAssertEqual(OBDParse.supportedPIDs("41400000000C", base: 0x40)?.contains(0x5E), true)
        XCTAssertNil(OBDParse.supportedPIDs("NODATA", base: 0x40))
    }

    func testCombinedReply() {
        // 0C 0D 04 11 0F 05 in one multi-frame reply (14 bytes)
        let v = OBDParse.mode01Values("010C0D04110F05;00E;0:410C0C180D00;1:043D11090F4305;2:56")
        XCTAssertEqual(v[0x0C], [0x0C, 0x18])
        XCTAssertEqual(v[0x0D], [0x00])
        XCTAssertEqual(v[0x11], [0x09])
        XCTAssertEqual(v[0x05], [0x56])
        XCTAssertEqual(v.count, 6)
        XCTAssertEqual(OBDParse.mode01Values("410E8A")[0x0E], [0x8A])
        XCTAssertTrue(OBDParse.mode01Values("NODATA").isEmpty)
    }

    func testRequestsAndDiscovery() {
        var p = PollPlan(pids: [0x0C, 0x0D, 0x04, 0x11, 0x05, 0x0F, 0x0E, 0x5E], combined: true)
        XCTAssertEqual(p.requests.map(\.count), [6, 2])
        p.apply(supported: [0x0C, 0x0D, 0x04, 0x11, 0x05, 0x0F, 0x0E])
        XCTAssertEqual(p.active.count, 7)
        XCTAssertEqual(p.requests.map(\.count), [6, 1])
        p.apply(supported: [0x01])
        XCTAssertEqual(p.active.count, 7) // never filter down to nothing
    }

    func testProbe() {
        var p = PollPlan(pids: [0x0C, 0x0D], combined: true)
        p.recordProbe(answered: [])
        XCTAssertFalse(p.probed)
        XCTAssertTrue(p.combined)
        p.recordProbe(answered: [0x0C])
        XCTAssertTrue(p.probed)
        XCTAssertFalse(p.combined)
        XCTAssertEqual(p.requests, [[0x0C, 0x0D]])
    }

    func testProbeRefused() {
        // 2012 VW Polo: 01 0C 0D -> 7F 01 12
        var p = PollPlan(pids: [0x0C, 0x0D, 0x0E], combined: true)
        let refused = OBDParse.negativeResponse("010C0D;7F0112", service: 0x01) != nil
        XCTAssertTrue(refused)
        p.recordProbe(answered: [], refused: refused)
        XCTAssertTrue(p.probed)
        XCTAssertFalse(p.combined)
        XCTAssertEqual(p.requests, [[0x0C, 0x0D, 0x0E]])
    }

    func testRefusedChunkDoesNotDropPIDs() {
        var p = PollPlan(pids: [0x0C, 0x0D, 0x0E], combined: true)
        for _ in 0..<5 { p.recordCycle(answered: [0x0E], unknown: [0x0C, 0x0D]) }
        XCTAssertEqual(p.active, [0x0C, 0x0D, 0x0E])
    }

    func testDropsSilentPIDs() {
        var p = PollPlan(pids: [0x0C, 0x0D, 0x5E], combined: false)
        for _ in 0..<2 { p.recordCycle(answered: [0x0C, 0x0D]) }
        XCTAssertEqual(p.active, [0x0C, 0x0D, 0x5E])
        p.recordCycle(answered: [])          // car off: no change
        p.recordCycle(answered: [0x0C, 0x0D])
        XCTAssertEqual(p.active, [0x0C, 0x0D])
    }
}
