import SwiftUI

struct ShimmerView: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geometry in
            Color.gymBroNeutral100
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.gymBroNeutral100,
                            Color.white.opacity(0.6),
                            Color.gymBroNeutral100
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: phase * geometry.size.width)
                )
                .clipped()
        }
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 1.5
            }
        }
    }
}
