import Foundation
import Unrar

/// Production RAR engine powered by Unrar.swift (official Alexander Roshal unrar C++ library).
/// Fully handles RAR4, RAR5, password protection, and multi-part volumes.
public final class RarEngine: ArchiveEngine, @unchecked Sendable {
    public let supportedFormats: Set<ArchiveFormat> = [.rar]

    public init() {}

    public func listContents(at archiveURL: URL, password: String?) async throws -> [ArchiveEntry] {
        let archive = try Archive(fileURL: archiveURL, password: password)
        let unrarEntries = try archive.entries()

        var entries: [ArchiveEntry] = []
        for entry in unrarEntries {
            let sanitized = PathSanitizer.sanitize(entryPath: entry.fileName)
            if !sanitized.isEmpty {
                entries.append(ArchiveEntry(
                    path: sanitized,
                    isDirectory: entry.directory,
                    uncompressedSize: Int64(entry.uncompressedSize),
                    compressedSize: Int64(entry.compressedSize),
                    modificationDate: entry.modified,
                    isEncrypted: entry.encrypted
                ))
            }
        }
        return entries
    }

    public func extract(
        from archiveURL: URL,
        to destinationDirectory: URL,
        options: ExtractionOptions
    ) -> AsyncThrowingStream<ExtractionProgress, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let archive = try Archive(fileURL: archiveURL, password: options.password)
                    let unrarEntries = try archive.entries()
                    let fileManager = FileManager.default
                    try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

                    let totalBytes = unrarEntries.reduce(0) { $0 + Int64($1.uncompressedSize) }
                    let totalFiles = unrarEntries.filter { !$0.directory }.count

                    var processedBytes: Int64 = 0
                    var processedFiles = 0
                    let startTime = Date()

                    for entry in unrarEntries {
                        if Task.isCancelled { break }
                        let sanitized = PathSanitizer.sanitize(entryPath: entry.fileName)

                        if let selected = options.selectedEntryPaths, !selected.contains(sanitized) {
                            continue
                        }

                        let targetURL = try ZipSlipGuard.validateAndResolve(
                            entryPath: sanitized,
                            destinationDirectory: destinationDirectory
                        )

                        if entry.directory {
                            try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
                        } else {
                            try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                            if options.overwritePolicy == .skip && fileManager.fileExists(atPath: targetURL.path) {
                                continue
                            }
                            if options.overwritePolicy == .replace && fileManager.fileExists(atPath: targetURL.path) {
                                try? fileManager.removeItem(at: targetURL)
                            }

                            // Real Roshal unrar decompression
                            var fileData = Data()
                            try archive.extract(entry) { chunk, progress in
                                fileData.append(chunk)
                            }
                            try fileData.write(to: targetURL)

                            processedBytes += Int64(entry.uncompressedSize)
                            processedFiles += 1
                        }

                        let elapsed = Date().timeIntervalSince(startTime)
                        let speed = elapsed > 0 ? Double(processedBytes) / elapsed : 0.0
                        let fraction = totalBytes > 0 ? Double(processedBytes) / Double(totalBytes) : 1.0

                        continuation.yield(ExtractionProgress(
                            bytesProcessed: processedBytes,
                            totalBytes: totalBytes,
                            filesProcessed: processedFiles,
                            totalFiles: totalFiles,
                            currentFilename: (sanitized as NSString).lastPathComponent,
                            fractionCompleted: min(1.0, fraction),
                            bytesPerSecond: speed
                        ))
                    }

                    continuation.yield(ExtractionProgress(fractionCompleted: 1.0))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func create(
        at destinationArchiveURL: URL,
        from sourceURLs: [URL],
        options: CompressionOptions
    ) -> AsyncThrowingStream<ExtractionProgress, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: ArchiveSecurityError.unsupportedFormat(
                message: "RAR creation is proprietary to RARLAB. Unpack supports extracting RAR, but creating RAR archives is prohibited. Please use ZIP or 7z instead."
            ))
        }
    }
}
