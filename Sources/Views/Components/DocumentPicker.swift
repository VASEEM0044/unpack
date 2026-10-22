import SwiftUI
import UniformTypeIdentifiers

/// UIKit bridge for UIDocumentPickerViewController supporting single/multiple archive picking or directory selection.
public struct DocumentPicker: UIViewControllerRepresentable {
    public enum Mode {
        case openArchives
        case selectFolder
    }

    private let mode: Mode
    private let allowsMultipleSelection: Bool
    private let onPick: ([URL]) -> Void
    private let onCancel: () -> Void

    public init(
        mode: Mode = .openArchives,
        allowsMultipleSelection: Bool = true,
        onPick: @escaping ([URL]) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self.mode = mode
        self.allowsMultipleSelection = allowsMultipleSelection
        self.onPick = onPick
        self.onCancel = onCancel
    }

    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let contentTypes: [UTType]
        switch mode {
        case .openArchives:
            contentTypes = [
                .zip,
                .archive,
                UTType(importedAs: "com.rarlab.rar-archive"),
                UTType(importedAs: "org.7-zip.7-zip-archive"),
                UTType(importedAs: "org.gnu.gnu-zip-archive"),
                UTType(importedAs: "org.tukaani.xz-archive"),
                UTType(importedAs: "public.tar-archive"),
                UTType(importedAs: "public.bzip2-archive"),
                UTType(importedAs: "public.iso-image"),
                UTType(importedAs: "com.microsoft.cab-archive")
            ]
        case .selectFolder:
            contentTypes = [.folder]
        }

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: false)
        picker.allowsMultipleSelection = (mode == .selectFolder) ? false : allowsMultipleSelection
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    public final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPick: @MainActor ([URL]) -> Void
        private let onCancel: @MainActor () -> Void

        init(onPick: @escaping @MainActor ([URL]) -> Void, onCancel: @escaping @MainActor () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        nonisolated public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            Task { @MainActor in
                onPick(urls)
            }
        }

        nonisolated public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            Task { @MainActor in
                onCancel()
            }
        }
    }
}
