import SwiftUI

/// Bus traffic. Demo mode shows the simulated bus; on a logger it shows the OBD requests (TX) and
/// ECU replies (RX) relayed over BLE, since the telelogger doesn't sniff the bus while polling.
struct CANView: View {
    @EnvironmentObject var model: AppModel

    private var rows: [CANFrame] {
        model.frames.filter { f in
            switch model.canFilter {
            case .all: return true
            case .obd: return f.obd
            case .broadcast: return !f.obd
            }
        }
        .prefix(30)
        .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(AppModel.CANFilter.allCases, id: \.self) { f in
                    let on = model.canFilter == f
                    Button { model.canFilter = f } label: {
                        Text(label(f))
                            .font(DS.body(13))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .foregroundStyle(on ? DS.bg : DS.text)
                            .background(on ? DS.text : Color.clear)
                    }
                    .buttonStyle(.plain)
                    DS.divider.frame(width: 1)
                }
                Spacer(minLength: 0)
                DS.divider.frame(width: 1)
                Button { model.paused.toggle() } label: {
                    Text(model.paused ? "Resume" : "Pause")
                        .font(DS.heading(13))
                        .foregroundStyle(DS.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .buttonStyle(TintButtonStyle(background: .clear, pressed: DS.text.opacity(0.07)))
            }
            .fixedSize(horizontal: false, vertical: true)
            Rule()

            columns(Text("Time"), Text("ID"), Text("L"), Text("Data"))
                .font(DS.body(10))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(DS.neutral700)
                .padding(.vertical, 8)
            Rule()

            ForEach(rows) { f in
                columns(
                    Text(f.ts).foregroundColor(DS.neutral600),
                    Text(f.canId).fontWeight(.semibold).foregroundColor(f.obd ? DS.accent700 : DS.text),
                    Text(f.dlc).foregroundColor(DS.neutral600),
                    Text(f.data)
                )
                .font(DS.mono(12))
                .lineLimit(1)
                .padding(.vertical, 5)
                .background(f.obd ? DS.accent100 : Color.clear)
                Rule(weight: 1, color: DS.neutral300)
            }

            if model.source == .device && model.canFilter == .broadcast {
                Text("Broadcast frames need the logger in CAN sniffing mode, which the telelogger firmware doesn't run while it polls OBD.")
                    .font(DS.body(13))
                    .foregroundStyle(DS.neutral700)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
            }

            Text(model.source == .demo
                 ? "Tinted rows are OBD request/response pairs on 7DF / 7E8. 11-bit IDs, 500 kbps."
                 : "Tinted rows are OBD requests (TX) and ECU replies (RX) relayed by the ONE+ over BLE.")
                .font(DS.body(12))
                .lineSpacing(6)
                .foregroundStyle(DS.neutral700)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
    }

    private func label(_ f: AppModel.CANFilter) -> String {
        switch f {
        case .all: return "All"
        case .obd: return "OBD"
        case .broadcast: return "Broadcast"
        }
    }

    /// The 62 / 38 / 16 / rest grid with 8pt gaps.
    private func columns(_ ts: Text, _ id: Text, _ dlc: Text, _ data: Text) -> some View {
        HStack(spacing: 8) {
            ts.frame(width: 62, alignment: .leading)
            id.frame(width: 38, alignment: .leading)
            dlc.frame(width: 16, alignment: .leading)
            data.frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
    }
}
