//
//  Colors.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import SwiftUI

/// Design system colors matching the React design specifications
extension Color {

    // MARK: - Primary Colors

    /// Primary accent color #E86A75
    static let gymBroPrimary = Color(hex: "E86A75")

    /// Darker accent for gradients #D65D68
    static let gymBroPrimaryDark = Color(hex: "D65D68")

    // MARK: - Neutral Colors

    /// Page background #F8F9FA
    static let gymBroBackground = Color(hex: "F8F9FA")

    /// Card/container white
    static let gymBroCardBackground = Color.white

    /// Primary text color #030213
    static let gymBroTextPrimary = Color(hex: "030213")

    /// Secondary text color #717182
    static let gymBroTextSecondary = Color(hex: "717182")

    /// Light border #ECECF0
    static let gymBroBorderLight = Color(hex: "ECECF0")

    /// Input background #F3F3F5
    static let gymBroInputBackground = Color(hex: "F3F3F5")

    /// Neutral 50 (hover states)
    static let gymBroNeutral50 = Color(hex: "FAFAFA")

    /// Neutral 100
    static let gymBroNeutral100 = Color(hex: "F5F5F5")

    /// Neutral 200
    static let gymBroNeutral200 = Color(hex: "E5E5E5")

    /// Neutral 400 (placeholders)
    static let gymBroNeutral400 = Color(hex: "A3A3A3")

    /// Neutral 600 (secondary text)
    static let gymBroNeutral600 = Color(hex: "525252")

    /// Neutral 900 (dark text)
    static let gymBroNeutral900 = Color(hex: "171717")

    // MARK: - Gradient

    /// Primary gradient (E86A75 to D65D68)
    static let gymBroPrimaryGradient = LinearGradient(
        colors: [gymBroPrimary, gymBroPrimaryDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Helper

    /// Initialize Color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
