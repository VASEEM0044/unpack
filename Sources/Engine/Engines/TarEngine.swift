import Foundation
import SWCompression

/// Production TAR, GZ, BZ2, and XZ engine powered by SWCompression.
public final class TarEngine: ArchiveEngine, @unchecked Sendable {
    public let supportedFormats: Set<ArchiveFormat> = [
        .tar, .tarGz, .tarBz2, .tarXz, .gz, .bz2, .xz
    ]

    public init() {}

    public func listContents(at archiveURL: URL, password: String?) async throws -> [ArchiveEntry] {
        let rawData = try Data(contentsOf: archiveURL, options: .mappedIfSafe)
        let tarData = try decompressToTarIfNeeded(archiveURL: archiveURL, data: rawData)

        let infos = try TarContainer.info(container: tarData)
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
                    let rawData = try Data(contentsOf: archiveURL, options: .mappedIfSafe)
                    let tarData = try self.decompressToTarIfNeeded(archiveURL: archiveURL, data: rawData)
                    let items = try TarContainer.open(container: tarData)

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
                            if let data = item.data {
                                try data.write(to: targetURL)
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

    private func decompressToTarIfNeeded(archiveURL: URL, data: Data) throws -> Data {
        let ext = archiveURL.pathExtension.lowercased()
        let name = archiveURL.lastPathComponent.lowercased()

        if name.hasSuffix(".tar.gz") || ext == "tgz" || ext == "gz" {
            return try GzipArchive.unarchive(archive: data)
        } else if name.hasSuffix(".tar.bz2") || ext == "tbz2" || ext == "bz2" {
            return try BZip2.decompress(data: data)
        } else if name.hasSuffix(".tar.xz") || ext == "txz" || ext == "xz" {
            return try XZArchive.unarchive(archive: data)
        }
        return data
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
