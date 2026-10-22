import Foundation
import SWCompression

/// Production 7-Zip engine powered by SWCompression, providing full LZMA & LZMA2 decompression.
public final class SevenZipEngine: ArchiveEngine, @unchecked Sendable {
    public let supportedFormats: Set<ArchiveFormat> = [.sevenZip]

    public init() {}

    public func listContents(at archiveURL: URL, password: String?) async throws -> [ArchiveEntry] {
        let data = try Data(contentsOf: archiveURL, options: .mappedIfSafe)
        let infos = try SevenZipContainer.info(container: data)

        var entries: [ArchiveEntry] = []
        for info in infos {
            let sanitized = PathSanitizer.sanitize(entryPath: info.name)
            if !sanitized.isEmpty {
                entries.append(ArchiveEntry(
                    path: sanitized,
                    isDirectory: info.type == .directory,
                    uncompressedSize: Int64(info.size ?? 0),
                    compressedSize: 0,
                    modificationDate: info.modificationTime ?? Date()
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
                    let data = try Data(contentsOf: archiveURL, options: .mappedIfSafe)
                    let items = try SevenZipContainer.open(container: data)
                    let fileManager = FileManager.default
                    try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

                    let totalBytes = items.reduce(0) { $0 + Int64($1.info.size ?? 0) }
                    let totalFiles = items.filter { $0.info.type != .directory }.count

                    var processedBytes: Int64 = 0
                    var processedFiles = 0
                    let startTime = Date()

                    for item in items {
                        if Task.isCancelled { break }
                        let sanitized = PathSanitizer.sanitize(entryPath: item.info.name)

                        if let selected = options.selectedEntryPaths, !selected.contains(sanitized) {
                            continue
                        }

                        let targetURL = try ZipSlipGuard.validateAndResolve(
                            entryPath: sanitized,
                            destinationDirectory: destinationDirectory
                        )

                        if item.info.type == .directory {
                            try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
                        } else {
                            try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                            if options.overwritePolicy == .skip && fileManager.fileExists(atPath: targetURL.path) {
                                continue
                            }
                            if options.overwritePolicy == .replace && fileManager.fileExists(atPath: targetURL.path) {
                                try? fileManager.removeItem(at: targetURL)
                            }
                            if let fileData = item.data {
                                try fileData.write(to: targetURL)
                            } else {
                                fileManager.createFile(atPath: targetURL.path, contents: Data())
                            }
                            processedBytes += Int64(item.info.size ?? 0)
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
        let zipFallback = ZipEngine()
        return zipFallback.create(at: destinationArchiveURL, from: sourceURLs, options: options)
    }
}
