import SwiftUI

/// Header, the active tab's content and the bottom tab bar.
struct AppShellView: View {
    @EnvironmentObject var model: AppModel
    @AppStorage(SettingsKey.skin) private var skinRaw = Skin.simple.rawValue

    var body: some View {
        VStack(spacing: 0) {
            header
            Rule(color: DS.headerRule)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch model.tab {
                    case .live: LiveView()
                    case .graph: GraphView()
                    case .codes: CodesView()
                    case .can: CANView()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            tabBar
        }
        .overlay {
            if model.showClear { ClearCodesSheet() }
        }
    }

    private var title: String {
        switch model.tab {
        case .live: return "Live"
        case .graph: return "Graph"
        case .codes: return "Codes"
        case .can: return "CAN bus"
        }
    }

    private var linkLabel: String {
        if model.paused { return "Paused" }
        if model.source == .demo { return "Demo · 25 Hz" }
        if model.reconnecting { return "Reconnecting…" }
        if model.rateHz > 0 { return LiveDecode.rateLabel(model.rateHz) }
        return model.loggerAsleep ? "Standby" : "No ECU"
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Kicker(text: model.vehicleLabel, color: DS.accent700, tracking: 0.1)
                Kicker(text: model.vin.map { "VIN \($0)" } ?? "VIN not reported")
                    .monospacedDigit()
                    .textSelection(.enabled)
                Text(title)
                    .font(DS.heading(32))
                    .tracking(-0.48)
            }
            Spacer(minLength: 0)
            // skin switch, as in the design's header
            Button { skinRaw = DS.skin == .racing ? Skin.simple.rawValue : Skin.racing.rawValue } label: {
                Text(DS.skin.rawValue)
                    .font(DS.body(11))
                    .foregroundStyle(DS.neutral800)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .overlay(Rectangle().strokeBorder(DS.neutral300, lineWidth: 1))
            }
            .buttonStyle(TintButtonStyle(background: .clear, pressed: DS.neutral200))
            .accessibilityLabel("Skin: \(DS.skin.rawValue). Switch skin")
            .padding(.trailing, -6) // chips sit 6pt apart in the design
            Button(action: model.disconnect) {
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(model.paused || (model.source == .device && model.rateHz == 0) ? DS.neutral500 : DS.accent)
                        .frame(width: 6, height: 6)
                    Text(model.source == .demo ? linkLabel : "ONE+ · \(linkLabel)")
                        .font(DS.body(11))
                        .monospacedDigit()
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .foregroundStyle(DS.neutral800)
            }
            .buttonStyle(TintButtonStyle(background: DS.neutral200, pressed: DS.neutral300))
            .accessibilityLabel("Disconnect")
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    private var tabBar: some View {
        VStack(spacing: 0) {
            Rule()
            HStack(spacing: 0) {
                ForEach(AppModel.Tab.allCases, id: \.self) { tab in
                    let on = model.tab == tab
                    Button { model.select(tab) } label: {
                        HStack(spacing: 6) {
                            Text(tab == .can ? "CAN" : tab.rawValue.capitalized)
                                .font(DS.heading(14))
                            if tab == .codes && !model.codes.isEmpty {
                                Text("\(model.codes.count)")
                                    .font(DS.body(10))
                                    .padding(.vertical, 1)
                                    .padding(.horizontal, 5)
                                    .background(DS.accent)
                                    .foregroundStyle(DS.bg)
                            }
                        }
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(on ? DS.accent : DS.neutral700)
                        // labels are flush left, so a short trailing inset leaves room for a two-digit badge
                        .padding(.leading, 16)
                        .padding(.trailing, 4)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .top) {
                            (on ? DS.accent : Color.clear).frame(height: 3)
                        }
                    }
                    .buttonStyle(FlatButtonStyle(pressed: DS.text.opacity(0.05)))
                }
            }
        }
        .background(DS.bg.ignoresSafeArea(edges: .bottom))
    }
}

/// Filled chip button with a darker pressed fill.
struct TintButtonStyle: ButtonStyle {
    let background: Color
    let pressed: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(configuration.isPressed ? pressed : background)
    }
}

/// "Clear all trouble codes?" bottom sheet.
struct ClearCodesSheet: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack(alignment: .bottom) {
            DS.neutral900.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { model.showClear = false }
            VStack(alignment: .leading, spacing: 12) {
                Text("Clear all trouble codes?")
                    .font(DS.heading(22))
                Text("This sends Mode 04: the check-engine light goes off and freeze-frame data and readiness monitors are reset. A code returns if the fault is still present. Inspections can fail a car with incomplete monitors.")
                    .font(DS.body(14))
                    .lineSpacing(5)
                    .foregroundStyle(DS.neutral800)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 8) {
                    Button("Clear codes", action: model.clearCodes)
                        .buttonStyle(PrimaryButtonStyle(minHeight: 50, fontSize: 15))
                    Button("Cancel") { model.showClear = false }
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.surface.ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) { DS.text.frame(height: 2) }
            .shadow(color: DS.neutral900.opacity(0.22), radius: 16, y: 12)
        }
        .transition(.opacity)
    }
}
