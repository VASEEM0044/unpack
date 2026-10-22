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
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped { url.stopAccessingSecurityScopedResource() }
        }

        // Add to recents and trigger browsing
        deepLinkedArchiveURL = url
    }
}
