import Foundation

enum DTCStatus: String { case stored = "Stored", pending = "Pending" }

struct FreezeField: Equatable {
    let k: String
    let v: String
}

struct TroubleCode: Identifiable, Equatable {
    var id: String { code }
    let code: String
    let status: DTCStatus
    let description: String
    let hint: String
    /// Empty when the ECU stored no freeze frame for this code.
    var freezeFrame: [FreezeField]
}

/// Plain-language descriptions for the generic (SAE) codes seen most often; anything else falls back to its group.
enum DTCLibrary {
    static func describe(_ code: String, status: DTCStatus) -> TroubleCode {
        let (desc, hint) = known[code] ?? fallback(code)
        return TroubleCode(code: code, status: status, description: desc, hint: hint, freezeFrame: [])
    }

    private static func fallback(_ code: String) -> (String, String) {
        let chars = Array(code)
        guard chars.count == 5 else { return ("Unknown trouble code", "") }
        // SAE J2012: x1xxx is manufacturer-controlled, as are B2/C2/U2 and P30–P33
        let manufacturer = chars[1] == "1" || (chars[0] != "P" && chars[1] == "2") || (chars[0] == "P" && chars[1] == "3" && chars[2] <= "3")
        let makeHint = "Manufacturer-specific code. Look it up in the service information for your make."
        switch chars[0] {
        case "B": return ("Body system fault", manufacturer ? makeHint : "Generic body code: airbags, seat belts, lighting or comfort systems.")
        case "C": return ("Chassis system fault", manufacturer ? makeHint : "Generic chassis code: brakes, ABS, steering or suspension.")
        case "U": return ("Network communication fault", manufacturer ? makeHint : "A control module is missing or not answering on the vehicle network.")
        default: break
        }
        if manufacturer { return ("Manufacturer-specific powertrain fault", makeHint) }
        switch chars[2] {
        case "0", "1", "2": return ("Fuel and air metering fault", "Generic powertrain code in the fuel and air metering group.")
        case "3": return ("Ignition system or misfire fault", "Generic powertrain code in the ignition and misfire group.")
        case "4": return ("Auxiliary emission control fault", "Generic powertrain code in the emission controls group.")
        case "5": return ("Speed, idle control or auxiliary input fault", "Generic powertrain code in the speed and idle control group.")
        case "6": return ("Engine computer or output circuit fault", "Generic powertrain code in the computer and output circuits group.")
        default: return ("Transmission fault", "Generic powertrain code in the transmission group.")
        }
    }

