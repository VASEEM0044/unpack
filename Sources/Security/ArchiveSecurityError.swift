import Foundation

/// Security and validation violations encountered during archive operations.
public enum ArchiveSecurityError: LocalizedError, Equatable, Sendable {
    case zipSlipDetected(entryPath: String)
    case zipBombQuotaExceeded(reason: String)
    case excessiveCompressionRatio(ratio: Double, threshold: Double)
    case excessiveFileCount(count: Int, limit: Int)
    case excessiveUncompressedSize(bytes: Int64, limit: Int64)
    case insufficientDiskSpace(requiredBytes: Int64, availableBytes: Int64)
    case forbiddenSymlinkTarget(target: String)
    case sanitizedPathEmpty(original: String)
    case invalidPassword
    case unauthorized(reason: String)
    case corruptArchive(message: String)
    case unsupportedFormat(message: String)

    public var errorDescription: String? {
        switch self {
        case .unauthorized(let reason):
            return String(localized: "Authentication Error: \(reason)")
        case .zipSlipDetected(let path):
            return String(localized: "Security Alert: Path traversal attempt detected in entry '\(path)'. Extraction aborted to protect your device.")
        case .zipBombQuotaExceeded(let reason):
            return String(localized: "Security Alert: Archive exceeded decompression safety quota (\(reason)).")
        case .excessiveCompressionRatio(let ratio, let threshold):
            return String(localized: "Potential Zip Bomb: Compression ratio (\(Int(ratio)):1) exceeds safety threshold of \(Int(threshold)):1.")
        case .excessiveFileCount(let count, let limit):
            return String(localized: "Safety Limit: Archive contains \(count) files, exceeding the limit of \(limit).")
        case .excessiveUncompressedSize(let bytes, let limit):
            let formattedBytes = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
            let formattedLimit = ByteCountFormatter.string(fromByteCount: limit, countStyle: .file)
            return String(localized: "Safety Limit: Uncompressed size (\(formattedBytes)) exceeds the maximum configured limit of \(formattedLimit).")
        case .insufficientDiskSpace(let required, let available):
            let reqStr = ByteCountFormatter.string(fromByteCount: required, countStyle: .file)
            let availStr = ByteCountFormatter.string(fromByteCount: available, countStyle: .file)
            return String(localized: "Insufficient Storage: Extraction requires \(reqStr), but only \(availStr) is available.")
        case .forbiddenSymlinkTarget(let target):
            return String(localized: "Security Violation: Symbolic link points outside the destination directory ('\(target)').")
        case .sanitizedPathEmpty(let orig):
            return String(localized: "Invalid Filename: Entry '\(orig)' resolved to an empty or forbidden path.")
        case .invalidPassword:
            return String(localized: "Incorrect Password: The archive could not be decrypted.")
        case .corruptArchive(let msg):
            return String(localized: "Corrupt Archive: \(msg)")
        case .unsupportedFormat(let msg):
            return String(localized: "Unsupported Format: \(msg)")
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .zipSlipDetected:
            return String(localized: "This archive may be malicious. Please verify the source before extracting.")
        case .excessiveCompressionRatio, .excessiveFileCount, .excessiveUncompressedSize, .zipBombQuotaExceeded:
            return String(localized: "You can adjust security limits or allow overrides in Settings > Security.")
        case .insufficientDiskSpace:
            return String(localized: "Free up storage on your device and try again.")
        case .invalidPassword:
            return String(localized: "Please re-enter the password or check your saved passwords in Keychain.")
        default:
            return String(localized: "Check the archive file integrity or try another format.")
        }
    }
}
