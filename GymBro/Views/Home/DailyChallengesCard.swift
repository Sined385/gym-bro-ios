//
//  DailyChallengesCard.swift
//  GymBro
//
//  One small physical or mental wellness task per day. Server picks
//  deterministically per (user × date). Tap the checkbox to mark complete.
//

import SwiftUI

struct DailyChallengesCard: View {

    let challenge: DailyChallenge
    let onComplete: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)
                        .strikethrough(challenge.completed, color: .gymBroNeutral400)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(challenge.description)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "717182"))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                checkbox
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 10, y: 4)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.gymBroPrimary)
            Text("TODAY'S CHALLENGE")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundColor(Color(hex: "717182"))
            Spacer()
        }
    }

    // MARK: - Checkbox

    private var checkbox: some View {
        Button {
            guard !challenge.completed else { return }
            onComplete(challenge.id)
        } label: {
            Image(systemName: challenge.completed ? "checkmark.square.fill" : "square")
                .font(.system(size: 32, weight: .regular))
                .foregroundColor(challenge.completed ? .gymBroPrimary : Color(hex: "D4D4D4"))
        }
        .buttonStyle(.plain)
        .disabled(challenge.completed)
    }
}
