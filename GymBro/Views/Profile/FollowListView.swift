//
//  FollowListView.swift
//  GymBro
//

import SwiftUI

struct FollowListView: View {
    @StateObject private var viewModel: FollowListViewModel

    init(initialTab: FollowListTab) {
        _viewModel = StateObject(wrappedValue: FollowListViewModel(
            initialTab: initialTab,
            networkService: DependencyContainer.shared.resolve(NetworkServiceProtocol.self),
            analyticsService: DependencyContainer.shared.resolve(AnalyticsTrackingServiceProtocol.self)
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $viewModel.selectedTab) {
                ForEach(FollowListTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                    .tint(.gymBroPrimary)
                Spacer()
            } else {
                let users = viewModel.selectedTab == .followers ? viewModel.followers : viewModel.following
                if users.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(users) { user in
                                NavigationLink(value: user.id) {
                                    userRow(user)
                                }
                                .buttonStyle(.plain)

                                Divider()
                                    .padding(.leading, 72)
                            }

                            // Load more trigger
                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .tint(.gymBroPrimary)
                                    .padding(.vertical, 16)
                            } else if !users.isEmpty {
                                Color.clear
                                    .frame(height: 1)
                                    .onAppear {
                                        Task { await viewModel.loadMore() }
                                    }
                            }
                        }
                    }
                }
            }
        }
        .background(Color.gymBroBackground.ignoresSafeArea())
        .navigationTitle(viewModel.selectedTab.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: String.self) { userId in
            UserProfileView(userId: userId)
        }
        .task {
            await viewModel.loadInitial()
        }
        .onChange(of: viewModel.selectedTab) { _, _ in
            Task { await viewModel.onTabChanged() }
        }
    }

    // MARK: - User Row

    private func userRow(_ user: FollowListUser) -> some View {
        HStack(spacing: 12) {
            AvatarView(
                name: user.fullName,
                avatarUrl: user.avatarUrl,
                size: 44
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(user.fullName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.gymBroNeutral900)

                if let username = user.username, !username.isEmpty {
                    Text("@\(username)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gymBroTextSecondary)
                }
            }

            Spacer()

            followButton(user)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Follow Button

    @ViewBuilder
    private func followButton(_ user: FollowListUser) -> some View {
        if viewModel.selectedTab == .followers {
            Button {
                viewModel.toggleFollow(userId: user.id)
            } label: {
                Text(user.isFollowing ? "Following" : "Follow")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(user.isFollowing ? Color(hex: "30C08D") : Color(hex: "2D3240"))
                    .clipShape(Capsule())
            }
        } else {
            Button {
                viewModel.toggleFollow(userId: user.id)
            } label: {
                Text("Following")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color(hex: "30C08D"))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: viewModel.selectedTab == .followers ? "person.2" : "person.badge.plus")
                .font(.system(size: 36, weight: .medium))
                .foregroundColor(.gymBroNeutral400)
            Text(viewModel.selectedTab == .followers ? "No followers yet" : "Not following anyone yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gymBroTextSecondary)
        }
    }
}
