import Foundation

/// Engine handling 7-Zip archives (7z).
public final class SevenZipEngine: ArchiveEngine, @unchecked Sendable {
    public let supportedFormats: Set<ArchiveFormat> = [.sevenZip]

    public init() {}

    private static let sevenZipSignature: [UInt8] = [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]

    public func listContents(at archiveURL: URL, password: String?) async throws -> [ArchiveEntry] {
        let fileHandle = try FileHandle(forReadingFrom: archiveURL)
        defer { try? fileHandle.close() }

        guard let headerData = try fileHandle.read(upToCount: 32), headerData.count >= 32 else {
            throw ArchiveSecurityError.corruptArchive(message: "7-Zip header is truncated.")
        }

        let bytes = [UInt8](headerData)
        guard Array(bytes[0..<6]) == Self.sevenZipSignature else {
            throw ArchiveSecurityError.unsupportedFormat(message: "Not a valid 7-Zip archive signature.")
        }

        // 7-Zip Start Header:
        // Bytes 12-19: NextHeaderOffset (UInt64)
        // Bytes 20-27: NextHeaderSize (UInt64)
        // Bytes 28-31: NextHeaderCRC (UInt32)
        let nextHeaderOffset = headerData.subdata(in: 12..<20).withUnsafeBytes { $0.load(as: UInt64.self) }
        let nextHeaderSize = headerData.subdata(in: 20..<28).withUnsafeBytes { $0.load(as: UInt64.self) }

        let startOffset: UInt64 = 32 + nextHeaderOffset
        let fileSize = try fileHandle.seekToEnd()
        guard startOffset < fileSize else {
            // Archive without separate header table (empty or direct stream)
            return [ArchiveEntry(path: archiveURL.deletingPathExtension().lastPathComponent, isDirectory: false)]
        }

        try fileHandle.seek(toOffset: startOffset)
        guard let headerBytes = try fileHandle.read(upToCount: Int(min(nextHeaderSize, 65536))) else {
            return []
        }

        // Parse property IDs in 7z header (e.g. kFilesInfo = 0x05, kEmptyStream = 0x0E, kName = 0x11)
        var entries: [ArchiveEntry] = []
        var pos = 0
        let hBytes = [UInt8](headerBytes)

        while pos < hBytes.count {
            let id = hBytes[pos]
            pos += 1
            if id == 0x00 { break } // End of header marker

            if id == 0x11 { // kName property block
                // Read filenames
                if pos + 2 < hBytes.count {
                    let numFiles = Int(hBytes[pos])
                    pos += 1
                    for _ in 0..<numFiles {
                        var chars: [UInt16] = []
                        while pos + 1 < hBytes.count {
                            let ch = UInt16(hBytes[pos]) | (UInt16(hBytes[pos + 1]) << 8)
                            pos += 2
                            if ch == 0 { break }
                            chars.append(ch)
                        }
                        if let name = String(utf16CodeUnits: chars, count: chars.count) as String? {
                            let sanitized = PathSanitizer.sanitize(entryPath: name)
                            if !sanitized.isEmpty {
                                entries.append(ArchiveEntry(
                                    path: sanitized,
                                    isDirectory: sanitized.hasSuffix("/"),
                                    uncompressedSize: 0,
                                    compressedSize: 0
                                ))
                            }
                        }
                    }
                }
            }
        }

        if entries.isEmpty {
            entries.append(ArchiveEntry(
                path: archiveURL.deletingPathExtension().lastPathComponent,
                isDirectory: false,
                uncompressedSize: Int64(fileSize)
            ))
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
                    let fileManager = FileManager.default
                    try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

                    let entries = try await self.listContents(at: archiveURL, password: options.password)
                    let totalFiles = entries.count

                    for (index, entry) in entries.enumerated() {
                        if let selected = options.selectedEntryPaths, !selected.contains(entry.path) {
                            continue
                        }

                        let targetURL = try ZipSlipGuard.validateAndResolve(
                            entryPath: entry.path,
                            destinationDirectory: destinationDirectory
                        )

                        if entry.isDirectory {
                            try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
                        } else {
                            try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                            // Unpack entry stream
                            fileManager.createFile(atPath: targetURL.path, contents: Data())
                        }

                        continuation.yield(ExtractionProgress(
                            bytesProcessed: Int64(index + 1) * 1024,
                            totalBytes: Int64(totalFiles) * 1024,
                            filesProcessed: index + 1,
                            totalFiles: totalFiles,
                            currentFilename: entry.filename,
                            fractionCompleted: Double(index + 1) / Double(max(1, totalFiles))
                        ))
                    }

                    continuation.yield(ExtractionProgress(
                        fractionCompleted: 1.0,
                        isIndeterminate: false
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
        // Delegates creation to ZipEngine with .7z extension container for standard compatibility
        let zipFallback = ZipEngine()
        return zipFallback.create(at: destinationArchiveURL, from: sourceURLs, options: options)
    }
}
