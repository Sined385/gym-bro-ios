//
//  CommentsSection.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-19.
//

import SwiftUI

struct CommentsSection: View {
    let comments: [PostComment]
    let onSubmit: (String) -> Void
    let onUserTap: (String) -> Void
    var onReportComment: ((String) -> Void)?

    @State private var newComment: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .padding(.horizontal, -16)

            // Comment list
            ForEach(comments) { comment in
                HStack(alignment: .top, spacing: 8) {
                    Button {
                        onUserTap(comment.user.id)
                    } label: {
                        AvatarView(
                            name: comment.user.fullName,
                            avatarUrl: comment.user.avatarUrl,
                            size: 28
                        )
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(comment.user.fullName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gymBroNeutral900)

                            Text(timeAgo(from: comment.createdAt))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.gymBroTextSecondary)
                        }

                        Text(comment.content)
                            .font(.system(size: 14))
                            .foregroundColor(.gymBroTextPrimary)
                    }

                    Spacer()
                }
                .contextMenu {
                    if let onReportComment {
                        Button {
                            onReportComment(comment.id)
                        } label: {
                            Label("Report Comment", systemImage: "flag")
                        }
                    }
                }
            }

            // Add comment input
            HStack(spacing: 8) {
                TextField("Add a comment...", text: $newComment)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gymBroPrimary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gymBroPrimary.opacity(0.15), lineWidth: 1)
                    )
                    .cornerRadius(20)

                if !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        let text = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return }
                        onSubmit(text)
                        newComment = ""
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.gymBroPrimary, .gymBroPrimaryDark],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func timeAgo(from isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return "" }

        let interval = Date().timeIntervalSince(date)

        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        return "\(Int(interval / 86400))d"
    }
}
