//
//  ReportContentView.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-24.
//

import SwiftUI

struct ReportContentView: View {
    let contentType: String
    let contentId: String
    let onDismiss: () -> Void

    @State private var selectedReason: ReportReason?
    @State private var description: String = ""
    @State private var isSubmitting = false
    @State private var didSubmit = false

    private let networkService: NetworkServiceProtocol = DependencyContainer.shared.resolve(NetworkServiceProtocol.self)

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Why are you reporting this \(contentType)?")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.gymBroNeutral900)
                    .padding(.top, 8)

                VStack(spacing: 0) {
                    ForEach(ReportReason.allCases) { reason in
                        Button {
                            selectedReason = reason
                        } label: {
                            HStack {
                                Text(reason.displayName)
                                    .font(.system(size: 15))
                                    .foregroundColor(.gymBroTextPrimary)
                                Spacer()
                                Image(systemName: selectedReason == reason ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(selectedReason == reason ? .gymBroPrimary : .gymBroNeutral400)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)

                        if reason != ReportReason.allCases.last {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(Color.gymBroCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
                )

                if selectedReason == .other {
                    TextField("Tell us more (optional)", text: $description, axis: .vertical)
                        .font(.system(size: 15))
                        .lineLimit(3...6)
                        .padding(12)
                        .background(Color.gymBroCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
                        )
                }

                Spacer()

                if didSubmit {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(hex: "30C08D"))
                        Text("Report submitted. Thank you.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.gymBroNeutral900)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                } else {
                    Button {
                        Task { await submitReport() }
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Submit Report")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selectedReason != nil ? Color.gymBroPrimary : Color.gymBroNeutral400)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(selectedReason == nil || isSubmitting)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .background(Color.gymBroBackground.ignoresSafeArea())
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func submitReport() async {
        guard let reason = selectedReason else { return }
        isSubmitting = true
        let desc: String? = description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description
        let _ = try? await networkService.request(
            CommunityRouter.reportContent(
                contentType: contentType,
                contentId: contentId,
                reason: reason.rawValue,
                description: desc
            ).endpoint,
            responseType: ReportResponse.self
        )
        isSubmitting = false
        didSubmit = true
        try? await Task.sleep(for: .seconds(1))
        onDismiss()
    }
}
