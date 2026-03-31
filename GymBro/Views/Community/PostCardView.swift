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
                workoutAttachmentCard(attachment)
            }

            // Photo
            if let photoUrl = post.photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .contentShape(Rectangle())
                            .onTapGesture { isPhotoExpanded = true }
                    case .failure:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gymBroNeutral100)
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gymBroNeutral400)
                            )
                    default:
                        ShimmerView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
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

    // MARK: - Workout Attachment Card

    @ViewBuilder
    private func workoutAttachmentCard(_ attachment: WorkoutAttachment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row with gradient accent
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color.gymBroPrimary, Color.gymBroPrimaryDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)

                    HStack(spacing: 4) {
                        if let duration = attachment.durationMinutes {
                            Text("\(duration) MIN")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.gymBroTextSecondary)
                        }
                        Text("\u{2022}")
                            .font(.system(size: 11))
                            .foregroundColor(.gymBroTextSecondary)
                        Text("\(attachment.exerciseCount) EXERCISE\(attachment.exerciseCount == 1 ? "" : "S")")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.gymBroTextSecondary)
                    }
                }

                Spacer()

                if let rpe = attachment.rpe {
                    Text("\(rpe)/10")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.gymBroPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gymBroPrimary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Exercise rows
            if let exercises = attachment.exercises, !exercises.isEmpty {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                    ExerciseRowView(
                        name: exercise.name,
                        sets: exercise.setsDisplay ?? "\(exercise.totalSets) \u{00D7} \(exercise.totalReps)",
                        step: exercise.stepNumber ?? (index + 1),
                        accentColor: Color(hex: exercise.accentColor ?? "#E86A75")
                    )
                }
            }
        }
        .padding(12)
        .background(Color.gymBroPrimary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gymBroPrimary.opacity(0.12), lineWidth: 1)
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
