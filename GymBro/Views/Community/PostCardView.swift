//
//  PostCardView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-19.
//

import SwiftUI

struct PostCardView: View {
    let post: CommunityPost
    let onReaction: (String) -> Void
    let onComment: () -> Void
    let onUserTap: (String) -> Void
    var onFollow: (() -> Void)?
    var onDelete: (() -> Void)?
    var onReport: (() -> Void)?
    var onBlockUser: (() -> Void)?
    var isCommentsExpanded: Bool = false
    var onShare: (() -> Void)?
    var isWorkoutExpandedByDefault: Bool = false

    @State private var isTextExpanded: Bool = false
    @State private var isPhotoExpanded: Bool = false
    @State private var showReactionPicker: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: avatar + name + follow
            HStack(spacing: 10) {
                Button {
                    onUserTap(post.user.id)
                } label: {
                    AvatarView(name: post.user.fullName, avatarUrl: post.user.avatarUrl, size: 40)
                }
                .buttonStyle(.plain)

                HStack(spacing: 6) {
                    Button {
                        onUserTap(post.user.id)
                    } label: {
                        Text(post.user.fullName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.gymBroNeutral900)
                    }
                    .buttonStyle(.plain)

                    if post.visibility == "followers" {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.gymBroTextSecondary)
                    }

                    Text("·")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gymBroNeutral400)

                    Text(timeAgo(from: post.createdAt))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gymBroTextSecondary)
                }

                Spacer()

                if let onFollow {
                    if post.isFollowingAuthor {
                        Button {
                            onFollow()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Color(hex: "30C08D"))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            onFollow()
                        } label: {
                            Text("Follow")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Color(hex: "2D3240"))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                if onDelete != nil || onReport != nil {
                    Menu {
                        if let onDelete {
                            Button(role: .destructive) {
                                onDelete()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        if let onReport {
                            Button {
                                onReport()
                            } label: {
                                Label("Report Post", systemImage: "flag")
                            }
                        }
                        if let onBlockUser {
                            Button(role: .destructive) {
                                onBlockUser()
                            } label: {
                                Label("Block User", systemImage: "person.slash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gymBroTextSecondary)
                            .frame(width: 32, height: 32)
                    }
                }
            }

            // Content text
            if post.content.count > 300 && !isTextExpanded {
                Text(String(post.content.prefix(300)) + "...")
                    .font(.system(size: 15))
                    .foregroundColor(.gymBroTextPrimary)
                    .lineSpacing(3)

                Button("Read more") {
                    isTextExpanded = true
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gymBroPrimary)
            } else {
                Text(post.content)
                    .font(.system(size: 15))
                    .foregroundColor(.gymBroTextPrimary)
                    .lineSpacing(3)
            }

            // Workout attachment → single share card (no carousel). Photo, if
            // any, renders as its own block below the card.
            if let attachment = post.workoutAttachment {
                workoutCard(attachment: attachment)
            }
            if let photoUrl = post.photoUrl, let url = URL(string: photoUrl) {
                standalonePhoto(url: url)
            }

            // Emoji reactions + add emoji row (always visible)
            HStack(spacing: 6) {
                if let emojiReactions = post.reactions?.filter({ $0.emoji != "heart" && $0.count > 0 }), !emojiReactions.isEmpty {
                    ForEach(emojiReactions) { reaction in
                        Button {
                            onReaction(reaction.emoji)
                        } label: {
                            HStack(spacing: 3) {
                                Text(ReactionEmoji(rawValue: reaction.emoji)?.display ?? reaction.emoji)
                                    .font(.system(size: 15))
                                Text("\(reaction.count)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(reaction.isReacted ? .gymBroPrimary : .gymBroNeutral600)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(reaction.isReacted ? Color.gymBroPrimary.opacity(0.10) : Color.gymBroNeutral100)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    if !emojiReactions.contains(where: { $0.isReacted }) {
                        addEmojiButton
                    }
                } else {
                    addEmojiButton
                }

                Spacer()
            }

            // Like / Comment / Share row
            HStack(spacing: 8) {
                // Like button
                Button {
                    onReaction("heart")
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: post.isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(post.isLiked ? .gymBroPrimary : .gymBroNeutral400)

                        if post.likeCount > 0 {
                            Text("\(post.likeCount)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(post.isLiked ? .gymBroPrimary : .gymBroNeutral600)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(post.isLiked ? Color.gymBroPrimary.opacity(0.08) : Color.clear)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Comment button
                Button {
                    onComment()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isCommentsExpanded ? "bubble.left.fill" : "bubble.left")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(isCommentsExpanded ? .gymBroPrimary : .gymBroNeutral400)

                        if post.commentCount > 0 {
                            Text("\(post.commentCount)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(isCommentsExpanded ? .gymBroPrimary : .gymBroNeutral600)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isCommentsExpanded ? Color.gymBroPrimary.opacity(0.08) : Color.clear)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                if let onShare {
                    Button {
                        onShare()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.gymBroNeutral400)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay {
                if showReactionPicker {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showReactionPicker = false
                            }
                        }
                }
            }
            .overlay(alignment: .topLeading) {
                if showReactionPicker {
                    ReactionPickerView(
                        activeEmojis: Set((post.reactions ?? []).filter { $0.isReacted && $0.emoji != "heart" }.map(\.emoji)),
                        onReaction: { emoji in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showReactionPicker = false
                            }
                            onReaction(emoji)
                        }
                    )
                    .transition(.scale(scale: 0.5, anchor: .bottomLeading).combined(with: .opacity))
                    .offset(y: -48)
                    .onTapGesture { }
                }
            }
        }
        .padding(16)
        .background(Color.gymBroCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "2D3240").opacity(0.10), lineWidth: 1)
        )
        .gymBroCardShadow()
    }

    // MARK: - Time Ago Helper

    private var addEmojiButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showReactionPicker.toggle()
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "face.smiling")
                    .font(.system(size: 15, weight: .medium))
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(.gymBroNeutral400)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gymBroNeutral100)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Workout share card (single piece, no carousel)

    @ViewBuilder
    private func workoutCard(attachment: WorkoutAttachment) -> some View {
        let snapshot = WorkoutSnapshot.from(attachment, authorHandle: post.user.username)
        // Server-stored config wins when present (the OP's exact composition).
        // Falls back to a synthesized default for legacy posts.
        let cardConfig = post.shareConfig ?? ShareConfig.defaultConfig(for: snapshot)
        ShareCardView(config: cardConfig, workout: snapshot)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "ECECF0"), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func standalonePhoto(url: URL) -> some View {
        CachedAsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
                .onTapGesture { isPhotoExpanded = true }
        } placeholder: {
            ShimmerView()
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } failure: {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gymBroNeutral100)
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 32))
                        .foregroundColor(.gymBroNeutral400)
                )
        }
        .background(
            ExpandedGalleryView(
                urls: [url],
                initialIndex: 0,
                isPresented: $isPhotoExpanded
            )
            .frame(width: 0, height: 0)
        )
    }

    private func timeAgo(from isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
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
