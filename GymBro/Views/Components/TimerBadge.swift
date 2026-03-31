import SwiftUI

struct TimerBadge: View {
    let time: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "stopwatch.fill")
                .font(.system(size: 12, weight: .semibold))
            Text(time)
                .font(.system(size: 14, weight: .bold))
                .monospacedDigit()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.gymBroPrimary)
        .clipShape(Capsule())
    }
}

#Preview {
    TimerBadge(time: "12:34")
}
