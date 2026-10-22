import Foundation

public extension Int64 {
    /// Formats the integer as a human-readable file size (e.g. "24.5 MB", "1.2 GB").
    func formattedByteCount() -> String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
