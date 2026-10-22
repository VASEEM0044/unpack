import Foundation

/// Core contract for archive format handling, listing, streaming extraction, and creation.
public protocol ArchiveEngine: Sendable {
    /// Format identifier associated with this engine.
    var supportedFormats: Set<ArchiveFormat> { get }

    /// Inspects the archive table of contents without decompressing payload bodies to disk.
    func listContents(at archiveURL: URL, password: String?) async throws -> [ArchiveEntry]

    /// Streams extraction to the destination directory, emitting real-time progress.
    func extract(
        from archiveURL: URL,
        to destinationDirectory: URL,
        options: ExtractionOptions
    ) -> AsyncThrowingStream<ExtractionProgress, Error>

    /// Creates an archive from source files/directories, emitting real-time progress.
    func create(
        at destinationArchiveURL: URL,
        from sourceURLs: [URL],
        options: CompressionOptions
    ) -> AsyncThrowingStream<ExtractionProgress, Error>
}
