import SwiftUI

struct CreateCustomExerciseView: View {
    @ObservedObject var libraryViewModel: ExerciseLibraryViewModel
    @ObservedObject var sessionViewModel: SessionFlowViewModel
    var onComplete: () -> Void

    @State private var exerciseName: String = ""
    @State private var selectedMuscleGroup: String? = nil
    // Use the same EquipmentType enum the library filter uses so a custom
    // exercise's equipment string is guaranteed to match an Equipment chip.
    // A free-form TextField produced near-misses ("Dumbbell" vs "Dumbbells")
    // that the filter silently dropped.
    @State private var selectedEquipment: EquipmentType? = .bodyweight
    @State private var isSaving: Bool = false

    private var isValid: Bool {
        !exerciseName.trimmingCharacters(in: .whitespaces).isEmpty && selectedMuscleGroup != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Exercise Name
            VStack(alignment: .leading, spacing: 8) {
                Text("EXERCISE NAME")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(.gymBroNeutral600)

                TextField("e.g. Zercher Squat", text: $exerciseName)
                    .font(.system(size: 16))
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gymBroNeutral200, lineWidth: 1)
                    )
            }

            // Muscle Group
            VStack(alignment: .leading, spacing: 8) {
                Text("TARGET MUSCLE GROUP")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(.gymBroNeutral600)

                CategoryFilterChips(
                    categories: MuscleGroup.allCases.map { $0.rawValue },
                    selectedCategory: $selectedMuscleGroup,
                    allowDeselect: false
                )
                .padding(.horizontal, -20) // Counter parent padding
            }

            // Equipment
            VStack(alignment: .leading, spacing: 8) {
                Text("EQUIPMENT NEEDED")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(.gymBroNeutral600)

                EquipmentFilterChips(
                    selectedEquipment: $selectedEquipment,
                    allowDeselect: false,
                )
                .padding(.horizontal, -20) // Counter parent padding
            }

            Spacer()

            // Save button
            Button {
                isSaving = true
                Task {
                    let item = await libraryViewModel.createCustomExercise(
                        name: exerciseName.trimmingCharacters(in: .whitespaces),
                        muscleGroup: selectedMuscleGroup ?? "Other",
                        equipment: (selectedEquipment ?? .bodyweight).rawValue
                    )
                    if let item = item {
                        await sessionViewModel.addExercise(item)
                    }
                    isSaving = false
                    onComplete()
                }
            } label: {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Save & Add to Workout")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Group {
                        if isValid {
                            LinearGradient(
                                colors: [.gymBroPrimary, .gymBroPrimaryDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        } else {
                            LinearGradient(
                                colors: [Color.gymBroNeutral400, Color.gymBroNeutral400],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)
            .disabled(!isValid || isSaving)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 40)
        .background(Color.gymBroBackground.ignoresSafeArea())
        .navigationTitle("Create Exercise")
        .navigationBarTitleDisplayMode(.inline)
    }
}
