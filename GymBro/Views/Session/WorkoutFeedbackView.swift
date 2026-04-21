import SwiftUI

struct WorkoutFeedbackView: View {
    @ObservedObject var viewModel: SessionFlowViewModel
    @EnvironmentObject var sessionManager: ActiveSessionManager
    var onDismiss: () -> Void

    @State private var isSubmitting: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var completionDurationMinutes: Int?
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    private let painOptions = ["None", "Joint Pain", "Muscle Tweak", "Extreme Fatigue"]
    private let painIcons = ["checkmark.circle", "figure.arms.open", "bandage", "zzz"]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "30C08D").opacity(0.15))
                            .frame(width: 72, height: 72)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(Color(hex: "30C08D"))
                    }

                    Text("Workout Complete!")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)

                    Text("Duration: \(sessionManager.formattedTime)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.gymBroNeutral600)
                }
                .padding(.top, 20)

                // Effort Level
                VStack(alignment: .leading, spacing: 12) {
                    Text("How hard was this workout?")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)

                    HStack(spacing: 0) {
                        ForEach(1...10, id: \.self) { level in
                            Button {
                                viewModel.effortLevel = level
                            } label: {
                                Text("\(level)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(viewModel.effortLevel == level ? .white : .gymBroNeutral600)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        viewModel.effortLevel == level
                                        ? Color.gymBroPrimary
                                        : Color.clear
                                    )
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                viewModel.effortLevel == level ? Color.clear : Color.gymBroNeutral200,
                                                lineWidth: 1
                                            )
                                    )
                            }
                            .buttonStyle(.plain)

                            if level < 10 { Spacer(minLength: 0) }
                        }
                    }

                    HStack {
                        Text("Easy")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gymBroNeutral400)
                        Spacer()
                        Text("Maximum")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gymBroNeutral400)
                    }
                }

                // Energy Level
                VStack(alignment: .leading, spacing: 12) {
                    Text("How's your energy level?")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)

                    HStack(spacing: 10) {
                        energyButton(level: 1, icon: "battery.0percent", label: "Exhausted")
                        energyButton(level: 2, icon: "battery.25percent", label: "Tired")
                        energyButton(level: 3, icon: "battery.50percent", label: "Okay")
                        energyButton(level: 4, icon: "battery.75percent", label: "Good")
                        energyButton(level: 5, icon: "battery.100percent", label: "Great")
                    }
                }

                // Pain / Discomfort
                VStack(alignment: .leading, spacing: 12) {
                    Text("Any pain or discomfort?")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.gymBroNeutral900)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(Array(zip(painOptions, painIcons)), id: \.0) { option, icon in
                            painButton(option: option, icon: icon)
                        }
                    }
                }

                // Submit button
                Button {
                    isSubmitting = true
                    Task {
                        let response = await viewModel.submitFeedbackAndComplete()
                        isSubmitting = false
                        if let response {
                            completionDurationMinutes = response.durationMinutes
                            showShareSheet = true
                        } else {
                            errorMessage = "Failed to save workout. Please try again."
                            showError = true
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Submit & Return Home")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [.gymBroPrimary, .gymBroPrimaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting || viewModel.effortLevel == 0 || viewModel.energyLevel == 0 || viewModel.painDiscomfort.isEmpty)
                .opacity(viewModel.effortLevel == 0 || viewModel.energyLevel == 0 || viewModel.painDiscomfort.isEmpty ? 0.5 : 1.0)
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color.gymBroBackground.ignoresSafeArea())
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSessionView(
                viewModel: viewModel,
                sessionDurationMinutes: completionDurationMinutes,
                onShare: { _ in onDismiss() },
                onSkip: { onDismiss() }
            )
        }
    }

    // MARK: - Energy Button

    private func energyButton(level: Int, icon: String, label: String) -> some View {
        let isSelected = viewModel.energyLevel == level

        return Button {
            viewModel.energyLevel = level
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .gymBroPrimary : .gymBroNeutral400)

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .gymBroPrimary : .gymBroNeutral400)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(isSelected ? Color.gymBroPrimary.opacity(0.1) : Color.gymBroNeutral100)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.gymBroPrimary : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pain Button

    private func painButton(option: String, icon: String) -> some View {
        let isSelected = viewModel.painDiscomfort == option

        return Button {
            viewModel.painDiscomfort = option
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .gymBroPrimary : .gymBroNeutral600)

                Text(option)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .gymBroNeutral900 : .gymBroNeutral600)

                Spacer()
            }
            .padding(14)
            .background(isSelected ? Color.gymBroPrimary.opacity(0.08) : Color.gymBroNeutral100)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.gymBroPrimary : Color.gymBroNeutral200, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
