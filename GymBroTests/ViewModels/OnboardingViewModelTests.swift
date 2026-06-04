//
//  OnboardingViewModelTests.swift
//  GymBroTests
//
//  Created by Claude Code on 2026-03-12.
//

import Foundation
import Testing
@testable import GymJam

@Suite("OnboardingViewModel Tests")
@MainActor
struct OnboardingViewModelTests {

    // MARK: - Helper

    private func makeSUT(shouldFail: Bool = false) -> (OnboardingViewModel, MockAuthService, MockNetworkService) {
        let mockAuth = MockAuthService()
        mockAuth.shouldFail = shouldFail
        let mockNetwork = MockNetworkService()
        mockNetwork.shouldFail = shouldFail
        let viewModel = OnboardingViewModel(authService: mockAuth, networkService: mockNetwork)
        return (viewModel, mockAuth, mockNetwork)
    }

    // MARK: - Initialization Tests

    @Test("Should initialize with default state")
    func testInitialization() {
        let (sut, _, _) = makeSUT()

        #expect(sut.currentStep == .primaryGoal)
        #expect(sut.onboardingData.primaryGoals.isEmpty)
        #expect(sut.onboardingData.primarySports.isEmpty)
        #expect(sut.onboardingData.experienceLevel == nil)
        #expect(sut.onboardingData.trainingFrequency == nil)
        #expect(sut.onboardingData.workoutDuration == nil)
        #expect(sut.onboardingData.availableEquipment == nil)
        #expect(sut.onboardingData.injuries.isEmpty)
        #expect(!sut.canContinue)
        #expect(!sut.isSubmitting)
        #expect(sut.errorMessage == nil)
    }

    // MARK: - Primary Goal Selection Tests

    @Test("Should toggle primary goal and enable continue")
    func testTogglePrimaryGoal() {
        let (sut, _, _) = makeSUT()

        sut.togglePrimaryGoal(.buildMuscle)

        #expect(sut.onboardingData.primaryGoals.contains(.buildMuscle))
        #expect(sut.canContinue)
    }

    @Test("Should allow multiple primary goals")
    func testMultiplePrimaryGoals() {
        let (sut, _, _) = makeSUT()

        sut.togglePrimaryGoal(.buildMuscle)
        sut.togglePrimaryGoal(.loseFat)

        #expect(sut.onboardingData.primaryGoals.contains(.buildMuscle))
        #expect(sut.onboardingData.primaryGoals.contains(.loseFat))
        #expect(sut.canContinue)
    }

    @Test("Should toggle primary goal off")
    func testTogglePrimaryGoalOff() {
        let (sut, _, _) = makeSUT()

        sut.togglePrimaryGoal(.buildMuscle)
        sut.togglePrimaryGoal(.buildMuscle)

        #expect(!sut.onboardingData.primaryGoals.contains(.buildMuscle))
    }

    @Test("Should validate all primary goal options",
          arguments: PrimaryGoal.allCases)
    func testAllPrimaryGoals(goal: PrimaryGoal) {
        let (sut, _, _) = makeSUT()

        sut.togglePrimaryGoal(goal)

        #expect(sut.onboardingData.primaryGoals.contains(goal))
        #expect(sut.canContinue)
    }

    // MARK: - Primary Sport Selection Tests

    @Test("Should toggle preset sport")
    func testTogglePresetSport() {
        let (sut, _, _) = makeSUT()
        sut.currentStep = .primarySport

        sut.togglePrimarySport("Running")

        #expect(sut.onboardingData.primarySports.contains("Running"))
        #expect(sut.canContinue)
    }

    @Test("Should allow multiple sports")
    func testMultipleSports() {
        let (sut, _, _) = makeSUT()
        sut.currentStep = .primarySport

        sut.togglePrimarySport("Running")
        sut.togglePrimarySport("Cycling")

        #expect(sut.onboardingData.primarySports.contains("Running"))
        #expect(sut.onboardingData.primarySports.contains("Cycling"))
        #expect(sut.canContinue)
    }

    @Test("Should toggle sport off")
    func testToggleSportOff() {
        let (sut, _, _) = makeSUT()
        sut.currentStep = .primarySport

        sut.togglePrimarySport("Running")
        sut.togglePrimarySport("Running")

        #expect(!sut.onboardingData.primarySports.contains("Running"))
    }

