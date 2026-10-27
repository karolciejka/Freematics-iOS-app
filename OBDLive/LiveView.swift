import SwiftUI

struct LiveView: View {
    @EnvironmentObject var model: AppModel
    @AppStorage(SettingsKey.rpmStyle) private var rpmStyle = "Dial"
    @AppStorage(SettingsKey.units) private var unitsRaw = "Metric"

    private var fmt: ReadingFormat { ReadingFormat(units: UnitSystem(rawValue: unitsRaw) ?? .metric) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !model.codes.isEmpty { milBanner }
            if DS.skin == .racing { racingGauge } else if rpmStyle == "Bar" { rpmBar } else { rpmDial }
            Rule()
            cells
            Text("Tap a reading to graph it.")
                .font(DS.body(12))
                .foregroundStyle(DS.neutral700)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
    }

    private var rpm: Double? { model.readings[.rpm] }
    private var rpmText: String { fmt.value(.rpm, rpm) }
    private var rpmColor: Color { (rpm ?? 0) > 6000 ? DS.accent : DS.text }
    private var peakText: String { fmt.value(.rpm, model.extremes[.rpm]?.hi ?? rpm) }

    private func graph(_ key: ChannelKey) {
        model.graphKey = key
        model.select(.graph)
    }

    private var milBanner: some View {
        Button { model.select(.codes) } label: {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    HStack(spacing: 10) {
                        DS.accent.frame(width: 8, height: 8)
                        Text("Check engine · \(model.codes.count) code\(model.codes.count > 1 ? "s" : "")")
                            .font(DS.body(14))
                    }
                    Spacer()
                    Text("View →").font(DS.heading(14))
                }
                .foregroundStyle(DS.accent800)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                Rule()
            }
        }
        .buttonStyle(FlatButtonStyle(background: DS.accent100, pressed: DS.accent200))
    }

    // Racing skin: Type R rev bar with the gear in the middle (replaces dial / bar).
    private var racingGauge: some View {
        Button { graph(.rpm) } label: {
            TypeRGauge(rpm: rpm ?? 0, rpmText: rpmText, peakText: peakText,
                       gear: model.readings.gear > 0 ? String(model.readings.gear) : "N",
                       speedText: fmt.value(.speed, model.readings[.speed]), speedUnit: fmt.unit(.speed),
                       rpmColor: rpmColor)
        }
        .buttonStyle(FlatButtonStyle(pressed: DS.text.opacity(0.04)))
    }

    // 2a: analog tachometer centred, the number under it, Peak and Gear below.
    private var rpmDial: some View {
        Button { graph(.rpm) } label: {
            VStack(spacing: 0) {
                VStack(spacing: 2) {
                    Tachometer(fraction: min(max((rpm ?? 0) / 7000, 0), 1))
                        .frame(width: 196, height: 196)
                    VStack(spacing: 2) {
                        Kicker(text: "Engine speed · 0x10C")
                        Text(rpmText)
                            .font(DS.heading(44))
                            .tracking(-1.32)
                            .monospacedDigit()
                            .foregroundStyle(rpmColor)
                        Text("rpm").font(DS.body(12)).foregroundStyle(DS.neutral700)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 12)
                Rule(weight: 1)
                HStack(spacing: 0) {
                    stat("Peak", peakText).padding(.leading, 16)
                    DS.divider.frame(width: 1)
                    stat("Gear", model.readings.gear > 0 ? String(model.readings.gear) : "N").padding(.leading, 14)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(FlatButtonStyle(pressed: DS.text.opacity(0.04)))
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Kicker(text: label)
            Text(value).font(DS.heading(18)).monospacedDigit()
        }
        .padding(.vertical, 10)
        .padding(.trailing, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 1a: big number over a 35-segment bar.
    private var rpmBar: some View {
        Button { graph(.rpm) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Kicker(text: "Engine speed · 0x10C", size: 11)
                    Spacer()
                    Kicker(text: "Peak \(peakText)", size: 11)
                }
                Text(rpmText)
                    .font(DS.heading(88))
                    .tracking(-3.52)
                    .monospacedDigit()
                    .foregroundStyle(rpmColor)
                    .frame(height: 80, alignment: .leading)
                SegmentBar(fraction: min(max((rpm ?? 0) / 7000, 0), 1))
                    .frame(height: 22)
                HStack(spacing: 0) {
                    ForEach(0..<8) { i in
                        Text("\(i)")
                        if i < 7 { Spacer(minLength: 0) }
                    }
                }
                .font(DS.body(10))
                .foregroundStyle(DS.neutral600)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .buttonStyle(FlatButtonStyle(pressed: DS.text.opacity(0.04)))
    }

    private var cells: some View {
        VStack(spacing: 0) {
            ForEach(0..<Channel.cells.count / 2, id: \.self) { row in
                HStack(spacing: 0) {
                    cell(Channel.cells[row * 2])
                    DS.divider.frame(width: 2)
                    cell(Channel.cells[row * 2 + 1])
                }
                .fixedSize(horizontal: false, vertical: true)
                Rule(weight: 1)
            }
        }
    }

    private func cell(_ key: ChannelKey) -> some View {
        let raw = model.readings[key]
        return Button { graph(key) } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Kicker(text: key.info.label)
                    Spacer(minLength: 4)
                    Kicker(text: key.info.pidLabel, color: DS.neutral500)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(fmt.value(key, raw))
                        .font(DS.heading(30))
                        .tracking(-0.6)
                        .monospacedDigit()
                        .foregroundStyle(fmt.isWarning(key, raw) ? DS.accent : DS.text)
                    Text(fmt.unit(key)).font(DS.body(13)).foregroundStyle(DS.neutral700)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .buttonStyle(FlatButtonStyle(pressed: DS.text.opacity(0.1)))
    }
}

/// The 2a dial, drawn in the design's 240-unit viewBox: 270° sweep, redline from 6000 rpm.
struct Tachometer: View {
    let fraction: Double

    static func point(_ f: Double, _ r: Double) -> CGPoint {
        let a = (225 - 270 * f) * .pi / 180
        return CGPoint(x: 120 + r * cos(a), y: 120 - r * sin(a))
    }

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / 240
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    ctx.scaleBy(x: s, y: s)
                    func arc(from f0: Double, to f1: Double) -> Path {
                        var p = Path()
                        p.addArc(center: CGPoint(x: 120, y: 120), radius: 100,
                                 startAngle: .degrees(-(225 - 270 * f0)), endAngle: .degrees(-(225 - 270 * f1)), clockwise: false)
                        return p
                    }
                    ctx.stroke(arc(from: 0, to: 1), with: .color(DS.neutral300), lineWidth: 2)
                    ctx.stroke(arc(from: 6.0 / 7.0, to: 1), with: .color(DS.accent), lineWidth: 8)
                    for i in 0...28 {
                        let major = i % 4 == 0
                        var p = Path()
                        p.move(to: Tachometer.point(Double(i) / 28, 100))
                        p.addLine(to: Tachometer.point(Double(i) / 28, major ? 84 : 93))
                        ctx.stroke(p, with: .color(i >= 24 ? DS.accent : DS.text), lineWidth: major ? 3 : 1.5)
                    }
                    var needle = Path()
                    needle.move(to: CGPoint(x: 120, y: 120))
                    needle.addLine(to: Tachometer.point(fraction, 90))
                    ctx.stroke(needle, with: .color(DS.accent), lineWidth: 4)
                    ctx.fill(Path(CGRect(x: 111, y: 111, width: 18, height: 18)), with: .color(DS.text))
                }
                Text("×1000 RPM")
                    .font(DS.body(11 * s))
                    .tracking(1 * s)
                    .foregroundStyle(DS.neutral700)
                    .fixedSize()
                    .position(x: 120 * s, y: 174 * s)
                ForEach(0..<8) { i in
                    let p = Tachometer.point(Double(i) / 7, 70)
                    Text("\(i)")
                        .font(DS.heading(14))
                        .foregroundStyle(i >= 6 ? DS.accent700 : DS.text)
                        .position(x: p.x * s, y: p.y * s)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// The 1a segmented bar: 35 segments, the last five are the redline.
struct SegmentBar: View {
    let fraction: Double

    var body: some View {
        let lit = Int((fraction * 35).rounded())
        HStack(spacing: 2) {
            ForEach(0..<35) { i in
                let red = i >= 30
                (i < lit ? (red ? DS.accent : DS.text) : (red ? DS.accent200 : DS.neutral300))
            }
        }
    }
}
