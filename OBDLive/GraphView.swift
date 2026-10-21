import SwiftUI

/// One reading over the last 18 s (120 samples at 150 ms), with min / avg / max.
struct GraphView: View {
    @EnvironmentObject var model: AppModel
    @AppStorage(SettingsKey.units) private var unitsRaw = "Metric"

    private var fmt: ReadingFormat { ReadingFormat(units: UnitSystem(rawValue: unitsRaw) ?? .metric) }

    var body: some View {
        let key = model.graphKey
        let c = key.info
        let samples = (model.history[key] ?? []).map { fmt.convert(key, $0) }
        let lo = fmt.convert(key, c.min), hi = fmt.convert(key, c.max)
        let avg = samples.isEmpty ? 0 : samples.reduce(0, +) / Double(samples.count)

        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(ChannelKey.allCases) { k in
                        let on = k == key
                        Button { model.graphKey = k } label: {
                            Text(k.info.label)
                                .font(DS.body(13))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .foregroundStyle(on ? DS.bg : DS.text)
                                .background(on ? DS.text : Color.clear)
                        }
                        .buttonStyle(.plain)
                        DS.divider.frame(width: 1)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            Rule()

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Kicker(text: "\(c.label) · \(c.pidLabel)")
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(fmt.value(key, model.readings[key]))
                            .font(DS.heading(64))
                            .tracking(-2.56)
                            .monospacedDigit()
                        Text(fmt.unit(key)).font(DS.body(15)).foregroundStyle(DS.neutral700)
                    }
                }
                Spacer(minLength: 0)
                Button(model.paused ? "Resume" : "Pause") { model.paused.toggle() }
                    .buttonStyle(SecondaryButtonStyle(minHeight: 40, fontSize: 13))
                    .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                HistoryChart(samples: samples, lo: lo, hi: hi)
                    .frame(height: 200)
                HStack {
                    Text("\(fmt.number(key, hi)) max · −18 s")
                    Spacer()
                    Text("−9 s")
                    Spacer()
                    Text("now")
                }
                .font(DS.body(10))
                .foregroundStyle(DS.neutral700)
                .padding(.top, 6)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            VStack(spacing: 0) {
                Rule()
                HStack(spacing: 0) {
                    stat("Min", samples.min() ?? 0, key)
                    DS.divider.frame(width: 1)
                    stat("Avg", avg, key)
                    DS.divider.frame(width: 1)
                    stat("Max", samples.max() ?? 0, key)
                }
                .fixedSize(horizontal: false, vertical: true)
                Rule(weight: 1)
            }
            .padding(.top, 16)

            Text(c.description)
                .font(DS.body(14))
                .lineSpacing(5)
                .foregroundStyle(DS.neutral800)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
        }
    }

    private func stat(_ label: String, _ value: Double, _ key: ChannelKey) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Kicker(text: label)
            Text(fmt.number(key, value)).font(DS.heading(22)).monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Rolling line chart in the design's 370×200 viewBox, stretched to the available width.
struct HistoryChart: View {
    let samples: [Double]
    let lo: Double
    let hi: Double

    var body: some View {
        Canvas { ctx, size in
            let n = AppModel.historyLength
            let sx = size.width / 370, sy = size.height / 200
            let pts: [CGPoint] = samples.enumerated().map { i, v in
                let x = 370 * Double(i + n - samples.count) / Double(n - 1)
                let f = min(max((v - lo) / (hi - lo), 0), 1)
                return CGPoint(x: x * sx, y: (200 - 200 * f) * sy)
            }
            func hline(_ y: CGFloat, _ color: Color, _ width: CGFloat, dash: [CGFloat] = []) {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, dash: dash))
            }
            hline(0, DS.neutral300, 1)
            hline(size.height / 2, DS.neutral300, 1, dash: [2, 3])
            if let first = pts.first {
                var area = Path()
                area.move(to: CGPoint(x: first.x, y: size.height))
                pts.forEach { area.addLine(to: $0) }
                area.addLine(to: CGPoint(x: size.width, y: size.height))
                area.closeSubpath()
                ctx.fill(area, with: .color(DS.accent200))
                var line = Path()
                line.addLines(pts)
                ctx.stroke(line, with: .color(DS.text), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            }
            hline(size.height, DS.text, 2)
        }
    }
}
