import SwiftUI

/// A container that wraps content with swipe-to-delete functionality.
/// Swipe left to reveal a red circular trash button behind the card.
struct SwipeToDeleteCard<Content: View>: View {
    let content: Content
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isSwiped = false

    private let deleteThreshold: CGFloat = -80
    private let deleteButtonSize: CGFloat = 54

    init(@ViewBuilder content: () -> Content, onDelete: @escaping () -> Void) {
        self.content = content()
        self.onDelete = onDelete
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button behind the card
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
                        .frame(width: deleteButtonSize, height: deleteButtonSize)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                    Image(systemName: "trash.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .opacity(deleteButtonOpacity)
            .padding(.trailing, 16)

            // Card content
            content
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            let translation = value.translation.width
                            if translation < 0 {
                                // Swiping left — allow with resistance
                                offset = isSwiped
                                    ? deleteThreshold + translation * 0.3
                                    : translation * 0.8
                            } else if isSwiped {
                                // Swiping right to close
                                offset = deleteThreshold + translation
                                if offset > 0 { offset = 0 }
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                if offset < deleteThreshold / 2 {
                                    offset = deleteThreshold
                                    isSwiped = true
                                } else {
                                    offset = 0
                                    isSwiped = false
                                }
                            }
                        }
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var deleteButtonOpacity: Double {
        let progress = min(abs(offset) / abs(deleteThreshold), 1.0)
        return Double(progress)
    }
}
