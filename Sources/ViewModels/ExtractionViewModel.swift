import SwiftUI
import Observation

/// ViewModel controlling extraction options, security pre-flight checks, password resolution, and live streaming progress.
@Observable
@MainActor
public final class ExtractionViewModel {
    public enum State: Equatable {
        case configuring
        case extracting(ExtractionProgress)
        case passwordRequired
        case completed(destination: URL)
        case failed(message: String)

        public static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.configuring, .configuring): return true
            case (.passwordRequired, .passwordRequired): return true
            case (.completed(let d1), .completed(let d2)): return d1 == d2
            case (.failed(let m1), .failed(let m2)): return m1 == m2
            case (.extracting(let p1), .extracting(let p2)): return p1.fractionCompleted == p2.fractionCompleted
            default: return false
            }
        }
    }

    public let archiveURL: URL
    public let selectedEntryPaths: Set<String>?

    public var destinationDirectory: URL
    public var createSubfolder: Bool = true
    public var overwritePolicy: OverwritePolicy = .keepBoth
    public var password: String = ""
    public var savePasswordToKeychain: Bool = false
    
    public var state: State = .configuring
    public var isSelectingDestinationFolder: Bool = false

    private var extractionTask: Task<Void, Never>?

    public init(archiveURL: URL, selectedEntryPaths: Set<String>? = nil) {
        self.archiveURL = archiveURL
        self.selectedEntryPaths = selectedEntryPaths
        self.destinationDirectory = SecurityScopedFileManager.shared.preferredExtractionDirectory
        checkKeychainForSavedPassword()
    }

    public func startExtraction() {
        state = .extracting(ExtractionProgress())

        extractionTask = Task {
            let isScoped = archiveURL.startAccessingSecurityScopedResource()
            let isDestScoped = destinationDirectory.startAccessingSecurityScopedResource()
            defer {
                if isScoped { archiveURL.stopAccessingSecurityScopedResource() }
                if isDestScoped { destinationDirectory.stopAccessingSecurityScopedResource() }
            }

            let options = ExtractionOptions(
                destinationDirectory: destinationDirectory,
                createSubfolder: createSubfolder,
                overwritePolicy: overwritePolicy,
                password: password.isEmpty ? nil : password,
                selectedEntryPaths: selectedEntryPaths
            )

            do {
                let stream = await ArchiveCoordinator.shared.extract(
                    archiveURL: archiveURL,
                    options: options
                )

                for try await progress in stream {
                    if Task.isCancelled { break }
                    self.state = .extracting(progress)
                }

                if savePasswordToKeychain && !password.isEmpty {
                    try? KeychainPasswordManager.shared.savePassword(password, for: archiveURL.lastPathComponent)
                }

                NotificationService.shared.notifyCompletion(
                    title: String(localized: "Extraction Complete"),
                    body: String(localized: "Extracted \(archiveURL.lastPathComponent) successfully.")
                )

                self.state = .completed(destination: destinationDirectory)
            } catch let error as ArchiveSecurityError {
                if case .invalidPassword = error {
                    self.state = .passwordRequired
                } else {
                    self.state = .failed(message: error.localizedDescription)
                }
            } catch {
                self.state = .failed(message: error.localizedDescription)
            }
        }
    }

    public func cancel() {
        extractionTask?.cancel()
        state = .configuring
    }

    private func checkKeychainForSavedPassword() {
        Task {
            if let saved = try? await KeychainPasswordManager.shared.retrievePassword(for: archiveURL.lastPathComponent) {
                self.password = saved
            }
        }
    }
}
