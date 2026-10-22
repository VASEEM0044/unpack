import Foundation

/// Coordinates file exchange between extensions (Share Extension) and the main application using an App Group container.
public final class AppGroupHandoffService: @unchecked Sendable {
    public static let shared = AppGroupHandoffService()
    public static let appGroupID = "group.com.unpack.app"

    private let fileManager = FileManager.default

    private init() {}

    /// Shared directory container for the App Group.
    public var sharedContainerURL: URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)
    }

    /// Inbox folder within the shared container where extensions drop archives.
    public var sharedInboxURL: URL? {
        guard let container = sharedContainerURL else { return nil }
        let inbox = container.appendingPathComponent("Inbox", isDirectory: true)
        if !fileManager.fileExists(atPath: inbox.path) {
            try? fileManager.createDirectory(at: inbox, withIntermediateDirectories: true)
        }
        return inbox
    }

    /// Polls and imports pending archives from the shared inbox into the local app sandbox.
    public func fetchPendingInboxArchives() -> [URL] {
        guard let inbox = sharedInboxURL,
              let files = try? fileManager.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil) else {
            return []
        }
        return files
    }

    /// Moves a file out of the shared inbox into the app's local sandbox or active workspace.
    public func consumeInboxFile(at url: URL, to destination: URL) throws {
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: url, to: destination)
    }
}
