import SwiftUI
import PhotosUI
import UIKit

/// A reusable component that presents an action sheet offering
/// "Photo Library" or "Take a Photo", then delivers the selected image data.
struct ImageSourcePicker: ViewModifier {
    @Binding var isPresented: Bool
    var onImageSelected: (Data) -> Void

    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var selectedItem: PhotosPickerItem?

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Add Photo", isPresented: $isPresented, titleVisibility: .visible) {
                Button("Choose from Library") {
                    showPhotoPicker = true
                }
                Button("Take a Photo") {
                    showCamera = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        onImageSelected(data)
                    }
                    selectedItem = nil
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView { data in
                    onImageSelected(data)
                }
                .ignoresSafeArea()
            }
    }
}

extension View {
    func imageSourcePicker(isPresented: Binding<Bool>, onImageSelected: @escaping (Data) -> Void) -> some View {
        modifier(ImageSourcePicker(isPresented: isPresented, onImageSelected: onImageSelected))
    }
}

// MARK: - Camera UIKit Wrapper

struct CameraView: UIViewControllerRepresentable {
    var onCapture: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (Data) -> Void
        let dismiss: DismissAction

        init(onCapture: @escaping (Data) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.85) {
                onCapture(data)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
