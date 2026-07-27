//
//  FeedTabPills.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-19.
//

import SwiftUI

struct FeedTabPills: View {
    @Binding var selectedTab: String
    let onTabChanged: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            tabPill(title: String(localized: "Global"), icon: "globe", tab: "global")
            tabPill(title: String(localized: "Following"), icon: "person.2", tab: "following")
            Spacer()
        }
    }

    private func tabPill(title: String, icon: String, tab: String) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            onTabChanged(tab)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .gymBroNeutral600)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color(hex: "2D3240") : Color.gymBroNeutral100)
            )
        }
        .buttonStyle(.plain)
    }
}
