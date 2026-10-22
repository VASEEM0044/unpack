import SwiftUI
import Observation

/// Global observable application state tracking deep links, active archives, and external file open events.
@Observable
@MainActor
public final class AppState {
    public static let shared = AppState()

    public var deepLinkedArchiveURL: URL?

    public init() {}

    public func handleIncomingURL(_ url: URL) {
        // Stage incoming file into local sandbox inbox so it retains full file access
        let stagedURL = SecurityScopedFileManager.shared.stageArchiveForInspection(from: url)
        deepLinkedArchiveURL = stagedURL
    }
}
