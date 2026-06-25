//
//  ProfilePostsGrid.swift
//  GymBro
//
//  Instagram-style posts grid for the profile "Posts" tab, plus the popover
//  feed that lifts over the profile when a tile is tapped.
//

import SwiftUI

// MARK: - Shared source

/// Drives the posts grid + full-screen feed. Both UserProfileViewModel and
/// MyProfileViewModel conform, so the same UI serves either profile.
@MainActor
protocol ProfilePostsSource: ObservableObject {
    var posts: [CommunityPost] { get }
    var filteredPosts: [CommunityPost] { get }
    var postFilter: PostFilter { get set }
    var isLoadingPosts: Bool { get }
    var expandedComments: Set<String> { get }
    var commentsMap: [String: [PostComment]] { get }
    /// True only on the viewer's own profile — enables post deletion in the feed.
    var canDeletePosts: Bool { get }
    func loadMorePosts() async
    func toggleReaction(postId: String, emoji: String)
    func toggleComments(postId: String)
    func addComment(postId: String, content: String) async
    func deletePost(_ id: String) async
}

// MARK: - Grid

struct ProfilePostsGrid<VM: ProfilePostsSource>: View {
    @ObservedObject var viewModel: VM
    let onSelect: (String) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 3)

    var body: some View {
        VStack(spacing: 10) {
            // Filter chips
            HStack(spacing: 6) {
                ForEach(PostFilter.allCases) { filter in
                    let isSel = viewModel.postFilter == filter
                    Button {
                        viewModel.postFilter = filter
                    } label: {
                        Text(filter.title)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(isSel ? .white : .gymBroNeutral600)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Capsule().fill(isSel ? Color(hex: "2D3240") : Color.gymBroNeutral100))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            let posts = viewModel.filteredPosts
            if posts.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(posts) { post in
                        PostTile(post: post)
                            .onTapGesture { onSelect(post.id) }
                            .onAppear {
                                if post.id == viewModel.posts.last?.id {
                                    Task { await viewModel.loadMorePosts() }
                                }
                            }
                    }
                }
                if viewModel.isLoadingPosts {
                    ProgressView().tint(.gymBroPrimary).padding(.vertical, 12)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 30))
                .foregroundColor(.gymBroNeutral400)
            Text("No posts yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gymBroTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }
}

// MARK: - Tile

struct PostTile: View {
    let post: CommunityPost

    var body: some View {
        // Color.clear fit to 1:1 forces every cell to an identical square sized
        // to the column width; content fills it via overlay + clip.
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay { content }
            .overlay(alignment: .bottomLeading) {
                if let count = post.reactionCount, count > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "heart.fill").font(.system(size: 8, weight: .bold))
                        Text("\(count)").font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color.black.opacity(0.28))
                    .clipShape(Capsule())
                    .padding(7)
                }
            }
            .clipped()
            .cornerRadius(4)
    }

    @ViewBuilder private var content: some View {
        if let photo = post.photoUrl, let url = URL(string: photo), !photo.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: Rectangle().fill(Color.gymBroNeutral100)
                }
            }
        } else if let attachment = post.workoutAttachment {
            workoutTile(attachment)
        } else {
            textTile
        }
    }

    private func workoutTile(_ attachment: WorkoutAttachment) -> some View {
        let snapshot = WorkoutSnapshot.from(attachment)
        // Mirror exactly what the post renders: its share-card background when
        // the post has one, otherwise the same "paper" default the card falls
        // back to (PostCardView uses ShareConfig.defaultConfig) — never a flat gray.
        let background = post.shareConfig?.background ?? .preset(.paper)
        let dark = background.prefersDarkContent
        let textColor: Color = dark ? .gymBroNeutral900 : .white
        let subColor: Color = dark ? .gymBroTextSecondary : .white.opacity(0.7)
        return ZStack {
            if let photoURL = background.photoURL {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Color.gymBroNeutral100
                    }
                }
                background.gradient // dark scrim for legibility over the photo
            } else {
                background.gradient
            }

            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 11))
                    .foregroundColor(textColor.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Spacer()
                Text(snapshot.formattedVolume)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(textColor)
                Text("VOLUME")
                    .font(.system(size: 8, weight: .bold)).tracking(0.5)
                    .foregroundColor(subColor)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
    }

    private var textTile: some View {
        Text(post.content)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.gymBroNeutral600)
            .lineLimit(5)
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.gymBroNeutral100)
    }
}

// MARK: - Full-screen feed

/// Instagram-style full-screen feed shown when a grid tile is tapped. Scrolls
/// the whole post list and lands on the tapped post.
struct ProfilePostsFeedView<VM: ProfilePostsSource>: View {
    @ObservedObject var viewModel: VM
    let initialPostId: String
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var shareURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.gymBroNeutral900)
                        .frame(width: 40, height: 40)
                }
                Spacer()
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
                    .lineLimit(1)
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 8)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.gymBroBorderLight).frame(height: 1) }

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.filteredPosts) { post in
                            postRow(post)
                                .id(post.id)
                                .onAppear {
                                    if post.id == viewModel.posts.last?.id {
                                        Task { await viewModel.loadMorePosts() }
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onAppear { proxy.scrollTo(initialPostId, anchor: .top) }
            }
        }
        .background(Color.gymBroBackground.ignoresSafeArea())
        .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) {
            if let url = shareURL { ActivityViewController(activityItems: [url]) }
        }
    }

    private func postRow(_ post: CommunityPost) -> some View {
        VStack(spacing: 0) {
            PostCardView(
                post: post,
                onReaction: { emoji in viewModel.toggleReaction(postId: post.id, emoji: emoji) },
                onComment: { viewModel.toggleComments(postId: post.id) },
                onUserTap: { _ in },
                onDelete: viewModel.canDeletePosts ? { Task { await viewModel.deletePost(post.id) } } : nil,
                isCommentsExpanded: viewModel.expandedComments.contains(post.id),
                onShare: { shareURL = URL(string: "\(AppEnvironment.current.shareDomain)/p/\(post.id)") }
            )
            if viewModel.expandedComments.contains(post.id) {
                CommentsSection(
                    comments: viewModel.commentsMap[post.id] ?? [],
                    onSubmit: { content in
                        Task { await viewModel.addComment(postId: post.id, content: content) }
                    },
                    onUserTap: { _ in }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .background(Color.gymBroCardBackground)
                .cornerRadius(16, corners: [.bottomLeft, .bottomRight])
                .offset(y: -8)
            }
        }
    }
}