    @Test("Should add custom sport via input field")
    func testAddCustomSport() {
        let (sut, _, _) = makeSUT()
        sut.currentStep = .primarySport

        sut.customInputText = "  Rock Climbing  "
        sut.addCustomSport()

        #expect(sut.onboardingData.primarySports.contains("Rock Climbing"))
        #expect(sut.customInputText.isEmpty)
        #expect(!sut.showCustomInput)
        #expect(sut.canContinue)
    }

    @Test("Should not add empty custom sport")
    func testAddEmptyCustomSport() {
        let (sut, _, _) = makeSUT()
        sut.currentStep = .primarySport

        sut.customInputText = "   "
        sut.addCustomSport()

        #expect(sut.onboardingData.primarySports.isEmpty)
    }

    // MARK: - Experience Level Tests

    @Test("Should select experience level",
          arguments: ExperienceLevel.allCases)
    func testSelectExperienceLevel(level: ExperienceLevel) {
        let (sut, _, _) = makeSUT()
        sut.currentStep = .experienceLevel

        sut.selectExperienceLevel(level)

        #expect(sut.onboardingData.experienceLevel == level)
        #expect(sut.canContinue)
    }

    // MARK: - Training Frequency Tests

    @Test("Should select training frequency",
          arguments: TrainingFrequency.allCases)
    func testSelectTrainingFrequency(frequency: TrainingFrequency) {
        let (sut, _, _) = makeSUT()
        sut.currentStep = .trainingFrequency

        sut.selectTrainingFrequency(frequency)

        #expect(sut.onboardingData.trainingFrequency == frequency)
        #expect(sut.canContinue)
    }

    @Test("Should have correct day values for frequencies")
    func testTrainingFrequencyDays() {
        #expect(TrainingFrequency.oneDay.days == 1)
        #expect(TrainingFrequency.twoDays.days == 2)
        #expect(TrainingFrequency.threeDays.days == 3)
        #expect(TrainingFrequency.fourDays.days == 4)
        #expect(TrainingFrequency.fiveDays.days == 5)
        #expect(TrainingFrequency.sixDays.days == 6)
        #expect(TrainingFrequency.sevenDays.days == 7)
    }

    // MARK: - Workout Duration Tests

    @Test("Should select workout duration",
          arguments: WorkoutDuration.allCases)
    func testSelectWorkoutDuration(duration: WorkoutDuration) {
        let (sut, _, _) = makeSUT()
        sut.currentStep = .workoutDuration

        sut.selectWorkoutDuration(duration)

        #expect(sut.onboardingData.workoutDuration == duration)
        #expect(sut.canContinue)
    }

    @Test("Should have correct minute values for durations")
    func testWorkoutDurationMinutes() {
        #expect(WorkoutDuration.thirty.minutes == 30)
        #expect(WorkoutDuration.fortyFive.minutes == 45)
        #expect(WorkoutDuration.sixty.minutes == 60)
        #expect(WorkoutDuration.ninety.minutes == 90)
    }

    // MARK: - Equipment Tests

    @Test("Should select equipment",
          arguments: Equipment.allCases)
    func testSelectEquipment(equipment: Equipment) {
        let (sut, _, _) = makeSUT()
        sut.currentStep = .equipment

        sut.selectEquipment(equipment)

        #expect(sut.onboardingData.availableEquipment == equipment)
        #expect(sut.canContinue)
    }

    // MARK: - Injury Selection Tests

    @Test("Should always allow continue on injuries step")
    func testInjuriesStepAlwaysCanContinue() {
        let (sut, _, _) = makeSUT()

        // Navigate through all steps to reach injuries
        sut.togglePrimaryGoal(.buildMuscle)
        sut.nextStep()
        sut.togglePrimarySport("Running")
        sut.nextStep()
        sut.selectExperienceLevel(.beginner)
        sut.nextStep()
        sut.selectTrainingFrequency(.threeDays)
        sut.nextStep()
        sut.selectWorkoutDuration(.thirty)
        sut.nextStep()
        sut.selectEquipment(.bodyweight)
        sut.nextStep()

        #expect(sut.currentStep == .injuries)
        #expect(sut.canContinue)
        #expect(sut.onboardingData.injuries.isEmpty)
    }

    @Test("Should toggle standard injury on")
    func testToggleInjuryOn() {
        let (sut, _, _) = makeSUT()

        sut.toggleInjury(.shoulders)

        #expect(sut.onboardingData.injuries.contains(.shoulders))
    }

    @Test("Should toggle standard injury off")
    func testToggleInjuryOff() {
        let (sut, _, _) = makeSUT()

        sut.toggleInjury(.shoulders)
        sut.toggleInjury(.shoulders)

        #expect(!sut.onboardingData.injuries.contains(.shoulders))
    }

