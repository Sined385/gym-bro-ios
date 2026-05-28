//
//  AboutYouField.swift
//  GymBro
//
//  Shared text-area component used by both the onboarding "About You"
//  step and the Settings editor sheet.
//

import SwiftUI

struct AboutYouField: View {
    @Binding var text: String
    let maxLength: Int

    init(text: Binding<String>, maxLength: Int = 500) {
        self._text = text
        self.maxLength = maxLength
    }

    var body: some View {
        textAreaCard
    }

    // MARK: - Text Area Card

    private var textAreaCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("YOUR NOTE TO THE COACH")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(Color(hex: "A1A1A1"))
                Spacer()
                Text("\(text.count) / \(maxLength)")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(Color(hex: "A1A1A1"))
                    .monospacedDigit()
            }

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("e.g. \"I have a back injury, keep deadlifts light\"")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "A1A1A1"))
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.system(size: 16))
                    .foregroundColor(.gymBroNeutral900)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 128, maxHeight: 200)
                    .onChange(of: text) { _, newValue in
                        if newValue.count > maxLength {
                            text = String(newValue.prefix(maxLength))
                        }
                    }
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.02), radius: 2, x: 0, y: 1)
    }
}
