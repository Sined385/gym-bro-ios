//
//  PhoneMockupView.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-01.
//

import SwiftUI

/// Phone preview wrapper that displays a mockup screenshot with fallback
struct PhoneMockupView: View {
    let imageName: String

    private var hasImage: Bool {
        UIImage(named: imageName) != nil
    }

    var body: some View {
        Group {
            if hasImage {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Gradient placeholder when asset is missing
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.gymBroPrimaryGradient)
                    .overlay(
                        Image(systemName: "iphone")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.white.opacity(0.6))
                    )
            }
        }
        .frame(maxHeight: 300)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
    }
}

#Preview {
    PhoneMockupView(imageName: "showcase-track")
        .padding(24)
        .background(Color.gymBroBackground)
}
