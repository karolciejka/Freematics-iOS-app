import SwiftUI

/// The Power skin's engine-speed display (`pwStyle` in OBD Prototype.dc.html): two mirrored
/// six-sided gauges, speed on the left (blue) and rpm on the right (blue → violet → red, redline from
/// 6500 rpm), the gear and rpm in the right one and the peak rpm between them. Drawn in the design's
/// 402×244 coordinates, scaled to the available width.
struct PowerGauge: View {
    let rpm: Double
    let rpmText: String
    let peakText: String
    let gear: String
    /// Speed in display units, for the left gauge.
    let speed: Double
    let speedText: String
    let speedUnit: String
    let imperial: Bool
    let rpmColor: Color

    static let maxRPM = 8000.0

    var body: some View {
        let g = PowerGeometry.shared(imperial: imperial)
        GeometryReader { geo in
            let s = geo.size.width / 402
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    ctx.scaleBy(x: s, y: s)
                    draw(&ctx, g)
                }
                ForEach(g.labels.indices, id: \.self) { i in
                    let l = g.labels[i]
                    Text(l.text)
                        .font(DS.bodyMedium(13 * s))
                        .monospacedDigit()
                        .foregroundStyle(l.red ? Color(hex: 0xFF5A4A) : DS.text)
                        .fixedSize()
                        .position(x: l.point.x * s, y: l.point.y * s)
                }
                VStack(spacing: 2) {
                    Text(speedText).font(DS.headingBold(56 * s)).monospacedDigit().frame(height: 50 * s)
                    Kicker(text: speedUnit, size: 11 * s)
                }
                .fixedSize()
                .position(x: 0.276 * 402 * s, y: 0.47 * 244 * s)
                VStack(spacing: 2) {
                    Text(gear).font(DS.heading(64 * s)).frame(height: 54 * s)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(rpmText).font(DS.headingBold(18 * s)).monospacedDigit().foregroundStyle(rpmColor)
                        Text("rpm").font(DS.body(10 * s)).foregroundStyle(DS.neutral700)
                    }
                }
                .fixedSize()
                .position(x: 0.724 * 402 * s, y: 0.47 * 244 * s)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Kicker(text: "Peak")
                    Text(peakText).font(DS.headingBold(13)).monospacedDigit()
                }
                .fixedSize()
                .position(x: 201 * s, y: 232 * s)
            }
        }
        .aspectRatio(402.0 / 244.0, contentMode: .fit)
        .background(glow)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Speed \(speedText) \(speedUnit), engine speed \(rpmText) rpm, gear \(gear)")
    }

    /// Blue glow behind the speed gauge, red behind the rpm gauge.
    private var glow: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                ellipseGlow(Color(red: 0, green: 102 / 255, blue: 177 / 255).opacity(0.20), center: CGPoint(x: w * 0.24, y: h * 0.55), w: w, h: h)
                ellipseGlow(Color(red: 226 / 255, green: 39 / 255, blue: 24 / 255).opacity(0.12), center: CGPoint(x: w * 0.76, y: h * 0.55), w: w, h: h)
            }
        }
    }

    /// `radial-gradient(55% 65% at x y, color, transparent 70%)`
    private func ellipseGlow(_ color: Color, center: CGPoint, w: CGFloat, h: CGFloat) -> some View {
        let rx = w * 0.55, ry = h * 0.65
        return RadialGradient(colors: [color, color.opacity(0)], center: .center, startRadius: 0, endRadius: rx * 0.7)
            .frame(width: rx * 2, height: rx * 2)
            .scaleEffect(x: 1, y: ry / rx)
            .position(center)
    }

    private func draw(_ ctx: inout GraphicsContext, _ g: PowerGeometry) {
        let round = StrokeStyle(lineWidth: 1.5, lineJoin: .round)
        ctx.stroke(g.outL, with: .color(DS.neutral700), style: round)
        ctx.stroke(g.outR, with: .color(DS.neutral700), style: round)
        ctx.stroke(g.outR.trimmedPath(from: 0.8125, to: 1), with: .color(Color(hex: 0xE22718)), lineWidth: 3.5)

        let track = StrokeStyle(lineWidth: 7, lineJoin: .round)
        ctx.stroke(g.inL, with: .color(DS.neutral200), style: track)
        ctx.stroke(g.inR, with: .color(DS.neutral200), style: track)

        let spd = min(max(speed / g.speedMax, 0), 1)
        if spd > 0 {
            var c = ctx
            c.addFilter(.shadow(color: Color(red: 79 / 255, green: 179 / 255, blue: 1).opacity(0.55), radius: 5))
            c.stroke(g.inL.trimmedPath(from: 0, to: spd), with: .linearGradient(Gradient(colors: [Color(hex: 0x8FD0FF), Color(hex: 0x0F4D92)]),
                                                                              startPoint: CGPoint(x: 0, y: 214), endPoint: CGPoint(x: 0, y: 34)), style: track)
        }
        let rev = min(max(rpm / PowerGauge.maxRPM, 0), 1)
        if rev > 0 {
            var c = ctx
            c.addFilter(.shadow(color: Color(red: 226 / 255, green: 39 / 255, blue: 24 / 255).opacity(0.45), radius: 5))
            c.stroke(g.inR.trimmedPath(from: 0, to: rev), with: .linearGradient(Gradient(stops: [
                .init(color: Color(hex: 0x0066B1), location: 0),
                .init(color: Color(hex: 0x4B2D9E), location: 0.5),
                .init(color: Color(hex: 0xE22718), location: 0.8),
                .init(color: Color(hex: 0xFF4433), location: 1),
            ]), startPoint: CGPoint(x: 0, y: 214), endPoint: CGPoint(x: 0, y: 34)), style: track)
        }

        for t in g.ticks {
            var p = Path()
            p.move(to: t.from)
            p.addLine(to: t.to)
            ctx.stroke(p, with: .color(t.red ? Color(hex: 0xE22718) : (t.major ? DS.text : DS.neutral600)), lineWidth: t.major ? 2 : 1)
        }
    }
}