    @Test("Should allow multiple injuries")
    func testMultipleInjuries() {
        let (sut, _, _) = makeSUT()

        sut.toggleInjury(.shoulders)
        sut.toggleInjury(.knees)
        sut.toggleInjury(.lowerBack)

        #expect(sut.onboardingData.injuries.count == 3)
        #expect(sut.onboardingData.injuries.contains(.shoulders))
        #expect(sut.onboardingData.injuries.contains(.knees))
        #expect(sut.onboardingData.injuries.contains(.lowerBack))
    }

    @Test("Should clear all injuries when selecting None")
    func testSelectNoneClearsInjuries() {
        let (sut, _, _) = makeSUT()

        sut.toggleInjury(.shoulders)
        sut.toggleInjury(.knees)
        sut.toggleInjury(.none)

        #expect(sut.onboardingData.injuries == [.none])
    }

    @Test("Should remove None when selecting specific injury")
    func testSelectInjuryRemovesNone() {
        let (sut, _, _) = makeSUT()

        sut.toggleInjury(.none)
        #expect(sut.onboardingData.injuries == [.none])

        sut.toggleInjury(.shoulders)

        #expect(!sut.onboardingData.injuries.contains(.none))
        #expect(sut.onboardingData.injuries.contains(.shoulders))
    }

    @Test("Should toggle None off")
    func testToggleNoneOff() {
        let (sut, _, _) = makeSUT()

        sut.toggleInjury(.none)
        sut.toggleInjury(.none)

        #expect(sut.onboardingData.injuries.isEmpty)
    }

    @Test("Should add custom injury")
    func testAddCustomInjury() {
        let (sut, _, _) = makeSUT()

        sut.customInputText = "Tennis elbow"
        sut.addCustomInjury()

        #expect(sut.onboardingData.injuries.contains(.custom("Tennis elbow")))
        #expect(sut.customInputText.isEmpty)
        #expect(!sut.showCustomInput)
    }

    @Test("Should not add empty custom injury")
    func testAddEmptyCustomInjury() {
        let (sut, _, _) = makeSUT()

        sut.customInputText = "  "
        sut.addCustomInjury()

        #expect(sut.onboardingData.injuries.isEmpty)
    }

    @Test("Should remove None when adding custom injury")
    func testAddCustomInjuryRemovesNone() {
        let (sut, _, _) = makeSUT()

        sut.toggleInjury(.none)
        sut.customInputText = "Tennis elbow"
        sut.addCustomInjury()

        #expect(!sut.onboardingData.injuries.contains(.none))
        #expect(sut.onboardingData.injuries.contains(.custom("Tennis elbow")))
    }

    @Test("Should not add duplicate custom injury")
    func testNoDuplicateCustomInjury() {
        let (sut, _, _) = makeSUT()

        sut.customInputText = "Tennis elbow"
        sut.addCustomInjury()
        sut.customInputText = "Tennis elbow"
        sut.addCustomInjury()

        let customCount = sut.onboardingData.injuries.filter {
            if case .custom("Tennis elbow") = $0 { return true }
            return false
        }.count
        #expect(customCount == 1)
    }

    // MARK: - Navigation Tests

    @Test("Should advance to next step")
    func testNextStep() {
        let (sut, _, _) = makeSUT()

        sut.togglePrimaryGoal(.buildMuscle)
        sut.nextStep()

        #expect(sut.currentStep == .primarySport)
    }

    @Test("Should not advance when canContinue is false")
    func testNextStepBlockedWhenCantContinue() {
        let (sut, _, _) = makeSUT()

        // No goal selected, canContinue is false
        sut.nextStep()

        #expect(sut.currentStep == .primaryGoal)
    }

    @Test("Should go back to previous step")
    func testPreviousStep() {
        let (sut, _, _) = makeSUT()

        sut.togglePrimaryGoal(.buildMuscle)
        sut.nextStep()
        #expect(sut.currentStep == .primarySport)

        sut.previousStep()
        #expect(sut.currentStep == .primaryGoal)
    }

    @Test("Should not go back past primaryGoal")
    func testPreviousStepAtFirstStep() {
        let (sut, _, _) = makeSUT()

        sut.previousStep()

        #expect(sut.currentStep == .primaryGoal)
    }

