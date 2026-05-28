//
//  AppDataState.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-31.
//

import Foundation
import Combine

@MainActor
final class AppDataState: ObservableObject {
    @Published private(set) var reloadVersion: Int = 0

    /// Set when a workout has been fully completed on the server. MainTabView
    /// observes this and presents the (optional) post-workout share screen
    /// after the active session has already been torn down — so even if the
    /// user kills the app from the share sheet, there's no half-state to
    /// restore on next launch.
    @Published var pendingShareData: CompletedWorkoutShareData?

    /// Set when ShareEditorView successfully posts to the community. MainTabView
    /// switches to the Community tab; CommunityFeedView injects the post at
    /// the top of its list and clears the slot. This avoids the user landing
    /// back on their previous tab unsure whether the share actually went out.
    @Published var pendingFeedPost: CommunityPost?

    func triggerReload() {
        reloadVersion += 1
    }
}

/// Self-contained snapshot of a just-completed workout, used to drive the
/// share screen without holding on to the SessionFlowViewModel after teardown.
struct CompletedWorkoutShareData: Identifiable {
    let id = UUID()
    let sessionId: String
    let sessionTitle: String
    let exercises: [ActiveSessionExercise]
    let effortLevel: Int
    let energyLevel: Int
    let durationMinutes: Int?
    /// Calories burned (from session response or Apple Watch summary).
    var calories: Int? = nil
    /// Average heart rate during the workout (only set when Apple Watch was
    /// the HR source — past workouts loaded from history don't carry this).
    var avgHeartRate: Int? = nil
}