/// Outline, track, ticks and scale labels of the Power gauges (`pwGeom` in the design).
struct PowerGeometry {
    struct Tick { let from: CGPoint; let to: CGPoint; let major: Bool; let red: Bool }
    struct Label { let text: String; let point: CGPoint; let red: Bool }

    let outL, inL, outR, inR: Path
    let ticks: [Tick]
    let labels: [Label]
    /// Top of the speed scale in display units: 240 km/h or 160 mph.
    let speedMax: Double

    private static let metric = PowerGeometry(imperial: false)
    private static let imperialScale = PowerGeometry(imperial: true)
    static func shared(imperial: Bool) -> PowerGeometry { imperial ? imperialScale : metric }

    private static let outline: [CGPoint] = [(182, 214), (74, 214), (24, 160), (24, 94), (74, 34), (192, 34)].map { CGPoint(x: $0.0, y: $0.1) }
    private static let inner: [CGPoint] = [(182, 205), (78, 205), (33, 156), (33, 98), (78, 43), (192, 43)].map { CGPoint(x: $0.0, y: $0.1) }

    private init(imperial: Bool) {
        let mirror: (CGPoint) -> CGPoint = { CGPoint(x: 402 - $0.x, y: $0.y) }
        func path(_ pts: [CGPoint]) -> Path { var p = Path(); p.addLines(pts); return p }
        outL = path(Self.outline)
        inL = path(Self.inner)
        outR = path(Self.outline.map(mirror))
        inR = path(Self.inner.map(mirror))

        // point and inward normal at fraction f of the outline's length
        let pts = Self.outline
        var cum: [Double] = [0]
        for i in 1..<pts.count { cum.append(cum[i - 1] + hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y)) }
        let length = cum.last!
        func at(_ f: Double) -> (CGPoint, CGVector) {
            let t = f * length
            var i = 1
            while i < pts.count - 1 && cum[i] < t { i += 1 }
            let a = pts[i - 1], b = pts[i], seg = cum[i] - cum[i - 1], k = (t - cum[i - 1]) / seg
            let dx = (b.x - a.x) / seg, dy = (b.y - a.y) / seg
            return (CGPoint(x: a.x + (b.x - a.x) * k, y: a.y + (b.y - a.y) * k), CGVector(dx: -dy, dy: dx))
        }

        var ticks: [Tick] = [], labels: [Label] = []
        func scale(_ n: Int, _ per: Int, mirrored: Bool, redFrom: Double?, label: (Int) -> String) {
            let count = n * per
            let X: (Double) -> Double = { mirrored ? 402 - $0 : $0 }
            for i in 0...count {
                let f = Double(i) / Double(count)
                let (p, nrm) = at(f)
                let major = i % per == 0, len: Double = major ? 10 : 5
                let red = redFrom.map { f >= $0 - 1e-6 } ?? false
                ticks.append(Tick(from: CGPoint(x: X(p.x), y: p.y), to: CGPoint(x: X(p.x + nrm.dx * len), y: p.y + nrm.dy * len), major: major, red: red))
                if major {
                    labels.append(Label(text: label(i / per), point: CGPoint(x: X(p.x + nrm.dx * 24), y: p.y + nrm.dy * 24), red: red))
                }
            }
        }
        let step = imperial ? 20 : 40, n = imperial ? 8 : 6
        scale(n, 2, mirrored: false, redFrom: nil) { String($0 * step) }
        scale(8, 2, mirrored: true, redFrom: 6.5 / 8) { String($0) }
        self.ticks = ticks
        self.labels = labels
        speedMax = Double(n * step)
    }
}
