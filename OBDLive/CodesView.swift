import SwiftUI

/// Stored and pending trouble codes with their freeze frame, Mode 04 clear and readiness monitors.
struct CodesView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(model.codes) { code in codeBlock(code) }

            if let note = model.codesNote {
                Text(note)
                    .font(DS.body(13))
                    .foregroundStyle(DS.accent700)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
            }

            if !model.codes.isEmpty {
                Button("Clear codes") { model.showClear = true }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(model.codesLoading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            } else if model.codesLoading {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reading codes…").font(DS.heading(25))
                    Text("Asking the ECU for stored and pending codes.").font(DS.body(14)).foregroundStyle(DS.neutral800)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                Rule()
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No trouble codes").font(DS.heading(25))
                    Text("Readiness monitors will re-run over the next few drive cycles.").font(DS.body(14)).foregroundStyle(DS.neutral800)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                Rule()
            }

            HStack {
                Kicker(text: "Readiness monitors · Mode 01 PID 01", size: 11)
                Spacer()
                Kicker(text: "\(model.monitors.filter(\.complete).count)/\(model.monitors.count) ready", size: 11)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            Rule()
            ForEach(Array(model.monitors.enumerated()), id: \.offset) { _, m in
                HStack {
                    Text(m.name).font(DS.body(14))
                    Spacer()
                    Tag(text: m.complete ? "Complete" : "Incomplete",
                        background: m.complete ? DS.neutral200 : DS.accent100,
                        foreground: m.complete ? DS.neutral800 : DS.accent800)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                Rule(weight: 1)
            }
            Color.clear.frame(height: 16)
        }
    }

    private func codeBlock(_ c: TroubleCode) -> some View {
        let open = model.openCode == c.code
        let stored = c.status == .stored
        return VStack(alignment: .leading, spacing: 0) {
            Button { model.openCode = open ? nil : c.code } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(c.code)
                            .font(DS.heading(24))
                            .tracking(-0.24)
                            .foregroundStyle(stored ? DS.accent : DS.text)
                        Spacer()
                        Tag(text: c.status.rawValue,
                            background: stored ? DS.accent100 : DS.neutral200,
                            foreground: stored ? DS.accent800 : DS.neutral800)
                    }
                    Text(c.description).font(DS.body(15)).fixedSize(horizontal: false, vertical: true)
                    Text(c.hint).font(DS.body(13)).foregroundStyle(DS.neutral700).fixedSize(horizontal: false, vertical: true)
                    Text(open ? "Hide freeze frame" : "Show freeze frame")
                        .font(DS.heading(12))
                        .foregroundStyle(DS.accent700)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(FlatButtonStyle(pressed: DS.text.opacity(0.04)))

            if open {
                Rule(weight: 1)
                if c.freezeFrame.isEmpty {
                    Text("The ECU stored no freeze frame for this code.")
                        .font(DS.body(13))
                        .foregroundStyle(DS.neutral700)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DS.surface)
                } else {
                    VStack(spacing: 0) {
                        ForEach(0..<(c.freezeFrame.count + 1) / 2, id: \.self) { row in
                            HStack(spacing: 0) {
                                field(c.freezeFrame[row * 2])
                                DS.divider.frame(width: 1)
                                if row * 2 + 1 < c.freezeFrame.count { field(c.freezeFrame[row * 2 + 1]) } else { DS.surface }
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            Rule(weight: 1)
                        }
                    }
                }
            }
            Rule()
        }
    }

    private func field(_ f: FreezeField) -> some View {
        HStack(spacing: 8) {
            Text(f.k).foregroundStyle(DS.neutral700)
            Spacer(minLength: 0)
            Text(f.v).font(DS.heading(13)).monospacedDigit()
        }
        .font(DS.body(13))
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(DS.surface)
    }
}
