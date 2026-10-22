import Foundation

/// Compression algorithm levels.
public enum CompressionLevel: String, CaseIterable, Identifiable, Sendable {
    case fast
    case normal
    case maximum

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .fast: return String(localized: "Fast (Low CPU)")
        case .normal: return String(localized: "Standard Balanced")
        case .maximum: return String(localized: "Maximum (Smallest Size)")
        }
    }
}

/// Parameters for creating a new archive.
public struct CompressionOptions: Sendable {
    public var format: ArchiveFormat
    public var level: CompressionLevel
    public var password: String?
    public var useAES256: Bool

    public init(
        format: ArchiveFormat = .zip,
        level: CompressionLevel = .normal,
        password: String? = nil,
        useAES256: Bool = true
    ) {
        self.format = format
        self.level = level
        self.password = password
        self.useAES256 = useAES256
    }
}
