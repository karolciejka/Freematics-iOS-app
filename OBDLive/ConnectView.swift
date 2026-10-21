import SwiftUI

/// Step 1: scan for loggers (or pick demo data). Step 2: the setup exchange with the logger.
struct ConnectView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ConnectContent(link: model.link)
    }
}

private struct ConnectContent: View {
    @EnvironmentObject var model: AppModel
    /// Observed directly so scan results and Bluetooth state refresh the screen.
    @ObservedObject var link: FreematicsLink

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Kicker(text: model.phase == .connecting ? "Step 2 of 2" : "Step 1 of 2", color: DS.accent700, tracking: 0.1)
                Text("Connect the Freematics ONE+")
                    .font(DS.heading(32))
                    .tracking(-0.48)
                    .lineSpacing(-2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 14)

            Rule()

            Text("Plug the logger into the OBD-II port under the dashboard and switch the ignition on. The engine can stay off.")
                .font(DS.body(15))
                .lineSpacing(5)
                .foregroundStyle(DS.neutral800)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

            PortPhoto()
                .frame(height: 150)
                .padding(.horizontal, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if model.phase == .scanning { deviceList }
                    if model.phase == .connecting { setupLog }
                    if let error = model.connectError, model.phase != .connecting {
                        Text(error)
                            .font(DS.body(13))
                            .foregroundStyle(DS.accent700)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                    }
                }
            }

            if model.phase == .idle || (model.phase == .scanning && !link.scanning && link.radio != .unknown) {
                VStack(spacing: 8) {
                    Button(action: model.startScan) {
                        HStack {
                            Text(model.phase == .scanning ? "Scan again" : "Scan for loggers")
                            Spacer()
                            Text("→")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Button("Use demo data", action: model.connectDemo)
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)
            }
        }
    }

    private var scanLabel: String {
        switch link.radio {
        case .poweredOff: return "Bluetooth off"
        case .unauthorized: return "Not allowed"
        case .unsupported: return "Unavailable"
        case .unknown: return "Scanning…"
        case .ready: return link.scanning ? "Scanning…" : "\(link.discovered.count) found"
        }
    }

    private var deviceList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Kicker(text: "Bluetooth LE", size: 11)
                Spacer()
                Kicker(text: scanLabel, color: DS.accent700, size: 11)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            Rule()
            ForEach(link.discovered) { d in
                Button { model.connect(d) } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.name == FreematicsBLE.advertisedName ? "Freematics ONE+" : d.name).font(DS.heading(17))
                            Text("BLE · \(d.name) · ID \(d.id.uuidString.suffix(4))").font(DS.body(12)).foregroundStyle(DS.neutral700)
                        }
                        Spacer(minLength: 0)
                        Text("−\(abs(d.rssi)) dBm").font(DS.body(12)).monospacedDigit().foregroundStyle(DS.neutral700)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(FlatButtonStyle(pressed: DS.text.opacity(0.12)))
                Rule(weight: 1)
            }
            if link.discovered.isEmpty && !link.scanning && link.radio == .ready {
                Text("No loggers found. Check that the ONE+ is powered and its firmware has ENABLE_BLE set.")
                    .font(DS.body(13))
                    .foregroundStyle(DS.neutral700)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }
            if link.radio == .poweredOff || link.radio == .unauthorized {
                Text(link.radio == .poweredOff ? "Turn Bluetooth on in Control Centre to scan." : "Allow Bluetooth for OBD Live in Settings › Privacy & Security › Bluetooth.")
                    .font(DS.body(13))
                    .foregroundStyle(DS.neutral700)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }
        }
        .padding(.top, 20)
    }

    private var setupLog: some View {
        VStack(alignment: .leading, spacing: 0) {
            Kicker(text: "Negotiating protocol", size: 11)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            Rule()
            ForEach(Array(model.connectLog.enumerated()), id: \.offset) { _, l in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(l.cmd).foregroundStyle(DS.accent700).frame(width: 72, alignment: .leading)
                    Text(l.res).frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(DS.mono(13))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                Rule(weight: 1)
            }
        }
        .padding(.top, 20)
    }
}

/// Photo of the OBD-II port location. Shows the striped placeholder until a "PortPhoto" image is added to the asset catalog.
struct PortPhoto: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image = UIImage(named: "PortPhoto") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .grayscale(1)
                    .contrast(1.08)
            } else {
                Canvas { ctx, size in
                    ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(DS.bg))
                    ctx.clip(to: Path(CGRect(origin: .zero, size: size)))
                    ctx.rotate(by: .degrees(45))
                    let span = size.width + size.height
                    var x = -span
                    while x < span {
                        ctx.fill(Path(CGRect(x: x, y: -span, width: 8, height: span * 2)), with: .color(DS.surface))
                        x += 16
                    }
                }
                Text("photo: OBD-II port location (grayscale)")
                    .font(DS.mono(11))
                    .foregroundStyle(DS.neutral700)
                    .padding(10)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay(Rectangle().strokeBorder(DS.divider, lineWidth: 1))
    }
}