    private static let known: [String: (String, String)] = [
        "P0010": ("Camshaft position actuator circuit, bank 1", "Check the camshaft adjuster solenoid wiring and the oil level."),
        "P0011": ("Camshaft timing over-advanced, bank 1", "Often low or dirty oil, a sticking adjuster solenoid or a stretched timing chain."),
        "P0016": ("Crankshaft and camshaft position correlation, bank 1", "Timing chain or belt may have jumped or stretched."),
        "P0087": ("Fuel rail pressure too low", "Check the fuel filter, high-pressure pump and fuel pressure sensor."),
        "P0101": ("Mass airflow sensor range or performance", "A dirty MAF sensor or an intake leak after it is common."),
        "P0102": ("Mass airflow sensor circuit low", "Check the MAF connector and wiring."),
        "P0106": ("Manifold pressure sensor range or performance", "Check the MAP sensor and its vacuum line."),
        "P0113": ("Intake air temperature sensor circuit high", "Usually an unplugged or broken IAT sensor connector."),
        "P0117": ("Coolant temperature sensor circuit low", "Check the sensor and its wiring for a short."),
        "P0118": ("Coolant temperature sensor circuit high", "Check the sensor connector for an open circuit."),
        "P0121": ("Throttle position sensor range or performance", "Throttle body may need cleaning or replacement."),
        "P0128": ("Coolant below thermostat regulating temperature", "Usually a thermostat stuck open."),
        "P0130": ("O2 sensor circuit, bank 1 sensor 1", "Check the upstream O2 sensor and its wiring."),
        "P0133": ("O2 sensor slow response, bank 1 sensor 1", "An ageing upstream O2 sensor is the usual cause."),
        "P0135": ("O2 sensor heater circuit, bank 1 sensor 1", "Check the heater fuse and the sensor's heater resistance."),
        "P0141": ("O2 sensor heater circuit, bank 1 sensor 2", "Check the heater fuse and the downstream sensor."),
        "P0171": ("System too lean, bank 1", "Check for vacuum leaks or a dirty MAF sensor."),
        "P0172": ("System too rich, bank 1", "Check for leaking injectors, high fuel pressure or a faulty MAF sensor."),
        "P0174": ("System too lean, bank 2", "Check for vacuum leaks or a dirty MAF sensor."),
        "P0175": ("System too rich, bank 2", "Check for leaking injectors, high fuel pressure or a faulty MAF sensor."),
        "P0234": ("Turbocharger overboost", "Check the wastegate, its actuator and the boost control solenoid."),
        "P0299": ("Turbocharger underboost", "Look for boost leaks, a sticking wastegate or a worn turbo."),
        "P0300": ("Random or multiple cylinder misfire", "Check spark plugs, coils, injectors and for vacuum leaks."),
        "P0301": ("Cylinder 1 misfire", "Swap the coil or plug with another cylinder to see if the misfire follows."),
        "P0302": ("Cylinder 2 misfire", "Swap the coil or plug with another cylinder to see if the misfire follows."),
        "P0303": ("Cylinder 3 misfire", "Swap the coil or plug with another cylinder to see if the misfire follows."),
        "P0304": ("Cylinder 4 misfire", "Swap the coil or plug with another cylinder to see if the misfire follows."),
        "P0305": ("Cylinder 5 misfire", "Swap the coil or plug with another cylinder to see if the misfire follows."),
        "P0306": ("Cylinder 6 misfire", "Swap the coil or plug with another cylinder to see if the misfire follows."),
        "P0325": ("Knock sensor circuit, bank 1", "Check the knock sensor connector and its torque."),
        "P0335": ("Crankshaft position sensor circuit", "Engine may crank but not start. Check the sensor and wiring."),
        "P0340": ("Camshaft position sensor circuit, bank 1", "Check the sensor and wiring."),
        "P0401": ("EGR flow insufficient", "EGR valve or passages are often clogged with carbon."),
        "P0402": ("EGR flow excessive", "EGR valve may be stuck open."),
        "P0420": ("Catalyst system efficiency below threshold, bank 1", "Often a worn catalytic converter or a failing downstream O2 sensor."),
        "P0430": ("Catalyst system efficiency below threshold, bank 2", "Often a worn catalytic converter or a failing downstream O2 sensor."),
        "P0440": ("Evaporative emission system fault", "Start with the fuel cap seal."),
        "P0441": ("Evaporative emission system incorrect purge flow", "Check the purge valve and its hoses."),
        "P0442": ("Evaporative emission system small leak", "Check the fuel cap and the EVAP hoses for cracks."),
        "P0455": ("Evaporative emission system large leak", "Often a loose or missing fuel cap."),
        "P0456": ("Evaporative emission system very small leak", "Check the fuel cap seal and the EVAP hoses."),
        "P0500": ("Vehicle speed sensor fault", "Check the speed or ABS wheel sensors."),
        "P0505": ("Idle air control system fault", "Throttle body may need cleaning."),
        "P0507": ("Idle speed higher than expected", "Look for vacuum leaks or a dirty throttle body."),
        "P0562": ("System voltage low", "Test the battery and the alternator output."),
        "P0563": ("System voltage high", "Alternator voltage regulator may be faulty."),
        "P0600": ("Serial communication link fault", "Check control-module wiring and grounds."),
        "P0700": ("Transmission control system fault", "The transmission module has its own stored code; read it with a scan tool."),
    ]
}
