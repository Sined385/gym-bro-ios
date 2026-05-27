//
//  AboutYouEditorView.swift
//  GymBro
//
//  Sheet-presented editor for the AI coach context note. Reuses the same
//  `AboutYouField` component as the onboarding step.
//

import SwiftUI

struct AboutYouEditorView: View {
    @ObservedObject var viewModel: SettingsViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    descriptionBlock

                    AboutYouField(text: $draft)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color.gymBroBackground.ignoresSafeArea())
            .navigationTitle("About You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.gymBroNeutral900)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task { await viewModel.updateAiCoachContext(draft) }
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.gymBroPrimary)
                }
            }
            .onAppear { draft = viewModel.aiCoachContext }
        }
    }

    private var descriptionBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Personal context for the AI")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.gymBroNeutral900)
            Text("This note gets added to every plan and coach reply. Mention injuries, exercises you love or hate, equipment quirks — anything the AI should always keep in mind.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gymBroTextSecondary)
                .lineSpacing(2)
        }
    }
}
