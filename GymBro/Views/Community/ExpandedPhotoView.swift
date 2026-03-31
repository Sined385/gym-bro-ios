import SwiftUI

struct ExpandedPhotoView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero

    private var currentOffset: CGSize {
        CGSize(width: offset.width + dragOffset.width, height: offset.height + dragOffset.height)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
                .opacity(max(0.4, 1.0 - Double(abs(dragOffset.height)) / 400.0))

            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(currentOffset)
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    scale = lastScale * value.magnification
                                }
                                .onEnded { value in
                                    lastScale = max(1.0, scale)
                                    scale = lastScale
                                    if scale == 1.0 { offset = .zero }
                                }
                        )
                        .simultaneousGesture(
                            scale <= 1.0
                            ? DragGesture()
                                .onChanged { value in
                                    dragOffset = value.translation
                                }
                                .onEnded { value in
                                    if abs(value.translation.height) > 120 {
                                        dismiss()
                                    } else {
                                        withAnimation(.spring(response: 0.3)) {
                                            dragOffset = .zero
                                        }
                                    }
                                }
                            : nil
                        )
                case .failure:
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.4))
                default:
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(.trailing, 20)
        }
        .statusBarHidden(true)
    }
}
