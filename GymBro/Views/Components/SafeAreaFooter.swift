//
//  SafeAreaFooter.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import SwiftUI

/// Liquid glass effect footer fixed to bottom with backdrop blur
struct SafeAreaFooter<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top border
            Rectangle()
                .fill(Color.white.opacity(0.4))
                .frame(height: 1)

            // Content
            content()
                .padding(.horizontal, 24)
                .padding(.top, 25)
                .padding(.bottom, 8)
        }
        .background(
            Color.white.opacity(0.8)
                .background(.ultraThinMaterial)
        )
        .gymBroUpwardShadow()
    }
}

#Preview {
    ZStack {
        // Simulated content
        ScrollView {
            VStack(spacing: 20) {
                ForEach(0..<10) { index in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gymBroNeutral200)
                        .frame(height: 100)
                }
            }
            .padding()
            .padding(.bottom, 120) // Space for footer
        }
        .background(Color.gymBroBackground)

        // Footer
        VStack {
            Spacer()

            SafeAreaFooter {
                GradientButton(title: "Continue") {
                    print("Tapped")
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
