import SwiftUI

/// The app's two looks. Simple is the Modernist design system; Racing is the "Type R" skin from the
/// OBD Prototype design: dark carbon ground, Saira type and a Civic Type R style rev gauge on Live.
enum Skin: String, CaseIterable {
    case simple = "Simple", racing = "Racing"

    var palette: Palette { self == .racing ? .racing : .simple }
}

/// Colour and type tokens for one skin (the design's CSS custom properties).
struct Palette {
    let bg, surface, text, accent, divider: Color
    let neutral200, neutral300, neutral500, neutral600, neutral700, neutral800, neutral900: Color
    let accent100, accent200, accent600, accent700, accent800: Color
    /// The 2px rule under the app header (`--skin-rule`).
    let headerRule: Color
    let headingFont, headingBoldFont, bodyFont: String
    /// Carbon-weave texture over the ground (`--skin-texture`).
    let textured: Bool
    let dark: Bool

    /// project/_ds/modernist-…/styles.css
    static let simple = Palette(
        bg: Color(hex: 0xF3F2F2), surface: Color(hex: 0xEAE9E9), text: Color(hex: 0x201E1D), accent: Color(hex: 0xEC3013),
        divider: Color(hex: 0x201E1D).opacity(0.4),
        neutral200: Color(hex: 0xEAE7E7), neutral300: Color(hex: 0xD7D3D3), neutral500: Color(hex: 0x9B9797), neutral600: Color(hex: 0x7D7979),
        neutral700: Color(hex: 0x605D5D), neutral800: Color(hex: 0x444141), neutral900: Color(hex: 0x2D2B2B),
        accent100: Color(hex: 0xFFF2EF), accent200: Color(hex: 0xFFE0D9), accent600: Color(hex: 0xDD2B0F), accent700: Color(hex: 0xAE1800),
        accent800: Color(hex: 0x7C1405), headerRule: Color(hex: 0x201E1D).opacity(0.4),
        headingFont: "Archivo-ExtraBold", headingBoldFont: "Archivo-ExtraBold", bodyFont: "Archivo-Regular", textured: false, dark: false)

    /// SKINS['Type R'] in OBD Prototype.dc.html
    static let racing = Palette(
        bg: Color(hex: 0x0D0D0F), surface: Color(hex: 0x18181C), text: Color(hex: 0xF5F5F6), accent: Color(hex: 0xE8001F),
        divider: Color(hex: 0x38383F),
        neutral200: Color(hex: 0x24242A), neutral300: Color(hex: 0x33333A), neutral500: Color(hex: 0x6C6C75), neutral600: Color(hex: 0x8B8B94),
        neutral700: Color(hex: 0xA9A9B1), neutral800: Color(hex: 0xD2D2D7), neutral900: Color(hex: 0x000000),
        accent100: Color(hex: 0x3B0910), accent200: Color(hex: 0x5E0E19), accent600: Color(hex: 0xFF2B44), accent700: Color(hex: 0xFF5468),
        accent800: Color(hex: 0xFFB8C1), headerRule: Color(hex: 0xE8001F),
        headingFont: "SairaCondensed-ExtraBold", headingBoldFont: "SairaCondensed-Bold", bodyFont: "Saira-Regular", textured: true, dark: true)
}

/// Design tokens of the active skin. RootView sets `skin` and rebuilds the view tree when it changes,
/// so views read these directly.
enum DS {
    private(set) static var skin: Skin = .simple
    private static var p: Palette { skin.palette }

    static func use(_ skin: Skin) { self.skin = skin }

    static var bg: Color { p.bg }
    static var surface: Color { p.surface }
    static var text: Color { p.text }
    static var accent: Color { p.accent }
    static var divider: Color { p.divider }
    static var headerRule: Color { p.headerRule }

    static var neutral200: Color { p.neutral200 }
    static var neutral300: Color { p.neutral300 }
    static var neutral500: Color { p.neutral500 }
    static var neutral600: Color { p.neutral600 }
    static var neutral700: Color { p.neutral700 }
    static var neutral800: Color { p.neutral800 }
    static var neutral900: Color { p.neutral900 }

    static var accent100: Color { p.accent100 }
    static var accent200: Color { p.accent200 }
    static var accent600: Color { p.accent600 }
    static var accent700: Color { p.accent700 }
    static var accent800: Color { p.accent800 }

    /// Headings, numbers and button labels (Archivo ExtraBold / Saira Condensed ExtraBold).
    static func heading(_ size: CGFloat) -> Font { .custom(p.headingFont, fixedSize: size) }
    /// The 700 weight the Racing gauge uses for its scale, speed and rpm figures.
    static func headingBold(_ size: CGFloat) -> Font { .custom(p.headingBoldFont, fixedSize: size) }
    static func body(_ size: CGFloat) -> Font { .custom(p.bodyFont, fixedSize: size) }
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight, design: .monospaced) }
}

/// The Racing skin's carbon weave: 2px stripes at ±45°, every 4px, in 2.5% white.
struct CarbonTexture: View {
    var body: some View {
        Canvas { ctx, size in
            let span = size.width + size.height
            for angle in [45.0, -45.0] {
                var c = ctx
                c.translateBy(x: size.width / 2, y: size.height / 2)
                c.rotate(by: .degrees(angle))
                var x = -span
                var stripes = Path()
                while x < span {
                    stripes.addRect(CGRect(x: x, y: -span, width: 2, height: span * 2))
                    x += 4
                }
                c.fill(stripes, with: .color(.white.opacity(0.025)))
            }
        }
        .allowsHitTesting(false)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// Small uppercase label used above values (10px, 0.08em tracking).
struct Kicker: View {
    let text: String
    var color: Color = DS.neutral700
    var size: CGFloat = 10
    var tracking: CGFloat = 0.08

    var body: some View {
        Text(text.uppercased())
            .font(DS.body(size))
            .tracking(size * tracking)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

/// Full-width rule: 2px between major sections, 1px between rows.
struct Rule: View {
    var weight: CGFloat = 2
    var color: Color = DS.divider
    var body: some View { color.frame(height: weight) }
}

/// Flat, flush-left button with the design system's pressed tint.
struct FlatButtonStyle: ButtonStyle {
    var background: Color = .clear
    var pressed: Color = DS.text.opacity(0.1)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(configuration.isPressed ? pressed : background)
            .contentShape(Rectangle())
    }
}

/// Solid accent action ("Scan for loggers", "Clear codes").
struct PrimaryButtonStyle: ButtonStyle {
    var minHeight: CGFloat = 52
    var fontSize: CGFloat = 16

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.heading(fontSize))
            .foregroundStyle(DS.bg)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(configuration.isPressed ? DS.accent700 : DS.accent)
            .contentShape(Rectangle())
    }
}

/// Outlined action ("Use demo data", "Cancel").
struct SecondaryButtonStyle: ButtonStyle {
    var minHeight: CGFloat = 48
    var fontSize: CGFloat = 15

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.heading(fontSize))
            .foregroundStyle(DS.text)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(configuration.isPressed ? DS.text.opacity(0.14) : .clear)
            .overlay(Rectangle().strokeBorder(DS.divider, lineWidth: 1))
            .contentShape(Rectangle())
    }
}

/// Small tinted status tag (11px, 3/10 padding).
struct Tag: View {
    let text: String
    let background: Color
    let foreground: Color
    var body: some View {
        Text(text)
            .font(DS.body(11))
            .tracking(0.44)
            .padding(.vertical, 3)
            .padding(.horizontal, 10)
            .background(background)
            .foregroundStyle(foreground)
    }
}
