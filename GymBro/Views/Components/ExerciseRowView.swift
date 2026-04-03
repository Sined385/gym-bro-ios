//
//  ExerciseRowView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-23.
//

import SwiftUI

struct ExerciseRowView: View {
    let name: String
    let sets: String
    let step: Int
    let accentColor: Color
    var imageUrl: String? = nil
    var showChevron: Bool = true

    var body: some View {
        HStack(spacing: 16) {
            // Colored accent bar
            RoundedRectangle(cornerRadius: 100)
                .fill(accentColor)
                .frame(width: 6, height: 56)

            // Exercise image
            exerciseImage

            // Exercise info
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
                    .lineLimit(1)
                    .tracking(-0.3)

                if !sets.isEmpty {
                    Text(sets.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.6)
                        .foregroundColor(Color(hex: "737373"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2.5)
                        .background(Color(hex: "F5F5F5"))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Spacer()

            if showChevron {
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "D4D4D4"))
            }
        }
        .padding(.horizontal, 21)
        .padding(.vertical, 1)
        .frame(minHeight: 72)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder
    private var exerciseImage: some View {
        if let imageUrl, let url = URL(string: imageUrl) {
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                exercisePlaceholder
            } failure: {
                exercisePlaceholder
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            exercisePlaceholder
        }
    }

    private var exercisePlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(hex: "F5F5F5"))
            .frame(width: 56, height: 56)
            .overlay(
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "D4D4D4"))
            )
    }
}