    @Test("Should navigate through full flow")
    func testFullNavigationFlow() {
        let (sut, _, _) = makeSUT()

        sut.togglePrimaryGoal(.buildMuscle)
        sut.nextStep()
        #expect(sut.currentStep == .primarySport)

        sut.togglePrimarySport("Running")
        sut.nextStep()
        #expect(sut.currentStep == .experienceLevel)

        sut.selectExperienceLevel(.intermediate)
        sut.nextStep()
        #expect(sut.currentStep == .trainingFrequency)

        sut.selectTrainingFrequency(.fourDays)
        sut.nextStep()
        #expect(sut.currentStep == .workoutDuration)

        sut.selectWorkoutDuration(.sixty)
        sut.nextStep()
        #expect(sut.currentStep == .equipment)

        sut.selectEquipment(.fullGym)
        sut.nextStep()
        #expect(sut.currentStep == .injuries)
    }

    // MARK: - Progress Tests

    @Test("Should calculate progress correctly")
    func testProgressCalculation() {
        let (sut, _, _) = makeSUT()

        // Step 2 of 8 = 0.25
        #expect(sut.calculateProgress() == 2.0 / 8.0)

        sut.togglePrimaryGoal(.buildMuscle)
        sut.nextStep()
        // Step 3 of 8 = 0.375
        #expect(sut.calculateProgress() == 3.0 / 8.0)
    }

    @Test("Should show correct progress text")
    func testProgressText() {
        let (sut, _, _) = makeSUT()

        #expect(sut.progressText() == "2 of 8")

        sut.togglePrimaryGoal(.buildMuscle)
        sut.nextStep()
        #expect(sut.progressText() == "3 of 8")
    }

    // MARK: - Step Completion Tests

    @Test("Should report step completion correctly")
    func testIsStepCompleted() {
        let (sut, _, _) = makeSUT()

        #expect(sut.isStepCompleted(.authentication))
        #expect(!sut.isStepCompleted(.primaryGoal))
        #expect(sut.isStepCompleted(.injuries))

        sut.togglePrimaryGoal(.buildMuscle)
        #expect(sut.isStepCompleted(.primaryGoal))
        #expect(!sut.isStepCompleted(.primarySport))
    }

    // MARK: - Completeness Tests

    @Test("Should report incomplete when missing fields")
    func testIncompleteData() {
        let (sut, _, _) = makeSUT()

        sut.togglePrimaryGoal(.buildMuscle)
        sut.togglePrimarySport("Running")

        #expect(!sut.onboardingData.isComplete)
        #expect(!sut.canSubmit)
    }

    @Test("Should report complete when all required fields set")
    func testCompleteData() {
        let (sut, _, _) = makeSUT()

        sut.togglePrimaryGoal(.buildMuscle)
        sut.togglePrimarySport("Running")
        sut.selectExperienceLevel(.intermediate)
        sut.selectTrainingFrequency(.fourDays)
        sut.selectWorkoutDuration(.sixty)
        sut.selectEquipment(.fullGym)

        #expect(sut.onboardingData.isComplete)
    }

    @Test("Should be complete without injuries")
    func testCompleteWithoutInjuries() {
        let (sut, _, _) = makeSUT()

        sut.togglePrimaryGoal(.buildMuscle)
        sut.togglePrimarySport("Running")
        sut.selectExperienceLevel(.beginner)
        sut.selectTrainingFrequency(.threeDays)
        sut.selectWorkoutDuration(.thirty)
        sut.selectEquipment(.bodyweight)

        #expect(sut.onboardingData.isComplete)
        #expect(sut.onboardingData.injuries.isEmpty)
    }

    @Test("canSubmit should be true only on injuries step with complete data")
    func testCanSubmit() {
        let (sut, _, _) = makeSUT()

        // Fill all data but stay on primaryGoal step
        sut.togglePrimaryGoal(.buildMuscle)
        sut.togglePrimarySport("Running")
        sut.selectExperienceLevel(.intermediate)
        sut.selectTrainingFrequency(.fourDays)
        sut.selectWorkoutDuration(.sixty)
        sut.selectEquipment(.fullGym)

        #expect(!sut.canSubmit) // Not on injuries step

        // Navigate to injuries step
        sut.currentStep = .injuries
        #expect(sut.canSubmit)
    }

    // MARK: - Submission Tests

