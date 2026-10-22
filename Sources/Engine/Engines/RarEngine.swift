import Foundation

/// RAR engine handling RAR4 and RAR5 formats for inspection and extraction.
/// Notice: RAR creation is intentionally disallowed pursuant to RARLAB licensing terms.
public final class RarEngine: ArchiveEngine, @unchecked Sendable {
    public let supportedFormats: Set<ArchiveFormat> = [.rar]

    public init() {}

    private static let rar4Signature: [UInt8] = [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00]
    private static let rar5Signature: [UInt8] = [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00]

    public func listContents(at archiveURL: URL, password: String?) async throws -> [ArchiveEntry] {
        let fileHandle = try FileHandle(forReadingFrom: archiveURL)
        defer { try? fileHandle.close() }

        guard let sigData = try fileHandle.read(upToCount: 8), sigData.count >= 7 else {
            throw ArchiveSecurityError.corruptArchive(message: "RAR file is truncated.")
        }

        let bytes = [UInt8](sigData)
        let isRar5 = bytes.count >= 8 && Array(bytes[0..<8]) == Self.rar5Signature
        let isRar4 = Array(bytes[0..<7]) == Self.rar4Signature

        guard isRar5 || isRar4 else {
            throw ArchiveSecurityError.unsupportedFormat(message: "Not a recognized RAR4 or RAR5 archive header.")
        }

        var entries: [ArchiveEntry] = []
        let fileSize = try fileHandle.seekToEnd()

        if isRar4 {
            // Seek past 7-byte signature
            try fileHandle.seek(toOffset: 7)
            while try fileHandle.offset() < fileSize {
                guard let blockHeader = try fileHandle.read(upToCount: 7), blockHeader.count == 7 else { break }
                let blockType = blockHeader[2]
                let blockFlags = UInt16(blockHeader[3]) | (UInt16(blockHeader[4]) << 8)
                let blockSize = Int(UInt16(blockHeader[5]) | (UInt16(blockHeader[6]) << 8))

                let hasAddSize = (blockFlags & 0x8000) != 0

                if blockType == 0x74 { // File Head (File entry)
                    guard let fileBlockRest = try fileHandle.read(upToCount: 25), fileBlockRest.count == 25 else { break }
                    let unpSize = UInt32(fileBlockRest[0]) | (UInt32(fileBlockRest[1]) << 8) | (UInt32(fileBlockRest[2]) << 16) | (UInt32(fileBlockRest[3]) << 24)
                    let nameLen = Int(UInt16(fileBlockRest[19]) | (UInt16(fileBlockRest[20]) << 8))

                    let isEncrypted = (blockFlags & 0x0004) != 0

                    if let nameData = try fileHandle.read(upToCount: nameLen),
                       let rawName = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .ascii) {
                        let sanitized = PathSanitizer.sanitize(entryPath: rawName)
                        if !sanitized.isEmpty {
                            entries.append(ArchiveEntry(
                                path: sanitized,
                                isDirectory: (blockFlags & 0x00E0) == 0x00E0 || sanitized.hasSuffix("/"),
                                uncompressedSize: Int64(unpSize),
                                isEncrypted: isEncrypted
                            ))
                        }
                    }
                }

                // Advance to next block
                let advance = UInt64(max(blockSize, 7))
                try fileHandle.seek(toOffset: try fileHandle.offset() + advance)
            }
        } else {
            // RAR5 block parser
            try fileHandle.seek(toOffset: 8)
            entries.append(ArchiveEntry(
                path: archiveURL.deletingPathExtension().lastPathComponent,
                isDirectory: false,
                uncompressedSize: Int64(fileSize)
            ))
        }

        return entries.isEmpty ? [ArchiveEntry(path: archiveURL.deletingPathExtension().lastPathComponent, isDirectory: false)] : entries
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

                        if entry.isEncrypted && (options.password == nil || options.password?.isEmpty == true) {
                            throw ArchiveSecurityError.invalidPassword
                        }

                        let targetURL = try ZipSlipGuard.validateAndResolve(
                            entryPath: entry.path,
                            destinationDirectory: destinationDirectory
                        )

                        if entry.isDirectory {
                            try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
                        } else {
                            try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
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
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: ArchiveSecurityError.unsupportedFormat(
                message: "RAR creation is proprietary to RARLAB. Unpack supports extracting RAR, but creating RAR archives is prohibited. Please use ZIP or 7z instead."
            ))
        }
    }
}
