//
//  SessionHistorySection.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-16.
//

import SwiftUI

// MARK: - SessionHistorySection

struct SessionHistorySection: View {

    // MARK: - Properties

    var session: SessionHistory
    var dayLabel: String

    @State private var isSharingCommunity = false
    @State private var communityShareSuccess = false
    @State private var isSharingLink = false
    @State private var shareURL: URL?

    private let networkService: NetworkServiceProtocol = DependencyContainer.shared.resolve(NetworkServiceProtocol.self)
    private let analytics: AnalyticsTrackingServiceProtocol = DependencyContainer.shared.resolve(AnalyticsTrackingServiceProtocol.self)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title
            Text("\(dayLabel)'s Session")
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.44)
                .foregroundColor(.gymBroNeutral900)

            // Stats row (Duration + Calories)
            SessionStatsRow(
                durationMinutes: session.durationMinutes,
                calories: session.calories
            )

            // Exercises completed
            ExercisesCompletedCard(exercises: session.exercises)

            // Share buttons
            shareButtons
        }
        .sheet(isPresented: Binding(
            get: { shareURL != nil },
            set: { if !$0 { shareURL = nil } }
        )) {
            if let url = shareURL {
                ActivityViewController(activityItems: [url])
            }
        }
    }

    // MARK: - Share Buttons

    private var shareButtons: some View {
        HStack(spacing: 12) {
            // Share to Community
            Button {
                Task { await shareToCommunity() }
            } label: {
                HStack(spacing: 6) {
                    if isSharingCommunity {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: communityShareSuccess ? "checkmark" : "bubble.left.fill")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text(communityShareSuccess ? "Shared!" : "Post")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: communityShareSuccess
                            ? [Color(hex: "30C08D"), Color(hex: "28A677")]
                            : [.gymBroPrimary, .gymBroPrimaryDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(isSharingCommunity || communityShareSuccess)

            // Share via deep link
            Button {
                Task { await shareViaLink() }
            } label: {
                HStack(spacing: 6) {
                    if isSharingLink {
                        ProgressView()
                            .tint(.gymBroPrimary)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text("Share")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.gymBroPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.gymBroPrimary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(isSharingLink)
        }
    }

    // MARK: - Actions

    private func shareToCommunity() async {
        isSharingCommunity = true

        let duration = session.durationMinutes ?? 0
        let exerciseCount = session.exercises.count
        let content = "Just completed a \(duration) minute workout with \(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")! \u{1F4AA}"

        do {
            _ = try await networkService.request(
                CommunityRouter.createPost(
                    content: content,
                    visibility: "global",
                    workoutSessionId: session.id,
                    photoUrl: nil
                ).endpoint,
                responseType: CommunityPost.self
            )
            isSharingCommunity = false
            communityShareSuccess = true
            analytics.track("workout_shared_as_post", properties: ["session_id": session.id])
        } catch {
            isSharingCommunity = false
        }
    }

    private func shareViaLink() async {
        isSharingLink = true
        do {
            // Save session(s) as template, then share it
            let ids = session.sessionIds ?? [session.id]
            let template = try await networkService.request(
                TemplateRouter.create(name: session.title, sessionIds: ids).endpoint,
                responseType: WorkoutTemplate.self
            )
            let response = try await networkService.request(
                TemplateRouter.share(templateId: template.id).endpoint,
                responseType: ShareTemplateResponse.self
            )
            isSharingLink = false
            shareURL = URL(string: response.shareUrl)
            analytics.track("workout_shared_as_link", properties: ["session_id": session.id])
        } catch {
            isSharingLink = false
        }
    }
}

// MARK: - Preview

#Preview {
    let mockSession = SessionHistory(
        id: "session-1",
        sessionIds: ["session-1"],
        title: "Upper Body Strength",
        type: "strength",
        durationMinutes: 52,
        calories: 385,
        performanceScore: 87,
        exercises: [
            HistoryExercise(
                id: "1",
                name: "Bench Press",
                muscleGroup: "Chest",
                accentColor: "E86A75",
                stepNumber: 1,
                sets: [
                    ExerciseSetData(setNumber: 1, weight: 185, weightUnit: "lbs", reps: 8),
                    ExerciseSetData(setNumber: 2, weight: 185, weightUnit: "lbs", reps: 8),
                    ExerciseSetData(setNumber: 3, weight: 195, weightUnit: "lbs", reps: 6),
                    ExerciseSetData(setNumber: 4, weight: 195, weightUnit: "lbs", reps: 7),
                ]
            ),
            HistoryExercise(
                id: "2",
                name: "Pull-ups",
                muscleGroup: "Back",
                accentColor: "30C08D",
                stepNumber: 2,
                sets: [
                    ExerciseSetData(setNumber: 1, weight: nil, weightUnit: "lbs", reps: 12),
                    ExerciseSetData(setNumber: 2, weight: nil, weightUnit: "lbs", reps: 10),
                    ExerciseSetData(setNumber: 3, weight: nil, weightUnit: "lbs", reps: 8),
                ]
            ),
            HistoryExercise(
                id: "3",
                name: "Overhead Press",
                muscleGroup: "Shoulders",
                accentColor: "7A82F6",
                stepNumber: 3,
                sets: [
                    ExerciseSetData(setNumber: 1, weight: 95, weightUnit: "lbs", reps: 10),
                    ExerciseSetData(setNumber: 2, weight: 95, weightUnit: "lbs", reps: 10),
                    ExerciseSetData(setNumber: 3, weight: 105, weightUnit: "lbs", reps: 8),
                ]
            ),
            HistoryExercise(
                id: "4",
                name: "Dumbbell Rows",
                muscleGroup: "Back",
                accentColor: "F5A623",
                stepNumber: 4,
                sets: [
                    ExerciseSetData(setNumber: 1, weight: 60, weightUnit: "lbs", reps: 10),
                    ExerciseSetData(setNumber: 2, weight: 60, weightUnit: "lbs", reps: 10),
                    ExerciseSetData(setNumber: 3, weight: 65, weightUnit: "lbs", reps: 9),
                ]
            ),
        ]
    )

    ScrollView {
        SessionHistorySection(session: mockSession, dayLabel: "Mon")
            .padding(.horizontal, 20)
    }
    .background(Color.gymBroBackground)
}
