import Foundation

/// Policy controlling file collisions during extraction.
public enum OverwritePolicy: String, CaseIterable, Identifiable, Sendable {
    case replace
    case skip
    case keepBoth

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .replace: return String(localized: "Replace Existing")
        case .skip: return String(localized: "Skip Existing")
        case .keepBoth: return String(localized: "Keep Both (Rename)")
        }
    }
}

/// Configuration options passed to an extraction task.
public struct ExtractionOptions: Sendable {
    public var destinationDirectory: URL
    public var createSubfolder: Bool
    public var overwritePolicy: OverwritePolicy
    public var password: String?
    public var selectedEntryPaths: Set<String>? // nil means extract all

    public init(
        destinationDirectory: URL,
        createSubfolder: Bool = true,
        overwritePolicy: OverwritePolicy = .keepBoth,
        password: String? = nil,
        selectedEntryPaths: Set<String>? = nil
    ) {
        self.destinationDirectory = destinationDirectory
        self.createSubfolder = createSubfolder
        self.overwritePolicy = overwritePolicy
        self.password = password
        self.selectedEntryPaths = selectedEntryPaths
    }
}
