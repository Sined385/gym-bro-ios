//
//  DetailTabPicker.swift
//  GymBro
//
//  Created by Claude Code on 2026-06-17.
//

import SwiftUI

/// Detail view tab — switches between live session UI and the perf graph.
enum DetailTab: String, CaseIterable, Identifiable {
    case workouts, stats
    var id: String { rawValue }
    var label: String {
        switch self {
        case .workouts: return "Workouts"
        case .stats: return "Stats"
        }
    }
}

struct DetailTabPicker: View {
    @Binding var selection: DetailTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { selection = tab }
                } label: {
                    Text(tab.label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(selection == tab ? .gymBroNeutral900 : .gymBroNeutral400)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(selection == tab ? Color.white : .clear)
                                .shadow(color: selection == tab ? .black.opacity(0.06) : .clear, radius: 2, y: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.gymBroNeutral100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
