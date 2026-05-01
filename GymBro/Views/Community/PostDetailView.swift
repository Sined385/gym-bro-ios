//
//  PostDetailView.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-03.
//

import SwiftUI

struct PostDetailView: View {
    let postId: String
    @StateObject private var viewModel: PostDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var shareURL: URL?
    @State private var newComment: String = ""
    @State private var reportTarget: (contentType: String, contentId: String)?
    @State private var blockTarget: (userId: String, userName: String)?

    init(postId: String) {
        self.postId = postId
        _viewModel = StateObject(wrappedValue: PostDetailViewModel(
            postId: postId,
            networkService: DependencyContainer.shared.resolve(NetworkServiceProtocol.self)
        ))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.gymBroPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                    } else if let post = viewModel.post {
                        PostCardView(
                            post: post,
                            onReaction: { emoji in viewModel.toggleReaction(emoji: emoji) },
                            onComment: { },
                            onUserTap: { _ in },
                            onFollow: post.isOwnPost ? nil : {
                                viewModel.toggleFollow()
                            },
                            onDelete: post.isOwnPost ? {
                                Task {
                                    if await viewModel.deletePost() {
                                        dismiss()
                                    }
                                }
                            } : nil,
                            onReport: post.isOwnPost ? nil : {
                                reportTarget = (contentType: "post", contentId: post.id)
                            },
                            onBlockUser: post.isOwnPost ? nil : {
                                blockTarget = (userId: post.user.id, userName: post.user.fullName)
                            },
                            isCommentsExpanded: false,
                            onShare: {
                                shareURL = URL(string: "https://gyymjaam.com/p/\(postId)")
                            },
                            isWorkoutExpandedByDefault: true
                        )

                        // Comments header
                        HStack {
                            Text("Comments")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.gymBroNeutral900)
                            if let post = viewModel.post, post.commentCount > 0 {
                                Text("\(post.commentCount)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gymBroTextSecondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 8)

                        // Comments list
                        if viewModel.comments.isEmpty {
                            Text("No comments yet. Be the first!")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gymBroTextSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.comments) { comment in
                                    commentRow(comment)
                                        .contextMenu {
                                            if let post = viewModel.post, !post.isOwnPost || comment.user.id != post.user.id {
                                                Button {
                                                    reportTarget = (contentType: "comment", contentId: comment.id)
                                                } label: {
                                                    Label("Report Comment", systemImage: "flag")
                                                }
                                            }
                                        }
                                }
                            }
                            .background(Color.gymBroCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(hex: "F5F5F5"), lineWidth: 1)
                            )
                        }
                    } else if viewModel.errorMessage != nil {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 36))
                                .foregroundColor(.gymBroNeutral400)
                            Text("Could not load post.")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gymBroTextSecondary)
                            Button("Retry") {
                                Task { await viewModel.loadPost() }
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.gymBroPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    }

                    Spacer()
                        .frame(height: 80)
                }
                .padding(.horizontal, 20)
            }

            // Bottom comment input bar
            commentInputBar
        }
        .background(Color.gymBroBackground.ignoresSafeArea())
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadPost()
        }
        .sheet(isPresented: Binding(
            get: { shareURL != nil },
            set: { if !$0 { shareURL = nil } }
        )) {
            if let url = shareURL {
                ActivityViewController(activityItems: [url])
            }
        }
        .sheet(isPresented: Binding(
            get: { reportTarget != nil },
            set: { if !$0 { reportTarget = nil } }
        )) {
            if let target = reportTarget {
                ReportContentView(contentType: target.contentType, contentId: target.contentId) {
                    reportTarget = nil
                }
            }
        }
        .confirmationDialog(
            "Block \(blockTarget?.userName ?? "user")?",
            isPresented: Binding(
                get: { blockTarget != nil },
                set: { if !$0 { blockTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                if let target = blockTarget {
                    Task {
                        await viewModel.blockUser(userId: target.userId)
                        dismiss()
                    }
                }
                blockTarget = nil
            }
            Button("Cancel", role: .cancel) {
                blockTarget = nil
            }
        } message: {
            Text("You won't see their content and they won't be able to interact with you.")
        }
    }

    // MARK: - Comment Row

    private func commentRow(_ comment: PostComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(
                name: comment.user.fullName,
                avatarUrl: comment.user.avatarUrl,
                size: 32
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(comment.user.fullName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gymBroNeutral900)

                    Text(timeAgo(from: comment.createdAt))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gymBroTextSecondary)
                }

                Text(comment.content)
                    .font(.system(size: 14))
                    .foregroundColor(.gymBroTextPrimary)
                    .lineSpacing(2)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Comment Input Bar

    private var commentInputBar: some View {
        HStack(spacing: 10) {
            TextField("Add a comment...", text: $newComment)
                .font(.system(size: 15))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.gymBroPrimary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.gymBroPrimary.opacity(0.15), lineWidth: 1)
                )
                .cornerRadius(22)

            if !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    let text = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    Task { await viewModel.addComment(content: text) }
                    newComment = ""
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
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
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Color.gymBroCardBackground
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Time Ago Helper

    private func timeAgo(from isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return "" }

        let interval = Date().timeIntervalSince(date)

        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 604800 { return "\(Int(interval / 86400))d ago" }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        return dateFormatter.string(from: date)
    }
}
