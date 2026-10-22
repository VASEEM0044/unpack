import Foundation

/// Unified actor responsible for archive dispatch, security pipeline enforcement, and progress streaming.
public actor ArchiveCoordinator {
    public static let shared = ArchiveCoordinator()

    private let zipEngine = ZipEngine()
    private let tarEngine = TarEngine()
    private let sevenZipEngine = SevenZipEngine()
    private let rarEngine = RarEngine()

    private init() {}

    /// Dispatches inspection to the engine matching the detected archive signature.
    public func inspect(archiveURL: URL, password: String? = nil) async throws -> (format: ArchiveFormat, entries: [ArchiveEntry]) {
        let format = ArchiveFormat.detect(at: archiveURL)
        let engine = try resolveEngine(for: format)
        let entries = try await engine.listContents(at: archiveURL, password: password)
        return (format, entries)
    }

    /// Coordinates full or selective extraction through the security wall.
    public func extract(
        archiveURL: URL,
        options: ExtractionOptions,
        bombGuard: ZipBombGuard = ZipBombGuard()
    ) -> AsyncThrowingStream<ExtractionProgress, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let format = ArchiveFormat.detect(at: archiveURL)
                    let engine = try self.resolveEngine(for: format)

                    // 1. Inspect table of contents for security pre-flight
                    let entries = try await engine.listContents(at: archiveURL, password: options.password)
                    bombGuard.reset()

                    var totalRequiredBytes: Int64 = 0
                    for entry in entries {
                        try bombGuard.validateEntryMetadata(
                            uncompressedSize: entry.uncompressedSize,
                            compressedSize: entry.compressedSize
                        )
                        totalRequiredBytes += entry.uncompressedSize
                    }

                    // 2. Compute destination folder (supporting subfolder creation if requested)
                    var targetDestination = options.destinationDirectory
                    if options.createSubfolder {
                        let subfolderName = archiveURL.deletingPathExtension().lastPathComponent
                        targetDestination = targetDestination.appendingPathComponent(subfolderName, isDirectory: true)
                    }

                    // 3. Verify host volume storage headroom
                    try DiskSpaceAssurance.verifyAvailableSpace(
                        requiredBytes: totalRequiredBytes,
                        at: targetDestination
                    )

                    // 4. Stream extraction with live progress
                    var adjustedOptions = options
                    adjustedOptions.destinationDirectory = targetDestination

                    let stream = engine.extract(
                        from: archiveURL,
                        to: targetDestination,
                        options: adjustedOptions
                    )

                    for try await progress in stream {
                        if Task.isCancelled { break }
                        try bombGuard.recordStreamChunk(bytes: progress.bytesProcessed)
                        continuation.yield(progress)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Coordinates compression into a new archive.
    public func createArchive(
        destinationURL: URL,
        sources: [URL],
        options: CompressionOptions
    ) -> AsyncThrowingStream<ExtractionProgress, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let engine = try self.resolveEngine(for: options.format)
                    let stream = engine.create(
                        at: destinationURL,
                        from: sources,
                        options: options
                    )
                    for try await progress in stream {
                        continuation.yield(progress)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func resolveEngine(for format: ArchiveFormat) throws -> any ArchiveEngine {
        switch format {
        case .zip:
            return zipEngine
        case .tar, .tarGz, .tarBz2, .tarXz, .gz, .bz2, .xz:
            return tarEngine
        case .sevenZip:
            return sevenZipEngine
        case .rar:
            return rarEngine
        case .iso, .cab:
            // Fallback to Tar/Generic reader
            return tarEngine
        case .unknown:
            throw ArchiveSecurityError.unsupportedFormat(message: "The file does not match any recognized archive signature.")
        }
    }
}
