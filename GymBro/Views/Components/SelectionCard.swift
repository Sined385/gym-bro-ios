//
//  SelectionCard.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import SwiftUI

/// Option selection card with selected/unselected states
struct SelectionCard: View {
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    var showCheckmark: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isSelected ? .gymBroPrimary : .gymBroNeutral600)
                        .tracking(-0.31)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.gymBroCaption)
                            .foregroundColor(.gymBroTextSecondary)
                    }
                }

                Spacer()

                if isSelected && showCheckmark {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.gymBroPrimary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .frame(height: 60)
            .background(Color.white)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? Color.gymBroPrimary : Color.gymBroNeutral100,
                        lineWidth: 2
                    )
            )
            .shadow(color: Color.black.opacity(0.1), radius: 1.5, x: 0, y: 1)
            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

/// Custom button style with scale effect on press
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Helper extension for conditional view modifiers
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SelectionCard(
            title: "Weight Loss",
            subtitle: "Burn fat and get lean",
            isSelected: false,
            onTap: {}
        )

        SelectionCard(
            title: "Muscle Gain",
            subtitle: "Build strength and size",
            isSelected: true,
            onTap: {}
        )

        SelectionCard(
            title: "Maintenance",
            isSelected: false,
            onTap: {}
        )
    }
    .padding()
    .background(Color.gymBroBackground)
}
