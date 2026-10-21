# OBD Live (iOS)

SwiftUI implementation of `project/OBD Prototype.dc.html`: Connect, Live (2a dial or 1a bar), Graph, Codes and CAN, styled with the Modernist design system. It talks to a Freematics ONE+ over Bluetooth Low Energy, or runs on the prototype's demo data.

## Build

1. Open `OBDLive.xcodeproj` in Xcode 15 or later.
2. Under *Signing & Capabilities*, pick your team (the bundle id is `com.karolciejka.obdlive`; change it if needed).
3. Run on an iPhone (iOS 16+). Bluetooth doesn't work in the Simulator, but **Use demo data** does.

Core logic tests (parsing, framing, simulator) run without Xcode:

```sh
cd OBDCore && swift test
```

The design's Tweaks panel lives in the iOS Settings app under **OBD Live**: engine-speed style (Dial / Bar), units (Metric / Imperial) and the simulated car (Parked / Driving) for demo mode.

## Logger firmware

The app needs the **telelogger** firmware (`firmware_v5/telelogger` in karolciejka/Freematics) with `ENABLE_BLE 1` (the default) and the `PIDS` / `RAW` BLE commands from branch `obd-live-ble`. Flash it with PlatformIO or Freematics Builder.

| | |
| --- | --- |
| Service | `0xABF0`, advertised as `FreematicsPlus` |
| Command (write) | `0xFFE1`, plain text, e.g. `PIDS0C0D0411050F0E5E` |
| Reply (notify) | `0xFFE2`, one line per command, terminated by `\r` |

What the app sends:

| When | Command | Used for |
| --- | --- | --- |
| Connect | `ATE0`, `UPTIME`, `BATT`, `VIN`, `RAW0100` | the setup log, header (model year and make from the VIN) |
| Continuously | `PIDS0C0D0411050F0E5E` | rpm, speed, load, throttle, coolant, intake air, timing, fuel rate |
| Every 2 s | `BATT` | battery voltage measured by the logger |
| Codes tab | `RAW0101`, `RAW03`, `RAW07`, `RAW020200`, `RAW02xx00` | MIL and readiness monitors, stored and pending codes, freeze frame |
| Clear codes | `RAW04` | Mode 04 clear, then the codes are read again |

## Behaviour on a real car

- **Polling rate.** The header shows the rate actually achieved (typically a few Hz over BLE), not the prototype's fixed 25 Hz. Graph history is sampled every 150 ms, so its time axis matches the design.
- **Ignition off.** The logger answers `N/A`; engine values show "—", the battery reading stays live and the header shows "No ECU".
- **Gear** isn't an OBD-II PID. It's estimated from the rpm/speed ratio using typical gear ratios, and shows N when stopped or coasting.
- **Freeze frame.** OBD-II stores one freeze frame (frame 0) for the code that triggered it, so only that code shows freeze-frame values.
- **Readiness monitors** list only the monitors the ECU reports as supported, so the count may not be 9.
- **CAN tab.** The telelogger can't sniff the bus while it polls OBD, so on a real logger the tab shows the OBD requests (TX) and ECU replies (RX) relayed over BLE. Broadcast traffic only appears in demo mode.
- **Port photo.** The connect screen shows the design's striped placeholder until you add a `PortPhoto` image to `Assets.xcassets`. It's shown in grayscale.

## Layout

- `OBDCore/`: Foundation-only Swift package with the channel table, OBD-II reply parsing, BLE line framing, trouble-code descriptions and the demo simulator, plus its tests. The app target compiles these sources directly.
- `OBDLive/`: the SwiftUI app. `FreematicsLink` is the CoreBluetooth transport, `AppModel` holds the state for every screen, and there's one view file per screen.
