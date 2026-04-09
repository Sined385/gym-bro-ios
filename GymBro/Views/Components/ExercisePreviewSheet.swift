//
//  ExercisePreviewSheet.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-31.
//

import SwiftUI

struct ExercisePreviewSheet: View {

    let exercise: ExercisePreviewData
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ExercisePreviewViewModel = {
        DependencyContainer.shared.resolve(ExercisePreviewViewModel.self)
    }()

    @State private var showExpandedGallery = false
    @State private var expandedGalleryUrls: [URL] = []
    @State private var expandedGalleryIndex: Int = 0
    private let analytics: AnalyticsTrackingServiceProtocol = DependencyContainer.shared.resolve(AnalyticsTrackingServiceProtocol.self)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                imageCarousel
                exerciseInfo
                setsTargetCard
                previousResultsSection
            }
            .padding(.bottom, 32)
        }
        .background(Color.gymBroBackground)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .task {
            analytics.track("exercise_preview_opened", properties: ["exercise_name": exercise.name])
            if let libId = exercise.libraryExerciseId {
                await viewModel.loadData(for: libId)
            }
        }
    }

    // MARK: - Image Carousel

    private var exerciseImageURLs: [URL] {
        ExerciseImageURLBuilder.imageURLs(for: exercise.externalId)
    }

    private var imageCarousel: some View {
        ZStack(alignment: .topTrailing) {
            if exerciseImageURLs.isEmpty {
                // Placeholder
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.gymBroNeutral100)
                    .frame(height: 220)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.gymBroNeutral400)
                    )
            } else {
                TabView {
                    ForEach(exerciseImageURLs, id: \.absoluteString) { imgUrl in
                        CachedAsyncImage(url: imgUrl) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 220)
                                .clipped()
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    expandedGalleryUrls = exerciseImageURLs
                                    expandedGalleryIndex = exerciseImageURLs.firstIndex(of: imgUrl) ?? 0
                                    showExpandedGallery = true
                                }
                        } placeholder: {
                            ShimmerView()
                                .frame(height: 220)
                        } failure: {
                            RoundedRectangle(cornerRadius: 0)
                                .fill(Color.gymBroNeutral100)
                                .frame(height: 220)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 32))
                                        .foregroundColor(.gymBroNeutral400)
                                )
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: exerciseImageURLs.count > 1 ? .automatic : .never))
                .frame(height: 220)
            }

            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .padding(12)
        }
        .background(
            ExpandedGalleryView(
                urls: expandedGalleryUrls,
                initialIndex: expandedGalleryIndex,
                isPresented: $showExpandedGallery
            )
            .frame(width: 0, height: 0)
        )
    }

    // MARK: - Exercise Info

    private var exerciseInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(exercise.name)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.gymBroNeutral900)

            HStack(spacing: 8) {
                if let muscleGroup = exercise.muscleGroup {
                    Text(muscleGroup.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(hex: exercise.accentColor))
                        .clipShape(Capsule())
                }

                if let equipment = exercise.equipment {
                    Text(equipment.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(Color(hex: "525252"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.gymBroNeutral200)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Sets x Target Card

    private var setsTargetCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SETS \u{00D7} TARGET")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.1)
                .foregroundColor(.gymBroNeutral400)

            Text(exercise.setsDisplay)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.gymBroNeutral900)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gymBroNeutral100, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Previous Results

    private var previousResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gymBroNeutral400)
                Text("PREVIOUS RESULTS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.1)
                    .foregroundColor(.gymBroNeutral400)
                Spacer()
            }

            if viewModel.isLoading && viewModel.previousSessions.isEmpty {
                ShimmerView()
                    .frame(height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else if let session = viewModel.previousSessions.first {
                VStack(alignment: .leading, spacing: 8) {
                    Text(formattedSessionDate(session.sessionDate))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)

                    ForEach(session.sets) { set in
                        HStack(spacing: 0) {
                            Text("Set \(set.setNumber)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gymBroNeutral400)
                                .frame(width: 48, alignment: .leading)

                            if let w = set.weight {
                                Text("\(Int(w)) \(set.weightUnit)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gymBroNeutral900)
                                Text("  \u{00D7}  ")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gymBroNeutral400)
                            }

                            Text("\(set.reps) reps")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gymBroNeutral900)

                            Spacer()

                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "30C08D"))
                        }
                    }
                }
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gymBroNeutral100, lineWidth: 1)
                )
            } else if exercise.libraryExerciseId == nil || !viewModel.isLoading {
                Text("No previous sessions")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gymBroNeutral400)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Helpers

    private func formattedSessionDate(_ isoDate: String?) -> String {
        guard let isoDate = isoDate else { return "Previous Session" }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = isoFormatter.date(from: isoDate) ?? ISO8601DateFormatter().date(from: isoDate)
        guard let date = date else { return isoDate }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}
