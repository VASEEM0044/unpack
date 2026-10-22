import Foundation
import Compression

/// TAR engine supporting POSIX ustar, GNU TAR, and compressed variants (GZ, BZ2, XZ).
public final class TarEngine: ArchiveEngine, @unchecked Sendable {
    public let supportedFormats: Set<ArchiveFormat> = [
        .tar, .tarGz, .tarBz2, .tarXz, .gz, .bz2, .xz
    ]

    public init() {}

    public func listContents(at archiveURL: URL, password: String?) async throws -> [ArchiveEntry] {
        let streamURL = try resolveDecompressedStreamURL(archiveURL: archiveURL)
        defer {
            if streamURL != archiveURL {
                try? FileManager.default.removeItem(at: streamURL)
            }
        }

        let fileHandle = try FileHandle(forReadingFrom: streamURL)
        defer { try? fileHandle.close() }

        var entries: [ArchiveEntry] = []
        let blockSize = 512

        while true {
            guard let block = try fileHandle.read(upToCount: blockSize), block.count == blockSize else { break }

            // Two consecutive zero blocks indicate end of archive
            if block.allSatisfy({ $0 == 0 }) {
                if let nextBlock = try? fileHandle.read(upToCount: blockSize), nextBlock.allSatisfy({ $0 == 0 }) {
                    break
                }
                continue
            }

            guard let rawName = extractString(from: block, offset: 0, length: 100), !rawName.isEmpty else {
                continue
            }

            let typeFlag = Character(UnicodeScalar(block[156]))
            let size = extractOctal(from: block, offset: 124, length: 12)
            let isDir = typeFlag == "5" || rawName.hasSuffix("/")

            let sanitized = PathSanitizer.sanitize(entryPath: rawName)
            if !sanitized.isEmpty {
                entries.append(ArchiveEntry(
                    path: sanitized,
                    isDirectory: isDir,
                    uncompressedSize: size,
                    compressedSize: size,
                    modificationDate: Date()
                ))
            }

            // Skip payload blocks (rounded up to 512 bytes)
            if size > 0 && !isDir {
                let padding = (blockSize - (Int(size) % blockSize)) % blockSize
                let totalSkip = UInt64(size + Int64(padding))
                try fileHandle.seek(toOffset: try fileHandle.offset() + totalSkip)
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
                    let fileManager = FileManager.default
                    try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

                    let streamURL = try self.resolveDecompressedStreamURL(archiveURL: archiveURL)
                    defer {
                        if streamURL != archiveURL {
                            try? fileManager.removeItem(at: streamURL)
                        }
                    }

                    let fileHandle = try FileHandle(forReadingFrom: streamURL)
                    defer { try? fileHandle.close() }

                    let entries = try await self.listContents(at: archiveURL, password: options.password)
                    let totalBytes = entries.reduce(0) { $0 + $1.uncompressedSize }
                    let totalFiles = entries.filter { !$0.isDirectory }.count

                    var processedBytes: Int64 = 0
                    var processedFiles = 0
                    let startTime = Date()
                    let blockSize = 512

                    while !Task.isCancelled {
                        guard let block = try fileHandle.read(upToCount: blockSize), block.count == blockSize else { break }

                        if block.allSatisfy({ $0 == 0 }) {
                            if let nextBlock = try? fileHandle.read(upToCount: blockSize), nextBlock.allSatisfy({ $0 == 0 }) {
                                break
                            }
                            continue
                        }

                        guard let rawName = extractString(from: block, offset: 0, length: 100), !rawName.isEmpty else {
                            continue
                        }

                        let typeFlag = Character(UnicodeScalar(block[156]))
                        let size = extractOctal(from: block, offset: 124, length: 12)
                        let isDir = typeFlag == "5" || rawName.hasSuffix("/")
                        let sanitized = PathSanitizer.sanitize(entryPath: rawName)

                        if let selected = options.selectedEntryPaths, !selected.contains(sanitized) {
                            if size > 0 && !isDir {
                                let padding = (blockSize - (Int(size) % blockSize)) % blockSize
                                try fileHandle.seek(toOffset: try fileHandle.offset() + UInt64(size + Int64(padding)))
                            }
                            continue
                        }

                        let targetURL = try ZipSlipGuard.validateAndResolve(
                            entryPath: sanitized,
                            destinationDirectory: destinationDirectory
                        )

                        if isDir {
                            try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
                        } else {
                            try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)

                            // Stream file contents
                            if fileManager.fileExists(atPath: targetURL.path) && options.overwritePolicy == .skip {
                                let padding = (blockSize - (Int(size) % blockSize)) % blockSize
                                try fileHandle.seek(toOffset: try fileHandle.offset() + UInt64(size + Int64(padding)))
                                continue
                            }

                            fileManager.createFile(atPath: targetURL.path, contents: nil)
                            if let outHandle = try? FileHandle(forWritingTo: targetURL) {
                                var bytesRemaining = size
                                while bytesRemaining > 0 {
                                    let chunk = min(Int64(65536), bytesRemaining)
                                    guard let data = try fileHandle.read(upToCount: Int(chunk)) else { break }
                                    try outHandle.write(contentsOf: data)
                                    bytesRemaining -= Int64(data.count)
                                }
                                try? outHandle.close()

                                // Skip padding block alignment
                                let padding = (blockSize - (Int(size) % blockSize)) % blockSize
                                if padding > 0 {
                                    try fileHandle.seek(toOffset: try fileHandle.offset() + UInt64(padding))
                                }
                            }
                            processedBytes += size
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
                        try fileManager.removeItem(at: destinationArchiveURL)
                    }

                    fileManager.createFile(atPath: destinationArchiveURL.path, contents: nil)
                    guard let handle = try? FileHandle(forWritingTo: destinationArchiveURL) else {
                        throw ArchiveSecurityError.corruptArchive(message: "Failed to open destination TAR archive.")
                    }
                    defer { try? handle.close() }

                    var allFiles: [URL] = []
                    for source in sourceURLs {
                        if (try? source.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                            let enumerator = fileManager.enumerator(at: source, includingPropertiesForKeys: nil)
                            while let item = enumerator?.nextObject() as? URL {
                                allFiles.append(item)
                            }
                        } else {
                            allFiles.append(source)
                        }
                    }

                    for (index, fileURL) in allFiles.enumerated() {
                        let relPath = fileURL.lastPathComponent
                        let data = (try? Data(contentsOf: fileURL)) ?? Data()

                        var header = [UInt8](repeating: 0, count: 512)
                        // Name
                        let nameBytes = [UInt8](relPath.utf8.prefix(100))
                        header.replaceSubrange(0..<nameBytes.count, with: nameBytes)
                        // Mode (0644)
                        let mode = "0000644\0"
                        header.replaceSubrange(100..<108, with: [UInt8](mode.utf8))
                        // Size (octal)
                        let sizeOctal = String(format: "%011o\0", data.count)
                        header.replaceSubrange(124..<136, with: [UInt8](sizeOctal.utf8))
                        // Ustar magic
                        let magic = "ustar\000"
                        header.replaceSubrange(257..<265, with: [UInt8](magic.utf8))

                        // Checksum
                        var chksum: UInt32 = 0
                        for i in 0..<512 {
                            chksum += (i >= 148 && i < 156) ? 32 : UInt32(header[i])
                        }
                        let chkStr = String(format: "%06o\0 ", chksum)
                        header.replaceSubrange(148..<156, with: [UInt8](chkStr.utf8))

                        try handle.write(contentsOf: Data(header))
                        if !data.isEmpty {
                            try handle.write(contentsOf: data)
                            let pad = (512 - (data.count % 512)) % 512
                            if pad > 0 {
                                try handle.write(contentsOf: Data(repeating: 0, count: pad))
                            }
                        }

                        continuation.yield(ExtractionProgress(
                            bytesProcessed: Int64(data.count),
                            totalBytes: Int64(data.count * allFiles.count),
                            filesProcessed: index + 1,
                            totalFiles: allFiles.count,
                            currentFilename: relPath,
                            fractionCompleted: Double(index + 1) / Double(allFiles.count)
                        ))
                    }

                    // Write 1024 zero bytes trailer
                    try handle.write(contentsOf: Data(repeating: 0, count: 1024))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func resolveDecompressedStreamURL(archiveURL: URL) throws -> URL {
        let ext = archiveURL.pathExtension.lowercased()
        if ext == "tar" { return archiveURL }

        // If compressed (.gz, .tgz, etc), stream decompress to temporary raw TAR
        let tempTAR = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tar")
        let inData = try Data(contentsOf: archiveURL)

        var decompressed = Data(count: inData.count * 4)
        let decodedSize = decompressed.withUnsafeMutableBytes { outBuf in
            inData.withUnsafeBytes { inBuf in
                compression_decode_buffer(
                    outBuf.bindMemory(to: UInt8.self).baseAddress!,
                    outBuf.count,
                    inBuf.bindMemory(to: UInt8.self).baseAddress!,
                    inData.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        if decodedSize > 0 {
            decompressed.count = decodedSize
            try decompressed.write(to: tempTAR)
            return tempTAR
        }

        return archiveURL
    }

    private func extractString(from block: Data, offset: Int, length: Int) -> String? {
        let sub = block.subdata(in: offset..<(offset + length))
        let nullTerminated = sub.prefix(while: { $0 != 0 })
        return String(data: nullTerminated, encoding: .utf8) ?? String(data: nullTerminated, encoding: .ascii)
    }

    private func extractOctal(from block: Data, offset: Int, length: Int) -> Int64 {
        guard let str = extractString(from: block, offset: offset, length: length)?
            .trimmingCharacters(in: .whitespacesAndNewlines) else { return 0 }
        return Int64(str, radix: 8) ?? 0
    }
}
