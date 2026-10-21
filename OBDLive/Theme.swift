import SwiftUI

/// Modernist design-system tokens (project/_ds/modernist-…/styles.css).
enum DS {
    static let bg = Color(hex: 0xF3F2F2)
    static let surface = Color(hex: 0xEAE9E9)
    static let text = Color(hex: 0x201E1D)
    static let accent = Color(hex: 0xEC3013)
    static let divider = text.opacity(0.4)

    static let neutral200 = Color(hex: 0xEAE7E7)
    static let neutral300 = Color(hex: 0xD7D3D3)
    static let neutral500 = Color(hex: 0x9B9797)
    static let neutral600 = Color(hex: 0x7D7979)
    static let neutral700 = Color(hex: 0x605D5D)
    static let neutral800 = Color(hex: 0x444141)
    static let neutral900 = Color(hex: 0x2D2B2B)

    static let accent100 = Color(hex: 0xFFF2EF)
    static let accent200 = Color(hex: 0xFFE0D9)
    static let accent600 = Color(hex: 0xDD2B0F)
    static let accent700 = Color(hex: 0xAE1800)
    static let accent800 = Color(hex: 0x7C1405)

    /// Archivo ExtraBold — headings, numbers and button labels.
    static func heading(_ size: CGFloat) -> Font { .custom("Archivo-ExtraBold", fixedSize: size) }
    static func body(_ size: CGFloat) -> Font { .custom("Archivo-Regular", fixedSize: size) }
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight, design: .monospaced) }
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
