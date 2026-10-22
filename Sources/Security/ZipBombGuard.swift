import Foundation

/// Monitors and mitigates Zip-Bomb denial-of-service threats during archive parsing and extraction.
/// Tracks aggregate file count, accumulated decompressed bytes, and compression ratios in real time.
public final class ZipBombGuard: @unchecked Sendable {
    public struct Limits: Sendable {
        public var maxTotalBytes: Int64
        public var maxFileCount: Int
        public var maxCompressionRatio: Double
        public var ratioCheckThresholdBytes: Int64
        public var allowOverrides: Bool

        public static let standard = Limits(
            maxTotalBytes: 50 * 1024 * 1024 * 1024, // 50 GB
            maxFileCount: 25_000,
            maxCompressionRatio: 100.0,             // 100:1 ratio
            ratioCheckThresholdBytes: 1024 * 1024,  // Check ratio only if uncompressed > 1 MB
            allowOverrides: false
        )

        public static let relaxed = Limits(
            maxTotalBytes: 150 * 1024 * 1024 * 1024, // 150 GB
            maxFileCount: 100_000,
            maxCompressionRatio: 250.0,
            ratioCheckThresholdBytes: 5 * 1024 * 1024,
            allowOverrides: true
        )
    }

    private let limits: Limits
    private let lock = NSLock()
    
    private var accumulatedBytes: Int64 = 0
    private var accumulatedFiles: Int = 0

    public init(limits: Limits = .standard) {
        self.limits = limits
    }

    /// Resets tracking counters before a new extraction job.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        accumulatedBytes = 0
        accumulatedFiles = 0
    }

    /// Pre-validates entry metadata during table-of-contents inspection.
    public func validateEntryMetadata(uncompressedSize: Int64, compressedSize: Int64) throws {
        lock.lock()
        defer { lock.unlock() }

        if !limits.allowOverrides {
            // Check compression ratio if file exceeds minimum threshold
            if uncompressedSize > limits.ratioCheckThresholdBytes && compressedSize > 0 {
                let ratio = Double(uncompressedSize) / Double(compressedSize)
                if ratio > limits.maxCompressionRatio {
                    throw ArchiveSecurityError.excessiveCompressionRatio(
                        ratio: ratio,
                        threshold: limits.maxCompressionRatio
                    )
                }
            }
        }
    }

    /// Validates an increment during live streaming decompression.
    public func recordStreamChunk(bytes: Int64) throws {
        lock.lock()
        defer { lock.unlock() }

        accumulatedBytes += bytes

        if !limits.allowOverrides && accumulatedBytes > limits.maxTotalBytes {
            throw ArchiveSecurityError.excessiveUncompressedSize(
                bytes: accumulatedBytes,
                limit: limits.maxTotalBytes
            )
        }
    }

    /// Increments and validates processed file count.
    public func recordFileCompleted() throws {
        lock.lock()
        defer { lock.unlock() }

        accumulatedFiles += 1

        if !limits.allowOverrides && accumulatedFiles > limits.maxFileCount {
            throw ArchiveSecurityError.excessiveFileCount(
                count: accumulatedFiles,
                limit: limits.maxFileCount
            )
        }
    }
}
