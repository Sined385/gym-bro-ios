//
//  CustomTextField.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import SwiftUI

/// Styled text input with focus states
struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.gymBroTextPrimary)
            .padding(.horizontal, 24)
            .frame(height: 60)
            .background(Color.white)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isFocused ? Color.gymBroPrimary : Color(hex: "EACBCB"),
                        lineWidth: 2
                    )
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 1.5, x: 0, y: 1)
            .focused($isFocused)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var name = ""
        @State private var email = ""
        @State private var filledText = "John Doe"

        var body: some View {
            VStack(spacing: 20) {
                CustomTextField(placeholder: "Enter your name", text: $name)
                CustomTextField(placeholder: "Enter your email", text: $email)
                CustomTextField(placeholder: "Filled", text: $filledText)
            }
            .padding()
            .background(Color.gymBroBackground)
        }
    }

    return PreviewWrapper()
}
