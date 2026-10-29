import HingeAssistKit
import SwiftUI
import UIKit

/// Colour, type and shape tokens. Every colour adapts to light and dark mode.
/// Look: editorial and calm — warm paper background, ink text, serif for people's words,
/// one confident accent for the "best move".
enum Theme {
    static let background = Color(light: 0xF4F1EC, dark: 0x0A0A0C)
    static let surface = Color(light: 0xFFFFFF, dark: 0x151518)
    static let surfaceRaised = Color(light: 0xF8F6F2, dark: 0x1E1E23)
    static let stroke = Color(light: 0xE6E1D9, dark: 0x2A2A31)
    static let textPrimary = Color(light: 0x111114, dark: 0xF5F3EF)
    static let textSecondary = Color(light: 0x6E6A72, dark: 0x9C98A2)
    static let ink = Color(light: 0x111114, dark: 0xF5F3EF)
    static let inkInverse = Color(light: 0xFFFFFF, dark: 0x111114)

    static let signal = Color(light: 0xF2435A, dark: 0xFF5C70)
    static let signalDeep = Color(light: 0xB8124F, dark: 0xE0457F)
    static let like = Color(light: 0x149E55, dark: 0x34D399)
    static let maybe = Color(light: 0xD97706, dark: 0xFBBF24)
    static let skip = Color(light: 0x8E8A93, dark: 0x6B6870)

    static let signalGradient = LinearGradient(colors: [signal, signalDeep], startPoint: .topLeading, endPoint: .bottomTrailing)

    static func color(for recommendation: MatchRecommendation) -> Color {
        switch recommendation {
        case .like: like
        case .consider: maybe
        case .skip: skip
        }
    }

    static let corner: CGFloat = 24
    static let gutter: CGFloat = 16
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

extension Font {
    static let eyebrow = Font.system(size: 12, weight: .bold, design: .rounded)
    static let quote = Font.system(.title2, design: .serif).weight(.medium)
    static let message = Font.system(.title3, design: .default).weight(.semibold)
    /// Big editorial headline (names, titles).
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .serif) }
}

extension View {
    /// Soft elevation used for floating cards.
    func softShadow() -> some View {
        shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 6)
    }
}
