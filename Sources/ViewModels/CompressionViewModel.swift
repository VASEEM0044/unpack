import SwiftUI
import Observation

/// ViewModel managing archive creation, format selection, encryption parameters, and streaming compression.
@Observable
@MainActor
public final class CompressionViewModel {
    public enum State: Equatable {
        case configuring
        case compressing(ExtractionProgress)
        case completed(archiveURL: URL)
        case failed(message: String)

        public static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.configuring, .configuring): return true
            case (.completed(let u1), .completed(let u2)): return u1 == u2
            case (.failed(let m1), .failed(let m2)): return m1 == m2
            case (.compressing(let p1), .compressing(let p2)): return p1.fractionCompleted == p2.fractionCompleted
            default: return false
            }
        }
    }

    public var sourceURLs: [URL]
    public var archiveName: String = "Archive"
    public var selectedFormat: ArchiveFormat = .zip
    public var compressionLevel: CompressionLevel = .normal
    public var password: String = ""
    public var useAES256: Bool = true
    
    public var state: State = .configuring
    private var compressionTask: Task<Void, Never>?

    public init(sourceURLs: [URL] = []) {
        self.sourceURLs = sourceURLs
        if let first = sourceURLs.first {
            self.archiveName = first.deletingPathExtension().lastPathComponent
        }
    }

    public func startCompression() {
        state = .compressing(ExtractionProgress())

        let ext = selectedFormat == .sevenZip ? "7z" : "zip"
        let destURL = SecurityScopedFileManager.shared.preferredExtractionDirectory
            .appendingPathComponent("\(archiveName).\(ext)")

        compressionTask = Task {
            let options = CompressionOptions(
                format: selectedFormat,
                level: compressionLevel,
                password: password.isEmpty ? nil : password,
                useAES256: useAES256
            )

            do {
                let stream = await ArchiveCoordinator.shared.createArchive(
                    destinationURL: destURL,
                    sources: sourceURLs,
                    options: options
                )

                for try await progress in stream {
                    if Task.isCancelled { break }
                    self.state = .compressing(progress)
                }

                NotificationService.shared.notifyCompletion(
                    title: String(localized: "Archive Created"),
                    body: String(localized: "Successfully created \(archiveName).\(ext).")
                )

                self.state = .completed(archiveURL: destURL)
            } catch {
                self.state = .failed(message: error.localizedDescription)
            }
        }
    }

    public func cancel() {
        compressionTask?.cancel()
        state = .configuring
    }
}
