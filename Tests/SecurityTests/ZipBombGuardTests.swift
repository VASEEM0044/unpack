import XCTest
@testable import Unpack

final class ZipBombGuardTests: XCTestCase {

    func testHighCompressionRatioThrowsZipBomb() {
        let guardTracker = ZipBombGuard(limits: .standard)

        // 10 MB uncompressed, compressed into 50 KB (Ratio = 200:1, exceeding standard 100:1 limit)
        let uncompressedSize: Int64 = 10 * 1024 * 1024
        let compressedSize: Int64 = 50 * 1024

        XCTAssertThrowsError(
            try guardTracker.validateEntryMetadata(
                uncompressedSize: uncompressedSize,
                compressedSize: compressedSize
            )
        ) { error in
            guard case ArchiveSecurityError.excessiveCompressionRatio = error else {
                XCTFail("Expected excessiveCompressionRatio error but got \(error)")
                return
            }
        }
    }

    func testSmallFileWithHighRatioIsPermitted() throws {
        let guardTracker = ZipBombGuard(limits: .standard)

        // 100 KB uncompressed (below 1 MB threshold)
        let uncompressedSize: Int64 = 100 * 1024
        let compressedSize: Int64 = 100 // 1000:1 ratio, but total bytes too small to pose DoS risk

        XCTAssertNoThrow(
            try guardTracker.validateEntryMetadata(
                uncompressedSize: uncompressedSize,
                compressedSize: compressedSize
            )
        )
    }

    func testAccumulatedBytesLimitTriggersCutoff() {
        var limits = ZipBombGuard.Limits.standard
        limits.maxTotalBytes = 100 * 1024 * 1024 // 100 MB test limit
        let guardTracker = ZipBombGuard(limits: limits)

        XCTAssertNoThrow(try guardTracker.recordStreamChunk(bytes: 60 * 1024 * 1024))
        
        // Exceeds 100 MB
        XCTAssertThrowsError(
            try guardTracker.recordStreamChunk(bytes: 50 * 1024 * 1024)
        ) { error in
            guard case ArchiveSecurityError.excessiveUncompressedSize = error else {
                XCTFail("Expected excessiveUncompressedSize error but got \(error)")
                return
            }
        }
    }

    func testAccumulatedFileCountLimitTriggersCutoff() {
        var limits = ZipBombGuard.Limits.standard
        limits.maxFileCount = 3
        let guardTracker = ZipBombGuard(limits: limits)

        XCTAssertNoThrow(try guardTracker.recordFileCompleted())
        XCTAssertNoThrow(try guardTracker.recordFileCompleted())
        XCTAssertNoThrow(try guardTracker.recordFileCompleted())

        // 4th file exceeds limit of 3
        XCTAssertThrowsError(
            try guardTracker.recordFileCompleted()
        ) { error in
            guard case ArchiveSecurityError.excessiveFileCount = error else {
                XCTFail("Expected excessiveFileCount error but got \(error)")
                return
            }
        }
    }
}
