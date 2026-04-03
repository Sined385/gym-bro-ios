import SwiftUI

struct SessionStartedView: View {
    @ObservedObject var viewModel: SessionFlowViewModel
    @EnvironmentObject var sessionManager: ActiveSessionManager
    var onAddExercise: () -> Void
    var onCancelWorkout: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.gymBroNeutral900)
                        .frame(width: 40, height: 40)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                }
                Spacer()
                if sessionManager.isWorkoutStarted {
                    TimerBadge(time: sessionManager.formattedTime)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()

            // Center content
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.gymBroPrimary.opacity(0.1))
                        .frame(width: 80, height: 80)
                    Image(systemName: "stopwatch.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.gymBroPrimary)
                }

                Text("Ready to Work Out")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)

                Text("Add exercises to get started")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gymBroNeutral400)
            }

            Spacer()

            // Bottom buttons
            HStack(spacing: 12) {
                // Add Exercise button (always present)
                Button(action: onAddExercise) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.25))
                                .frame(width: 28, height: 28)
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text("Add Exercise")
                            .font(.system(size: 16, weight: .bold))
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
                    .shadow(color: Color.gymBroPrimary.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)

                // Cancel Workout button (outlined white) — no exercises to start with
                Button(action: onCancelWorkout) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                        Text("Cancel Workout")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.gymBroNeutral900)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gymBroNeutral200, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color.gymBroBackground.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}