    @Test("Should submit onboarding data successfully")
    func testSubmitOnboarding() async {
        let (sut, _, mockNetwork) = makeSUT()

        sut.togglePrimaryGoal(.buildMuscle)
        sut.togglePrimarySport("Gym / Weightlifting")
        sut.selectExperienceLevel(.advanced)
        sut.selectTrainingFrequency(.fiveDays)
        sut.selectWorkoutDuration(.ninety)
        sut.selectEquipment(.fullGym)
        sut.toggleInjury(.shoulders)

        await sut.submitOnboarding()

        #expect(mockNetwork.requestCallCount == 1)
        #expect(mockNetwork.lastEndpoint?.path == "/api/v1/onboarding")
        #expect(mockNetwork.lastEndpoint?.method == .put)
        #expect(!sut.isSubmitting)
        #expect(sut.errorMessage == nil)
    }

    @Test("Should set completedAt on submission")
    func testSubmitSetsCompletedAt() async {
        let (sut, _, mockNetwork) = makeSUT()

        sut.togglePrimaryGoal(.buildMuscle)
        sut.togglePrimarySport("Running")
        sut.selectExperienceLevel(.beginner)
        sut.selectTrainingFrequency(.threeDays)
        sut.selectWorkoutDuration(.fortyFive)
        sut.selectEquipment(.bodyweight)

        await sut.submitOnboarding()

        #expect(mockNetwork.requestCallCount == 1)
        // Verify completed_at is included in the request parameters
        let params = mockNetwork.lastEndpoint?.parameters
        #expect(params?["completed_at"] != nil)
    }

    @Test("Should show error when submitting incomplete data")
    func testSubmitIncompleteData() async {
        let (sut, _, mockNetwork) = makeSUT()

        sut.togglePrimaryGoal(.buildMuscle)
        // Missing other required fields

        await sut.submitOnboarding()

        #expect(mockNetwork.requestCallCount == 0)
        #expect(sut.errorMessage == "Please complete all required fields")
    }

    @Test("Should handle submission failure")
    func testSubmitFailure() async {
        let (sut, _, _) = makeSUT(shouldFail: true)

        sut.togglePrimaryGoal(.buildMuscle)
        sut.togglePrimarySport("Running")
        sut.selectExperienceLevel(.beginner)
        sut.selectTrainingFrequency(.threeDays)
        sut.selectWorkoutDuration(.thirty)
        sut.selectEquipment(.bodyweight)

        await sut.submitOnboarding()

        #expect(sut.errorMessage != nil)
        #expect(!sut.isSubmitting)
    }

    // MARK: - Custom Input UI State Tests

    @Test("Should show and hide custom input field")
    func testCustomInputFieldToggle() {
        let (sut, _, _) = makeSUT()

        sut.showCustomInputField()
        #expect(sut.showCustomInput)
        #expect(sut.customInputText.isEmpty)

        sut.customInputText = "Some text"
        sut.hideCustomInputField()
        #expect(!sut.showCustomInput)
        #expect(sut.customInputText.isEmpty)
    }

    // MARK: - Error Handling Tests

    @Test("Should clear error message")
    func testClearError() {
        let (sut, _, _) = makeSUT()

        sut.errorMessage = "Some error"
        sut.clearError()

        #expect(sut.errorMessage == nil)
    }

    // MARK: - OnboardingData Model Tests

    @Test("Should encode and decode OnboardingData correctly")
    func testOnboardingDataCodable() throws {
        var data = OnboardingData()
        data.primaryGoals = [.buildMuscle, .loseFat]
        data.primarySports = ["Running", "Cycling"]
        data.experienceLevel = .intermediate
        data.trainingFrequency = .fourDays
        data.workoutDuration = .sixty
        data.availableEquipment = .fullGym
        data.injuries = [.shoulders, .custom("Tennis elbow")]
        data.completedAt = Date()

        let encoded = try JSONEncoder().encode(data)
        let decoded = try JSONDecoder().decode(OnboardingData.self, from: encoded)

        #expect(decoded.primaryGoals == [.buildMuscle, .loseFat])
        #expect(decoded.primarySports == ["Running", "Cycling"])
        #expect(decoded.experienceLevel == .intermediate)
        #expect(decoded.trainingFrequency == .fourDays)
        #expect(decoded.workoutDuration == .sixty)
        #expect(decoded.availableEquipment == .fullGym)
        #expect(decoded.injuries.count == 2)
        #expect(decoded.injuries.contains(.shoulders))
        #expect(decoded.injuries.contains(.custom("Tennis elbow")))
    }

