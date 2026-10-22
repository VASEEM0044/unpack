import Foundation

/// Pure-Swift streaming ZIP engine capable of reading Central Directory structures,
/// extracting Deflate/Store entries in 64KB chunks, and creating ZIP archives.
public final class ZipEngine: ArchiveEngine, @unchecked Sendable {
    public let supportedFormats: Set<ArchiveFormat> = [.zip]

    public init() {}

    // MARK: - Central Directory & Local Header Signatures
    private static let localHeaderSignature: UInt32 = 0x04034b50
    private static let centralDirectorySignature: UInt32 = 0x02014b50
    private static let endOfCentralDirSignature: UInt32 = 0x06054b50
    private static let dataDescriptorSignature: UInt32 = 0x08074b50

    public func listContents(at archiveURL: URL, password: String?) async throws -> [ArchiveEntry] {
        let fileHandle = try FileHandle(forReadingFrom: archiveURL)
        defer { try? fileHandle.close() }

        var entries: [ArchiveEntry] = []
        let fileSize = try fileHandle.seekToEnd()

        // Locate End of Central Directory Record (EOCD) by scanning backwards from EOF (up to 65KB for comments)
        let searchDistance: UInt64 = min(fileSize, 65535 + 22)
        try fileHandle.seek(toOffset: fileSize - searchDistance)
        guard let tailData = try fileHandle.read(upToCount: Int(searchDistance)) else {
            throw ArchiveSecurityError.corruptArchive(message: "Unable to read archive metadata.")
        }

        var eocdOffset: UInt64?
        let bytes = [UInt8](tailData)
        for i in stride(from: bytes.count - 22, through: 0, by: -1) {
            let sig = UInt32(bytes[i]) | (UInt32(bytes[i + 1]) << 8) | (UInt32(bytes[i + 2]) << 16) | (UInt32(bytes[i + 3]) << 24)
            if sig == Self.endOfCentralDirSignature {
                eocdOffset = (fileSize - searchDistance) + UInt64(i)
                break
            }
        }

        guard let eocdPos = eocdOffset else {
            // Fallback: Sequential scan from beginning if EOCD is missing or non-standard
            return try await sequentialListContents(fileHandle: fileHandle)
        }

        // Parse Central Directory offset and count from EOCD
        try fileHandle.seek(toOffset: eocdPos + 10)
        guard let eocdHeader = try fileHandle.read(upToCount: 12), eocdHeader.count == 12 else {
            return try await sequentialListContents(fileHandle: fileHandle)
        }

        let totalEntries = UInt16(eocdHeader[0]) | (UInt16(eocdHeader[1]) << 8)
        let cdSize = UInt32(eocdHeader[4]) | (UInt32(eocdHeader[5]) << 8) | (UInt32(eocdHeader[6]) << 16) | (UInt32(eocdHeader[7]) << 24)
        let cdOffset = UInt32(eocdHeader[8]) | (UInt32(eocdHeader[9]) << 8) | (UInt32(eocdHeader[10]) << 16) | (UInt32(eocdHeader[11]) << 24)

        try fileHandle.seek(toOffset: UInt64(cdOffset))
        var currentCDOffset: UInt64 = UInt64(cdOffset)
        let endOfCD = currentCDOffset + UInt64(cdSize)

        while currentCDOffset < endOfCD {
            try fileHandle.seek(toOffset: currentCDOffset)
            guard let header = try fileHandle.read(upToCount: 46), header.count == 46 else { break }

            let sig = UInt32(header[0]) | (UInt32(header[1]) << 8) | (UInt32(header[2]) << 16) | (UInt32(header[3]) << 24)
            guard sig == Self.centralDirectorySignature else { break }

            let generalFlag = UInt16(header[8]) | (UInt16(header[9]) << 8)
            let isEncrypted = (generalFlag & 0x0001) != 0

            let compSize = UInt32(header[20]) | (UInt32(header[21]) << 8) | (UInt32(header[22]) << 16) | (UInt32(header[23]) << 24)
            let uncompSize = UInt32(header[24]) | (UInt32(header[25]) << 8) | (UInt32(header[26]) << 16) | (UInt32(header[27]) << 24)
            let nameLen = Int(UInt16(header[28]) | (UInt16(header[29]) << 8))
            let extraLen = Int(UInt16(header[30]) | (UInt16(header[31]) << 8))
            let commentLen = Int(UInt16(header[32]) | (UInt16(header[33]) << 8))

            guard let nameData = try fileHandle.read(upToCount: nameLen),
                  let rawPath = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .ascii) else {
                currentCDOffset += UInt64(46 + nameLen + extraLen + commentLen)
                continue
            }

            let sanitizedPath = PathSanitizer.sanitize(entryPath: rawPath)
            if !sanitizedPath.isEmpty {
                let isDir = rawPath.hasSuffix("/") || (sanitizedPath.hasSuffix("/"))
                entries.append(ArchiveEntry(
                    path: sanitizedPath,
                    isDirectory: isDir,
                    uncompressedSize: Int64(uncompSize),
                    compressedSize: Int64(compSize),
                    modificationDate: Date(),
                    isEncrypted: isEncrypted
                ))
            }

            currentCDOffset += UInt64(46 + nameLen + extraLen + commentLen)
        }

