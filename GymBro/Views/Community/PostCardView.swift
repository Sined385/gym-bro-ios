//
//  PostCardView.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-19.
//

import SwiftUI

struct PostCardView: View {
    let post: CommunityPost
    let onLike: () -> Void
    let onComment: () -> Void
    let onUserTap: (String) -> Void
    var onFollow: (() -> Void)?
    var onDelete: (() -> Void)?
    var isCommentsExpanded: Bool = false
    var onShare: (() -> Void)?
    var isWorkoutExpandedByDefault: Bool = false

    @State private var isTextExpanded: Bool = false
    @State private var isPhotoExpanded: Bool = false

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
                    Button {
                        onFollow()
                    } label: {
                        HStack(spacing: 4) {
                            if post.isFollowingAuthor {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            Text(post.isFollowingAuthor ? "Following" : "Follow")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(post.isFollowingAuthor ? Color(hex: "30C08D") : Color(hex: "2D3240"))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                if let onDelete {
                    Menu {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Delete", systemImage: "trash")
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

            // Workout Attachment
            if let attachment = post.workoutAttachment {
                WorkoutAttachmentView(attachment: attachment, defaultExpanded: isWorkoutExpandedByDefault)
            }

            // Photo
            if let photoUrl = post.photoUrl, let url = URL(string: photoUrl) {
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

            // Like / Comment row
            HStack(spacing: 0) {
                Button {
                    onLike()
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
