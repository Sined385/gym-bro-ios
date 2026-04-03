//
//  SaveTemplateSheet.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-02.
//

import SwiftUI

struct SaveTemplateSheet: View {
    let defaultName: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var templateName: String = ""

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Save Workout")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.gymBroNeutral900)
                .padding(.top, 24)

            // Name field
            TextField("Workout name", text: $templateName)
                .font(.system(size: 16))
                .padding(16)
                .background(Color(hex: "F5F5F5"))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)

            // Save button
            Button {
                let name = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                onSave(name)
                dismiss()
            } label: {
                Text("Save Workout")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [.gymBroPrimary, .gymBroPrimaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            Spacer()
        }
        .onAppear {
            templateName = defaultName
        }
        .presentationDetents([.height(220)])
    }
}
