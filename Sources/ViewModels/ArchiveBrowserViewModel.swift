import SwiftUI
import Observation

/// ViewModel orchestrating archive inspection, file hierarchy navigation, search filtering, sorting, and selective extraction.
@Observable
@MainActor
public final class ArchiveBrowserViewModel {
    public enum SortOption: String, CaseIterable, Identifiable {
        case name = "Name"
        case size = "Size"
        case date = "Date"
        case ratio = "Ratio"

        public var id: String { rawValue }
    }

    public let archiveURL: URL
    public var detectedFormat: ArchiveFormat = .unknown
    public var rawEntries: [ArchiveEntry] = []
    public var treeEntries: [ArchiveEntry] = []
    
    public var isTreeMode: Bool = true
    public var searchQuery: String = ""
    public var sortOption: SortOption = .name
    public var sortAscending: Bool = true
    public var selectedPaths: Set<String> = []
    public var isSelectionMode: Bool = false
    public var isLoading: Bool = false
    public var errorMessage: String?
    public var passwordPromptNeeded: Bool = false
    public var enteredPassword: String = ""
    public var previewURL: URL?

    public init(archiveURL: URL) {
        self.archiveURL = archiveURL
    }

    public func loadContents() async {
        isLoading = true
        errorMessage = nil

        let isScoped = archiveURL.startAccessingSecurityScopedResource()
        defer {
            if isScoped { archiveURL.stopAccessingSecurityScopedResource() }
        }

        do {
            let result = try await ArchiveCoordinator.shared.inspect(
                archiveURL: archiveURL,
                password: enteredPassword.isEmpty ? nil : enteredPassword
            )
            detectedFormat = result.format
            rawEntries = result.entries
            treeEntries = ArchiveEntry.buildTree(from: result.entries)
            isLoading = false
        } catch let error as ArchiveSecurityError {
            isLoading = false
            if case .invalidPassword = error {
                passwordPromptNeeded = true
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    public var displayedEntries: [ArchiveEntry] {
        let baseList = isTreeMode ? treeEntries : rawEntries

        var filtered = baseList
        if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            let query = searchQuery.lowercased()
            filtered = rawEntries.filter { $0.filename.lowercased().contains(query) || $0.path.lowercased().contains(query) }
        }

        return filtered.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory // Directories first
            }
            switch sortOption {
            case .name:
                let result = lhs.filename.localizedStandardCompare(rhs.filename) == .orderedAscending
                return sortAscending ? result : !result
            case .size:
                let result = lhs.uncompressedSize < rhs.uncompressedSize
                return sortAscending ? result : !result
            case .date:
                let result = lhs.modificationDate < rhs.modificationDate
                return sortAscending ? result : !result
            case .ratio:
                let result = lhs.compressionRatio < rhs.compressionRatio
                return sortAscending ? result : !result
            }
        }
    }

    public func toggleSelection(for path: String) {
        if selectedPaths.contains(path) {
            selectedPaths.remove(path)
        } else {
            selectedPaths.insert(path)
        }
    }

    public func selectAll() {
        selectedPaths = Set(rawEntries.map { $0.path })
    }

    public func deselectAll() {
        selectedPaths.removeAll()
    }
}
