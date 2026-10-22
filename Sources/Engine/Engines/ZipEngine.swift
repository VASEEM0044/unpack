import Foundation
import ZIPFoundation

/// Production-grade streaming ZIP engine using Apple's standard ZIPFoundation library.
public final class ZipEngine: ArchiveEngine, @unchecked Sendable {
    public let supportedFormats: Set<ArchiveFormat> = [.zip]

    public init() {}

    public func listContents(at archiveURL: URL, password: String?) async throws -> [ArchiveEntry] {
        guard let archive = Archive(url: archiveURL, accessMode: .read) else {
            throw ArchiveSecurityError.corruptArchive(message: "Failed to open ZIP archive. File may be corrupted or inaccessible.")
        }

        var entries: [ArchiveEntry] = []
        for entry in archive {
            let sanitized = PathSanitizer.sanitize(entryPath: entry.path)
            if !sanitized.isEmpty {
                entries.append(ArchiveEntry(
                    path: sanitized,
                    isDirectory: entry.type == .directory,
                    uncompressedSize: Int64(entry.uncompressedSize),
                    compressedSize: Int64(entry.compressedSize),
                    modificationDate: (entry.fileAttributes[.modificationDate] as? Date) ?? Date()
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
                    guard let archive = Archive(url: archiveURL, accessMode: .read) else {
                        throw ArchiveSecurityError.corruptArchive(message: "Unable to open ZIP archive for decompression.")
                    }

                    let fileManager = FileManager.default
                    try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

                    var entriesToExtract: [Entry] = []
                    var totalBytes: Int64 = 0

                    for entry in archive {
                        let sanitized = PathSanitizer.sanitize(entryPath: entry.path)
                        if let selected = options.selectedEntryPaths {
                            if selected.contains(sanitized) {
                                entriesToExtract.append(entry)
                                totalBytes += Int64(entry.uncompressedSize)
                            }
                        } else {
                            entriesToExtract.append(entry)
                            totalBytes += Int64(entry.uncompressedSize)
                        }
                    }

                    let totalFiles = entriesToExtract.filter { $0.type != .directory }.count
                    var processedBytes: Int64 = 0
                    var processedFiles = 0
                    let startTime = Date()

                    for entry in entriesToExtract {
                        if Task.isCancelled { break }
                        let sanitized = PathSanitizer.sanitize(entryPath: entry.path)

                        let targetURL = try ZipSlipGuard.validateAndResolve(
                            entryPath: sanitized,
                            destinationDirectory: destinationDirectory
                        )

                        if entry.type == .directory {
                            try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
                        } else {
                            try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)

                            if options.overwritePolicy == .skip && fileManager.fileExists(atPath: targetURL.path) {
                                continue
                            }
                            if options.overwritePolicy == .replace && fileManager.fileExists(atPath: targetURL.path) {
                                try? fileManager.removeItem(at: targetURL)
                            }

                            _ = try archive.extract(entry, to: targetURL)
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

                    continuation.yield(ExtractionProgress(
                        bytesProcessed: totalBytes,
                        totalBytes: totalBytes,
                        filesProcessed: processedFiles,
                        totalFiles: totalFiles,
                        currentFilename: "Complete",
                        fractionCompleted: 1.0,
                        bytesPerSecond: 0.0
                    ))
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
            Task {
                do {
                    let fileManager = FileManager.default
                    if fileManager.fileExists(atPath: destinationArchiveURL.path) {
                        try? fileManager.removeItem(at: destinationArchiveURL)
                    }

                    guard let archive = Archive(url: destinationArchiveURL, accessMode: .create) else {
                        throw ArchiveSecurityError.corruptArchive(message: "Failed to initialize new ZIP archive.")
                    }

                    for (index, source) in sourceURLs.enumerated() {
                        let relPath = source.lastPathComponent
                        let parent = source.deletingLastPathComponent()
                        try archive.addEntry(with: relPath, relativeTo: parent)
                        continuation.yield(ExtractionProgress(
                            filesProcessed: index + 1,
                            totalFiles: sourceURLs.count,
                            currentFilename: relPath,
                            fractionCompleted: Double(index + 1) / Double(sourceURLs.count)
                        ))
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
