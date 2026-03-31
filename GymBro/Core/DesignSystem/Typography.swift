//
//  Typography.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import SwiftUI

/// Design system typography matching the React design specifications
extension Font {

    // MARK: - Headers

    /// Large header - 32px, bold
    static let gymBroHeaderLarge = Font.system(size: 32, weight: .bold)

    /// Medium header - 28px, bold
    static let gymBroHeaderMedium = Font.system(size: 28, weight: .bold)

    /// Small header - 24px, bold
    static let gymBroHeaderSmall = Font.system(size: 24, weight: .bold)

    /// Section header - 20px, semibold
    static let gymBroSectionHeader = Font.system(size: 20, weight: .semibold)

    // MARK: - Body Text

    /// iOS standard body - 17px, regular
    static let gymBroBody = Font.system(size: 17, weight: .regular)

    /// iOS standard body - 17px, medium
    static let gymBroBodyMedium = Font.system(size: 17, weight: .medium)

    /// iOS standard body - 17px, semibold
    static let gymBroBodySemibold = Font.system(size: 17, weight: .semibold)

    /// iOS standard body - 17px, bold
    static let gymBroBodyBold = Font.system(size: 17, weight: .bold)

    // MARK: - Secondary Text

    /// Secondary text - 16px, regular
    static let gymBroSecondary = Font.system(size: 16, weight: .regular)

    /// Secondary text - 16px, medium
    static let gymBroSecondaryMedium = Font.system(size: 16, weight: .medium)

    /// Secondary text - 16px, semibold
    static let gymBroSecondarySemibold = Font.system(size: 16, weight: .semibold)

    // MARK: - Small Text

    /// Small text - 14px, regular
    static let gymBroSmall = Font.system(size: 14, weight: .regular)

    /// Small text - 14px, medium
    static let gymBroSmallMedium = Font.system(size: 14, weight: .medium)

    /// Small text - 14px, semibold
    static let gymBroSmallSemibold = Font.system(size: 14, weight: .semibold)

    // MARK: - Caption

    /// Caption text - 12px, regular
    static let gymBroCaption = Font.system(size: 12, weight: .regular)

    /// Caption text - 12px, medium
    static let gymBroCaptionMedium = Font.system(size: 12, weight: .medium)

    /// Caption text - 12px, semibold
    static let gymBroCaptionSemibold = Font.system(size: 12, weight: .semibold)

    // MARK: - Buttons

    /// Primary button text - 17px, semibold
    static let gymBroButton = Font.system(size: 17, weight: .semibold)

    /// Secondary button text - 16px, semibold
    static let gymBroButtonSecondary = Font.system(size: 16, weight: .semibold)

    /// Small button text - 14px, semibold
    static let gymBroButtonSmall = Font.system(size: 14, weight: .semibold)

    // MARK: - Special

    /// Extra large display - 36px, black (900)
    static let gymBroDisplayLarge = Font.system(size: 36, weight: .black)

    /// Large display - 32px, black (900)
    static let gymBroDisplay = Font.system(size: 32, weight: .black)

    /// Numeric display - 28px, bold (for workout stats)
    static let gymBroNumeric = Font.system(size: 28, weight: .bold)

    /// Large numeric display - 36px, bold (for workout stats)
    static let gymBroNumericLarge = Font.system(size: 36, weight: .bold)

    // MARK: - Input Fields

    /// Input field text - 17px, regular
    static let gymBroInput = Font.system(size: 17, weight: .regular)

    /// Input field placeholder - 17px, regular
    static let gymBroInputPlaceholder = Font.system(size: 17, weight: .regular)

    /// Input field label - 14px, medium
    static let gymBroInputLabel = Font.system(size: 14, weight: .medium)
}

// MARK: - Text Styles

extension View {

    /// Apply header large style
    func headerLarge() -> some View {
        self
            .font(.gymBroHeaderLarge)
            .foregroundColor(.gymBroTextPrimary)
    }

    /// Apply header medium style
    func headerMedium() -> some View {
        self
            .font(.gymBroHeaderMedium)
            .foregroundColor(.gymBroTextPrimary)
    }

    /// Apply header small style
    func headerSmall() -> some View {
        self
            .font(.gymBroHeaderSmall)
            .foregroundColor(.gymBroTextPrimary)
    }

    /// Apply section header style
    func sectionHeader() -> some View {
        self
            .font(.gymBroSectionHeader)
            .foregroundColor(.gymBroTextPrimary)
    }

    /// Apply body text style
    func bodyText() -> some View {
        self
            .font(.gymBroBody)
            .foregroundColor(.gymBroTextPrimary)
    }

    /// Apply secondary text style
    func secondaryText() -> some View {
        self
            .font(.gymBroSecondary)
            .foregroundColor(.gymBroTextSecondary)
    }

    /// Apply caption text style
    func captionText() -> some View {
        self
            .font(.gymBroCaption)
            .foregroundColor(.gymBroTextSecondary)
    }

    /// Apply display large style
    func displayLarge() -> some View {
        self
            .font(.gymBroDisplayLarge)
            .foregroundColor(.gymBroTextPrimary)
    }

    /// Apply numeric display style
    func numericText() -> some View {
        self
            .font(.gymBroNumeric)
            .foregroundColor(.gymBroTextPrimary)
    }
}

// MARK: - Line Height and Spacing

extension Text {

    /// Apply line spacing for body text (1.5x)
    func bodyLineSpacing() -> some View {
        self.lineSpacing(8)
    }

    /// Apply line spacing for headers (1.2x)
    func headerLineSpacing() -> some View {
        self.lineSpacing(4)
    }

    /// Apply letter spacing for headers
    func headerLetterSpacing() -> some View {
        self.tracking(-0.5)
    }

    /// Apply letter spacing for buttons (slightly increased)
    func buttonLetterSpacing() -> some View {
        self.tracking(0.3)
    }
}
