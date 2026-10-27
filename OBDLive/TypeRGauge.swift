import SwiftUI

/// The Racing skin's engine-speed display (`trStyle` in OBD Prototype.dc.html), after the Civic Type R
/// cluster: a curved rev bar filling red → orange → yellow up to 8000 rpm, a hexagon shift block from
/// 7000 rpm that flashes past 6500 rpm, the gear in the middle over a red glow, speed top right and
/// rpm / peak below. Drawn in the design's 402×236 coordinates, scaled to the available width.
struct TypeRGauge: View {
    let rpm: Double
    let rpmText: String
    let peakText: String
    let gear: String
    let speedText: String
    let speedUnit: String
    let rpmColor: Color

    static let maxRPM = 8000.0
    static let shiftRPM = 6500.0

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / 402
            ZStack(alignment: .topLeading) {
                TimelineView(.periodic(from: .now, by: 0.15)) { context in
                    let tick = Int(context.date.timeIntervalSinceReferenceDate / 0.15)
                    Canvas { ctx, _ in
                        ctx.scaleBy(x: s, y: s)
                        draw(&ctx, hexOpacity: rpm > TypeRGauge.shiftRPM ? (tick % 2 == 0 ? 1 : 0.35) : 0.22)
                    }
                }
                ForEach(TypeRGeometry.labels, id: \.text) { l in
                    Text(l.text)
                        .font(DS.headingBold(15 * s))
                        .foregroundStyle(l.redline ? DS.accent700 : DS.text)
                        .position(x: l.point.x * s, y: l.point.y * s)
                }
                Text("×1000 r/min")
                    .font(DS.body(10 * s))
                    .foregroundStyle(DS.neutral700)
                    .offset(x: 14 * s, y: 18 * s)
                Text(gear)
                    .font(DS.heading(104 * s))
                    .foregroundStyle(DS.text)
                    .fixedSize()
                    .position(x: 201 * s, y: 150 * s)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(speedText).font(DS.headingBold(40 * s)).monospacedDigit()
                    Text(speedUnit).font(DS.body(12 * s)).foregroundStyle(DS.neutral800)
                }
                .frame(width: geo.size.width - 18 * s, alignment: .trailing)
                .offset(y: 80 * s)
                figure("rpm", rpmText, color: rpmColor, alignment: .leading)
                    .offset(x: 16 * s, y: 190 * s)
                figure("Peak", peakText, color: DS.text, alignment: .trailing)
                    .frame(width: geo.size.width - 16 * s, alignment: .trailing)
                    .offset(y: 190 * s)
            }
        }
        .aspectRatio(402.0 / 236.0, contentMode: .fit)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Engine speed \(rpmText) rpm, gear \(gear), speed \(speedText) \(speedUnit)")
    }

    private func figure(_ label: String, _ value: String, color: Color, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            Kicker(text: label)
            Text(value)
                .font(DS.headingBold(22))
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }

    private func draw(_ ctx: inout GraphicsContext, hexOpacity: Double) {
        let accent = DS.accent

        // red glow under the gear: radial gradient from the bottom centre of the ellipse
        var glow = ctx
        glow.translateBy(x: 201, y: 274)
        glow.scaleBy(x: 1, y: 92.0 / 190.0)
        glow.fill(Path(ellipseIn: CGRect(x: -190, y: -380, width: 380, height: 380)),
                  with: .radialGradient(Gradient(stops: [
                    .init(color: accent.opacity(0.85), location: 0),
                    .init(color: accent.opacity(0.25), location: 0.55),
                    .init(color: accent.opacity(0), location: 1),
                  ]), center: .zero, startRadius: 0, endRadius: 228))

        let arc = TypeRGeometry.arc
        ctx.stroke(arc, with: .color(DS.neutral300), lineWidth: 22)
        ctx.stroke(arc.applying(CGAffineTransform(translationX: 0, y: -12)), with: .color(DS.neutral700), lineWidth: 1)

        let filled = arc.trimmedPath(from: 0, to: TypeRGeometry.fraction(forRPM: rpm))
        ctx.stroke(filled, with: .color(DS.text), lineWidth: 23)
        ctx.stroke(filled, with: .linearGradient(Gradient(stops: [
            .init(color: Color(hex: 0xE8001F), location: 0),
            .init(color: Color(hex: 0xFF7A1A), location: 0.45),
            .init(color: Color(hex: 0xFFD21F), location: 1),
        ]), startPoint: CGPoint(x: 22, y: 0), endPoint: CGPoint(x: 300, y: 0)), lineWidth: 18)

        // hexagon shift block from 7000 rpm to the end of the bar
        var hex = ctx
        hex.opacity = hexOpacity
        let block = CGRect(x: TypeRGeometry.hexX, y: 29, width: 384 - TypeRGeometry.hexX, height: 22)
        hex.clip(to: Path(block))
        hex.fill(TypeRGeometry.hexPattern(covering: block), with: .color(Color(hex: 0xFF5A3C)))

        var base = Path()
        base.move(to: CGPoint(x: 0, y: 178))
        base.addLine(to: CGPoint(x: 118, y: 178))
        base.addCurve(to: CGPoint(x: 182, y: 216), control1: CGPoint(x: 150, y: 178), control2: CGPoint(x: 148, y: 216))
        base.addLine(to: CGPoint(x: 220, y: 216))
        base.addCurve(to: CGPoint(x: 284, y: 178), control1: CGPoint(x: 254, y: 216), control2: CGPoint(x: 252, y: 178))
        base.addLine(to: CGPoint(x: 402, y: 178))
        ctx.stroke(base, with: .color(accent), lineWidth: 2.5)
    }
}