    @Test("Should generate correct Supabase JSON")
    func testToSupabaseJSON() {
        var data = OnboardingData()
        data.primaryGoals = [.loseFat, .recomposition]
        data.primarySports = ["Cycling", "Swimming"]
        data.experienceLevel = .advanced
        data.trainingFrequency = .sixDays
        data.workoutDuration = .ninety
        data.availableEquipment = .homeGym
        data.injuries = [.knees, .custom("Bad ankle")]

        let json = data.toSupabaseJSON()

        #expect(json["primary_goals"] as? [String] == ["lose_fat", "recomposition"])
        #expect(json["primary_sports"] as? [String] == ["Cycling", "Swimming"])
        #expect(json["experience_level"] as? String == "advanced")
        #expect(json["training_frequency"] as? Int == 6)
        #expect(json["workout_duration"] as? Int == 90)
        #expect(json["available_equipment"] as? String == "home_gym")

        let injuries = json["injuries"] as? [[String: String]]
        #expect(injuries?.count == 2)
        #expect(injuries?[0]["type"] == "knees")
        #expect(injuries?[1]["type"] == "custom")
        #expect(injuries?[1]["value"] == "Bad ankle")
    }

    // MARK: - InjuryType Tests

    @Test("Should have correct raw values")
    func testInjuryTypeRawValues() {
        #expect(InjuryType.none.rawValue == "none")
        #expect(InjuryType.shoulders.rawValue == "shoulders")
        #expect(InjuryType.lowerBack.rawValue == "lower_back")
        #expect(InjuryType.knees.rawValue == "knees")
        #expect(InjuryType.wrists.rawValue == "wrists")
        #expect(InjuryType.custom("test").rawValue == "custom")
    }

    @Test("Should have correct display names")
    func testInjuryTypeDisplayNames() {
        #expect(InjuryType.none.displayName == "None")
        #expect(InjuryType.shoulders.displayName == "Shoulders / Rotator Cuff")
        #expect(InjuryType.lowerBack.displayName == "Lower Back")
        #expect(InjuryType.knees.displayName == "Knees")
        #expect(InjuryType.wrists.displayName == "Wrists")
        #expect(InjuryType.custom("Bad hip").displayName == "Bad hip")
    }

    @Test("Should have 5 standard cases")
    func testStandardCases() {
        #expect(InjuryType.standardCases.count == 5)
        #expect(InjuryType.standardCases.contains(.none))
        #expect(InjuryType.standardCases.contains(.shoulders))
        #expect(InjuryType.standardCases.contains(.lowerBack))
        #expect(InjuryType.standardCases.contains(.knees))
        #expect(InjuryType.standardCases.contains(.wrists))
    }

    @Test("Should encode and decode InjuryType correctly")
    func testInjuryTypeCodable() throws {
        let injuries: [InjuryType] = [.shoulders, .custom("ACL tear")]

        let encoded = try JSONEncoder().encode(injuries)
        let decoded = try JSONDecoder().decode([InjuryType].self, from: encoded)

        #expect(decoded.count == 2)
        #expect(decoded[0] == .shoulders)
        #expect(decoded[1] == .custom("ACL tear"))
    }

    // MARK: - Enum Raw Value Tests (API Contract)

    @Test("PrimaryGoal raw values match API contract")
    func testPrimaryGoalRawValues() {
        #expect(PrimaryGoal.buildMuscle.rawValue == "build_muscle")
        #expect(PrimaryGoal.loseFat.rawValue == "lose_fat")
        #expect(PrimaryGoal.recomposition.rawValue == "recomposition")
        #expect(PrimaryGoal.improveEndurance.rawValue == "improve_endurance")
        #expect(PrimaryGoal.generalFitness.rawValue == "general_fitness")
        #expect(PrimaryGoal.allCases.count == 5)
    }

    @Test("ExperienceLevel raw values match API contract")
    func testExperienceLevelRawValues() {
        #expect(ExperienceLevel.beginner.rawValue == "beginner")
        #expect(ExperienceLevel.intermediate.rawValue == "intermediate")
        #expect(ExperienceLevel.advanced.rawValue == "advanced")
        #expect(ExperienceLevel.allCases.count == 3)
    }

    @Test("Equipment raw values match API contract")
    func testEquipmentRawValues() {
        #expect(Equipment.fullGym.rawValue == "full_gym")
        #expect(Equipment.dumbbellsOnly.rawValue == "dumbbells_only")
        #expect(Equipment.bodyweight.rawValue == "bodyweight")
        #expect(Equipment.homeGym.rawValue == "home_gym")
        #expect(Equipment.allCases.count == 4)
    }
}