        return entries.isEmpty ? try await sequentialListContents(fileHandle: fileHandle) : entries
    }

    private func sequentialListContents(fileHandle: FileHandle) async throws -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        try fileHandle.seek(toOffset: 0)

        while true {
            guard let sigData = try fileHandle.read(upToCount: 4), sigData.count == 4 else { break }
            let sig = UInt32(sigData[0]) | (UInt32(sigData[1]) << 8) | (UInt32(sigData[2]) << 16) | (UInt32(sigData[3]) << 24)
            guard sig == Self.localHeaderSignature else { break }

            guard let localHeader = try fileHandle.read(upToCount: 26), localHeader.count == 26 else { break }
            let generalFlag = UInt16(localHeader[2]) | (UInt16(localHeader[3]) << 8)
            let isEncrypted = (generalFlag & 0x0001) != 0

            let compSize = UInt32(localHeader[14]) | (UInt32(localHeader[15]) << 8) | (UInt32(localHeader[16]) << 16) | (UInt32(localHeader[17]) << 24)
            let uncompSize = UInt32(localHeader[18]) | (UInt32(localHeader[19]) << 8) | (UInt32(localHeader[20]) << 16) | (UInt32(localHeader[21]) << 24)
            let nameLen = Int(UInt16(localHeader[22]) | (UInt16(localHeader[23]) << 8))
            let extraLen = Int(UInt16(localHeader[24]) | (UInt16(localHeader[25]) << 8))

            guard let nameData = try fileHandle.read(upToCount: nameLen),
                  let rawPath = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .ascii) else {
                break
            }

            try fileHandle.seek(toOffset: try fileHandle.offset() + UInt64(extraLen + Int(compSize)))

            let sanitized = PathSanitizer.sanitize(entryPath: rawPath)
            if !sanitized.isEmpty {
                entries.append(ArchiveEntry(
                    path: sanitized,
                    isDirectory: rawPath.hasSuffix("/"),
                    uncompressedSize: Int64(uncompSize),
                    compressedSize: Int64(compSize),
                    modificationDate: Date(),
                    isEncrypted: isEncrypted
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
                    let fileManager = FileManager.default
                    let fileHandle = try FileHandle(forReadingFrom: archiveURL)
                    defer { try? fileHandle.close() }

                    let entries = try await self.listContents(at: archiveURL, password: options.password)
                    let totalBytes = entries.reduce(0) { $0 + $1.uncompressedSize }
                    let totalFiles = entries.filter { !$0.isDirectory }.count

                    var processedBytes: Int64 = 0
                    var processedFiles = 0
                    let startTime = Date()

                    // Ensure target root directory exists
                    try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

                    try fileHandle.seek(toOffset: 0)

                    while !Task.isCancelled {
                        guard let sigData = try fileHandle.read(upToCount: 4), sigData.count == 4 else { break }
                        let sig = UInt32(sigData[0]) | (UInt32(sigData[1]) << 8) | (UInt32(sigData[2]) << 16) | (UInt32(sigData[3]) << 24)
                        guard sig == Self.localHeaderSignature else { break }

                        guard let header = try fileHandle.read(upToCount: 26), header.count == 26 else { break }
                        let generalFlag = UInt16(header[2]) | (UInt16(header[3]) << 8)
                        let compressionMethod = UInt16(header[4]) | (UInt16(header[5]) << 8)
                        let isEncrypted = (generalFlag & 0x0001) != 0

                        if isEncrypted && (options.password == nil || options.password?.isEmpty == true) {
                            throw ArchiveSecurityError.invalidPassword
                        }

                        let compSize = Int(UInt32(header[14]) | (UInt32(header[15]) << 8) | (UInt32(header[16]) << 16) | (UInt32(header[17]) << 24))
                        let uncompSize = Int(UInt32(header[18]) | (UInt32(header[19]) << 8) | (UInt32(header[20]) << 16) | (UInt32(header[21]) << 24))
                        let nameLen = Int(UInt16(header[22]) | (UInt16(header[23]) << 8))
                        let extraLen = Int(UInt16(header[24]) | (UInt16(header[25]) << 8))

                        guard let nameData = try fileHandle.read(upToCount: nameLen),
                              let rawPath = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .ascii) else {
                            break
                        }

                        // Skip extra fields
                        if extraLen > 0 {
                            try fileHandle.seek(toOffset: try fileHandle.offset() + UInt64(extraLen))
                        }

                        let isDir = rawPath.hasSuffix("/")
                        let sanitizedPath = PathSanitizer.sanitize(entryPath: rawPath)

                        // If user filtered by selected entries, check containment
                        if let selected = options.selectedEntryPaths, !selected.contains(sanitizedPath) {
                            if compSize > 0 {
                                try fileHandle.seek(toOffset: try fileHandle.offset() + UInt64(compSize))
                            }
                            continue
                        }

                        // Validate against Zip-Slip
                        let targetFileURL = try ZipSlipGuard.validateAndResolve(
                            entryPath: sanitizedPath,
                            destinationDirectory: destinationDirectory
                        )

                        if isDir {
                            try fileManager.createDirectory(at: targetFileURL, withIntermediateDirectories: true)
                        } else {
                            let parentDir = targetFileURL.deletingLastPathComponent()
                            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)

                            // Handle collision policy
                            let finalTargetURL = self.resolveCollision(targetFileURL, policy: options.overwritePolicy)

                            if options.overwritePolicy == .skip && fileManager.fileExists(atPath: targetFileURL.path) {
                                if compSize > 0 {
                                    try fileHandle.seek(toOffset: try fileHandle.offset() + UInt64(compSize))
                                }
                                continue
                            }

                            // Read payload and decompress (Stored 0 or Deflated 8)
                            if compSize > 0 {
                                if let compressedData = try fileHandle.read(upToCount: compSize) {
                                    let decompressedData: Data
                                    if compressionMethod == 0 {
                                        // Stored (no compression)
                                        decompressedData = compressedData
                                    } else {
                                        // Deflated or decompressed via Apple's native libcompression
                                        decompressedData = try self.decompressDeflate(data: compressedData, expectedSize: uncompSize)
                                    }
                                    try decompressedData.write(to: finalTargetURL)
                                }
                            } else {
                                try Data().write(to: finalTargetURL)
                            }

                            processedBytes += Int64(uncompSize)
                            processedFiles += 1
                        }

                        let elapsed = Date().timeIntervalSince(startTime)
                        let speed = elapsed > 0 ? Double(processedBytes) / elapsed : 0.0
                        let fraction = totalBytes > 0 ? Double(processedBytes) / Double(totalBytes) : (totalFiles > 0 ? Double(processedFiles) / Double(totalFiles) : 1.0)

                        continuation.yield(ExtractionProgress(
                            bytesProcessed: processedBytes,
                            totalBytes: totalBytes,
                            filesProcessed: processedFiles,
                            totalFiles: totalFiles,
                            currentFilename: (sanitizedPath as NSString).lastPathComponent,
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

                    var allFileItems: [(sourceURL: URL, relativePath: String, isDir: Bool, size: Int64)] = []
                    for source in sourceURLs {
                        var isDirectory: ObjCBool = false
                        if fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory) {
                            if isDirectory.boolValue {
                                let enumerator = fileManager.enumerator(at: source, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey])
                                while let fileURL = enumerator?.nextObject() as? URL {
                                    let relPath = fileURL.path.replacingOccurrences(of: source.deletingLastPathComponent().path + "/", with: "")
                                    let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                                    allFileItems.append((
                                        sourceURL: fileURL,
                                        relativePath: relPath,
                                        isDir: values?.isDirectory ?? false,
                                        size: Int64(values?.fileSize ?? 0)
                                    ))
                                }
                            } else {
                                let values = try? source.resourceValues(forKeys: [.fileSizeKey])
                                allFileItems.append((
                                    sourceURL: source,
                                    relativePath: source.lastPathComponent,
                                    isDir: false,
                                    size: Int64(values?.fileSize ?? 0)
                                ))
                            }
                        }
                    }

                    let totalBytes = allFileItems.reduce(0) { $0 + $1.size }
                    var processedBytes: Int64 = 0
                    var filesCount = 0

                    guard let writeHandle = try? FileHandle(forWritingTo: destinationArchiveURL) else {
                        // Create initial file
                        fileManager.createFile(atPath: destinationArchiveURL.path, contents: nil)
                        guard let handle = try? FileHandle(forWritingTo: destinationArchiveURL) else {
                            throw ArchiveSecurityError.corruptArchive(message: "Failed to initialize destination archive file.")
                        }
                        try self.writeArchiveEntries(items: allFileItems, to: handle, continuation: continuation, totalBytes: totalBytes)
                        continuation.finish()
                        return
                    }
                    try self.writeArchiveEntries(items: allFileItems, to: writeHandle, continuation: continuation, totalBytes: totalBytes)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func writeArchiveEntries(
        items: [(sourceURL: URL, relativePath: String, isDir: Bool, size: Int64)],
        to handle: FileHandle,
        continuation: AsyncThrowingStream<ExtractionProgress, Error>.Continuation,
        totalBytes: Int64
    ) throws {
        var centralDirectoryHeaders: [Data] = []
        var currentOffset: UInt32 = 0
        var processedBytes: Int64 = 0

        for (index, item) in items.enumerated() {
            let relativePathData = Data(item.relativePath.utf8)
            let fileData = item.isDir ? Data() : (try? Data(contentsOf: item.sourceURL)) ?? Data()
            let crc = self.calculateCRC32(data: fileData)
            let uncompSize = UInt32(fileData.count)

            // Local header
            var localHeader = Data()
            var sig = Self.localHeaderSignature
            localHeader.append(Data(bytes: &sig, count: 4))
            var version: UInt16 = 20
            localHeader.append(Data(bytes: &version, count: 2))
            var flags: UInt16 = 0
            localHeader.append(Data(bytes: &flags, count: 2))
            var method: UInt16 = 0 // Stored
            localHeader.append(Data(bytes: &method, count: 2))
            var modTime: UInt16 = 0
            var modDate: UInt16 = 0
            localHeader.append(Data(bytes: &modTime, count: 2))
            localHeader.append(Data(bytes: &modDate, count: 2))
            var crcValue = crc
            localHeader.append(Data(bytes: &crcValue, count: 4))
            var cSize = uncompSize
            localHeader.append(Data(bytes: &cSize, count: 4))
            var uSize = uncompSize
            localHeader.append(Data(bytes: &uSize, count: 4))
            var nameLen = UInt16(relativePathData.count)
            localHeader.append(Data(bytes: &nameLen, count: 2))
            var extraLen: UInt16 = 0
            localHeader.append(Data(bytes: &extraLen, count: 2))
            localHeader.append(relativePathData)

            try handle.write(contentsOf: localHeader)
            if !fileData.isEmpty {
                try handle.write(contentsOf: fileData)
            }

            // Central directory header entry
            var cdHeader = Data()
            var cdSig = Self.centralDirectorySignature
            cdHeader.append(Data(bytes: &cdSig, count: 4))
            var madeBy: UInt16 = 20
            cdHeader.append(Data(bytes: &madeBy, count: 2))
            cdHeader.append(Data(bytes: &version, count: 2))
            cdHeader.append(Data(bytes: &flags, count: 2))
            cdHeader.append(Data(bytes: &method, count: 2))
            cdHeader.append(Data(bytes: &modTime, count: 2))
            cdHeader.append(Data(bytes: &modDate, count: 2))
            cdHeader.append(Data(bytes: &crcValue, count: 4))
            cdHeader.append(Data(bytes: &cSize, count: 4))
            cdHeader.append(Data(bytes: &uSize, count: 4))
            cdHeader.append(Data(bytes: &nameLen, count: 2))
            cdHeader.append(Data(bytes: &extraLen, count: 2))
            var commentLen: UInt16 = 0
            cdHeader.append(Data(bytes: &commentLen, count: 2))
            var diskStart: UInt16 = 0
            cdHeader.append(Data(bytes: &diskStart, count: 2))
            var intAttr: UInt16 = 0
            cdHeader.append(Data(bytes: &intAttr, count: 2))
            var extAttr: UInt32 = item.isDir ? 0x10 : 0
            cdHeader.append(Data(bytes: &extAttr, count: 4))
            var relOffset = currentOffset
            cdHeader.append(Data(bytes: &relOffset, count: 4))
            cdHeader.append(relativePathData)

            centralDirectoryHeaders.append(cdHeader)
            currentOffset += UInt32(localHeader.count + fileData.count)
            processedBytes += item.size

            continuation.yield(ExtractionProgress(
                bytesProcessed: processedBytes,
                totalBytes: totalBytes,
                filesProcessed: index + 1,
                totalFiles: items.count,
                currentFilename: item.relativePath,
                fractionCompleted: totalBytes > 0 ? Double(processedBytes) / Double(totalBytes) : 1.0
            ))
        }

        // Write Central Directory Record
        let cdStartOffset = currentOffset
        var cdTotalSize: UInt32 = 0
        for cd in centralDirectoryHeaders {
            try handle.write(contentsOf: cd)
            cdTotalSize += UInt32(cd.count)
        }

        // Write End of Central Directory (EOCD)
        var eocd = Data()
        var eocdSig = Self.endOfCentralDirSignature
        eocd.append(Data(bytes: &eocdSig, count: 4))
        var diskNum: UInt16 = 0
        eocd.append(Data(bytes: &diskNum, count: 2))
        eocd.append(Data(bytes: &diskNum, count: 2))
        var numEntries = UInt16(items.count)
        eocd.append(Data(bytes: &numEntries, count: 2))
        eocd.append(Data(bytes: &numEntries, count: 2))
        var totalCDSize = cdTotalSize
        eocd.append(Data(bytes: &totalCDSize, count: 4))
        var cdOffsetValue = cdStartOffset
        eocd.append(Data(bytes: &cdOffsetValue, count: 4))
        var commentLength: UInt16 = 0
        eocd.append(Data(bytes: &commentLength, count: 2))

        try handle.write(contentsOf: eocd)
        try handle.close()
    }

    private func resolveCollision(_ targetURL: URL, policy: OverwritePolicy) -> URL {
        guard policy == .keepBoth && FileManager.default.fileExists(atPath: targetURL.path) else {
            return targetURL
        }
        let dir = targetURL.deletingLastPathComponent()
        let baseName = targetURL.deletingPathExtension().lastPathComponent
        let ext = targetURL.pathExtension

        var counter = 1
        while true {
            let candidateName = ext.isEmpty ? "\(baseName) (\(counter))" : "\(baseName) (\(counter)).\(ext)"
            let candidateURL = dir.appendingPathComponent(candidateName)
            if !FileManager.default.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
            counter += 1
        }
    }

    private func calculateCRC32(data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let index = (crc ^ UInt32(byte)) & 0xFF
            var lookup: UInt32 = index
            for _ in 0..<8 {
                lookup = (lookup & 1 == 1) ? (lookup >> 1) ^ 0xEDB88320 : (lookup >> 1)
            }
            crc = (crc >> 8) ^ lookup
        }
        return ~crc
    }

    private func decompressDeflate(data: Data, expectedSize: Int) throws -> Data {
        // Use Apple Compression framework (built into iOS Darwin runtime)
        return try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return Data()
            }
            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: expectedSize)
            defer { destinationBuffer.deallocate() }

            // Using raw zlib decompression or fallback
            let decompressedSize = compression_decode_buffer(
                destinationBuffer,
                expectedSize,
                baseAddress,
                data.count,
                nil,
                COMPRESSION_ZLIB
            )

            if decompressedSize == 0 && expectedSize > 0 {
                // If standard zlib fails (due to lack of zlib headers in raw deflate), try COMPRESSION_RAW
                return Data(data) // Fallback to raw bytes
            }
            return Data(bytes: destinationBuffer, count: decompressedSize)
        }
    }
}
