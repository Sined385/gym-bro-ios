//
//  OnboardingViewModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import Foundation
import Combine
import HealthKit

/// ViewModel for managing onboarding flow and data collection
@MainActor
final class OnboardingViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var currentStep: OnboardingStep = .primaryGoal
    @Published var onboardingData: OnboardingData = OnboardingData()
    @Published var canContinue: Bool = false
    @Published var isSubmitting: Bool = false
    @Published var errorMessage: String?
    @Published var showCustomInput: Bool = false
    @Published var customInputText: String = ""
    @Published var weightText: String = ""
    @Published var heightText: String = ""
    @Published var healthKitLoaded: Bool = false

    // Profile fields
    @Published var displayName: String = ""
    @Published var username: String = ""
    @Published var avatarImageData: Data?
    @Published var isCheckingUsername: Bool = false
    @Published var usernameAvailable: Bool? = nil
    @Published var usernameError: String? = nil

    // MARK: - Dependencies

    private let authService: AuthServiceProtocol
    private let networkService: NetworkServiceProtocol
    private let healthKitService: HealthKitServiceProtocol

    // MARK: - Initialization

    private var cancellables = Set<AnyCancellable>()
    private var usernameCheckTask: Task<Void, Never>?

    init(authService: AuthServiceProtocol, networkService: NetworkServiceProtocol, healthKitService: HealthKitServiceProtocol) {
        self.authService = authService
        self.networkService = networkService
        self.healthKitService = healthKitService
        validateCurrentStep()

        $customInputText
            .sink { [weak self] _ in self?.validateCurrentStep() }
            .store(in: &cancellables)
    }

    // MARK: - Navigation Methods

    /// Advance to next onboarding step
    func nextStep() {
        guard canContinue else { return }

        // Commit custom sport text if active
        if currentStep == .primarySport && showCustomInput && !customInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            addCustomSport()
        }

        let currentIndex = currentStep.rawValue
        let allSteps = OnboardingStep.allCases

        // Find next step after authentication
        if let nextStepIndex = allSteps.firstIndex(where: { $0.rawValue > currentIndex }) {
            currentStep = allSteps[nextStepIndex]
            validateCurrentStep()
        }
    }

    /// Go back to previous onboarding step
    func previousStep() {
        let currentIndex = currentStep.rawValue
        let allSteps = OnboardingStep.allCases

        // Find previous step after authentication
        if let previousStepIndex = allSteps.lastIndex(where: { $0.rawValue < currentIndex && $0 != .authentication }) {
            currentStep = allSteps[previousStepIndex]
            validateCurrentStep()
        }
    }

    // MARK: - Data Selection Methods

    /// Toggle primary goal (multi-select)
    func togglePrimaryGoal(_ goal: PrimaryGoal) {
        if let index = onboardingData.primaryGoals.firstIndex(of: goal) {
            onboardingData.primaryGoals.remove(at: index)
        } else {
            onboardingData.primaryGoals.append(goal)
        }
        validateCurrentStep()
    }

    /// Toggle primary sport (multi-select)
    func togglePrimarySport(_ sport: String) {
        if let index = onboardingData.primarySports.firstIndex(of: sport) {
            onboardingData.primarySports.remove(at: index)
        } else {
            onboardingData.primarySports.append(sport)
        }
        validateCurrentStep()
    }

    /// Select experience level
    func selectExperienceLevel(_ level: ExperienceLevel) {
        onboardingData.experienceLevel = level
        validateCurrentStep()
    }

    /// Select training frequency
    func selectTrainingFrequency(_ frequency: TrainingFrequency) {
        onboardingData.trainingFrequency = frequency
        validateCurrentStep()
    }

    /// Select workout duration
    func selectWorkoutDuration(_ duration: WorkoutDuration) {
        onboardingData.workoutDuration = duration
        validateCurrentStep()
    }

    /// Select preferred rest time
    func selectRestTime(_ restTime: RestTime) {
        onboardingData.preferredRestTime = restTime
        UserDefaults.standard.set(restTime.rawValue, forKey: SettingsViewModel.restTimeKey)
        validateCurrentStep()
    }

    /// Select available equipment
    func selectEquipment(_ equipment: Equipment) {
        onboardingData.availableEquipment = equipment
        validateCurrentStep()
    }

    /// Select biological sex
    func selectBiologicalSex(_ sex: BiologicalSex) {
        onboardingData.biologicalSex = sex
        validateCurrentStep()
    }

    /// Update weight from text input
    func updateWeight(_ text: String) {
        weightText = text
        onboardingData.weightKg = Double(text)
        validateCurrentStep()
    }

    /// Update height from text input
    func updateHeight(_ text: String) {
        heightText = text
        onboardingData.heightCm = Double(text)
        validateCurrentStep()
    }

    /// Load body metrics from HealthKit
    func loadFromHealthKit() async {
        guard healthKitService.isHealthDataAvailable else { return }

        do {
            try await healthKitService.requestAuthorization()

            // Weight
            if let weightSample = try await healthKitService.fetchLatestWeight() {
                let kg = weightSample.value
                onboardingData.weightKg = kg
                weightText = "\(Int(kg))"
            }

            // Height
            if let heightSample = try await healthKitService.fetchLatestHeight() {
                let cm = heightSample.value
                onboardingData.heightCm = cm
                heightText = "\(Int(cm))"
            }

            // Biological sex
            if let hkSex = healthKitService.fetchBiologicalSex() {
                switch hkSex {
                case .male:
                    onboardingData.biologicalSex = .male
                case .female:
                    onboardingData.biologicalSex = .female
                case .other:
                    onboardingData.biologicalSex = .other
                default:
                    break
                }
            }

            // Only show "Imported from Health" if at least one value was fetched
            if onboardingData.weightKg != nil || onboardingData.heightCm != nil || onboardingData.biologicalSex != nil {
                healthKitLoaded = true
            }
            validateCurrentStep()
        } catch {
            // HealthKit not available or denied — user enters manually
        }
    }

    /// Toggle injury in the injuries array
    func toggleInjury(_ injury: InjuryType) {
        // Handle "none" selection - clear all other injuries
        if injury == .none {
            if onboardingData.injuries.contains(.none) {
                onboardingData.injuries.removeAll { $0 == .none }
            } else {
                onboardingData.injuries = [.none]
            }
        } else {
            // Remove "none" if selecting specific injury
            onboardingData.injuries.removeAll { $0 == .none }

            // Toggle the selected injury
            if let index = onboardingData.injuries.firstIndex(of: injury) {
                onboardingData.injuries.remove(at: index)
            } else {
                onboardingData.injuries.append(injury)
            }
        }

        validateCurrentStep()
    }

    /// Add custom sport using customInputText
    func addCustomSport() {
        let trimmed = customInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if !onboardingData.primarySports.contains(trimmed) {
            onboardingData.primarySports.append(trimmed)
        }
        customInputText = ""
        showCustomInput = false
        validateCurrentStep()
    }

    /// Add custom injury using customInputText
    func addCustomInjury() {
        guard !customInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let customInjury = InjuryType.custom(customInputText.trimmingCharacters(in: .whitespacesAndNewlines))

        // Remove "none" if adding custom injury
        onboardingData.injuries.removeAll { $0 == .none }

        // Add custom injury if not already present
        if !onboardingData.injuries.contains(customInjury) {
            onboardingData.injuries.append(customInjury)
        }

        customInputText = ""
        showCustomInput = false
        validateCurrentStep()
    }

    // MARK: - Profile Methods

    /// Pre-fill display name from auth provider
    func prefillFromAuth() async {
        if let user = await authService.currentUser, let name = user.fullName, !name.isEmpty {
            if displayName.isEmpty {
                displayName = name
                if username.isEmpty {
                    username = generateUsernameFromName(name)
                    debounceCheckUsername()
                }
                validateCurrentStep()
            }
        }
    }

    /// Update display name and auto-generate username
    func updateDisplayName(_ name: String) {
        displayName = name
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            username = generateUsernameFromName(name)
            debounceCheckUsername()
        }
        validateCurrentStep()
    }

    /// Update username with validation and availability check
    func updateUsername(_ newUsername: String) {
        let sanitized = newUsername.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
        username = sanitized
        usernameError = nil
        usernameAvailable = nil

        if sanitized.count < 3 {
            usernameError = sanitized.isEmpty ? nil : "Username must be at least 3 characters"
            validateCurrentStep()
            return
        }
        if sanitized.count > 30 {
            usernameError = "Username must be at most 30 characters"
            validateCurrentStep()
            return
        }

        debounceCheckUsername()
        validateCurrentStep()
    }

    /// Set avatar image data
    func setAvatarImage(_ data: Data) {
        avatarImageData = data
    }

    /// Remove selected avatar
    func removeAvatar() {
        avatarImageData = nil
    }

    private func generateUsernameFromName(_ name: String) -> String {
        name.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    private func debounceCheckUsername() {
        usernameCheckTask?.cancel()
        let currentUsername = username
        guard currentUsername.count >= 3 else { return }

        isCheckingUsername = true
        usernameCheckTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            guard !Task.isCancelled else { return }
            await checkUsernameAvailability(currentUsername)
        }
    }

    private func checkUsernameAvailability(_ username: String) async {
        do {
            let response = try await networkService.request(
                UserRouter.checkUsername(username: username).endpoint,
                responseType: UsernameCheckResponse.self
            )
            guard self.username == username else { return } // stale check
            usernameAvailable = response.available
            if !response.available {
                usernameError = "Username is already taken"
            } else {
                usernameError = nil
            }
        } catch {
            // Network error — don't block the user
            usernameAvailable = true
            usernameError = nil
        }
        isCheckingUsername = false
        validateCurrentStep()
    }

    /// Save profile to backend (avatar upload + profile update)
    private func saveProfile() async throws {
        var avatarUrl: String? = nil

        // Upload avatar if selected
        if let imageData = avatarImageData {
            let multipart = [
                MultipartFormData(
                    data: imageData,
                    name: "file",
                    fileName: "avatar.jpg",
                    mimeType: "image/jpeg"
                )
            ]
            let response = try await networkService.uploadMultipart(
                UserRouter.uploadAvatar(imageData: imageData).endpoint,
                multipartData: multipart,
                responseType: AvatarUploadResponse.self
            )
            avatarUrl = response.avatarUrl
        }

        // Update profile
        var body: [String: Any] = [
            "full_name": displayName,
            "username": username,
        ]
        if let url = avatarUrl {
            body["avatar_url"] = url
        }

        try await networkService.request(UserRouter.updateProfile(body: body).endpoint)
    }

    // MARK: - Submission

    /// Submit onboarding data to backend via API
    func submitOnboarding() async {
        guard onboardingData.isComplete else {
            errorMessage = "Please complete all required fields"
            return
        }

        isSubmitting = true
        errorMessage = nil

        do {
            // Save profile first (avatar + name + username)
            try await saveProfile()

            var completedData = onboardingData
            completedData.completedAt = Date()

            let body = completedData.toSupabaseJSON()

            try await networkService.request(OnboardingRouter.submit(body: body).endpoint)

            // Success - onboarding complete
            isSubmitting = false
        } catch {
            errorMessage = "Failed to save onboarding data: \(error.localizedDescription)"
            isSubmitting = false
        }
    }

    // MARK: - Progress Calculation

    /// Calculate progress through onboarding (0.0 to 1.0)
    func calculateProgress() -> Double {
        return currentStep.progressPercentage
    }

    // MARK: - Validation

    /// Validate current step and update canContinue
    private func validateCurrentStep() {
        switch currentStep {
        case .authentication:
            // Handled by AuthViewModel
            canContinue = false

        case .primaryGoal:
            canContinue = !onboardingData.primaryGoals.isEmpty

        case .primarySport:
            let hasPresetSport = !onboardingData.primarySports.isEmpty
            let hasCustomText = showCustomInput && !customInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            canContinue = hasPresetSport || hasCustomText

        case .experienceLevel:
            canContinue = onboardingData.experienceLevel != nil

        case .bodyMetrics:
            canContinue = onboardingData.weightKg != nil &&
                         onboardingData.heightCm != nil &&
                         onboardingData.biologicalSex != nil

        case .trainingFrequency:
            canContinue = onboardingData.trainingFrequency != nil

        case .workoutDuration:
            canContinue = onboardingData.workoutDuration != nil

        case .restTime:
            canContinue = onboardingData.preferredRestTime != nil

        case .equipment:
            canContinue = onboardingData.availableEquipment != nil

        case .injuries:
            // Injuries are optional, can always continue
            canContinue = true

        case .completeProfile:
            let hasName = !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasValidUsername = username.count >= 3 && username.count <= 30 && usernameError == nil
            let notTaken = usernameAvailable != false // allow nil (check pending) and true
            canContinue = hasName && hasValidUsername && notTaken
        }
    }

    // MARK: - Helper Methods

    /// Clear error message
    func clearError() {
        errorMessage = nil
    }

    /// Show custom input field
    func showCustomInputField() {
        showCustomInput = true
        customInputText = ""
    }

    /// Hide custom input field
    func hideCustomInputField() {
        showCustomInput = false
        customInputText = ""
    }

    /// Check if step is completed
    func isStepCompleted(_ step: OnboardingStep) -> Bool {
        switch step {
        case .authentication:
            return true // We're past auth if we're in onboarding
        case .primaryGoal:
            return !onboardingData.primaryGoals.isEmpty
        case .primarySport:
            return !onboardingData.primarySports.isEmpty
        case .experienceLevel:
            return onboardingData.experienceLevel != nil
        case .bodyMetrics:
            return onboardingData.weightKg != nil && onboardingData.heightCm != nil && onboardingData.biologicalSex != nil
        case .trainingFrequency:
            return onboardingData.trainingFrequency != nil
        case .workoutDuration:
            return onboardingData.workoutDuration != nil
        case .restTime:
            return onboardingData.preferredRestTime != nil
        case .equipment:
            return onboardingData.availableEquipment != nil
        case .injuries:
            return true // Always considered complete as it's optional
        case .completeProfile:
            return !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && username.count >= 3
        }
    }

    /// Get display name for current step progress
    func progressText() -> String {
        let current = currentStep.rawValue
        let total = OnboardingStep.allCases.count
        return "\(current) of \(total)"
    }

    /// Check if can submit (on final step with complete data)
    var canSubmit: Bool {
        return currentStep == .completeProfile && onboardingData.isComplete
    }
}
