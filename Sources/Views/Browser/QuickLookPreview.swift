import SwiftUI
import QuickLook

/// Bridges QLPreviewController into SwiftUI for instant document/media preview.
public struct QuickLookPreview: UIViewControllerRepresentable {
    public let previewItemURL: URL
    public let onDismiss: () -> Void

    public init(previewItemURL: URL, onDismiss: @escaping () -> Void = {}) {
        self.previewItemURL = previewItemURL
        self.onDismiss = onDismiss
    }

    public func makeUIViewController(context: Context) -> UINavigationController {
        let previewController = QLPreviewController()
        previewController.dataSource = context.coordinator
        previewController.delegate = context.coordinator
        
        let nav = UINavigationController(rootViewController: previewController)
        let doneButton = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction { _ in
                onDismiss()
            }
        )
        previewController.navigationItem.rightBarButtonItem = doneButton
        return nav
    }

    public func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(previewURL: previewItemURL, onDismiss: onDismiss)
    }

    public class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        let previewURL: URL
        let onDismiss: () -> Void

        init(previewURL: URL, onDismiss: @escaping () -> Void) {
            self.previewURL = previewURL
            self.onDismiss = onDismiss
        }

        public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            previewURL as NSURL
        }

        public func previewControllerDidDismiss(_ controller: QLPreviewController) {
            onDismiss()
        }
    }
}
