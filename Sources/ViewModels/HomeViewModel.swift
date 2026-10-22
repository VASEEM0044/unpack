import SwiftUI
import Observation

/// ViewModel powering the Home dashboard screen.
@Observable
@MainActor
public final class HomeViewModel {
    public var recentArchives: [URL] = []
    public var extractedItems: [URL] = []
    public var totalExtractedSize: Int64 = 0
    public var isImportingDocument: Bool = false
    public var selectedArchiveForBrowsing: URL?
    public var activeAlertMessage: String?

    private let fileManager = SecurityScopedFileManager.shared
    private let userDefaultsKey = "com.unpack.recentArchives"

    public init() {
        loadRecents()
        refreshExtractedItems()
    }

    public func refreshExtractedItems() {
        extractedItems = fileManager.listExtractedItems()
        calculateStorageUsage()
    }

    public func addRecentArchive(url: URL) {
        var recents = recentArchives.filter { $0.path != url.path }
        recents.insert(url, at: 0)
        if recents.count > 15 {
            recents = Array(recents.prefix(15))
        }
        recentArchives = recents
        saveRecents()
    }

    public func removeRecentArchive(at offsets: IndexSet) {
        recentArchives.remove(atOffsets: offsets)
        saveRecents()
    }

    public func clearAllRecents() {
        recentArchives.removeAll()
        saveRecents()
    }

    public func deleteExtractedItem(url: URL) {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped { url.stopAccessingSecurityScopedResource() }
        }
        try? FileManager.default.removeItem(at: url)
        refreshExtractedItems()
    }

    private func calculateStorageUsage() {
        var bytes: Int64 = 0
        for item in extractedItems {
            let isScoped = item.startAccessingSecurityScopedResource()
            if let attrs = try? FileManager.default.attributesOfItem(atPath: item.path),
               let size = attrs[.size] as? Int64 {
                bytes += size
            }
            if isScoped { item.stopAccessingSecurityScopedResource() }
        }
        totalExtractedSize = bytes
    }

    private func loadRecents() {
        if let paths = UserDefaults.standard.stringArray(forKey: userDefaultsKey) {
            recentArchives = paths.compactMap { URL(fileURLWithPath: $0) }
        }
    }

    private func saveRecents() {
        let paths = recentArchives.map { $0.path }
        UserDefaults.standard.set(paths, forKey: userDefaultsKey)
    }
}
