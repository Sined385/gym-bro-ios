//
//  AvatarView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-19.
//

import SwiftUI

struct AvatarView: View {
    let name: String
    var avatarUrl: String?
    var size: CGFloat = 40

    var body: some View {
        if let urlString = avatarUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                default:
                    initialsView
                }
            }
        } else {
            initialsView
        }
    }

    private var initialsView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.gymBroPrimary, .gymBroPrimaryDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Text(initials)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(1)).uppercased()
    }
}
