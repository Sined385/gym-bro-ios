import SwiftUI

struct SessionStartedView: View {
    @ObservedObject var viewModel: SessionFlowViewModel
    @EnvironmentObject var sessionManager: ActiveSessionManager
    var onStartExercise: () -> Void
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
                TimerBadge(time: sessionManager.formattedTime)
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

                Text("Session Started")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.gymBroNeutral900)

                Text("Add your first exercise to begin tracking")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gymBroNeutral400)
            }

            Spacer()

            // Start Exercise button
            Button(action: onStartExercise) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("Start Exercise")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(hex: "2D3240"))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color.gymBroBackground.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}
