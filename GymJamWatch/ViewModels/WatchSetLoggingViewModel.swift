//
//  WatchSetLoggingViewModel.swift
//  GymJamWatch
//
//  Weight/reps input and set completion from Watch.
//

import Foundation
import Combine

@MainActor
final class WatchSetLoggingViewModel: ObservableObject {

    // MARK: - Published

    @Published var weight: Double = 0
    @Published var reps: Int = 10
    @Published var isSubmitting = false
    @Published var lastCompletedWeight: Double?
    @Published var lastCompletedReps: Int?

    // MARK: - Dependencies

    private let connectivityService: PhoneConnectivityService

    // MARK: - Init

    init(connectivityService: PhoneConnectivityService) {
        self.connectivityService = connectivityService
    }

    // MARK: - Load from current set

    func loadFromSet(_ set: WatchSetState) {
        weight = set.weight ?? 0
        reps = set.reps ?? 10
    }

    func loadForRepeat(weight: Double?, reps: Int?) {
        self.weight = weight ?? 0
        self.reps = reps ?? 10
    }

    // MARK: - Adjustments

    func incrementWeight(by amount: Double = 2.5) {
        weight = max(0, weight + amount)
        WatchHaptics.digitalCrownTick()
    }

    func decrementWeight(by amount: Double = 2.5) {
        weight = max(0, weight - amount)
        WatchHaptics.digitalCrownTick()
    }

    func incrementReps() {
        reps += 1
    }

    func decrementReps() {
        reps = max(1, reps - 1)
    }

    // MARK: - Submit

    /// Ask the phone to start its cardio clock (phone is source of truth).
    /// The resulting state push flips this exercise into the recording phase
    /// on both devices.
    func startCardio(exerciseId: String) {
        connectivityService.sendStartCardio(exerciseId: exerciseId)
        WatchHaptics.setCompleted()
    }

    /// Cardio is time-based: send the recorded duration; the phone applies it
    /// via completeCardioSet (distance stays empty for watch-logged cardio).
    func completeCardio(exerciseId: String, durationSeconds: Int, distanceMeters: Int?) {
        isSubmitting = true
        connectivityService.sendCardioCompletion(
            exerciseId: exerciseId,
            durationSeconds: durationSeconds,
            distanceMeters: distanceMeters
        )
        WatchHaptics.setCompleted()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isSubmitting = false
        }
    }

    func completeSet(exerciseId: String, setId: String) {
        isSubmitting = true
        lastCompletedWeight = weight > 0 ? weight : nil
        lastCompletedReps = reps
        connectivityService.sendSetCompletion(
            exerciseId: exerciseId,
            setId: setId,
            weight: weight > 0 ? weight : nil,
            reps: reps
        )
        WatchHaptics.setCompleted()

        // Reset after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isSubmitting = false
        }
    }

    /// Append a NEW set to the exercise (no existing template row to
    /// mark complete). Used by Repeat Last when the exercise was
    /// added mid-session and only has completed sets in its history.
    /// Phone routes the empty `setId` to its `logSet` path which
    /// appends instead of looking up by id.
    func logSet(exerciseId: String, weight: Double?, reps: Int) {
        isSubmitting = true
        lastCompletedWeight = weight
        lastCompletedReps = reps
        connectivityService.sendSetCompletion(
            exerciseId: exerciseId,
            setId: "",
            weight: weight,
            reps: reps
        )
        WatchHaptics.setCompleted()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isSubmitting = false
        }
    }

    // MARK: - Display Helpers

    var weightDisplay: String {
        if weight == 0 { return "BW" }
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }
}
