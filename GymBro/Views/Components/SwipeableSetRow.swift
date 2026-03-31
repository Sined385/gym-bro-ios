import SwiftUI

/// Wraps a set row with bidirectional swipe actions:
/// - Swipe left → red delete button (trash icon)
/// - Swipe right → yellow repeat button (repeat icon)
struct SwipeableSetRow<Content: View>: View {
    let content: Content
    let onDelete: () -> Void
    let onRepeat: () -> Void

    @State private var offset: CGFloat = 0
    @State private var swipeState: SwipeState = .closed

    private let actionThreshold: CGFloat = 70
    private let buttonSize: CGFloat = 44

    enum SwipeState {
        case closed, openLeft, openRight
    }

    init(
        @ViewBuilder content: () -> Content,
        onDelete: @escaping () -> Void,
        onRepeat: @escaping () -> Void
    ) {
        self.content = content()
        self.onDelete = onDelete
        self.onRepeat = onRepeat
    }

    var body: some View {
        ZStack {
            // Delete button (revealed on swipe left)
            HStack {
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        offset = -400
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onDelete()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "FB2C36"))
                            .frame(width: buttonSize, height: buttonSize)
                            .shadow(color: Color(hex: "FB2C36").opacity(0.3), radius: 6, y: 2)
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .opacity(deleteOpacity)
                .padding(.trailing, 12)
            }

            // Repeat button (revealed on swipe right)
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        offset = 0
                        swipeState = .closed
                    }
                    onRepeat()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "F59E0B"))
                            .frame(width: buttonSize, height: buttonSize)
                            .shadow(color: Color(hex: "F59E0B").opacity(0.3), radius: 6, y: 2)
                        Image(systemName: "repeat")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .opacity(repeatOpacity)
                .padding(.leading, 12)
                Spacer()
            }

            // Card content
            content
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 15)
                        .onChanged { value in
                            let translation = value.translation.width
                            switch swipeState {
                            case .closed:
                                offset = translation * 0.7
                            case .openLeft:
                                let newOffset = -actionThreshold + translation
                                offset = min(0, newOffset)
                            case .openRight:
                                let newOffset = actionThreshold + translation
                                offset = max(0, newOffset)
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                if offset < -actionThreshold / 2 {
                                    offset = -actionThreshold
                                    swipeState = .openLeft
                                } else if offset > actionThreshold / 2 {
                                    offset = actionThreshold
                                    swipeState = .openRight
                                } else {
                                    offset = 0
                                    swipeState = .closed
                                }
                            }
                        }
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var deleteOpacity: Double {
        guard offset < 0 else { return 0 }
        return min(Double(abs(offset) / actionThreshold), 1.0)
    }

    private var repeatOpacity: Double {
        guard offset > 0 else { return 0 }
        return min(Double(offset / actionThreshold), 1.0)
    }
}
