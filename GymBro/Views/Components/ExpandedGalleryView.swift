import SwiftUI
import Agrume

struct ExpandedGalleryView: UIViewControllerRepresentable {
    let urls: [URL]
    let initialIndex: Int
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        let container = UIViewController()
        container.view.backgroundColor = .clear
        return container
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard isPresented, uiViewController.presentedViewController == nil else { return }

        let agrume = Agrume(
            urls: urls,
            startIndex: initialIndex,
            background: .colored(.black)
        )
        agrume.hideStatusBar = true
        agrume.didDismiss = {
            isPresented = false
        }
        agrume.modalPresentationStyle = .overFullScreen
        agrume.modalTransitionStyle = .crossDissolve
        uiViewController.present(agrume, animated: true)
    }
}