/// Geometry of the rev bar, ported from `trGeom()` in the design: the scale is stretched so 0–3
/// (×1000 rpm) take the curved part and 3–8 the straight part.
enum TypeRGeometry {
    static let arc: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 22, y: 150))
        p.addCurve(to: CGPoint(x: 130, y: 40), control1: CGPoint(x: 40, y: 104), control2: CGPoint(x: 70, y: 40))
        p.addLine(to: CGPoint(x: 384, y: 40))
        return p
    }()

    private static let points: [CGPoint] = {
        var pts = (0...60).map { i -> CGPoint in
            let t = Double(i) / 60, u = 1 - t
            return CGPoint(x: u * u * u * 20 + 3 * u * u * t * 40 + 3 * u * t * t * 70 + t * t * t * 130,
                           y: u * u * u * 150 + 3 * u * u * t * 104 + 3 * u * t * t * 40 + t * t * t * 40)
        }
        pts.append(CGPoint(x: 384, y: 40))
        return pts
    }()

    private static let cumulative: [Double] = {
        var cum = [0.0]
        for i in 1..<points.count {
            cum.append(cum[i - 1] + hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y))
        }
        return cum
    }()

    private static var length: Double { cumulative.last! }

    /// Point and unit normal at a fraction of the bar's length.
    private static func at(_ f: Double) -> (point: CGPoint, normal: CGVector) {
        let d = f * length
        var i = 1
        while i < cumulative.count - 1 && cumulative[i] < d { i += 1 }
        let a = points[i - 1], b = points[i], seg = cumulative[i] - cumulative[i - 1]
        let k = seg > 0 ? (d - cumulative[i - 1]) / seg : 0
        let dx = (b.x - a.x) / (seg > 0 ? seg : 1), dy = (b.y - a.y) / (seg > 0 ? seg : 1)
        return (CGPoint(x: a.x + (b.x - a.x) * k, y: a.y + (b.y - a.y) * k), CGVector(dx: -dy, dy: dx))
    }

    /// Fraction of the bar's length at `r` thousand rpm.
    static func map(_ r: Double) -> Double {
        let curved = cumulative[cumulative.count - 2]
        return r <= 3 ? (r / 3) * curved / length : (curved + (r - 3) / 5 * (length - curved)) / length
    }

    static func fraction(forRPM rpm: Double) -> Double {
        map(min(max(rpm / TypeRGauge.maxRPM, 0), 1) * 8)
    }

    struct Label { let text: String; let point: CGPoint; let redline: Bool }

    /// Scale numbers 0–8, 22 units below/outside the bar.
    static let labels: [Label] = (0...8).map { i in
        let (p, n) = at(map(Double(i)))
        return Label(text: String(i),
                     point: CGPoint(x: p.x + n.dx * 22 + (i == 0 ? 6 : 0), y: p.y + n.dy * 22 - (i == 0 ? 4 : 0)),
                     redline: i >= 7)
    }

    static let hexX: Double = at(map(7)).point.x

    /// The design's 7.8 × 13.5 hexagon tile, repeated over `rect` from the origin.
    static func hexPattern(covering rect: CGRect) -> Path {
        let tile: [[CGPoint]] = [
            [(3.9, 0.6), (7.2, 2.5), (7.2, 6.3), (3.9, 8.2), (0.6, 6.3), (0.6, 2.5)],
            [(0, 7.35), (3.3, 9.25), (3.3, 13.05), (0, 14.95), (-3.3, 13.05), (-3.3, 9.25)],
            [(7.8, 7.35), (11.1, 9.25), (11.1, 13.05), (7.8, 14.95), (4.5, 13.05), (4.5, 9.25)],
        ].map { $0.map { CGPoint(x: $0.0, y: $0.1) } }
        var path = Path()
        var y = (rect.minY / 13.5).rounded(.down) * 13.5 - 13.5
        while y < rect.maxY {
            var x = (rect.minX / 7.8).rounded(.down) * 7.8 - 7.8
            while x < rect.maxX {
                for poly in tile { path.addLines(poly.map { CGPoint(x: $0.x + x, y: $0.y + y) }); path.closeSubpath() }
                x += 7.8
            }
            y += 13.5
        }
        return path
    }
}
