//
//  Shadows.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import SwiftUI

/// Design system shadow effects matching the React design specifications
extension View {

    // MARK: - Light Shadow

    /// Light shadow for subtle elevation
    /// offset (0, 8), radius 30, opacity 0.04
    func gymBroLightShadow() -> some View {
        self.shadow(
            color: Color.black.opacity(0.04),
            radius: 30,
            x: 0,
            y: 8
        )
    }

    // MARK: - Medium Shadow

    /// Medium shadow for cards and containers
    /// offset (0, 8), radius 20, opacity 0.15
    func gymBroMediumShadow() -> some View {
        self.shadow(
            color: Color.black.opacity(0.15),
            radius: 20,
            x: 0,
            y: 8
        )
    }

    // MARK: - Primary Shadow

    /// Primary shadow for primary-colored elements
    /// offset (0, 8), radius 20, color E86A75, opacity 0.15
    func gymBroPrimaryShadow() -> some View {
        self.shadow(
            color: Color.gymBroPrimary.opacity(0.15),
            radius: 20,
            x: 0,
            y: 8
        )
    }

    // MARK: - Button Shadow

    /// Button shadow for primary buttons
    /// offset (0, 12), radius 25, color E86A75, opacity 0.35
    func gymBroButtonShadow() -> some View {
        self.shadow(
            color: Color.gymBroPrimary.opacity(0.35),
            radius: 25,
            x: 0,
            y: 12
        )
    }

    // MARK: - Card Shadow

    /// Subtle shadow for cards
    /// Matches: shadow-sm (0 1px 2px 0 rgb(0 0 0 / 0.05))
    func gymBroCardShadow() -> some View {
        self.shadow(
            color: Color.black.opacity(0.05),
            radius: 1,
            x: 0,
            y: 1
        )
    }

    // MARK: - Focus Ring

    /// Focus ring effect for inputs
    /// Matches: ring-4 ring-primary/10
    func gymBroFocusRing(isActive: Bool = true) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gymBroPrimary.opacity(0.1), lineWidth: isActive ? 4 : 0)
                .animation(.easeInOut(duration: 0.2), value: isActive)
        )
    }

    // MARK: - Upward Shadow (for footer)

    /// Upward shadow for bottom-fixed elements
    func gymBroUpwardShadow() -> some View {
        self.shadow(
            color: Color.black.opacity(0.08),
            radius: 12,
            x: 0,
            y: -4
        )
    }
}

// MARK: - Shadow View Modifiers

/// Light shadow modifier
struct LightShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.gymBroLightShadow()
    }
}

/// Medium shadow modifier
struct MediumShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.gymBroMediumShadow()
    }
}

/// Primary shadow modifier
struct PrimaryShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.gymBroPrimaryShadow()
    }
}

/// Button shadow modifier
struct ButtonShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.gymBroButtonShadow()
    }
}

/// Card shadow modifier
struct CardShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.gymBroCardShadow()
    }
}

/// Upward shadow modifier
struct UpwardShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.gymBroUpwardShadow()
    }
}

// MARK: - Convenience Extensions

extension View {
    /// Apply light shadow using modifier
    func lightShadow() -> some View {
        self.modifier(LightShadowModifier())
    }

    /// Apply medium shadow using modifier
    func mediumShadow() -> some View {
        self.modifier(MediumShadowModifier())
    }

    /// Apply primary shadow using modifier
    func primaryShadow() -> some View {
        self.modifier(PrimaryShadowModifier())
    }

    /// Apply button shadow using modifier
    func buttonShadow() -> some View {
        self.modifier(ButtonShadowModifier())
    }

    /// Apply card shadow using modifier
    func cardShadow() -> some View {
        self.modifier(CardShadowModifier())
    }

    /// Apply upward shadow using modifier
    func upwardShadow() -> some View {
        self.modifier(UpwardShadowModifier())
    }
}
