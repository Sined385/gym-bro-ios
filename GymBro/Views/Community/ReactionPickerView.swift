//
//  ReactionPickerView.swift
//  GymBro
//

import SwiftUI

struct ReactionPickerView: View {
    let activeEmojis: Set<String>
    let onReaction: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ReactionEmoji.allCases, id: \.rawValue) { emoji in
                let isActive = activeEmojis.contains(emoji.rawValue)
                Button {
                    onReaction(emoji.rawValue)
                } label: {
                    Text(emoji.display)
                        .font(.system(size: 24))
                        .frame(width: 40, height: 40)
                        .background(
                            isActive
                                ? Color.gymBroPrimary.opacity(0.15)
                                : Color.clear
                        )
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: "2D3240"))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
    }
}
