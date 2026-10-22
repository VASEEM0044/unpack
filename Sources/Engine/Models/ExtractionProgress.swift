import Foundation

/// Real-time progress update emitted during archive extraction or compression.
public struct ExtractionProgress: Sendable {
    public let bytesProcessed: Int64
    public let totalBytes: Int64
    public let filesProcessed: Int
    public let totalFiles: Int
    public let currentFilename: String
    public let fractionCompleted: Double
    public let bytesPerSecond: Double
    public let isIndeterminate: Bool

    public init(
        bytesProcessed: Int64 = 0,
        totalBytes: Int64 = 0,
        filesProcessed: Int = 0,
        totalFiles: Int = 0,
        currentFilename: String = "",
        fractionCompleted: Double = 0.0,
        bytesPerSecond: Double = 0.0,
        isIndeterminate: Bool = false
    ) {
        self.bytesProcessed = bytesProcessed
        self.totalBytes = totalBytes
        self.filesProcessed = filesProcessed
        self.totalFiles = totalFiles
        self.currentFilename = currentFilename
        self.fractionCompleted = fractionCompleted
        self.bytesPerSecond = bytesPerSecond
        self.isIndeterminate = isIndeterminate
    }

    /// Formatted transfer speed (e.g. "45.2 MB/s").
    public var formattedSpeed: String {
        guard bytesPerSecond > 0 else { return "" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(bytesPerSecond)))/s"
    }

    /// Estimated remaining time formatted as mm:ss.
    public var estimatedTimeRemaining: String? {
        guard bytesPerSecond > 0, totalBytes > bytesProcessed else { return nil }
        let remainingBytes = totalBytes - bytesProcessed
        let seconds = Double(remainingBytes) / bytesPerSecond
        guard seconds.isFinite && seconds < 86400 else { return nil }
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: seconds)
    }
}
