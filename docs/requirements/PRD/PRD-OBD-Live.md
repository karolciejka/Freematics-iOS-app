# PRD: OBD Live for iPhone

*Draft, 5 November 2026. Based on the `freematics-ios-app` and `freematics` repositories.*

## 1. Summary

OBD Live is an iPhone app that turns a Freematics ONE+ logger into a live dashboard and fault-code reader over Bluetooth. It is for ONE+ owners who want to see what their car is doing right now, without a laptop, cable or cloud account. The app already works on real cars and ships to TestFlight, so now is the time to decide what a first public version must include.

## 3. Background

The Freematics ONE+ is a capable OBD-II logger. On iPhone, though, the official app (Freematics Controller) is built to configure the logger, not to watch the car. Owners who want live data or fault codes today have to use a laptop or buy a second, cheaper ELM327 dongle.

What changed: we added two Bluetooth commands (`PIDS` and `RAW`) to the logger's telelogger firmware, on branch `obd-live-ble`. With them, a phone can ask the car for any OBD-II reading and get the raw reply. The iPhone app built on top of this now covers live readings, graphs, fault codes, freeze frames, readiness monitors, clearing the check-engine light, a bus log and a demo mode. CI builds every change and a manual workflow uploads to TestFlight.

## 4. Objective

**Objective:** Make the Freematics ONE+ the only device an owner needs to read and understand their car on an iPhone.

This matters to owners because it removes a second dongle and a laptop. It matters to the project because a firmware change is only useful if people can install it and the app works on their car.

**Key results (first public release, assumed targets, see 7.4):**
1. 8 in 10 testers who flash the firmware get live readings on their own car within 10 minutes of starting.
2. Live readings work on at least 15 different car models reported by testers, with no app crash in 95% of sessions.
3. Fault codes are read correctly (match a second scanner) on 9 in 10 test cars that have a stored code.

## 5. Market segments

1. **ONE+ owners who tinker with their own car.** They want to see live engine data while driving or parked, and check why a warning light is on. They are comfortable plugging in hardware, but flashing firmware is a hurdle for many.
2. **Developers and makers using the ONE+ for projects.** They want to see the raw OBD traffic between logger and car to debug their own firmware or check what a car supports.

Later, not now: owners of other Bluetooth LE OBD-II adapters, and people who want all their ONE+ data captured in the cloud.

**Constraints**
- The app needs the custom telelogger firmware from `obd-live-ble`. Stock firmware does not have the `PIDS` and `RAW` commands.
- Bluetooth LE limits polling to a few readings per second, far below the 25 Hz in the original design.
- While the logger polls OBD, it cannot listen to all CAN bus traffic, so the bus view shows only OBD requests and replies on a real car.
- Only the standard OBD-II readings are supported. Maker-specific data (for example, gear or oil temperature on many cars) is not available.
- iOS 16 or later; Bluetooth does not work in the iOS Simulator.

## 6. Value propositions

### Segment 1: ONE+ owners who tinker with their car

- **Who:** A car owner who already has a Freematics ONE+ and an iPhone.
- **Why:** They want to know what the engine is doing and why a warning light came on, without guessing.
- **What before:** They use a laptop with a serial cable, or buy a separate ELM327 dongle and an app such as Car Scanner or OBD Fusion. The ONE+ sits in the port doing nothing they can see.
- **How:** OBD Live connects to the ONE+ over Bluetooth, finds which readings the car supports, and shows them live, with fault codes in plain language and a one-tap clear.
- **What after:** One device in the port does logging and live diagnostics. They can check a fault in the driveway and see if a fix worked.
- **Alternatives:** A second dongle and a general OBD app. They would choose us because they keep the hardware they already own, need no account, and get an app built for the ONE+.

*Statement:* For ONE+ owners who want to understand their car, OBD Live turns the logger they already have into a live dashboard and fault-code reader on their iPhone, so they don't need a second dongle or a laptop.

### Segment 2: Developers and makers

- **Who:** Someone building on the ONE+ or its firmware.
- **Why:** They need to see what the logger sends and what the car answers, to debug and to learn what a car supports.
- **What before:** Serial logs on a laptop, often in the car with a cable across the seat.
- **How:** The bus view shows every OBD request and reply live, and the setup log shows the VIN, supported readings and whether the car accepts combined requests.
- **What after:** They can debug from the driver's seat with only a phone, and test changes faster.
- **Alternatives:** A laptop serial monitor or a CAN sniffer. They would choose us for speed and convenience, not depth.

*Statement:* For makers working with the ONE+, OBD Live shows the logger's conversation with the car on the phone, so they can debug in the car without a laptop.

## 7. Solution

### 7.1 UX

Five screens, each in two looks (Simple and Racing): Connect, Live, Graph, Codes and CAN bus. Screenshots are in the README and are made automatically by the Screenshots workflow. Key flow: plug in the logger, turn on the ignition, tap Connect, see live readings within seconds.

### 7.2 Key features for the first public version

All of these exist today and need testing on more cars, not new building:
- **Connect and stay connected.** Find the logger, wake it from standby, reconnect by itself after a drop, and clearly show "No ECU", "Standby" and "Reconnecting".
- **Live dashboard.** Engine speed, speed, load, throttle, temperatures, battery, timing and fuel rate, polling only what the car supports, with "—" for missing readings.
- **Graphs.** An 18-second chart with min, average and max for any reading.
- **Fault codes.** Stored and pending codes with plain descriptions, freeze frame, readiness monitors, and clear with a confirmation step.
- **Know the car.** Read and decode the VIN, and explain when the car refuses.
- **Demo mode** so anyone can try the app without a car (also needed for App Store review).

New work needed before a public release:
- **Firmware setup guide** inside the app or linked from it, since flashing is the biggest hurdle.
- **Clear message when the firmware is wrong or too old**, instead of empty readings.

### 7.3 Technology

SwiftUI app with a separate `OBDCore` Swift package for parsing, framing and the simulator, tested with `swift test`. The phone talks to the logger over a Bluetooth LE service (`0xABF0`) with plain-text commands. The firmware lives in the `freematics` repository.

### 7.4 Assumptions and open questions

- **Decided:** The goal is a public release (TestFlight, then the App Store).
- **Assumption:** The key-result targets above are placeholders. *What does success look like to you?*
- **Assumption:** Enough ONE+ owners will flash custom firmware. Could the `PIDS` and `RAW` commands be offered to the official Freematics firmware, so no custom flashing is needed?
- **Open:** How many ONE+ owners use iPhone? We have no numbers.
- **Open:** Is clearing fault codes safe to ship to everyone, or should it sit behind a setting?
- **Open:** Should we add local trip logging (save and export a drive) in version 1, or wait?

## 8. Release

**Version 1 (public beta, then App Store):** the features in 7.2, the firmware guide and the wrong-firmware message. Test on as many cars as testers bring.

**Later:** support for other OBD adapters that have Bluetooth LE, and a cloud service that captures all the data coming directly from the ONE+.

**Not doing:** changing car settings (coding), an Android app.

**Timing (rough):** the firmware guide and the wrong-firmware message take about 1 to 2 weeks. A public TestFlight round with outside testers takes about 4 to 6 weeks. App Store submission follows when the key results are met.
