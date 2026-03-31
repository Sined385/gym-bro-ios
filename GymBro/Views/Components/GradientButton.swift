//
//  GradientButton.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import SwiftUI

/// Primary CTA button with gradient background
struct GradientButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var cornerRadius: CGFloat = 16
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .tracking(-0.43)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                Color.gymBroPrimaryGradient
            )
            .cornerRadius(cornerRadius)
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1.0)
        .shadow(color: Color.gymBroPrimary.opacity(0.25), radius: 10, x: 0, y: 8)
    }
}

#Preview {
    VStack(spacing: 20) {
        GradientButton(title: "Continue", action: {})
        GradientButton(title: "Loading", isLoading: true, action: {})
        GradientButton(title: "Disabled", isDisabled: true, action: {})
    }
    .padding()
    .background(Color.gymBroBackground)
}
