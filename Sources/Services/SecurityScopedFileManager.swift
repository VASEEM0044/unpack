import Foundation

/// Manages security-scoped file system access, persistent directory bookmarks, and sandbox directories.
public final class SecurityScopedFileManager: @unchecked Sendable {
    public static let shared = SecurityScopedFileManager()

    private let bookmarkKey = "com.unpack.customDestinationBookmark"
    private let fileManager = FileManager.default

    private init() {
        createDefaultDirectoriesIfNeeded()
    }

    /// Default extraction folder located inside the app's sandboxed Documents directory.
    public var defaultExtractionDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Extracted", isDirectory: true)
    }

    /// User's current preferred extraction folder (custom folder bookmark or default sandbox directory).
    public var preferredExtractionDirectory: URL {
        get {
            if let savedURL = resolveCustomDestinationBookmark() {
                return savedURL
            }
            return defaultExtractionDirectory
        }
        set {
            saveCustomDestinationBookmark(url: newValue)
        }
    }

    /// Persists a custom folder chosen via UIDocumentPickerViewController as a security-scoped bookmark.
    public func saveCustomDestinationBookmark(url: URL) {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        } catch {
            print("Failed to create security-scoped bookmark for \(url): \(error)")
        }
    }

    /// Resolves saved bookmark data back into an active URL.
    public func resolveCustomDestinationBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withoutUI,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                saveCustomDestinationBookmark(url: url)
            }
            return url
        } catch {
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
            return nil
        }
    }

    /// Clears any custom folder selection, reverting to default sandboxed Extracted folder.
    public func resetToDefaultExtractionDirectory() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }

    /// Lists extracted folders and files inside the preferred extraction directory.
    public func listExtractedItems() -> [URL] {
        let dir = preferredExtractionDirectory
        let isScoped = dir.startAccessingSecurityScopedResource()
        defer {
            if isScoped { dir.stopAccessingSecurityScopedResource() }
        }

        guard let contents = try? fileManager.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.sorted { (lhs, rhs) -> Bool in
            let date1 = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            let date2 = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            return date1 > date2
        }
    }

    private func createDefaultDirectoriesIfNeeded() {
        let dir = defaultExtractionDirectory
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}
