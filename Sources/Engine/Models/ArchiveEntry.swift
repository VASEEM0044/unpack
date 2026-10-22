import Foundation

/// Represents a single file or directory inside an archive, with support for recursive hierarchical trees.
public struct ArchiveEntry: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let path: String
    public let filename: String
    public let isDirectory: Bool
    public let uncompressedSize: Int64
    public let compressedSize: Int64
    public let modificationDate: Date
    public let isEncrypted: Bool
    public var children: [ArchiveEntry]?

    public init(
        id: UUID = UUID(),
        path: String,
        filename: String? = nil,
        isDirectory: Bool,
        uncompressedSize: Int64 = 0,
        compressedSize: Int64 = 0,
        modificationDate: Date = Date(),
        isEncrypted: Bool = false,
        children: [ArchiveEntry]? = nil
    ) {
        self.id = id
        self.path = path
        self.filename = filename ?? (path as NSString).lastPathComponent
        self.isDirectory = isDirectory
        self.uncompressedSize = uncompressedSize
        self.compressedSize = compressedSize
        self.modificationDate = modificationDate
        self.isEncrypted = isEncrypted
        self.children = children
    }

    /// Calculated compression ratio (e.g. 2.5 means 2.5:1 compression).
    public var compressionRatio: Double {
        guard compressedSize > 0, uncompressedSize > 0 else { return 1.0 }
        return Double(uncompressedSize) / Double(compressedSize)
    }

    /// Percentage saved through compression (e.g. 60%).
    public var savingsPercentage: Int {
        guard uncompressedSize > 0 else { return 0 }
        let savings = Double(uncompressedSize - compressedSize) / Double(uncompressedSize)
        return max(0, min(100, Int(savings * 100)))
    }

    // MARK: - Tree Construction
    /// Converts a flat array of archive entries into a structured, hierarchical folder tree.
    public static func buildTree(from entries: [ArchiveEntry]) -> [ArchiveEntry] {
        class Node {
            var entry: ArchiveEntry
            var childrenMap: [String: Node] = [:]

            init(entry: ArchiveEntry) {
                self.entry = entry
            }

            func toEntry() -> ArchiveEntry {
                let sortedChildren = childrenMap.values
                    .map { $0.toEntry() }
                    .sorted { lhs, rhs in
                        if lhs.isDirectory != rhs.isDirectory {
                            return lhs.isDirectory // Folders first
                        }
                        return lhs.filename.localizedStandardCompare(rhs.filename) == .orderedAscending
                    }
                var updated = entry
                updated.children = sortedChildren.isEmpty ? nil : sortedChildren
                return updated
            }
        }

        let rootNode = Node(entry: ArchiveEntry(path: "", isDirectory: true))

        for entry in entries {
            let normalized = entry.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !normalized.isEmpty else { continue }
            
            let components = normalized.components(separatedBy: "/")
            var currentNode = rootNode

            for (index, component) in components.enumerated() {
                let isLast = index == components.count - 1
                let currentPath = components[0...index].joined(separator: "/")

                if let existing = currentNode.childrenMap[component] {
                    if isLast {
                        existing.entry = entry
                    }
                    currentNode = existing
                } else {
                    let isDir = isLast ? entry.isDirectory : true
                    let interimEntry = isLast ? entry : ArchiveEntry(
                        path: currentPath,
                        filename: component,
                        isDirectory: isDir,
                        modificationDate: entry.modificationDate
                    )
                    let newNode = Node(entry: interimEntry)
                    currentNode.childrenMap[component] = newNode
                    currentNode = newNode
                }
            }
        }

        return rootNode.toEntry().children ?? []
    }
}
